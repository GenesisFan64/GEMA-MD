; ====================================================================
; ----------------------------------------------------------------
; Z80 Code
; ----------------------------------------------------------------
		
; --------------------------------------------------------
; Init
; --------------------------------------------------------

		di				; Disable interrputs
		im	1			; Interrput mode 1
		ld	sp,2000h		; Set stack at the end of Z80
		jr	z80_init		; Jump to z80_init

; --------------------------------------------------------
; RST 0008h
; 
; Set ROM Bank
; ; a - 0xxx xxxx x0000 0000
; --------------------------------------------------------

		org 0008h
		push	hl
		ld	hl,zbank
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		xor	a			; 32X bit goes here
		ld	(hl),a
		pop	hl
		ret

; --------------------------------------------------------
; 
; --------------------------------------------------------

		org 0020h
wave_Head	ds 10h
		
; --------------------------------------------------------
; Z80 Interrupt at 0038h
; 
; VBlank only
; --------------------------------------------------------

		org 0038h			; align to 0038h
		jp	z80_int

; --------------------------------------------------------
; Z80 Init
; --------------------------------------------------------

z80_init:
		call	SndDrv_Init			; Initilize VBLANK sound driver

	; Sample request
		xor	a
		ld	(wave_Head+wvRead),a
		ld	hl,TEST_WAV&7FFFh|8000h		; START
		ld	de,TEST_WAV_E&7FFFh|8000h	; END	
		ld	bc,TEST_WAV&7FFFh|8000h		; START
		ld	(wave_Head+(wvRead+1)),hl
		ld	(wave_Head+wvEnd),de
		ld	(wave_Head+wvLoop),bc
		ld	a,TEST_WAV>>15
		ld	(wave_Head+wvReadB),a	
		ld	a,TEST_WAV_E>>15
		ld	(wave_Head+wvEndB),a
		ld	a,TEST_WAV>>15
		ld	(wave_Head+wvLoopB),a		
		ld	hl,100h
		ld	(wave_Head+wvPitch),hl
		ld	a,1
		ld	(wave_Head+wvFlags),a
		ei

; --------------------------------------------------------
; Sample playback
; --------------------------------------------------------

dac_loop:
		ld	a,(wave_Head+wvFlags)
		or	a
		jp	p,dac_request
		ld	hl,(wave_Head+(wvRead+1))
		
	; WAVE END CHECK
		rlca
		rlca
		jp	nc,.no_bnk
		rlca
		jp	nc,.no_mid
		ld	de,(wave_Head+(wvEnd))
		ld	a,l
		cp	e
		jp	c,.no_mid
		ld	a,(wave_Head+wvFlags)
		and	00001110b
		ld	(wave_Head+wvFlags),a
		ld	a,2Bh
		ld	(Zym_ctrl_1),a
		ld	a,00h
		ld	(Zym_data_1),a
		jp	dac_loop
.no_bnk:
		nop
		nop
		jp	.no_mid		; 3 cycle
.no_mid:
		ld	a,2Ah
		nop
		ld	(Zym_ctrl_1),a
		ld	a,(hl)
		ld	(wave_Head+wvCopy),a
		ld	(Zym_data_1),a
		ld	hl,(wave_Head+wvRead)
		ld	de,(wave_Head+wvPitch)
		add	hl,de
		jp	nc,.ch1_go
		ld	a,(wave_Head+(wvRead+2))
		inc 	a
		ld	(wave_Head+(wvRead+2)),a
		ld	de,(wave_Head+(wvEnd))
		cp	d
		jp	nz,.ch1_midok
		ld	e,a
		ld	a,(wave_Head+wvFlags)
		set	5,a
		ld	(wave_Head+wvFlags),a
		ld	a,e
