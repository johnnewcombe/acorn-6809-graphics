; ===========================================================================
; Rotating cube demo for the teletext graphics library
;   Load tgl.bin at TGL_BASE and cube.bin at its ORG, then run from START.
;   Each frame: clear buffer, rotate and project 8 corners, draw 12 edges,
;   blit. Runs until reset (an exit will come with the FLEX exit work).
;
;   Rotation: corners are (+/-S, +/-S, +/-S), so once per frame the rotation
;   matrix is scaled by S into nine terms, and every rotated corner is just
;   a signed sum of three of them. Perspective uses reciprocal tables
;   indexed by depth, so projecting a coordinate is a single MUL.
;
;   Build with -D TESTFRAMES=n to stop after n frames (for the emulator test).
; ===========================================================================
TGL_BASE        EQU     $1000
                INCLUDE "tgl_api.inc"

BUFFER          EQU     $3000           ; off-screen buffer (960 bytes)
STACK_TOP       EQU     $0200

S               EQU     24              ; half the cube's edge length
CX              EQU     39              ; screen centre
CY              EQU     36
STEP_A          EQU     2               ; rotation speed about x, per frame
STEP_B          EQU     3               ; rotation speed about y, per frame

; Demo variables in page zero, clear of the library workspace ($00-$0C)
ANG_A           EQU     $80             ; rotation angle about x (0-255)
ANG_B           EQU     $81             ; rotation angle about y
SA              EQU     $82             ; sin/cos of the angles (127 = 1.0)
CA              EQU     $83
SB              EQU     $84
CB              EQU     $85
TX              EQU     $86             ; 3 terms: rotated x = sum of +/-TX
TY              EQU     $89             ; 3 terms for y
TZ              EQU     $8C             ; 3 terms for z
VI              EQU     $8F             ; current corner (bit0 x, bit1 y, bit2 z)
VX              EQU     $90             ; rotated x of current corner
ZI              EQU     $91             ; depth table index of current corner
EC              EQU     $92             ; edge counter
FRAMES          EQU     $93             ; frame counter (test builds)
PX              EQU     $A0             ; projected x of corners 0-7
PY              EQU     $A8             ; projected y of corners 0-7 (PX+8)

                ORG     $2000
START           LDS     #STACK_TOP
                CLRA
                TFR     A,DP
                SETDP   $00
                JSR     TGL_INIT
                LDX     #BUFFER
                JSR     TGL_SETBUF
                CLR     <ANG_A
                CLR     <ANG_B
                CLR     <FRAMES

FRAME           JSR     TGL_CLS
                BSR     MATRIX
                LBSR    CORNERS
                LBSR    EDGES
                JSR     TGL_BLIT
                LDA     <ANG_A
                ADDA    #STEP_A
                STA     <ANG_A
                LDA     <ANG_B
                ADDA    #STEP_B
                STA     <ANG_B
                IFDEF   TESTFRAMES
                INC     <FRAMES
                LDA     <FRAMES
                CMPA    #TESTFRAMES
                BEQ     DONE
                ENDC
                BRA     FRAME
DONE            BRA     DONE

; ---------------------------------------------------------------------------
; MATRIX - rotation about y (angle B) then x (angle A), scaled by S
;   Matrix rows (127 = 1.0):
;     x: [ cb,             0,   sb          ]
;     y: [ sb*sa,          ca, -cb*sa       ]
;     z: [ -sb*ca,         sa,  cb*ca       ]
; ---------------------------------------------------------------------------
MATRIX          LEAX    SINTAB,PCR      ; sin/cos of both angles (ABX: the
                LDB     <ANG_A          ;  index is unsigned 0-255)
                ABX
                LDA     ,X
                STA     <SA
                LEAX    SINTAB,PCR
                LDB     <ANG_A
                ADDB    #64
                ABX
                LDA     ,X
                STA     <CA
                LEAX    SINTAB,PCR
                LDB     <ANG_B
                ABX
                LDA     ,X
                STA     <SB
                LEAX    SINTAB,PCR
                LDB     <ANG_B
                ADDB    #64
                ABX
                LDA     ,X
                STA     <CB

                LDA     <CB             ; TX = S * [cb, 0, sb]
                LDB     #S
                BSR     MULS7
                STA     <TX
                CLR     <TX+1
                LDA     <SB
                LDB     #S
                BSR     MULS7
                STA     <TX+2

                LDA     <SB             ; TY = S * [sb*sa, ca, -cb*sa]
                LDB     <SA
                BSR     MULS7
                LDB     #S
                BSR     MULS7
                STA     <TY
                LDA     <CA
                LDB     #S
                BSR     MULS7
                STA     <TY+1
                LDA     <CB
                LDB     <SA
                BSR     MULS7
                NEGA
                LDB     #S
                BSR     MULS7
                STA     <TY+2

                LDA     <SB             ; TZ = S * [-sb*ca, sa, cb*ca]
                LDB     <CA
                BSR     MULS7
                NEGA
                LDB     #S
                BSR     MULS7
                STA     <TZ
                LDA     <SA
                LDB     #S
                BSR     MULS7
                STA     <TZ+1
                LDA     <CB
                LDB     <CA
                BSR     MULS7
                LDB     #S
                BSR     MULS7
                STA     <TZ+2
                RTS

