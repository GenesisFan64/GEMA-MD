; ====================================================================
; ----------------------------------------------------------------
; MD Sound
; ----------------------------------------------------------------

; ====================================================================
; ----------------------------------------------------------------
; Z80 Code
; ----------------------------------------------------------------

		align $100
Z80_CODE:
		cpu Z80				; [AS] Set to Z80
		phase 0				; [AS] Reset PC to zero, for this section
		
; ====================================================================
; Z80 goes here

		include "system/md/sound/z80.asm"
		
; ====================================================================

		cpu 68000
		padding off
		phase Z80_CODE+*
Z80_CODE_END:
		align 2

; ====================================================================
; ----------------------------------------------------------------
; Subroutines
; ----------------------------------------------------------------

; --------------------------------------------------------
; Init Sound
; 
; Uses:
; a0-a1,d0-d1
; --------------------------------------------------------

Sound_Init:
		move.w	#$0100,(z80_bus).l		; Stop Z80
		move.b	#1,(z80_reset).l		; Reset
.wait:
		btst	#0,(z80_bus).l			; Wait for it
		bne.s	.wait
		lea	(z80_cpu).l,a0
		move.w	#$1FFF,d0
		moveq	#0,d1
.cleanup:
		move.b	d1,(a0)+
		dbf	d0,.cleanup
		lea	(Z80_CODE).l,a0			; Send sound code
		lea	(z80_cpu).l,a1
		move.w	#(Z80_CODE_END-Z80_CODE)-1,d0
.copy:
		move.b	(a0)+,(a1)+
		dbf	d0,.copy
		move.b	#1,(z80_reset).l		; Reset
		nop 
		nop 
		nop 
		move.w	#0,(z80_bus).l
		rts

; --------------------------------------------------------
; Sound_DMA_Start
; 
; Call this before doing any DMA task
; --------------------------------------------------------

Sound_DMA_Start:
		move.w	sr,-(sp)
		or.w	#$700,sr
.retry:
		move.w	#$0100,(z80_bus).l		; Stop Z80
.wait:
		btst	#0,(z80_bus).l			; Wait for it
		bne.s	.wait
		move.b	#1,(z80_cpu+commZRomBlk)	; Tell Z80 we want the bus
		move.b	(z80_cpu+commZRomRd),d0		; Get mid-read bit
		move.w	#0,(z80_bus).l			; Resume Z80
		tst.b	d0
		beq.s	.safe
		moveq	#68,d0
		dbf	d0,*
		bra.s	.retry
.safe:
		move.w	(sp)+,sr
		rts

; --------------------------------------------------------
; Sound_DMA_End
; 
; Call this after finishing DMA
; --------------------------------------------------------

Sound_DMA_End:
		move.w	sr,-(sp)
		or.w	#$700,sr
		bsr	sndLockZ80
		move.b	#0,(z80_cpu+commZRomBlk)	
		bsr	sndUnlockZ80
		move.w	(sp)+,sr
		rts

; ------------------------------------------------

sndLockZ80:
		move.w	#$0100,(z80_bus).l		; Stop Z80
.wait:
		btst	#0,(z80_bus).l			; Wait for it
		bne.s	.wait
		rts
sndUnlockZ80:
		move.w	#0,(z80_bus).l
		rts
sndSendCmd:
		rts
