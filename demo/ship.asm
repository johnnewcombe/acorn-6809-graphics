; ===========================================================================
; Spaceship demo for the teletext graphics library
;
;   An original ship design (the "Kestrel" courier, defined in
;   tools/gen_ship_model.py) tumbles slowly in perspective, drawn as a
;   wireframe with hidden lines removed, so it looks solid.
;   Press any key to exit.
;
;   Loading: tgl.bin at $1000 (TGL_BASE below), ship.bin at $2800 (its ORG).
;   Run from START ($2800). Works with either machine's library build.
;
;   Each frame:
;     1. clear the off-screen buffer                       (TGL_CLS)
;     2. build the rotation matrix for this frame          (MATRIX)
;     3. rotate every corner and project it to the screen  (CORNERS)
;     4. decide which faces point towards the viewer       (FACES)
;     5. draw the edges that border a visible face         (EDGES)
;     6. copy the buffer to the screen                     (TGL_BLIT)
;
; ---------------------------------------------------------------------------
; How it differs from the cube demo
; ---------------------------------------------------------------------------
;
;   General rotation. The cube's corners were all (+/-S, +/-S, +/-S), which
;   allowed a shortcut. A ship's corners can be anywhere, so each one is
;   multiplied by the full 3x3 rotation matrix:
;
;       rotated x = (mx0*x + mx1*y + mx2*z) / 128     (likewise y and z)
;
;   That's nine signed multiplies per corner (SMUL16), summed in 16 bits.
;   The division by 128 is rounded rather than truncated, which matters for
;   the hidden-line test below.
;
;   Hidden-line removal. The hull is convex, so each face is either wholly
;   visible or wholly hidden. A face is visible when it points back towards
;   the viewer:
;
;       visible if  n . (P - eye) < 0
;
;   where n is the face's outward normal (the direction it faces), P is any
;   corner on the face, and the eye sits 100 units in front of the ship (the
;   viewing distance the projection tables assume).
;
;   Rather than rotate every face to meet the viewer, the demo turns the
;   viewer's position into the ship's own coordinates, once per frame. Then
;   n and P never change, so n . P is precomputed by the generator (C), and
;   each face costs just three multiplies:  visible if C - n . eye < 0.
;
;   Working this out in 3D, before projection, is far more reliable than
;   testing a face's corners on screen, where small faces are only a few
;   pixels across.
;
;   An edge is drawn if either face it borders is visible. Decal lines
;   (engine outlines, cockpit window) belong to a single face and vanish
;   with it.
;
;   The model data (corners, faces with normals, edges) is generated into
;   ship_model.asm by tools/gen_ship_model.py, which also checks the design
;   is convex and fits the projection tables.
;
;   Build with -D TESTFRAMES=n to stop after n frames (emulator tests).
; ===========================================================================

TGL_BASE        EQU     $1000
                INCLUDE "tgl_api.inc"

; ---------------------------------------------------------------------------
; Memory
; ---------------------------------------------------------------------------
BUFFER          EQU     $3800           ; off-screen buffer (960 bytes)
STACK_TOP       EQU     $0200           ; stack $0100-$01FF

; ---------------------------------------------------------------------------
; Settings you can change
; ---------------------------------------------------------------------------
CX              EQU     39              ; screen position of the ship's centre
CY              EQU     36
STEP_A          EQU     1               ; rotation speed about x (pitch)
STEP_B          EQU     2               ; rotation speed about y (yaw)
EYE_K           EQU     101             ; viewing distance, scaled by 128/127
                                        ;  (101 * 127/128 = 100, matching the
                                        ;  projection tables)

