; ===========================================================================
; Circles demo for the teletext graphics library
;
;   A filled ball bounces around the screen, sliding partly off the edges
;   (showing the clipping), while rings ripple outwards from the centre.
;   Everything is drawn in XOR mode, so the rings invert where they cross
;   the ball. The screen is coloured in six rainbow bands that scroll slowly
;   downwards, and the status row shows a coloured title.
;   Press any key to exit.
;
;   Teletext colours whole rows: each row of character cells starts with a
;   colour code, which the library keeps in column 0. TGL_COLOUR sets it
;   for a band of rows and the library remembers it, so TGL_CLS keeps the
;   colours from frame to frame. Changing colours costs no drawing time.
;
;   Circles are corrected for the teletext pixel shape (pixels are wider
;   than they are tall), so they look round on screen even though they are
;   narrower than they are tall in pixels.
;
;   Loading: tgl.bin at $1000 (TGL_BASE below), circles.bin at $2800.
;   Run from START ($2800). Works with either machine's library build.
;
;   Circle calls: A,B = centre x,y (signed), X = radius (0-127).
;
;   Build with -D TESTFRAMES=n to stop after n frames (emulator tests).
; ===========================================================================

TGL_BASE        EQU     $1000
                INCLUDE "tgl_api.inc"

BUFFER          EQU     $3800           ; off-screen buffer (960 bytes)
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
SHIFT           EQU     $87             ; rainbow position, 0-5
CYC             EQU     $88             ; frames until the rainbow moves
BAND            EQU     $89             ; band being coloured, 0-5

NBANDS          EQU     6               ; six bands of four rows = 24 rows
CYCLE           EQU     4               ; frames between rainbow moves

                ORG     $2800

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
                CLR     <SHIFT
                LDA     #1              ; colour the bands on the first frame
                STA     <CYC
                CLRA                    ; status row title, at column 0
                LDX     #TITLE
                JSR     TGL_TEXT

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

; The rainbow. Every CYCLE frames each band takes the colour of the band
; above it, so the colours scroll downwards. Band b (rows 4b to 4b+3) gets
; RAINBOW[(b - SHIFT) mod 6]. The library remembers row colours, so this
; only needs doing when they change.
                DEC     <CYC
                BNE     RB_DONE
                LDA     #CYCLE
                STA     <CYC
                CLR     <BAND
RB_LOOP         LDA     <BAND           ; colour index = (band - shift) mod 6
                SUBA    <SHIFT
                BPL     RB_1
                ADDA    #NBANDS
RB_1            LEAX    RAINBOW,PCR     ; B = colour for this band
                LDB     A,X
                CLRA                    ; X = colour
                TFR     D,X
                LDA     <BAND           ; A = first row = band * 4
                ASLA
                ASLA
                TFR     A,B             ; B = last row = first + 3
                ADDB    #3
                JSR     TGL_COLOUR
                INC     <BAND
                LDA     <BAND
                CMPA    #NBANDS
                BLO     RB_LOOP
                LDA     <SHIFT          ; move the rainbow on for next time
                INCA
                CMPA    #NBANDS
                BLO     RB_2
                CLRA
RB_2            STA     <SHIFT
RB_DONE

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

; Rainbow order: red, yellow, green, cyan, blue, magenta
RAINBOW         FCB     TGL_RED,TGL_YELLOW,TGL_GREEN,TGL_CYAN,TGL_BLUE,TGL_MAGENTA

; Status row title: $83 yellow, $86 cyan and $82 green text codes
TITLE           FCB     $83
                FCC     "CIRCLES"
                FCB     $86
                FCC     "AND"
                FCB     $82
                FCC     "COLOUR"
                FCB     0
