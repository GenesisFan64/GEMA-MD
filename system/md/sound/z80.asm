; ====================================================================
; ----------------------------------------------------------------
; GEMA sound driver, inspired by GEMS
; 
; WARNING: any code change will desync the sample rate and
; need to re-manually sync it.
; DAC sample rate is 16000hz aprox.
; ----------------------------------------------------------------

; --------------------------------------------------------
; Variables
; --------------------------------------------------------

; To brute force DAC playback on/off
zopcEx		equ	08h
zopcNop		equ	00h
zopcRet		equ 	0C9h
zopcExx		equ	0D9h			; (dac_me ONLY)
zopcPushAf	equ	0F5h			; (dac_fill ONLY)

; PSG control      
COM		equ	0
LEV		equ	4
ATK		equ	8
DKY		equ	12
SLV		equ	16
RRT		equ	20
MODE		equ	24
DTL		equ	28
DTH		equ	32
ALV		equ	36
FLG		equ	40
			      
; --------------------------------------------------------
; Macros
; --------------------------------------------------------

; only uses A
dacStream	macro option
	if option==True
		ld	a,2Bh
		ld	(4000h),a
		ld	a,80h
		ld	(4001h),a
		ld 	a,zopcExx
		ld	(dac_me),a
		ld 	a,zopcPushAf
		ld	(dac_fill),a
	else
		ld	a,2Bh
		ld	(4000h),a
		ld	a,00h
		ld	(4001h),a
		ld 	a,zopcRet
		ld	(dac_me),a
		ld 	a,zopcRet
		ld	(dac_fill),a
	endif
		endm
		
; ====================================================================

		di				; Disable interrputs
		im	1			; Interrupt mode 1
		ld	sp,2000h		; Set stack at the end of Z80
		jr	z80_init		; Jump to z80_init
		
; --------------------------------------------------------
; Z80 Interrupt at 0038h
; 
; Requests a TICK
; --------------------------------------------------------

		org 0038h			; Align to 0038h
		ld	(TICKFLG),sp		; Use sp to set TICK request
		di				; Disable interrupt until next request
		ret

; --------------------------------------------------------
; Initilize
; --------------------------------------------------------

z80_init:
		call	SndDrv_Init		; Initilize VBLANK sound driver
		call	dac_reset
		ei

; --------------------------------------------------------
; MAIN LOOP
; --------------------------------------------------------

drv_loop:
		call	dac_me			; Do 1 sample
		call	checktick		; Check for tick on VBlank
		call	dac_me			; Another sample
		call	dac_fill		; Refill wave data
		ld	b,0			; b - Current song speed flags
		ld	a,(TICKCNT)		
		sub	1
		jr	c,.noticks
		ld	(TICKCNT),a
		call	psg_env			; Do PSG effects
		call	checktick		; Check for another tick
		ld 	b,1			; Set TICK flag
.noticks:
		call	dac_me
		ld	a,(SBPTACC+1)		; check beat counter (scaled by tempo)
		sub	1
		jr	c,.nobeats
		ld	(SBPTACC+1),a		; 1/24 beat passed.
		set	1,b			; Set BEAT flag
.nobeats:
		ld	a,b
		or	a
		jr	z,.neithertick
		ld	(TBASEFLAGS),a
; 		call	doenvelope
		call	checktick
; 		call	vtimer
		call	checktick
; 		call	updseq
		call	checktick
.neithertick:
			      
		call	dac_me
		ld	b,7
		djnz	$
		call	dac_me
		ld	b,7
		djnz	$

		jp	drv_loop

; Mandar WAVE usando entre:
; 		call	dac_me
; 		call	dac_fill
; y
; 		call	dac_me
; 		ld	b,8		; codigo va
; 		djnz	$		; aqui

; ====================================================================
; ----------------------------------------------------------------
; Sound code
; ----------------------------------------------------------------

; --------------------------------------------------------
; Init sound engine
; --------------------------------------------------------