; ---------------------------------------------------------------------------
; Variables in page zero (the library uses $00-$17)
; ---------------------------------------------------------------------------
ANG_A           EQU     $80             ; pitch angle (0-255 = full turn)
ANG_B           EQU     $81             ; yaw angle
SA              EQU     $82             ; sin/cos of the angles (127 = 1.0)
CA              EQU     $83
SB              EQU     $84
CB              EQU     $85
MROWX           EQU     $86             ; rotation matrix, row x (3 bytes)
MROWY           EQU     $89             ;  row y (3 bytes)
MROWZ           EQU     $8C             ;  row z (3 bytes)
VEC             EQU     $8F             ; vector being rotated (3 bytes)
ACC             EQU     $92             ; 16-bit running sum
MT_A            EQU     $94             ; SMUL16's saved inputs
MT_B            EQU     $95
VI              EQU     $96             ; corner number being worked on
ZI              EQU     $97             ; its depth, as a projection table index
FI              EQU     $98             ; face number being worked on
EC              EQU     $99             ; edges left to draw
FRAMES          EQU     $9A             ; frame counter (test builds)
EX              EQU     $9B             ; the eye, in ship coordinates
EY              EQU     $9C
EZ              EQU     $9D
TMPX            EQU     $9E             ; rotated x of the current corner
PX              EQU     $A0             ; screen x of corners (32 bytes)
PY              EQU     $C0             ; screen y of corners: PX+32, so if X
                                        ;  points at PX+n, the y is at 32,X
VIS             EQU     $E0             ; per face: $FF visible, 0 hidden
                                        ;  (16 bytes)

                ORG     $2800

; ---------------------------------------------------------------------------
; Set up
; ---------------------------------------------------------------------------
START           LDS     #STACK_TOP
                CLRA                    ; DP = $00 for the library and for
                TFR     A,DP            ;  our page-zero variables
                SETDP   $00
                ANDCC   #$EF            ; IRQs on (keyboard)
                JSR     TGL_INIT
                LDX     #BUFFER
                JSR     TGL_SETBUF
                CLR     <ANG_A
                CLR     <ANG_B
                CLR     <FRAMES

