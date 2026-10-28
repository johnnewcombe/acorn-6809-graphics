; ===========================================================================
; Rectangles demo for the teletext graphics library
;
;   Four filled boxes drift around the screen and bounce, drawn in XOR mode:
;   where boxes overlap, their pixels cancel out, so the overlaps show as
;   holes and the pattern keeps changing. The boxes bounce off limits a
;   little beyond the screen edges, so they keep sliding partly out of view
;   (showing the clipping). Two fixed outline frames, also in XOR, invert
;   wherever a box crosses them. The status row below the graphics shows a
;   coloured title and a frame counter. Press any key to exit.
;
;   Loading: tgl.bin at $1000 (TGL_BASE below), boxes.bin at $2000.
;   Run from START ($2000). Works with either machine's library build.
;
;   Rectangle calls take two opposite corners: A,B = x0,y0 and
;   X = x1:y1 (x1 in the high byte), signed, in any order.
;
;   Build with -D TESTFRAMES=n to stop after n frames (emulator tests).
; ===========================================================================

TGL_BASE        EQU     $1000
                INCLUDE "tgl_api.inc"

BUFFER          EQU     $3000           ; off-screen buffer (960 bytes)
STACK_TOP       EQU     $0200           ; stack $0100-$01FF

; How far beyond the screen the boxes may travel before bouncing
X_LO            EQU     -12             ; left limit for a box's left edge
X_HI            EQU     78+12           ; right limit for its right edge + 1
Y_LO            EQU     -9              ; top limit for its top edge
Y_HI            EQU     72+9            ; bottom limit for its bottom edge + 1

; Page-zero variables (the library uses $00-$2B)
BOXN            EQU     $80             ; boxes left to process
FRAMES          EQU     $81             ; frame counter (test builds)
FCOUNT          EQU     $82             ; frame counter shown on the status
                                        ;  row (16 bits, $82-$83)

                ORG     $2000

START           LDS     #STACK_TOP
                CLRA                    ; DP = $00 for the library
                TFR     A,DP
                SETDP   $00
                ANDCC   #$EF            ; IRQs on (keyboard)
                JSR     TGL_INIT
                LDX     #BUFFER
                JSR     TGL_SETBUF
                CLR     <FRAMES
                LDX     #0              ; frame counter starts at 0
                STX     <FCOUNT

; The status row: written once, since the blit never touches it
                CLRA                    ; column 0
                LDX     #TITLE
                JSR     TGL_TEXT

; ---------------------------------------------------------------------------
; Main loop
; ---------------------------------------------------------------------------
FRAME           JSR     TGL_CLS
                LDA     #TGL_MODE_XOR   ; everything this frame is XORed
                JSR     TGL_SETMODE

; Move and draw each box. U walks through the box table, one record per box.
                LEAU    BOXES,PCR
                LDA     #NBOXES
                STA     <BOXN
BX_LOOP         BSR     MOVEBOX         ; update position, bouncing
                LDA     BX_X,U          ; draw it: corner (x, y) ...
                ADDA    BX_W,U          ; ... to (x+w-1, y+h-1)
                DECA
                LDB     BX_Y,U
                ADDB    BX_H,U
                DECB
                TFR     D,X             ; X = x1:y1
                LDA     BX_X,U          ; A,B = x0,y0
                LDB     BX_Y,U
                JSR     TGL_RECTF
                LEAU    BX_SIZE,U       ; next box
                DEC     <BOXN
                BNE     BX_LOOP

; Two fixed outline frames, also in XOR
                CLRA                    ; round the whole screen: (0,0)
                CLRB
                LDX     #$4D47          ;  to (77,71)
                JSR     TGL_RECT
                LDA     #12             ; and an inner frame: (12,9)
                LDB     #9
                LDX     #$413E          ;  to (65,62)
                JSR     TGL_RECT

                JSR     TGL_BLIT        ; show the frame

                LDX     <FCOUNT         ; count the frame and show it on the
                LEAX    1,X             ;  status row (straight to the screen,
                STX     <FCOUNT         ;  five characters, right-aligned)
                LDA     #NUMCOL
                JSR     TGL_TNUM

                JSR     TGL_INKEY       ; any key exits
                LBNE    TGL_EXIT
                IFDEF   TESTFRAMES
                INC     <FRAMES
                LDA     <FRAMES
                CMPA    #TESTFRAMES
                BEQ     DONE
                ENDC
                BRA     FRAME
DONE            BRA     DONE

; ---------------------------------------------------------------------------
; MOVEBOX - move the box at U by its velocity, bouncing off the limits
;   A box bounces by reversing its velocity (NEG) and moving the other way
;   instead. The right/bottom limits depend on the box's size, so they are
;   worked out as limit - size and compared signed (BLT/BGT), since the
;   positions can be negative.
;   Entry: U -> box record    Exit: A, B corrupted
; ---------------------------------------------------------------------------
MOVEBOX         LDA     BX_X,U          ; new x = x + dx
                ADDA    BX_DX,U
                CMPA    #X_LO           ; past the left limit?
                BLT     MB_XFLIP
                LDB     #X_HI           ; past the right limit? (x > X_HI - w)
                SUBB    BX_W,U
                PSHS    B
                CMPA    ,S+
                BLE     MB_XOK
MB_XFLIP        NEG     BX_DX,U         ; bounce: reverse, move the other way
                LDA     BX_X,U
                ADDA    BX_DX,U
MB_XOK          STA     BX_X,U

                LDA     BX_Y,U          ; the same for y
                ADDA    BX_DY,U
                CMPA    #Y_LO
                BLT     MB_YFLIP
                LDB     #Y_HI
                SUBB    BX_H,U
                PSHS    B
                CMPA    ,S+
                BLE     MB_YOK
MB_YFLIP        NEG     BX_DY,U
                LDA     BX_Y,U
                ADDA    BX_DY,U
MB_YOK          STA     BX_Y,U
                RTS

; ---------------------------------------------------------------------------
; The boxes. Each record: x, y (top-left, signed), dx, dy (velocity per
; frame, signed), w, h (size in pixels). Positions and velocities change as
; the demo runs.
; ---------------------------------------------------------------------------
BX_X            EQU     0
BX_Y            EQU     1
BX_DX           EQU     2
BX_DY           EQU     3
BX_W            EQU     4
BX_H            EQU     5
BX_SIZE         EQU     6

; ---------------------------------------------------------------------------
; Status row text. $83 and $86 are teletext control codes: yellow text and
; cyan text from that point along the row. Each takes up one character
; position. The frame number goes in the five columns after "FRAME ".
; ---------------------------------------------------------------------------
TITLE           FCB     $83
                FCC     "RECTANGLES DEMO"
                FCB     $86
                FCC     "FRAME"
                FCB     0
NUMCOL          EQU     23              ; 1 + 15 + 1 + 5 = 22 characters,
                                        ;  plus a space

BOXES           FCB     4,6,1,1,30,20           ; wide box
                FCB     40,30,-2,1,24,30        ; tall box, faster
                FCB     20,45,2,-1,40,14        ; long flat box
                FCB     55,10,-1,-1,18,18       ; small square
NBOXES          EQU     4