SndDrv_Init:
		ld	hl,dWaveFifo			; Initilize WAVE FIFO
		ld	de,dWaveFifo+1
		ld	bc,100h-1
		ld	(hl),80h
		ldir
		ld	de,220Bh			; LFO 03h
		call	SndDrv_FmSet_1
		ld	de,2700h
		call	SndDrv_FmSet_1
		ld	de,2800h
		call	SndDrv_FmSet_1
		ld	de,2801h
		call	SndDrv_FmSet_1
		ld	de,2802h
		call	SndDrv_FmSet_1
		ld	de,2804h
		call	SndDrv_FmSet_1
		ld	de,2805h
		call	SndDrv_FmSet_1
		ld	de,2806h
		call	SndDrv_FmSet_1
		ld	de,2B00h
		call	SndDrv_FmSet_1
		ld	a,09Fh
		ld	(Zpsg_ctrl),a
		ld	a,0BFh
		ld	(Zpsg_ctrl),a		
		ld	a,0DFh
		ld	(Zpsg_ctrl),a	
		ld	a,0FFh
		ld	(Zpsg_ctrl),a
		dacStream False
		ret
		
; ====================================================================
; ----------------------------------------------------------------
; Subroutines
; ----------------------------------------------------------------

; --------------------------------------------------------
; checktick
; 
; Checks if VBlank triggred a TICK (1/150)
;
; Input (EXX):
;  c - WAVEFIFO pointer MSB
; de - Pitch (00.00)
; hl - FIFO LSB
; --------------------------------------------------------

checktick:
		di
		push	af
		push	hl
		ld	hl,TICKFLG+1
		ld	a,(hl)
		or 	a
		jr	z,.ctnotick
						; Now we are inside VBlank
		ld	(hl),0			; ints are disabled here
		inc	hl			; go to counter
		inc	(hl)
		call	dac_me
		push	de
		ld	hl,(SBPTACC)
		ld	de,(SBPT)
		add	hl,de
		ld	(SBPTACC),hl
		pop	de
		call	dac_me
.ctnotick:
		pop	hl
		pop	af
		ei
		ret

; --------------------------------------------------------
; psg_env
; 
; Processes the PSG to add effects
; --------------------------------------------------------

psg_env:
		ld	iy,psgcom
		ld	hl,Zpsg_ctrl
		ld	d,80h			; PSG first ctrl command
		ld	e,4			; 4 channels
.vloop:
		call	dac_me
		ld	c,(iy+COM)		; c - current command
		ld	(iy+COM),0		; reset
.stop:
		bit	2,c
		jr	z,.ckof
		ld	(iy+LEV),-1
		ld	(iy+FLG),1
		ld	(iy+MODE),0
		ld	a,1
		cp	e
		jr	nz,.ckof
		ld	IX,PSGVTBLTG3
		res	5,(ix)
.ckof:
		bit	1,c
		jr      z,.ckon
		ld	a,(iy+MODE)
		cp	0
		jr	z,.ckon
		ld	(iy+FLG),1
		ld	(iy+MODE),4
.ckon:
		bit	0,c
		jr	z,.envproc
		ld	(iy+LEV),-1
		ld	a,(iy+DTL)
		or	D
		ld	(HL),a
		ld	a,1
		cp	E
		jr	z,.nskip
		ld	a,(iy+DTH)
		ld	(Zpsg_ctrl),a
.nskip:
		ld	(iy+FLG),1
		ld	(iy+MODE),1
	
	; ----------------------------
	; Start processing
.envproc:
		call	dac_me
		ld	a,(iy+MODE)
		cp	0		; no modes
		jp	z,.vedlp
		cp 	1		; attack mode
		jr	nz,.chk2
.mode1:
		ld	(iy+FLG),1
		ld	a,(iy+LEV)
		ld	b,(iy+ALV)
		sub	a,(iy+ATK)
		jr	c,.atkend
		jr	z,.atkend
		ld	(iy+LEV),a
		jp	.vedlp
.atkend:
		ld	(iy+LEV),b
		ld	(iy+MODE),2
		jp	.vedlp