; ---------------------------------------------------------------------------
; MULS7 - signed multiply, scaled: A = (A * B) / 128
;   A, B signed (-127..127). B corrupted.
; ---------------------------------------------------------------------------
MULS7           PSHS    D               ; 0,S = A, 1,S = B
                TSTA
                BPL     MS_1
                NEGA
MS_1            TSTB
                BPL     MS_2
                NEGB
MS_2            MUL                     ; D = |A| * |B|
                ASLB                    ; A = D / 128
                ROLA
                PSHS    A
                LDA     1,S             ; sign of the result = sign(A^B)
                EORA    2,S
                PULS    A               ; (PULS leaves the flags alone)
                BPL     MS_3
                NEGA
MS_3            LEAS    2,S
                RTS

; ---------------------------------------------------------------------------
; CORNERS - rotate and project all 8 corners into PX/PY
; ---------------------------------------------------------------------------
CORNERS         CLR     <VI
CN_LOOP         LDB     <VI
                LDU     #TX
                BSR     VSUM
                STA     <VX             ; rotated x
                LDU     #TZ
                BSR     VSUM            ; rotated z -> depth table index
                ADDA    #64
                STA     <ZI
                LDU     #TY
                BSR     VSUM            ; rotated y (kept in A)

                LEAX    RYTAB,PCR       ; screen y = CY + y * RY[z]
                LDB     <ZI
                ABX
                LDB     ,X
                BSR     PMUL
                ADDA    #CY
                LDX     #PY
                LDB     <VI
                ABX
                STA     ,X

                LEAX    RXTAB,PCR       ; screen x = CX + x * RX[z]
                LDB     <ZI
                ABX
                LDB     ,X
                LDA     <VX
                BSR     PMUL
                ADDA    #CX
                LDX     #PX
                LDB     <VI
                ABX
                STA     ,X

                INC     <VI
                LDA     <VI
                CMPA    #8
                BNE     CN_LOOP
                RTS

; ---------------------------------------------------------------------------
; VSUM - signed sum of three terms for one corner
;   Entry: U -> 3 terms, B = corner index (bit set = +, clear = -)
;   Exit:  A = sum. B preserved.
; ---------------------------------------------------------------------------
VSUM            CLRA
                BITB    #1
                BEQ     VS_1
                ADDA    ,U
                BRA     VS_2
VS_1            SUBA    ,U
VS_2            BITB    #2
                BEQ     VS_3
                ADDA    1,U
                BRA     VS_4
VS_3            SUBA    1,U
VS_4            BITB    #4
                BEQ     VS_5
                ADDA    2,U
                RTS
VS_5            SUBA    2,U
                RTS

; ---------------------------------------------------------------------------
; PMUL - projection multiply: A = (A * B) / 128
;   A signed, B unsigned scale (0-255). B corrupted.
; ---------------------------------------------------------------------------
PMUL            TSTA
                BPL     PM_1
                NEGA
                MUL
                ASLB
                ROLA
                NEGA
                RTS
PM_1            MUL
                ASLB
                ROLA
                RTS

; ---------------------------------------------------------------------------
; EDGES - draw the 12 edges from the projected corners
; ---------------------------------------------------------------------------
EDGES           LEAY    EDGETAB,PCR
                LDA     #12
                STA     <EC
ED_LOOP         LDX     #PX             ; end point -> U
                LDB     1,Y
                ABX
                LDA     ,X
                LDB     8,X
                TFR     D,U
                LDX     #PX             ; start point -> A,B
                LDB     ,Y
                ABX
                LDA     ,X
                LDB     8,X
                TFR     U,X             ; X = x1:y1
                JSR     TGL_LINE
                LEAY    2,Y
                DEC     <EC
                BNE     ED_LOOP
                RTS

; Corner pairs that differ in exactly one bit
EDGETAB         FCB     0,1,2,3,4,5,6,7         ; edges along x
                FCB     0,2,1,3,4,6,5,7         ; edges along y
                FCB     0,4,1,5,2,6,3,7         ; edges along z

                INCLUDE "cube_tables.asm"
