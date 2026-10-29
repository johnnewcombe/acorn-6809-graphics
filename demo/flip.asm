; ===========================================================================
; Splash-screen flip demo for the teletext graphics library
;
;   Draws a deliberately lopsided picture (a letter F, a right-pointing
;   arrow and a ball, so the mirroring is easy to see), then turns it over
;   with TGL_FLIPH every couple of seconds: the picture narrows to the
;   centre line and opens out again mirror-reversed, like a card turning.
;   Press any key to exit.
;
;   Loading: tgl.bin at $1000 (TGL_BASE below), splash.bin at $2800.
;   Run from START ($2800). Works with either machine's library build.
;
;   TGL_FLIPH animates whatever is in the off-screen buffer and leaves the
;   buffer mirrored, so the next flip turns it back again.
; ===========================================================================

TGL_BASE        EQU     $1000
                INCLUDE "tgl_api.inc"

BUFFER          EQU     $3800           ; off-screen buffer (960 bytes)
STACK_TOP       EQU     $0200           ; stack $0100-$01FF

FLIP_TICKS      EQU     2               ; flip speed: 50Hz ticks per frame
                                        ;  (2 = about 0.7 s, 3 = about 1 s)
PAUSE           EQU     100             ; pause between flips, in 50Hz ticks

WAITN           EQU     $80             ; pause counter

                ORG     $2800

START           LDS     #STACK_TOP
                CLRA                    ; DP = $00 for the library
                TFR     A,DP
                SETDP   $00
                ANDCC   #$EF            ; IRQs on (keyboard)
                JSR     TGL_INIT
                LDX     #BUFFER
                JSR     TGL_SETBUF
                JSR     TGL_CLS
                CLRA                    ; status row title
                LDX     #TITLE
                JSR     TGL_TEXT

; ---------------------------------------------------------------------------
; The picture
; ---------------------------------------------------------------------------
                CLRA                    ; a frame round the screen
                CLRB
                LDX     #$4D47
                JSR     TGL_RECT
                LDA     #8              ; the letter F: upright ...
                LDB     #12
                LDX     #$0D3B          ;  (8,12)-(13,59)
                JSR     TGL_RECTF
                LDA     #14             ; ... top bar ...
                LDB     #12
                LDX     #$1E11          ;  (14,12)-(30,17)
                JSR     TGL_RECTF
                LDA     #14             ; ... and middle bar
                LDB     #32
                LDX     #$1824          ;  (14,32)-(24,36)
                JSR     TGL_RECTF
                LDX     #ARROW          ; the arrow, pointing right: its head
                JSR     TGL_POLYF
                LDX     #SHAFT          ;  and its shaft (an arrow isn't
                JSR     TGL_POLYF       ;  convex, so it is two polygons)
                LDA     #66             ; the ball, top right
                LDB     #16
                LDX     #7
                JSR     TGL_CIRCF
                JSR     TGL_BLIT

; ---------------------------------------------------------------------------
; Pause, flip, repeat (any key exits)
; ---------------------------------------------------------------------------
LOOP            LDA     #PAUSE          ; pause, checking for a key
                STA     <WAITN
WAIT            JSR     TGL_INKEY
                LBNE    TGL_EXIT
                LDA     #1              ; one 50Hz tick
                JSR     TGL_PACE
                DEC     <WAITN
                BNE     WAIT
                LDA     #FLIP_TICKS     ; turn the picture over
                JSR     TGL_FLIPH
                BRA     LOOP

; The arrow is not convex, so it is drawn as two convex polygons: a
; triangle for the head and a rectangle for the shaft
ARROW           FCB     3               ; head: a triangle pointing right
                FCB     50,20
                FCB     70,36
                FCB     50,52
SHAFT           FCB     4               ; shaft
                FCB     30,30
                FCB     50,30
                FCB     50,42
                FCB     30,42

; Status row title. $83 yellow, $86 cyan text codes.
TITLE           FCB     $83
                FCC     "SPLASH FLIP"
                FCB     $86
                FCC     "ANY KEY EXITS"
                FCB     0