.chk2:
		cp	2		; decay mode
		jp	nz,.chk4
		ld	(iy+FLG),1
		ld	a,(iy+LEV)
		ld	b,(iy+SLV)
		cp	b
		jr	c,.dkadd
		jr	z,.dkyend
		sub	(iy+DKY)
		jr	c,.dkyend
		cp	b
		jr	c,.dkyend
		jr	.dksav
.dkadd:
		add	a,(iy+DKY)
		jr	c,.dkyend
		cp	b
		jr	nc,.dkyend
.dksav:
		ld	(iy+LEV),a
		jr	.vedlp
.dkyend:
		ld	(iy+LEV),b
		ld	(iy+MODE),3
		jr	.vedlp
.chk4:
		cp	4		; sustain phase
		jr	nz,.vedlp
		ld	(iy+FLG),1
		ld	a,(iy+LEV)
		add 	a,(iy+RRT)
		jr	c,.killenv
		ld	(iy+LEV),a
		jr	.vedlp
.killenv:
		ld	(iy+LEV),-1
		ld	(iy+MODE),0
		ld	a,1
		cp	e
		jr	nz,.vedlp
		ld	ix,PSGVTBLTG3
		res	5,(ix)
.vedlp:
		inc	iy
		ld	a,20h
		add	a,d
		ld	d,a
		dec	e
		jp	nz,.vloop
		
	; ----------------------------
	; Set volumes
		call	dac_me
		ld	iy,psgcom
		ld	ix,Zpsg_ctrl
		ld	de,20h
		ld	b,4
		ld	hl,90h
.nextpsg:
		add	hl,de
		bit	0,(iy+FLG)
		jr	z,.flgoff
		ld	(iy+FLG),0
		ld	a,(iy+LEV)
		srl	a
		srl	a
		srl	a
		srl	a
		or	l
		ld	(ix),a
.flgoff:
		add	hl,de
		inc	iy
		djnz	.nextpsg
		call	dac_me
		ret

; 		call	dac_me
; 		ld	iy,psgcom
; 		ld	b,4
; 		ld	e,90h
; .uch1:
; 		bit	0,(iy+FLG)
; 		jr	z,.uch2
; 		ld	(iy+FLG),0
; 		ld	a,(iy+LEV)
; 		srl	a
; 		srl	a
; 		srl	a
; 		srl	a
; 		or	90h
; 		ld	(hl),a
; .uch2:
; 		bit	0,(iy+(FLG+1))
; 		jr	z,.uch3
; 		ld	(iy+(FLG+1)),0
; 		ld	a,(iy+(LEV+1))
; 		srl	a
; 		srl	a
; 		srl	a
; 		srl	a
; 		or	0B0h
; 		ld	(hl),a
; .uch3:
; 		bit	0,(iy+(FLG+2))
; 		jr	z,.uch4
; 		ld	(iy+(FLG+2)),0
; 		ld	a,(iy+(LEV+2))
; 		srl	a
; 		srl	a
; 		srl	a
; 		srl	a
; 		or	0D0h
; 		ld	(hl),a
; .uch4:
; 		bit	0,(iy+(FLG+3))
; 		jr	z,.vquit
; 		ld	(iy+(FLG+3)),0
; 		ld	a,(iy+(LEV+3))
; 		srl	a
; 		srl	a
; 		srl	a
; 		srl	a
; 		or	0F0h
; 		ld	(hl),a
; .vquit:
; 		call	dac_me
; 		ret

; --------------------------------------------------------
; dac_me
; 
; Writes wave data to DAC using data stored on FIFO.
; Call this routine every 6 or more lines of code
; (use any emu-debugger to check if it still plays
; at 16000hz)
;
; Input (EXX):
;  c - WAVEFIFO pointer MSB
; de - Pitch (00.00)
; hl - FIFO LSB
;
; *** self-modifiable code ***
; --------------------------------------------------------

