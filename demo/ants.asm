; ===========================================================================
; Marching ants demo for the teletext graphics library
;
;   A small scene (a ball and a box) with:
;     - a dashed box round it, in SET mode: on, on, off (the default
;       pattern), so its gaps clear any pixels they cross - it cuts into
;       the ball
;     - a second box inside with a longer pattern: 4 on, 4 off
;     - a diagonal dashed line across everything in XOR mode, marching the
;       other way
;   Each frame the phase moves on by one, so the dashes march: forwards
;   along a line, clockwise round a box. Press any key to exit.
;
;   Loading: tgl.bin at $1000 (TGL_BASE below), ants.bin at $2800.
;   Run from START ($2800). Works with either machine's library build.
;
;   Build with -D TESTFRAMES=n to stop after n frames (emulator tests).
; ===========================================================================

TGL_BASE        EQU     $1000
                INCLUDE "tgl_api.inc"

BUFFER          EQU     $3800           ; off-screen buffer (960 bytes)
STACK_TOP       EQU     $0200           ; stack $0100-$01FF
PACE_TICKS      EQU     3               ; 3 = about 17 frames per second

PHASE           EQU     $80             ; marching phase, counts up forever

                ORG     $2800

START           LDS     #STACK_TOP
                CLRA                    ; DP = $00 for the library
                TFR     A,DP
                SETDP   $00
                ANDCC   #$EF            ; IRQs on (keyboard)
                JSR     TGL_INIT
                LDX     #BUFFER
                JSR     TGL_SETBUF
                CLR     <PHASE
                CLRA                    ; status row title
                LDX     #TITLE
                JSR     TGL_TEXT

; ---------------------------------------------------------------------------
; Main loop
; ---------------------------------------------------------------------------
FRAME           JSR     TGL_CLS
                LDA     #TGL_MODE_SET   ; the scene
                JSR     TGL_SETMODE
                LDA     #16             ; a ball, partly inside the ants box
                LDB     #30
                LDX     #10
                JSR     TGL_CIRCF
                LDA     #42             ; a box
                LDB     #26
                LDX     #$3C30          ;  (42,26)-(60,48)
                JSR     TGL_RECTF

; Outer box: the default pattern (on, on, off), SET mode, so the gaps clear.
; TGL_SETDASH: A = pattern, B = length, X = phase. Moving the phase on by
; one each frame marches the dashes clockwise.
                LDB     <PHASE          ; X = phase (in the low byte)
                CLRA
                TFR     D,X
                LDA     #%011           ; A = pattern, B = length
                LDB     #3
                JSR     TGL_SETDASH
                LDA     #20             ; (20,10)-(70,60)
                LDB     #10
                LDX     #$463C
                JSR     TGL_RECTD

; Inner box: 4 on, 4 off
                LDB     <PHASE
                CLRA
                TFR     D,X
                LDA     #%00001111
                LDB     #8
                JSR     TGL_SETDASH
                LDA     #36             ; (36,20)-(64,52)
                LDB     #20
                LDX     #$4034
                JSR     TGL_RECTD

; The diagonal, in XOR: its gaps are left alone, so it runs over the scene
; without damaging it. Its phase counts down, so it marches the other way
; (from its end back towards its start).
                LDA     #TGL_MODE_XOR
                JSR     TGL_SETMODE
                LDB     <PHASE          ; X = -phase (low byte): counting
                NEGB                    ;  down marches the other way
                CLRA
                TFR     D,X
                LDA     #%011
                LDB     #3
                JSR     TGL_SETDASH
                LDA     #2              ; (2,69) up to (75,2)
                LDB     #69
                LDX     #$4B02
                JSR     TGL_LINED

                LDA     #PACE_TICKS
                JSR     TGL_PACE
                JSR     TGL_BLIT
                INC     <PHASE          ; march on one pixel
                JSR     TGL_INKEY       ; any key exits
                LBNE    TGL_EXIT
                IFDEF   TESTFRAMES      ; test builds stop after n frames
                LDA     <PHASE
                CMPA    #TESTFRAMES
                BEQ     DONE
                ENDC
                LBRA    FRAME
DONE            BRA     DONE

; Status row title. $83 yellow, $86 cyan text codes.
TITLE           FCB     $83
                FCC     "MARCHING ANTS"
                FCB     $86
                FCC     "ANY KEY EXITS"
                FCB     0