.ch1_midok:	
		or	a
		jp	m,.ch1_go
		set	7,a
		ld 	(wave_Head+(wvRead+2)),a
		
	; ROM BANK
		ld	a,(wave_Head+wvEndB)
		ld	e,a
		ld	a,(wave_Head+wvReadB)
		inc 	a
		ld	(wave_Head+wvReadB),a
		cp	e
		jp	nz,.ch1_gob
		ld	e,a
		ld	a,(wave_Head+wvFlags)
		set	6,a
		res	5,a
		ld	(wave_Head+wvFlags),a
		ld	a,e
.ch1_gob:
		rst	8

.ch1_go:
		ld	(wave_Head+wvRead),hl
		jp	dac_loop
		
; --------------------------------------------------------

dac_request:
		rrca
		jp	c,dac_on
		rrca	
		jp	c,dac_off
		jp	dac_loop
		
; $01 - reset
dac_on:
		ld	a,(wave_Head+wvFlags)
		and	00001100b
		or	80h
		ld	(wave_Head+wvFlags),a
		ld	de,2B80h
		call	SndDrv_FmSet_1
		ld	a,(wave_Head+wvReadB)	; This BANK
		rst	8
		jp	dac_loop
; $02 - stop
dac_off:
		ld	a,(wave_Head+wvFlags)
		and	00001100b
		ld	(wave_Head+wvFlags),a
		ld	de,2B00h
		call	SndDrv_FmSet_1
		jp	dac_loop
		
; ====================================================================
; ----------------------------------------------------------------
; FM/PSG track player
; 
; ticks: 150 + trck_tempo_bits*10
; speed: trck_speed - 1
; ----------------------------------------------------------------

z80_int:
		di
; 		push	af
; 		exx

; ; ------------------------------------
; ; Read tracks
; ; ------------------------------------
; 
; 		ld	a,(curr_SndBank)		; Move ROM to music data
; 		rst 	8
; 		ld	iy,SndBuff_Track_1
; 		ld	ix,SndBuff_ChnlBuff_1
; 		call	SndDrv_ReadTrack
; 		ld	iy,SndBuff_Track_2
; 		ld	ix,SndBuff_ChnlBuff_2
; 		call	SndDrv_ReadTrack
; 
; ; ------------------------------------
; ; Exit Vint
; ; ------------------------------------
; 
; 		ld	a,(Sample_Read+3)		; Return ROM bank to sample
; 		rst 	8
; 		ld	d,2Ah				; Play last byte
; 		ld	hl,(Sample_Read+1)		; TODO: might read a bad byte (no EOF check)
; 		ld	e,(hl)
; 		call	SndDrv_FmSet_1

; ; ------------------------------------

; .no_trcks:
; 		exx
; 		pop	af
		ei
		ret					; Return

; ===================================================================
; ------------------------------------
; Init driver
; ------------------------------------

SndDrv_Init:
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
		ret

; ===================================================================
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
		dw 644|800h		; C-1
		dw 681|800h
		dw 722|800h
		dw 765|800h
		dw 810|800h
		dw 858|800h
		dw 910|800h
		dw 964|800h
		dw 1021|800h
		dw 1081|800h
		dw 1146|800h
		dw 1214|800h
		dw 644|1000h		; C-2
		dw 681|1000h
		dw 722|1000h
		dw 765|1000h
		dw 810|1000h
		dw 858|1000h
		dw 910|1000h
		dw 964|1000h
		dw 1021|1000h
		dw 1081|1000h
		dw 1146|1000h
		dw 1214|1000h
		dw 644|1800h		; C-3
		dw 681|1800h
		dw 722|1800h
		dw 765|1800h
		dw 810|1800h
		dw 858|1800h
		dw 910|1800h
		dw 964|1800h
		dw 1021|1800h
		dw 1081|1800h
		dw 1146|1800h
		dw 1214|1800h
		dw 644|2000h		; C-4
		dw 681|2000h
		dw 722|2000h
		dw 765|2000h
		dw 810|2000h
		dw 858|2000h
		dw 910|2000h
		dw 964|2000h
		dw 1021|2000h
		dw 1081|2000h
		dw 1146|2000h
		dw 1214|2000h
		dw 644|2800h		; C-5
		dw 681|2800h
		dw 722|2800h
		dw 765|2800h
		dw 810|2800h
		dw 858|2800h
		dw 910|2800h
		dw 964|2800h
		dw 1021|2800h
		dw 1081|2800h
		dw 1146|2800h
		dw 1214|2800h		
		dw 644|3000h		; C-6
		dw 681|3000h
		dw 722|3000h
		dw 765|3000h
		dw 810|3000h
		dw 858|3000h
		dw 910|3000h
		dw 964|3000h
		dw 1021|3000h
		dw 1081|3000h
		dw 1146|3000h
		dw 1214|3000h
		dw 644|3800h		; C-7
		dw 681|3800h
		dw 722|3800h
		dw 765|3800h
		dw 810|3800h
		dw 858|3800h
		dw 910|3800h
		dw 964|3800h
		dw 1021|3800h
		dw 1081|3800h
		dw 1146|3800h
		dw 1214|3800h

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
; Z80 RAM
; ----------------------------------------------------------------

		org 0FE0h			; align to 0038h