dac_me:		exx				; <-- self-changes between EXX(play) and RET(stop)
		ex	af,af'
		ld	b,l
		ld	l,h
		ld	h,c
		ld	a,2Ah
		ld	(4000h),a
		ld	a,(hl)
		ld	(4001h),a
		ld	h,l
		ld	l,b
		add	hl,de
		ex	af,af'
		exx
		ret

; --------------------------------------------------------
; dac_fill
; 
; Refill half of the WAVE FIFO data
; if it reaches the end of one of the
; top or bottom sections
; 
; *** self-modifiable code ***
; --------------------------------------------------------

dac_fill:	push	af			; <-- self-changes between PUSH AF(play) and RET(stop)
		ld	a,(dDacFifoMid)
		exx
		xor	h			; xx.00
		exx
		and	80h
		jp	nz,dac_refill
		pop	af
		ret
		
; first time
dac_firstfill:
; 		call	drv_chktick
		push	af

; auto-fill
dac_refill:
		call	dac_me
		push	bc
		push	de
		push	hl
		ld	a,(wav_Flags)
		cp	111b
		jp	nc,.FDF7

		ld	a,(dDacCntr+2)
		ld	hl,(dDacCntr)
		ld	bc,80h
		scf
		ccf
		sbc	hl,bc
		sbc	a,0
		ld	(dDacCntr+2),a
		ld	(dDacCntr),hl
		ld	d,dWaveFifo>>8
		or	a
		jp	m,.FDF4DONE
; 		jr	c,.FDF4DONE
; 		jr	z,.FDF4DONE
.keepcntr:

		ld	a,(dDacFifoMid)
		ld	e,a
		add 	a,80h
		ld	(dDacFifoMid),a
		ld	hl,(dDacPntr)
		ld	a,(dDacPntr+2)
		call	transferRom
		ld	hl,(dDacPntr)
		ld	a,(dDacPntr+2)
		ld	bc,80h
		add	hl,bc
		adc	a,0
		ld	(dDacPntr),hl
		ld	(dDacPntr+2),a
		jp	.FDFreturn
.FDF4DONE:
		ld	d,dWaveFifo>>8
		ld	a,(wav_Flags)
		cp	101b
		jp	z,.FDF72
		
		ld	a,l
		add	a,80h
		ld	c,a
		ld	b,0
		push	bc
		ld	a,(dDacFifoMid)
		ld	e,a
		add	a,80h
		ld	(dDacFifoMid),a
		pop	bc			; C <- # just xfered
		ld	a,c
		or	b
		jr	z,.FDF7
		ld	hl,(dDacPntr)
		ld	a,(dDacPntr+2)
		call	transferRom
		jr	.FDF7
.FDF72:

	; loop sample
		push	bc
		push	de
		ld	a,(wave_Loop+2)
		ld	c,a
		ld	de,(wave_Loop)
		ld	hl,(wave_Start)
		ld 	a,(wave_Start+2)
		add	a,c
		add	hl,de
		adc	a,0
		ld	(dDacPntr),hl
		ld	(dDacPntr+2),a
		ld	hl,(wave_End)
		ld 	a,(wave_End+2)
		sub	a,c
		scf
		ccf
		sbc	hl,de
		sbc	a,0
		ld	(dDacCntr),hl
		ld	(dDacCntr+2),a
		pop	de
		pop	bc
		ld	a,b
		or	c
		jr	z,.FDFreturn
		ld	a,(dDacFifoMid)
		ld	e,a
		add	a,80h
		ld	(dDacFifoMid),a
		ld	hl,(dDacPntr)
		ld	a,(dDacPntr+2)
		call	transferRom
		jr	.FDFreturn
.FDF7:
		dacStream False
.FDFreturn:
		pop	hl
		pop	de
		pop	bc
		pop	af
		ret

; --------------------------------------------------------
; dac_reset
; 
; Plays a new sample
; --------------------------------------------------------

