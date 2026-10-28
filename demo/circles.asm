; ===========================================================================
; Circles demo for the teletext graphics library
;
;   A filled ball bounces around the screen, sliding partly off the edges
;   (showing the clipping), while rings ripple outwards from the centre.
;   Everything is drawn in XOR mode, so the rings invert where they cross
;   the ball. Press any key to exit.
;
;   Circles are corrected for the teletext pixel shape (pixels are wider
;   than they are tall), so they look round on screen even though they are
;   narrower than they are tall in pixels.
;
;   Loading: tgl.bin at $1000 (TGL_BASE below), circles.bin at $2000.
;   Run from START ($2000). Works with either machine's library build.
;
;   Circle calls: A,B = centre x,y (signed), X = radius (0-127).
;
;   Build with -D TESTFRAMES=n to stop after n frames (emulator tests).
; ===========================================================================

TGL_BASE        EQU     $1000
                INCLUDE "tgl_api.inc"

BUFFER          EQU     $3000           ; off-screen buffer (960 bytes)
STACK_TOP       EQU     $0200           ; stack $0100-$01FF

CX              EQU     38              ; centre of the ripples
CY              EQU     35
NRINGS          EQU     3               ; rings on screen at once
RING_GAP        EQU     12              ; spacing between rings (pixels)
RING_MAX        EQU     NRINGS*RING_GAP ; a ring restarts at the centre here

BALL_R          EQU     8               ; ball radius
BX_LO           EQU     -6              ; ball centre limits: a little beyond
BX_HI           EQU     83              ;  the screen edges, so the ball
BY_LO           EQU     -6              ;  slides partly out of view
BY_HI           EQU     77

; Page-zero variables (the library uses $00-$37)
BALLX           EQU     $80             ; ball centre (signed)
BALLY           EQU     $81
BALLDX          EQU     $82             ; ball velocity (signed)
BALLDY          EQU     $83
PHASE           EQU     $84             ; ripple phase, 0 .. RING_GAP-1
RING            EQU     $85             ; radius of the ring being drawn
FRAMES          EQU     $86             ; frame counter (test builds)

                ORG     $2000

START           LDS     #STACK_TOP
                CLRA                    ; DP = $00 for the library
                TFR     A,DP
                SETDP   $00
                ANDCC   #$EF            ; IRQs on (keyboard)
                JSR     TGL_INIT
                LDX     #BUFFER
                JSR     TGL_SETBUF
                LDA     #TGL_MODE_XOR   ; everything is drawn in XOR
                JSR     TGL_SETMODE
                LDD     #$1410          ; ball starts at (20,16) ...
                STD     <BALLX
                LDD     #$0201          ; ... moving right 2, down 1
                STD     <BALLDX
                CLR     <PHASE
                CLR     <FRAMES

; ---------------------------------------------------------------------------
; Main loop
; ---------------------------------------------------------------------------
FRAME           JSR     TGL_CLS

; The ball: move it (bouncing off the limits), then draw it filled
                LDA     <BALLX          ; new x = x + dx
                ADDA    <BALLDX
                CMPA    #BX_LO          ; outside the limits? (signed, as
                BLT     BL_XF           ;  the centre can go negative)
                CMPA    #BX_HI
                BLE     BL_XOK
BL_XF           NEG     <BALLDX         ; bounce: reverse, move the other way
                LDA     <BALLX
                ADDA    <BALLDX
BL_XOK          STA     <BALLX
                LDA     <BALLY          ; the same for y
                ADDA    <BALLDY
                CMPA    #BY_LO
                BLT     BL_YF
                CMPA    #BY_HI
                BLE     BL_YOK
BL_YF           NEG     <BALLDY
                LDA     <BALLY
                ADDA    <BALLDY
BL_YOK          STA     <BALLY
                LDA     <BALLX          ; A,B = centre
                LDB     <BALLY
                LDX     #BALL_R         ; X = radius
                JSR     TGL_CIRCF

; The rings: radii PHASE, PHASE+GAP, PHASE+2*GAP. As PHASE counts up to
; GAP-1 and wraps to 0, every ring grows by one pixel per frame, and the
; outermost one reappears at the centre - so the rings seem to ripple
; outwards for ever.
                LDA     <PHASE
                STA     <RING
RG_LOOP         CLRA                    ; X = radius: D = 0:RING, then
                LDB     <RING           ;  copied to X
                TFR     D,X
                LDA     #CX             ; A,B = centre
                LDB     #CY
                JSR     TGL_CIRC
                LDA     <RING           ; next ring out
                ADDA    #RING_GAP
                STA     <RING
                CMPA    #RING_MAX
                BLO     RG_LOOP

                LDA     <PHASE          ; advance the ripple
                INCA
                CMPA    #RING_GAP
                BLO     PH_OK
                CLRA
PH_OK           STA     <PHASE

                JSR     TGL_BLIT        ; show the frame
                JSR     TGL_INKEY       ; any key exits
                LBNE    TGL_EXIT
                IFDEF   TESTFRAMES
                INC     <FRAMES
                LDA     <FRAMES
                CMPA    #TESTFRAMES
                BEQ     DONE
                ENDC
                LBRA    FRAME
DONE            BRA     DONE