wave_Mix	ds 600h
wave_Blank	ds 100h

wvRead		equ 0				; 3 bytes 00.0080
wvReadB		equ 3
wvLoop		equ 4
wvLoopB		equ 6
wvEnd		equ 7
wvEndB		equ 9
wvPitch		equ 10
wvFlags		equ 12
wvCopy		equ 13

; ----------------------------------------------------
; Tracker data buffer
; ----------------------------------------------------

trck_ReqBlk	equ 00h		; word
trck_ReqPatt	equ 02h		; word
trck_ReqIns	equ 04h		; word
trck_ReqTicks	equ 06h
trck_ReqTempo	equ 07h
trck_ReqCurrBlk	equ 08h
trck_ReqSndBnk	equ 09h
trck_ReqFlag	equ 0Ah
trck_ReqChnls	equ 0Bh
trck_PsgNoise	equ 0Ch
trck_TicksRead	equ 0Dh
trck_BlockCurr	equ 0Eh
trck_MasterVol	equ 0Fh
trck_Priority	equ 10h
trck_Active	equ 11h
trck_Blocks	equ 12h		; word
trck_PattBase	equ 14h		; word
trck_Instr	equ 16h		; word
trck_PattRead	equ 18h		; word
trck_RowSteps	equ 1Ah		; word
trck_TicksMain 	equ 1Ch
trck_TempoBits	equ 1Dh
trck_RowWait	equ 1Eh
trck_TicksCurr	equ 1Fh
trck_Volume	equ 20h

; ----------------------------------------------------
; Tracker note buffers
; ----------------------------------------------------

chnl_Chip	equ 0
chnl_Type	equ 1
chnl_Note	equ 2
chnl_Ins	equ 3
chnl_Vol	equ 4
chnl_EffId	equ 5
chnl_EffArg	equ 6
chnl_InsAddr	equ 7		; word
chnl_Freq	equ 09h		; word
chnl_InsType	equ 0Bh
chnl_InsOpt	equ 0Ch
chnl_FmPan	equ 0Dh
chnl_FmRegB0	equ 0Eh
chnl_FmRegB4	equ 0Fh
chnl_FmRegKeys	equ 10h
chnl_FmVolBase	equ 11h
chnl_PsgVolBase	equ 12h
chnl_PsgVolEnv	equ 13h
chnl_PsgIndx	equ 14h
chnl_SmplFlags	equ 15h
chnl_EfVolSlide	equ 16h
chnl_EfNewVol	equ 17h
chnl_EfPortam	equ 18h		; word
chnl_EfNewFreq	equ 1Ah		; word
chnl_PsgOutFreq	equ 1Ch		; word

; ----------------------------------------------------
; Buffers
; ----------------------------------------------------

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