dac_reset:
		exx
		ld	bc,dWaveFifo>>8			; bc - 0
		ld	de,(wave_Pitch)			; de - Pitch
		ld	hl,0				; hl - FIFO pointer (00.00)
		exx
		ld	hl,(wave_Start)
		ld 	a,(wave_Start+2)
		ld	(dDacPntr),hl
		ld	(dDacPntr+2),a
		ld	hl,(wave_End)
		ld 	a,(wave_End+2)
		ld	(dDacCntr),hl
		ld	(dDacCntr+2),a
		call	dac_firstfill
		dacStream True
		ret

; --------------------------------------------------------
; transferRom
; 
; Transfer bytes from ROM to Z80
; 
; Input:
; a  - Source ROM address xx0000
;  c - Byte count (0000h NOT allowed)
; hl - Source ROM address 00xxxx
; de - Destination address
; 
; Uses:
; b , ix
; --------------------------------------------------------

transferRom:
		call	dac_me
		push	ix
		ld	ix,cpuComm
		ld	(x68ksrclsb),hl
		res	7,h
		ld	b,0
		dec	c
		add	hl,bc
		bit	7,h
		jr	nz,.half_way
		ld	hl,(x68ksrclsb)
		inc	c
		ld	b,a
		call	.transfer
		pop	ix
.badlen:
		ret
.half_way:

		ld	b,a
		push	bc
		push	hl
		ld	a,c
		sub	a,l
		ld	c,a
		ld	hl,(x68ksrclsb)
		call	.transfer
		pop	hl
		pop	bc
		ld	c,l
		inc	c
		ld	a,(x68ksrcmid)
		and	80h
		add	a,80h
		ld	h,a
		ld	l,0
		jr	nc,.x68knocarry
		inc	b
.x68knocarry:
		call	.transfer
		pop	ix
		ret

; b  - Source ROM xx0000
;  c - Bytes to transfer (00h not allowed)
; hl - Source ROM 00xxxx
; de - Destination address
; 
; Uses:
; a
.transfer:
		call	dac_me
		push	de
		ld	de,6000h
		ld	a,h
		rlc	a
		ld	(de),a
		ld	a,b
		ld	(de),a
		rra
		ld	(de),a
		rra
		ld	(de),a
		rra
		ld	(de),a
		rra
		ld	(de),a
		rra
		ld	(de),a
		rra
		ld	(de),a
		rra
		ld	(de),a
		pop	de
		call	dac_me
		set	7,h

	; Transfer data in parts of 3bytes
	; while playing DAC in the
	; process
		ld	a,c
		ld	b,0
		set	0,(ix+1)
		sub	a,3
		jr	c,.x68klast
.x68kloop:
		ld	c,3-1
		bit	0,(ix)
		jr	nz,.x68klpwt
.x68klpcont:
		ldir
		call	dac_me
		nop
		nop
; 		nop
		sub	a,3-1
		jp	nc,.x68kloop
.x68klast:
		add	a,3
		ld	c,a
		bit	0,(ix)
		jp	nz,.x68klstwt
.x68klstcont:
		ldir
		call	dac_me
		call	dac_fill
		res	0,(ix+1)
		ret

; If 68k wants to DMA...
; TODO: This MIGHT cause the DAC to ran out of data

.x68klpwt:
		res	0,(ix+1)
.x68kpwtlp:
		call	dac_me
		bit	0,(ix)
		jr	nz,.x68kpwtlp
		set	0,(ix+1)
		jr	.x68klpcont
.x68klstwt:
		res	0,(ix+1)
.x68klstwtlp:
		call	dac_me
		bit	0,(ix)
		jr	nz,.x68klstwtlp
		set	0,(ix+1)
		jr	.x68klstcont

; ---------------------------------------------
; FM send registers
; 
; Input:
; d - ctrl
; e - data
; c - channel
; ---------------------------------------------

SndDrv_FmSet_1:
		ld	a,d
		ld	(Zym_ctrl_1),a
		nop
		ld	a,e
		ld	(Zym_data_1),a
		nop
		ret