; ---------------------------------------------------------------------------
; Main loop
; ---------------------------------------------------------------------------
FRAME           JSR     TGL_CLS
                LBSR    MATRIX
                LBSR    CORNERS
                LBSR    FACES
                LBSR    EDGES
                JSR     TGL_BLIT
                LDA     <ANG_A          ; advance the angles (they wrap from
                ADDA    #STEP_A         ;  255 to 0 by themselves)
                STA     <ANG_A
                LDA     <ANG_B
                ADDA    #STEP_B
                STA     <ANG_B
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
; MATRIX - rotation about y (yaw, angle B) then x (pitch, angle A)
;
;   The same matrix as the cube demo (see cube.asm for the derivation),
;   stored row by row so ROWDOT can walk along a row:
;
;     MROWX: [  cb,      0,    sb     ]
;     MROWY: [  sb*sa,   ca,  -cb*sa  ]
;     MROWZ: [ -sb*ca,   sa,   cb*ca  ]
; ---------------------------------------------------------------------------
MATRIX          LEAX    SINTAB,PCR      ; SA = sin(ANG_A)
                LDB     <ANG_A          ;  (ABX: unsigned index 0-255)
                ABX
                LDA     ,X
                STA     <SA
                LEAX    SINTAB,PCR      ; CA = cos(ANG_A) = sin(ANG_A + 64)
                LDB     <ANG_A
                ADDB    #64
                ABX
                LDA     ,X
                STA     <CA
                LEAX    SINTAB,PCR      ; SB = sin(ANG_B)
                LDB     <ANG_B
                ABX
                LDA     ,X
                STA     <SB
                LEAX    SINTAB,PCR      ; CB = cos(ANG_B)
                LDB     <ANG_B
                ADDB    #64
                ABX
                LDA     ,X
                STA     <CB

                LDA     <CB             ; row x
                STA     <MROWX
                CLR     <MROWX+1
                LDA     <SB
                STA     <MROWX+2

                LDA     <SB             ; row y
                LDB     <SA
                LBSR    MULS7           ;  sb*sa
                STA     <MROWY
                LDA     <CA
                STA     <MROWY+1
                LDA     <CB
                LDB     <SA
                LBSR    MULS7           ;  -cb*sa
                NEGA
                STA     <MROWY+2

                LDA     <SB             ; row z
                LDB     <CA
                LBSR    MULS7           ;  -sb*ca
                NEGA
                STA     <MROWZ
                LDA     <SA
                STA     <MROWZ+1
                LDA     <CB
                LDB     <CA
                LBSR    MULS7           ;  cb*ca
                STA     <MROWZ+2
                RTS

; ---------------------------------------------------------------------------
; CORNERS - rotate and project every corner
;
;   For each corner: copy it into VEC, take its dot product with each row
;   of the matrix to get the rotated x, y and z, and project to screen as
;   in the cube demo:
;     screen x = CX + x * RXTAB[z+64] / 128
;     screen y = CY + y * RYTAB[z+64] / 128
; ---------------------------------------------------------------------------
CORNERS         LEAY    SHIP_V,PCR      ; Y -> first corner's x, y, z
                CLR     <VI
CN_LOOP         LDD     ,Y              ; copy the corner into VEC
                STD     <VEC
                LDA     2,Y
                STA     <VEC+2

                LDU     #MROWX          ; rotated x
                LBSR    ROWDOT
                STA     <TMPX
                LDU     #MROWZ          ; rotated z
                LBSR    ROWDOT
                ADDA    #64             ; depth -> projection table index
                STA     <ZI
                LDU     #MROWY          ; rotated y, left in A
                LBSR    ROWDOT

                LEAX    RYTAB,PCR       ; screen y (rotated y still in A)
                LDB     <ZI
                ABX
                LDB     ,X
                LBSR    PMUL
                ADDA    #CY
                LDX     #PX             ; PY entry is at 32,X
                LDB     <VI
                ABX
                STA     32,X

                LEAX    RXTAB,PCR       ; screen x
                LDB     <ZI
                ABX
                LDB     ,X
                LDA     <TMPX
                LBSR    PMUL
                ADDA    #CX
                LDX     #PX
                LDB     <VI
                ABX
                STA     ,X

                LEAY    3,Y             ; next corner
                INC     <VI
                LDA     <VI
                CMPA    SHIP_NV,PCR
                LBNE    CN_LOOP
                RTS

; ---------------------------------------------------------------------------
; FACES - decide which faces point towards the viewer
;
;   First, the eye's position in ship coordinates. The eye is at (0, 0,
;   -100) in viewer coordinates; turning that back into ship coordinates
;   uses the matrix "the other way round" (its transpose), which for this
;   point picks out the z row:  eye = -100 * MROWZ / 127.
;
;   Then for each face, with C = n . P precomputed by the generator:
;
;       d = C - (nx*EX + ny*EY + nz*EZ)       visible if d < 0
; ---------------------------------------------------------------------------
FACES           LDA     <MROWZ          ; EX = MROWZ[0] * -EYE_K / 128
                LBSR    EYEC
                STA     <EX
                LDA     <MROWZ+1        ; EY
                LBSR    EYEC
                STA     <EY
                LDA     <MROWZ+2        ; EZ
                LBSR    EYEC
                STA     <EZ

                LEAY    SHIP_F,PCR      ; Y -> C (2 bytes), nx, ny, nz
                CLR     <FI
FC_LOOP         LDA     2,Y             ; n . eye
                LDB     <EX
                LBSR    SMUL16
                STD     <ACC
                LDA     3,Y
                LDB     <EY
                LBSR    SMUL16
                ADDD    <ACC
                STD     <ACC
                LDA     4,Y
                LDB     <EZ
                LBSR    SMUL16
                ADDD    <ACC
                STD     <ACC
                LDD     ,Y              ; d = C - n . eye
                SUBD    <ACC            ; N flag = sign of d
                BMI     FC_VIS          ; negative: facing the viewer
                CLRA                    ; hidden: VIS = 0
                BRA     FC_SET
FC_VIS          LDA     #$FF            ; visible: VIS = $FF
FC_SET          LDX     #VIS            ; store at VIS + face number
                LDB     <FI
                ABX
                STA     ,X
                LEAY    5,Y             ; next face
                INC     <FI
                LDA     <FI
                CMPA    SHIP_NF,PCR
                BNE     FC_LOOP
                RTS

; EYEC - one coordinate of the eye: A = (A * -EYE_K) / 128, rounded
EYEC            LDB     #-EYE_K
                LBSR    SMUL16
                ADDD    #64             ; round
                ASLB                    ; A = D / 128
                ROLA
                RTS

