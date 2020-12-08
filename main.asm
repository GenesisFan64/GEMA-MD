; ===========================================================================
; +-----------------------------------------------------------------+
; SEGA GENESIS GAME TEMPLATE
; +-----------------------------------------------------------------+

		cpu 68000				; [AS] Current CPU is 68000
		padding off				; [AS] Don't pad dc.b
		listing purecode			; [AS] Want listing file, but only the final code in expanded macros
		supmode on 				; [AS] Supervisor mode
		page 0
		
; ====================================================================
; ----------------------------------------------------------------
; Include variables
; ----------------------------------------------------------------

		include "system/macros.asm"		; Assembler macros
		include "system/md/const.asm"		; Variables and constants
		include "system/md/map.asm"		; Memory map
		include "game/global.asm"		; Global variables and RAM

; ====================================================================
; ----------------------------------------------------------------
; Header
; ----------------------------------------------------------------

		include "system/head.asm"		; Header and initialization

; ====================================================================
; CODE Section
; ====================================================================

; ====================================================================
; ----------------------------------------------------------------
; System functions
; ----------------------------------------------------------------

		include "system/md/sound/main.asm"	; Sound
		include "system/md/video.asm"		; Video
		include "system/md/system.asm"		; System

; ====================================================================
; ----------------------------------------------------------------
; HBlank
; ----------------------------------------------------------------

MD_HBlank:
		rte				; Return from Exception

; ====================================================================
; ----------------------------------------------------------------
; VBlank
; ----------------------------------------------------------------

; MD_VBlank:
; 		rte				; Return from Exception

; ====================================================================
; ----------------------------------------------------------------
; Main
; ----------------------------------------------------------------

MD_Main:
		bsr	Sound_Init		; Init Sound (and the Z80)
		bsr	Video_Init		; Init Video (default VDP setup)
		bsr	System_Init		; Init System (user input)

; ================================================================
; ------------------------------------------------------------
; Your 68000 code starts here
; ------------------------------------------------------------

CodeBank:
		include	"game/code.asm"

		align $8000
TEST_WAV:
		binclude "FEEL.wav",$2C,$3587E4
TEST_WAV_E:
		
; ====================================================================

ROM_END:	rompad (ROM_END&$FF0000)+$10000