SndDrv_FmSet_2:
		ld	a,d
		ld	(Zym_ctrl_2),a
		nop
		ld	a,e
		ld	(Zym_data_2),a
		nop	
		ret

; ====================================================================
; ----------------------------------------------------------------
; Tables
; ----------------------------------------------------------------

fmFreq_List:	dw 644			; C-0
		dw 681
		dw 722
		dw 765
		dw 810
		dw 858
		dw 910
		dw 964
		dw 1021
		dw 1081
		dw 1146
		dw 1214

psgFreq_List:
		dw -1		; C-0 $0
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1		; C-1 $C
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1		; C-2 $18
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1		; C-3 $24
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw -1
		dw 3F8h
		dw 3BFh
		dw 389h
		dw 356h		;C-4 30
		dw 326h
		dw 2F9h
		dw 2CEh
		dw 2A5h
		dw 280h
		dw 25Ch
		dw 23Ah
		dw 21Ah
		dw 1FBh
		dw 1DFh
		dw 1C4h
		dw 1ABh		;C-5 3C
		dw 193h
		dw 17Dh
		dw 167h
		dw 153h
		dw 140h
		dw 12Eh
		dw 11Dh
		dw 10Dh
		dw 0FEh
		dw 0EFh
		dw 0E2h
		dw 0D6h		;C-6 48
		dw 0C9h
		dw 0BEh
		dw 0B4h
		dw 0A9h
		dw 0A0h
		dw 97h
		dw 8Fh
		dw 87h
		dw 7Fh
		dw 78h
		dw 71h
		dw 6Bh		; C-7 54
		dw 65h
		dw 5Fh
		dw 5Ah
		dw 55h
		dw 50h
		dw 4Bh
		dw 47h
		dw 43h
		dw 40h
		dw 3Ch
		dw 39h
		dw 36h		; C-8 $60
		dw 33h
		dw 30h
		dw 2Dh
		dw 2Bh
		dw 28h
		dw 26h
		dw 24h
		dw 22h
		dw 20h
		dw 1Fh
		dw 1Dh
		dw 1Bh		; C-9 $6C
		dw 1Ah
		dw 18h
		dw 17h
		dw 16h
		dw 15h
		dw 13h
		dw 12h
		dw 11h
 		dw 10h
 		dw 9h
 		dw 8h
		dw 0		; use +60 if using C-5 for tone 3 noise
		
wavFreq_List:	dw 100h		; C-0
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h	
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h		; C-1
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h	
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h		; C-2
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 03Bh
		dw 03Eh		; C-3 5512
		dw 043h		; C#3
		dw 046h		; D-3
		dw 049h		; D#3
		dw 04Eh		; E-3
		dw 054h		; F-3
		dw 058h		; F#3
		dw 05Eh		; G-3 8363 -17
		dw 063h		; G#3
		dw 068h		; A-3
		dw 070h		; A#3
		dw 075h		; B-3
		dw 07Fh		; C-4 11025 -12
		dw 088h		; C#4
		dw 08Fh		; D-4
		dw 097h		; D#4
		dw 0A0h		; E-4
		dw 0ADh		; F-4
		dw 0B5h		; F#4
		dw 0C0h		; G-4
		dw 0CCh		; G#4
		dw 0D7h		; A-4
		dw 0E7h		; A#4
		dw 0F0h		; B-4
		dw 100h		; C-5 22050
		dw 110h		; C#5
		dw 120h		; D-5
		dw 12Ch		; D#5
		dw 142h		; E-5
		dw 158h		; F-5
		dw 16Ah		; F#5 32000 +6
		dw 17Eh		; G-5
		dw 190h		; G#5
		dw 1ACh		; A-5
		dw 1C2h		; A#5
		dw 1E0h		; B-5
		dw 1F8h		; C-6 44100 +12
		dw 210h		; C#6
		dw 240h		; D-6
		dw 260h		; D#6
		dw 280h		; E-6
		dw 2A0h		; F-6
		dw 2D0h		; F#6
		dw 2F8h		; G-6
		dw 320h		; G#6
		dw 350h		; A-6
		dw 380h		; A#6
		dw 3C0h		; B-6
		dw 400h		; C-7 88200
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h	
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h	
		dw 100h		; C-8
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h	
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h	
		dw 100h		; C-9
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h	
		dw 100h
		dw 100h
		dw 100h
		dw 100h
		dw 100h