; ---------------------------------------------------------------------------
; EDGES - draw every edge that borders a visible face
;   Each edge: corner, corner, face, face. The generator's range check keeps
;   the ship on screen, so the faster unclipped TGL_LINE is safe here.
; ---------------------------------------------------------------------------
EDGES           LEAY    SHIP_E,PCR
                LDA     SHIP_NE,PCR
                STA     <EC
ED_LOOP         LDX     #VIS            ; visible if either face is
                LDB     2,Y
                ABX
                LDA     ,X
                LDX     #VIS
                LDB     3,Y
                ABX
                ORA     ,X
                BEQ     ED_NEXT
                LDX     #PX             ; end corner -> U
                LDB     1,Y
                ABX
                LDA     ,X
                LDB     32,X
                TFR     D,U
                LDX     #PX             ; start corner -> A, B
                LDB     ,Y
                ABX
                LDA     ,X
                LDB     32,X
                TFR     U,X             ; X = x1:y1
                JSR     TGL_LINE
ED_NEXT         LEAY    4,Y
                DEC     <EC
                BNE     ED_LOOP
                RTS

; ---------------------------------------------------------------------------
; SMULI - SMUL16 written out in place (a macro), for the inner loop
;   Same as SMUL16 below but saves the call and return, about 12 cycles,
;   which adds up over nine multiplies per corner. \1 makes the labels
;   unique each time the macro is used.
; ---------------------------------------------------------------------------
SMULI           MACRO
                STA     <MT_A
                STB     <MT_B
                MUL
                TST     <MT_A
                BPL     \1_1
                SUBA    <MT_B
\1_1            TST     <MT_B
                BPL     \1_2
                SUBA    <MT_A
\1_2
                ENDM

; ---------------------------------------------------------------------------
; ROWDOT - one row of the matrix times VEC, rounded: A = (row . VEC) / 128
;   Entry: U -> 3 matrix entries; VEC holds the vector
;   Exit:  A = result (signed). B corrupted.
;   Adding 64 before dividing by 128 rounds to nearest instead of always
;   rounding down. ASLB/ROLA doubles D, leaving D/128 in A.
; ---------------------------------------------------------------------------
ROWDOT          LDA     ,U              ; row[0] * VEC[0]
                LDB     <VEC
                SMULI   RD1
                STD     <ACC
                LDA     1,U             ; + row[1] * VEC[1]
                LDB     <VEC+1
                SMULI   RD2
                ADDD    <ACC
                STD     <ACC
                LDA     2,U             ; + row[2] * VEC[2]
                LDB     <VEC+2
                SMULI   RD3
                ADDD    <ACC
                ADDD    #64             ; round
                ASLB                    ; A = D / 128
                ROLA
                RTS

; ---------------------------------------------------------------------------
; SMUL16 - full signed multiply: D = A * B
;   Entry: A, B signed (-128..127)
;   Exit:  D = 16-bit signed product
;
;   MUL treats both bytes as unsigned. A negative byte a is read as a + 256,
;   so the unsigned product is too big by 256 * (the other byte) for each
;   negative input. Subtracting the other byte from the high byte (A) for
;   each negative input corrects it exactly - no sign juggling needed.
; ---------------------------------------------------------------------------
SMUL16          STA     <MT_A           ; keep the original bytes
                STB     <MT_B
                MUL                     ; unsigned product
                TST     <MT_A           ; first input negative?
                BPL     SM_1
                SUBA    <MT_B           ;  then subtract 256 * second
SM_1            TST     <MT_B           ; second input negative?
                BPL     SM_2
                SUBA    <MT_A           ;  then subtract 256 * first
SM_2            RTS

; ---------------------------------------------------------------------------
; MULS7 - signed multiply, scaled: A = (A * B) / 128
;   Full product from SMUL16, then ASLB/ROLA leaves D/128 in A (rounded
;   down, which is all the matrix needs).
; ---------------------------------------------------------------------------
MULS7           BSR     SMUL16
                ASLB
                ROLA
                RTS

; ---------------------------------------------------------------------------
; PMUL - projection multiply: A = (A * B) / 128, A signed, B unsigned
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

; Ship model (generated) and the sine/projection tables shared with the cube
                INCLUDE "ship_model.asm"
                INCLUDE "cube_tables.asm"
