; ================================================================
; ------------------------------------------------------------
; Your game code starts here
; 
; No restrictions unless porting to Sega CD or 32X
; ------------------------------------------------------------

; ====================================================================
; ----------------------------------------------------------------
; Variables
; ----------------------------------------------------------------

; VAR_MAXSONGS	equ	((list_TrackData_e-list_TrackData)>>4)-1
VAR_MAXTRACK	equ	1

; ====================================================================
; ----------------------------------------------------------------
; RAM
; ----------------------------------------------------------------

		struct RAM_Local
RAM_PlyrCurrIds	ds.w 2
RAM_PlyrCurrVol	ds.w 2
RAM_CurrTrack	ds.w 1
RAM_CurrSelect	ds.w 1
		finish

; ====================================================================
; ----------------------------------------------------------------
; Init
; ----------------------------------------------------------------

		bsr	Video_Clear
		or.b	#%00000010,(RAM_VdpCache+$C).l
		bsr	Video_Update
		move.l	#Art_PrintFont,d0
		move.w	#(Art_PrintFont_e-Art_PrintFont),d1
		move.w	#$20,d2
		bsr	Video_LoadArt
		lea	Pal_FmScreen(pc),a0
		moveq	#0,d0
		move.w	#63,d1
		bsr	Video_LoadPal
		
		lea	str_Title(pc),a0
		move.l	#locate(0,1,1),d0
		bsr	Video_Print
		
; ====================================================================
; ----------------------------------------------------------------
; Loop
; ----------------------------------------------------------------

FmEd_Loop:
		move.w	(vdp_ctrl),d4
		btst	#bitVBlnk,d4
		beq.s	FmEd_Loop
		bsr	System_Input
.wait:		move.w	(vdp_ctrl),d4
		btst	#bitVBlnk,d4
		bne.s	.wait

		move.w	(Controller_1+on_press).l,d3
		btst	#bitJoyC,d3
		beq.s	.noc
		nop
		nop
		nop
.noc:

		bra	FmEd_Loop
		
; ====================================================================
; ----------------------------------------------------------------
; VBlank
; ----------------------------------------------------------------

MD_VBlank:
		rte
		
; ====================================================================
; ----------------------------------------------------------------
; Subs
; ----------------------------------------------------------------

; SndTest_Update:
; 		lea	(RAM_PlyrCurrIds),a2
; 		move.l	#locate(0,11,9),d0
; 		moveq	#1,d3
; .nextone:
; 		swap	d3
; 		move.w	#"0",d1
; 		cmp.w	(RAM_CurrTrack),d3
; 		bne.s	.noequltr
; 		tst.w	(RAM_CurrSelect)
; 		bne.s	.noequltr
; 		add.w	#$2000,d1
; .noequltr:
; 		move.w	(a2)+,d2
; 		bsr	ShowVal_custom
; 		add.l	#$000002,d0
; 		add.w	#1,d3
; 		swap	d3
; 		dbf	d3,.nextone
; 		
; 		lea	(RAM_PlyrCurrVol),a2
; 		move.l	#locate(0,19,9),d0
; 		moveq	#1,d3
; .nextone2:
; 		swap	d3
; 		move.w	#"0",d1
; 		cmp.w	(RAM_CurrTrack),d3
; 		bne.s	.noequltr2
; 		tst.w	(RAM_CurrSelect)
; 		beq.s	.noequltr2
; 		add.w	#$2000,d1
; .noequltr2:
; 		move.w	(a2)+,d2
; 		bsr	ShowVal_custom
; 		add.l	#$000002,d0
; 		add.w	#1,d3
; 		swap	d3
; 		dbf	d3,.nextone2
; 		
; 		rts
; 
; SndTest_PlaySound:
; 		move.w	(RAM_CurrTrack),d3
; 		move.w	d3,d4
; 		add.w	d4,d4
; 		moveq	#0,d2
; 		lea	(RAM_PlyrCurrVol),a0
; 		move.w	(a0,d4.w),d2
; 		ror.l	#8,d2
; 		lea	list_TrackData(pc),a0
; 		lsl.w	#4,d0
; 		adda	d0,a0
; 		move.l	(a0)+,d0
; 		move.l	(a0)+,d1
; 		or.l	(a0)+,d2
; 		move.w	(RAM_CurrTrack),d3
; 		bra	Sound_SetTrack
; 
; ShowVal_custom:
; 		bsr	vid_PickLayer
; 		lea	(vdp_data),a6
; 		move.l	d4,4(a6)
; 		move.w	d2,d4
; 		lsr.w	#4,d4
; 		and.w	#%1111,d4
; 		cmp.w	#10,d4
; 		bcs.s	.lowa
; 		add.w	#7,d4
; .lowa:
; 		add.w	d1,d4
; 		move.w	d4,(a6)
; 		
; 		move.w	d2,d4
; 		and.w	#%1111,d4
; 		cmp.w	#10,d4
; 		bcs.s	.lowa2
; 		add.w	#7,d4
; .lowa2:
; 		add.w	d1,d4
; 		move.w	d4,(a6)
; 		rts

; ====================================================================
; ----------------------------------------------------------------
; Small data
; ----------------------------------------------------------------

str_Title:	dc.b "GEMA Sound driver, ALPHA",0
		align 2
		
Pal_FmScreen:
		dc.w $0000,$0EEE,$0CCC,$0AAA,$0888,$0444,$000E,$0008
		dc.w $00EE,$0088,$00E0,$0080,$0E00,$0800,$0000,$0000
		dc.w $0000,$00AE,$008C,$006A,$0048,$0024,$000E,$0008
		dc.w $00EE,$0088,$00E0,$0080,$0E00,$0800,$0000,$0000
		dc.w $0000,$0AAA,$0888,$0666,$0444,$0222,$0000,$0000
		dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w $0000,$0E00,$0C00,$0A00,$0800,$0400,$0000,$0000
		dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		align 2

; list_TrackData:
; 		dc.w MusicBlk_TestMe&$FFFF
; 		dc.w MusicPat_TestMe&$FFFF
; 		dc.w MusicIns_TestMe&$FFFF
; 		dc.w (ZSnd_MusicBank>>15)
; 		dc.b 0
; 		dc.b 0
; 		dc.b 0
; 		dc.b 4
; 		dc.l 0
; 		
; 		dc.w MusicBlk_Jackrab&$FFFF
; 		dc.w MusicPat_Jackrab&$FFFF
; 		dc.w MusicIns_Jackrab&$FFFF
; 		dc.w (ZSnd_MusicBank>>15)
; 		dc.b 0
; 		dc.b 0
; 		dc.b 0
; 		dc.b 6
; 		dc.l 0
; 		
; 		dc.w MusicBlk_Gigalo&$FFFF
; 		dc.w MusicPat_Gigalo&$FFFF
; 		dc.w MusicIns_Gigalo&$FFFF
; 		dc.w (ZSnd_MusicBank>>15)
; 		dc.b 0
; 		dc.b 0
; 		dc.b 0
; 		dc.b 2
; 		dc.l 0

list_TrackData_e:
		align 2