; ====================================================================
; ----------------------------------------------------------------
; MUSIC DATA
; ----------------------------------------------------------------

; ----------------------------------------------------
; PSG Instruments
; ----------------------------------------------------

PsgIns_00:	db 0
		db -1
PsgIns_01:	db 0,2,4,5,6
		db -1
PsgIns_02:	db 0,15
		db -1
PsgIns_03:	db 0,0,1,1,2,2,3,4,6,10,15
		db -1
PsgIns_04:	db 0,2,4,6,10
		db -1	
		align 4
		
; ----------------------------------------------------
; FM Instruments
; ----------------------------------------------------

; .gsx instruments; filename,$2478,$20 ($28 for FM3 instruments)
FmIns_Fm3_OpenHat:
		binclude "game/sound/instr/fm/fm3_openhat.gsx",2478h,28h
FmIns_Fm3_ClosedHat:
		binclude "game/sound/instr/fm/fm3_closedhat.gsx",2478h,28h
FmIns_DrumKick:
		binclude "game/sound/instr/fm/drum_kick.gsx",2478h,20h
FmIns_DrumSnare:
		binclude "game/sound/instr/fm/drum_snare.gsx",2478h,20h
FmIns_DrumCloseHat:
		binclude "game/sound/instr/fm/drum_closehat.gsx",2478h,20h
FmIns_Piano_m1:
		binclude "game/sound/instr/fm/piano_m1.gsx",2478h,20h
FmIns_Bass_gum:
		binclude "game/sound/instr/fm/bass_gum.gsx",2478h,20h
FmIns_Bass_calm:
		binclude "game/sound/instr/fm/bass_calm.gsx",2478h,20h
FmIns_Bass_heavy:
		binclude "game/sound/instr/fm/bass_heavy.gsx",2478h,20h
FmIns_Bass_ambient:
		binclude "game/sound/instr/fm/bass_ambient.gsx",2478h,20h
FmIns_Brass_gummy:
		binclude "game/sound/instr/fm/brass_gummy.gsx",2478h,20h
FmIns_Flaute_1:
		binclude "game/sound/instr/fm/flaute_1.gsx",2478h,20h
FmIns_Bass_2:
		binclude "game/sound/instr/fm/bass_2.gsx",2478h,20h
FmIns_Bass_3:
		binclude "game/sound/instr/fm/bass_3.gsx",2478h,20h
FmIns_Bass_5:
		binclude "game/sound/instr/fm/bass_5.gsx",2478h,20h
FmIns_Bass_synth:
		binclude "game/sound/instr/fm/bass_synth_1.gsx",2478h,20h
FmIns_Guitar_1:
		binclude "game/sound/instr/fm/guitar_1.gsx",2478h,20h
FmIns_Horn_1:
		binclude "game/sound/instr/fm/horn_1.gsx",2478h,20h
FmIns_Organ_M1:
		binclude "game/sound/instr/fm/organ_m1.gsx",2478h,20h
FmIns_Bass_Beach:
		binclude "game/sound/instr/fm/bass_beach.gsx",2478h,20h
FmIns_Bass_Beach_2:
		binclude "game/sound/instr/fm/bass_beach_2.gsx",2478h,20h
FmIns_Brass_Cave:
		binclude "game/sound/instr/fm/brass_cave.gsx",2478h,20h
FmIns_Piano_Small:
		binclude "game/sound/instr/fm/piano_small.gsx",2478h,20h
FmIns_Trumpet_2:
		binclude "game/sound/instr/fm/trumpet_2.gsx",2478h,20h
FmIns_Bell_Glass:
		binclude "game/sound/instr/fm/bell_glass.gsx",2478h,20h
FmIns_Marimba_1:
		binclude "game/sound/instr/fm/marimba_1.gsx",2478h,20h
FmIns_Ambient_dark:
		binclude "game/sound/instr/fm/ambient_dark.gsx",2478h,20h
FmIns_Ambient_spook:
		binclude "game/sound/instr/fm/ambient_spook.gsx",2478h,20h
FmIns_Ding_toy:
		binclude "game/sound/instr/fm/ding_toy.gsx",2478h,20h

; ====================================================================
; ----------------------------------------------------------------
; Z80 RAM
; ----------------------------------------------------------------

		org 00F00h			; align to 0038h
patch_Data	ds 40h*16
wave_Start	dw TEST_WAV&0FFFFh
		db TEST_WAV>>16&0FFh
wave_End	dw (TEST_WAV_E-TEST_WAV)&0FFFFh
		db (TEST_WAV_E-TEST_WAV)>>16
wave_Loop	dw 0
		db 0
wave_Pitch	dw 100h
wav_Flags	db 101b				; WAVE playback flags (%1xx: 01 loop / 10 end)

		org 01C00h			; align to 0038h
dWaveFifo	ds 100h
cpuComm		db 0,0				; 68k ROM block flag, z80 response bit
MBOXES		db 32
TICKFLG		dw 0				; Use TICKFLG+1 for reading/reseting
TICKCNT		db 0
SBPT		dw 204				; sub beats per tick (8frac), default is 120bpm
SBPTACC		dw 0				; accumulates ^^ each tick to track sub beats
TBASEFLAGS	db 0			      
dDacPntr	db 0,0,0			; WAVE current position
dDacCntr	db 0,0,0			; WAVE fileread counter
dDacFifoMid	db 0
x68ksrclsb	db 0
x68ksrcmid	db 0
commRead	db 0				; read pointer (here)
commWrite	db 0				; cmd fifo wptr (from 68k)

psgcom		db 00h,00h,00h,00h		;  0 command 1 = key on, 2 = key off, 4 = stop snd
psglev		db 0FFh,0FFh,0FFh,0FFh		;  4 output level attenuation (4 bit)
psgatk		db 00h,00h,00h,00h		;  8 attack rate
psgdec		db 00h,00h,00h,00h		; 12 decay rate
psgslv		db 00h,00h,00h,00h		; 16 sustain level attenuation
psgrrt		db 00h,00h,00h,00h		; 20 release rate
psgenv		db 00h,00h,00h,00h		; 24 envelope mode 0 = off, 1 = attack, 2 = decay, 3 = sustain, 4
psgdtl		db 00h,00h,00h,00h		; 28 tone bottom 4 bits, noise bits
psgdth		db 00h,00h,00h,00h		; 32 tone upper 6 bits
psgalv		db 00h,00h,00h,00h		; 36 attack level attenuation
whdflg		db 00h,00h,00h,00h		; 40 flags to indicate hardware should be updated

; dynamic chip allocation
FMVTBL		db 080H,0,050H,0,0,0,0		; fm voice 0
		db 081H,0,050H,0,0,0,0		; fm voice 1
		db 084H,0,050H,0,0,0,0		; fm voice 3
		db 085H,0,050H,0,0,0,0		; fm voice 4
FMVTBLCH6	db 086H,0,050H,0,0,0,0		; fm voice 5 (supports digital)
FMVTBLCH3	db 082H,0,050H,0,0,0,0		; fm voice 2 (supports CH3 poly mode)
		db -1
PSGVTBL		db 080H,0,050H,0,0,0,0		; normal type voice, number 0
		db 081H,0,050H,0,0,0,0		; normal type voice, number 1
PSGVTBLTG3	db 082H,0,050H,0,0,0,0		; normal type voice, number 2
		db -1
PSGVTBLNG	db 083H,0,050H,0,0,0,0		; noise type voice, number 3
		db -1
	
; START: 68k direct pointer ($xxxxxx)
; LOOP:  sampleloop point
; END:   endpointer-startpointer

