; ===========================================================================
; Rotating cube demo for the teletext graphics library
;
;   A wireframe cube that tumbles about two axes and slowly zooms in and out,
;   drawn in perspective. Press any key to exit.
;
;   Loading: tgl.bin at $1000 (TGL_BASE below), cube.bin at $2000 (its ORG).
;   Run from START ($2000). Works with either machine's library build.
;
;   Each frame:
;     1. clear the off-screen buffer                       (TGL_CLS)
;     2. work out this frame's size from the zoom phase    (ZOOMSZ)
;     3. build the rotation for this frame's angles        (MATRIX)
;     4. rotate the 8 corners and project them to screen   (CORNERS)
;     5. draw the 12 edges between corners                 (EDGES)
;     6. copy the buffer to the screen                     (TGL_BLIT)
;     7. advance the angles and zoom, check for a key, repeat
;   Drawing off-screen and blitting the finished frame means no flicker.
;
; ---------------------------------------------------------------------------
; The maths, and how it is kept cheap on an 8-bit CPU
; ---------------------------------------------------------------------------
;
;   Fixed point. Sines and cosines are stored as signed bytes where 127
;   stands for 1.0 (so 64 is about 0.5, -127 is -1.0). Multiplying two such
;   numbers gives a result 128 times too big, so products are divided by
;   128 afterwards (see MULS7).
;
;   Angles. A full circle is 256 steps instead of 360 degrees, so an angle
;   fits in one byte and wraps round by itself when it overflows. A quarter
;   turn is 64 steps, which gives cos(a) = sin(a + 64): one sine table
;   serves for both.
;
;   Rotation. The cube is centred on the origin, so its corners are every
;   combination of (+S or -S, +S or -S, +S or -S), where S is half the edge
;   length. Rotating a point means multiplying it by a 3x3 matrix:
;
;       rotated x = m00*x + m01*y + m02*z      (and similarly for y, z)
;
;   With every coordinate being +S or -S, each product is just +/-(m * S).
;   So once per frame we work out the nine values m*S (the "terms" TX, TY,
;   TZ), and then every rotated corner coordinate is three of those terms
;   added or subtracted according to the corner's signs. That's 8 multiplies
;   per frame for the whole cube, instead of 9 per corner.
;
;   Perspective. Further-away points should be drawn closer to the centre:
;
;       screen x = centre + x * F / (distance + z)
;
;   Dividing is slow on a 6809, so the value F / (distance + z), suitably
;   scaled, is precomputed for every possible z and stored in a table
;   (RXTAB, RYTAB). Projecting is then one table lookup and one MUL.
;   The x table uses a smaller F than the y table because teletext pixels
;   are wider than they are tall; this keeps the cube looking square.
;
;   Corner numbering. Corners are numbered 0-7. Bit 0 of the number says
;   whether the corner's x is +S (bit set) or -S (bit clear); bit 1 does
;   the same for y and bit 2 for z. Two corners are joined by an edge when
;   their numbers differ in exactly one bit (see EDGETAB).
;
;   Build with -D TESTFRAMES=n to stop after n frames (used by the emulator
;   tests; a normal build runs until a key is pressed).
; ===========================================================================

; ---------------------------------------------------------------------------
; Library entry points (see tgl_api.inc)
; ---------------------------------------------------------------------------
TGL_BASE        EQU     $1000
                INCLUDE "tgl_api.inc"

; ---------------------------------------------------------------------------
; Memory
; ---------------------------------------------------------------------------
BUFFER          EQU     $3000           ; off-screen buffer (960 bytes)
STACK_TOP       EQU     $0200           ; stack $0100-$01FF

; ---------------------------------------------------------------------------
; Settings you can change
; ---------------------------------------------------------------------------
SIZE_MID        EQU     21              ; middle of the zoom range; the half
                                        ;  edge length pulses 5..36 around it
CX              EQU     39              ; screen position of the cube's centre
CY              EQU     36
STEP_A          EQU     2               ; rotation speed about x (per frame,
STEP_B          EQU     3               ;  and about y; 256 = a full turn)
STEP_Z          EQU     1               ; zoom speed (256 steps per in-and-out)

; ---------------------------------------------------------------------------
; Variables, in page zero so they can use fast direct addressing.
; The library's own workspace is $00-$17, so these start at $80.
; ---------------------------------------------------------------------------
ANG_A           EQU     $80             ; rotation angle about x (0-255)
ANG_B           EQU     $81             ; rotation angle about y (0-255)
SA              EQU     $82             ; sin(ANG_A)   (127 = 1.0)
CA              EQU     $83             ; cos(ANG_A)
SB              EQU     $84             ; sin(ANG_B)
CB              EQU     $85             ; cos(ANG_B)
TX              EQU     $86             ; 3 bytes: terms for rotated x
TY              EQU     $89             ; 3 bytes: terms for rotated y
TZ              EQU     $8C             ; 3 bytes: terms for rotated z
VI              EQU     $8F             ; corner number being worked on (0-7)
VX              EQU     $90             ; that corner's rotated x
ZI              EQU     $91             ; its depth, as an index into RXTAB/RYTAB
EC              EQU     $92             ; edges left to draw
FRAMES          EQU     $93             ; frame counter (test builds only)
SIZE            EQU     $94             ; this frame's half edge length (S)
ZOOM            EQU     $95             ; zoom phase (0-255, like an angle)
PX              EQU     $A0             ; 8 bytes: screen x of corners 0-7
PY              EQU     $A8             ; 8 bytes: screen y of corners 0-7.
                                        ;  PY is exactly PX+8, so if X points
                                        ;  at a corner's PX entry, its PY is
                                        ;  at 8,X

                ORG     $2000

; ---------------------------------------------------------------------------
; Set up
; ---------------------------------------------------------------------------
START           LDS     #STACK_TOP
                CLRA                    ; DP = $00: the library (and our
                TFR     A,DP            ;  variables) use direct addressing
                SETDP   $00             ;  in page zero
                ANDCC   #$EF            ; enable IRQs: the keyboard is read
                                        ;  under interrupt
                JSR     TGL_INIT        ; reset CRTC start, hide cursor
                LDX     #BUFFER         ; draw into our buffer at $3000
                JSR     TGL_SETBUF
                CLR     <ANG_A          ; start square-on, mid zoom
                CLR     <ANG_B
                CLR     <FRAMES
                CLR     <ZOOM

; ---------------------------------------------------------------------------
; Main loop: one pass per frame
; ---------------------------------------------------------------------------
FRAME           JSR     TGL_CLS         ; blank the buffer
                BSR     ZOOMSZ          ; SIZE for this frame
                LBSR    MATRIX          ; terms TX, TY, TZ for this frame
                LBSR    CORNERS         ; screen positions PX, PY
                LBSR    EDGES           ; draw into the buffer
                JSR     TGL_BLIT        ; show it

; Advance the angles and zoom phase. Being bytes, they wrap from 255 back
; to 0 by themselves, which is exactly one full turn.
                LDA     <ANG_A
                ADDA    #STEP_A
                STA     <ANG_A
                LDA     <ANG_B
                ADDA    #STEP_B
                STA     <ANG_B
                LDA     <ZOOM
                ADDA    #STEP_Z
                STA     <ZOOM

; Any key exits. TGL_INKEY returns Z clear if a key was pressed, and
; TGL_EXIT never returns, so a long branch straight to it is enough.
                JSR     TGL_INKEY
                LBNE    TGL_EXIT

; Test builds stop after TESTFRAMES frames so the emulator can inspect
; the result. Normal builds skip this.
                IFDEF   TESTFRAMES
                INC     <FRAMES
                LDA     <FRAMES
                CMPA    #TESTFRAMES
                BEQ     DONE
                ENDC
                BRA     FRAME
DONE            BRA     DONE

; ---------------------------------------------------------------------------
; ZOOMSZ - set SIZE from the zoom phase
;
;   SIZE = SIZE_MID + sin(ZOOM)/8, which swings smoothly between 5 and 36
;   as ZOOM goes round. From about 26 upwards the cube overhangs the screen
;   and TGL_LINEC clips it. Don't go above 36: beyond that the depth no
;   longer fits the projection tables (-64..63), and projected points no
;   longer fit the signed -128..127 that TGL_LINEC accepts.
; ---------------------------------------------------------------------------
ZOOMSZ          LEAX    SINTAB,PCR      ; X -> sine table
                LDB     <ZOOM           ; X -> sin(ZOOM). ABX adds B as an
                ABX                     ;  UNSIGNED byte (0-255). "LDA B,X"
                                        ;  would treat B as signed and read
                                        ;  before the table for B >= 128
                LDA     ,X              ; A = sin(ZOOM), -127..127
                ASRA                    ; divide by 8. ASR keeps the sign bit,
                ASRA                    ;  so negative numbers stay negative:
                ASRA                    ;  -127..127 becomes -16..15
                ADDA    #SIZE_MID       ; 5..36
                STA     <SIZE
                RTS

; ---------------------------------------------------------------------------
; MATRIX - work out this frame's nine terms
;
;   The cube is turned first about the y axis (angle B), then about the x
;   axis (angle A). Multiplying those two rotations together gives this
;   matrix (each entry scaled so 127 = 1.0):
;
;               x part      y part     z part
;     row x: [  cb,         0,         sb       ]
;     row y: [  sb*sa,      ca,       -cb*sa    ]
;     row z: [ -sb*ca,      sa,        cb*ca    ]
;
;   Each entry is then multiplied by SIZE to give the terms, e.g.
;   TX = [ cb*S, 0, sb*S ]. Two-factor entries like sb*sa need two
;   multiplies: first sb*sa, then that result * S.
; ---------------------------------------------------------------------------

; Look up the four sines and cosines. Each lookup: X -> table, add the
; angle (unsigned, via ABX), read the byte. cos uses angle + 64.
MATRIX          LEAX    SINTAB,PCR      ; SA = sin(ANG_A)
                LDB     <ANG_A
                ABX
                LDA     ,X
                STA     <SA
                LEAX    SINTAB,PCR      ; CA = cos(ANG_A) = sin(ANG_A + 64)
                LDB     <ANG_A
                ADDB    #64             ; (wraps round past 255 correctly)
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

; Row x: TX = S * [ cb, 0, sb ]
                LDA     <CB             ; TX+0 = cb * S
                LDB     <SIZE
                BSR     MULS7
                STA     <TX
                CLR     <TX+1           ; TX+1 = 0 (this entry is always 0)
                LDA     <SB             ; TX+2 = sb * S
                LDB     <SIZE
                BSR     MULS7
                STA     <TX+2

; Row y: TY = S * [ sb*sa, ca, -cb*sa ]
                LDA     <SB             ; TY+0 = (sb * sa) * S
                LDB     <SA
                BSR     MULS7           ;  A = sb * sa
                LDB     <SIZE
                BSR     MULS7           ;  A = that * S
                STA     <TY
                LDA     <CA             ; TY+1 = ca * S
                LDB     <SIZE
                BSR     MULS7
                STA     <TY+1
                LDA     <CB             ; TY+2 = -(cb * sa) * S
                LDB     <SA
                BSR     MULS7
                NEGA
                LDB     <SIZE
                BSR     MULS7
                STA     <TY+2

; Row z: TZ = S * [ -sb*ca, sa, cb*ca ]
                LDA     <SB             ; TZ+0 = -(sb * ca) * S
                LDB     <CA
                BSR     MULS7
                NEGA
                LDB     <SIZE
                BSR     MULS7
                STA     <TZ
                LDA     <SA             ; TZ+1 = sa * S
                LDB     <SIZE
                BSR     MULS7
                STA     <TZ+1
                LDA     <CB             ; TZ+2 = (cb * ca) * S
                LDB     <CA
                BSR     MULS7
                LDB     <SIZE
                BSR     MULS7
                STA     <TZ+2
                RTS

; ---------------------------------------------------------------------------
; MULS7 - signed multiply, scaled: A = (A * B) / 128
;   Entry: A, B signed (-127..127)
;   Exit:  A = result. B corrupted.
;
;   The 6809's MUL only does unsigned A * B -> D. So: remember the signs,
;   multiply the sizes (absolute values), then put the sign back.
;   The result's sign is negative when exactly one input is negative,
;   which is what the top bit of (A EOR B) tells us.
;
;   Dividing D by 128: shifting D left once (ASLB then ROLA, which carries
;   B's top bit into A) gives D * 2, and the high byte of D * 2 is D / 128.
;   So after the shift the answer is simply in A.
; ---------------------------------------------------------------------------
MULS7           PSHS    D               ; save the originals: 0,S = A, 1,S = B
                TSTA                    ; make A positive
                BPL     MS_1
                NEGA
MS_1            TSTB                    ; make B positive
                BPL     MS_2
                NEGB
MS_2            MUL                     ; D = |A| * |B|
                ASLB                    ; D * 2 ...
                ROLA                    ; ... so A = D / 128
                PSHS    A               ; keep the result. The originals are
                                        ;  now at 1,S (A) and 2,S (B)
                LDA     1,S             ; sign of result = top bit of A EOR B
                EORA    2,S             ;  (sets N flag)
                PULS    A               ; result back in A. PULS doesn't
                                        ;  change the flags, so N survives
                BPL     MS_3            ; positive: done
                NEGA                    ; negative: negate the result
MS_3            LEAS    2,S             ; discard the saved originals
                RTS

; ---------------------------------------------------------------------------
; CORNERS - rotate and project all 8 corners into PX/PY
;
;   For each corner number VI (0-7):
;     rotated x = signed sum of the TX terms       (VSUM)
;     rotated z = signed sum of the TZ terms, turned into a table index
;     rotated y = signed sum of the TY terms
;     screen y  = CY + y * RYTAB[z] / 128         (PMUL)
;     screen x  = CX + x * RXTAB[z] / 128
; ---------------------------------------------------------------------------
CORNERS         CLR     <VI             ; start with corner 0
CN_LOOP         LDB     <VI             ; B = corner number, used by VSUM
                LDU     #TX             ;  to pick + or - for each term
                BSR     VSUM
                STA     <VX             ; rotated x
                LDU     #TZ             ; (B is preserved by VSUM)
                BSR     VSUM            ; rotated z, range about -60..60
                ADDA    #64             ; shift to 0..127 to index the tables
                STA     <ZI
                LDU     #TY
                BSR     VSUM            ; rotated y, left in A

; screen y = CY + y * RYTAB[z] / 128
                LEAX    RYTAB,PCR       ; B = RYTAB[ZI]
                LDB     <ZI
                ABX
                LDB     ,X
                BSR     PMUL            ; A = y * RYTAB[z] / 128
                ADDA    #CY
                LDX     #PY             ; store at PY + VI
                LDB     <VI
                ABX
                STA     ,X

; screen x = CX + x * RXTAB[z] / 128
                LEAX    RXTAB,PCR       ; B = RXTAB[ZI]
                LDB     <ZI
                ABX
                LDB     ,X
                LDA     <VX             ; A = rotated x
                BSR     PMUL
                ADDA    #CX
                LDX     #PX             ; store at PX + VI
                LDB     <VI
                ABX
                STA     ,X

                INC     <VI             ; next corner, until all 8 done
                LDA     <VI
                CMPA    #8
                BNE     CN_LOOP
                RTS

; ---------------------------------------------------------------------------
; VSUM - one rotated coordinate of one corner
;   Entry: U -> the three terms for this coordinate (TX, TY or TZ)
;          B = corner number: bit 0 set means x = +S, clear means x = -S;
;              bit 1 likewise for y, bit 2 for z
;   Exit:  A = term0 * (+/-1) + term1 * (+/-1) + term2 * (+/-1)
;          B preserved (so the caller can reuse it for the next coordinate)
; ---------------------------------------------------------------------------
VSUM            CLRA                    ; running total
                BITB    #1              ; x sign: add or subtract term 0
                BEQ     VS_1
                ADDA    ,U
                BRA     VS_2
VS_1            SUBA    ,U
VS_2            BITB    #2              ; y sign: term 1
                BEQ     VS_3
                ADDA    1,U
                BRA     VS_4
VS_3            SUBA    1,U
VS_4            BITB    #4              ; z sign: term 2
                BEQ     VS_5
                ADDA    2,U
                RTS
VS_5            SUBA    2,U
                RTS

; ---------------------------------------------------------------------------
; PMUL - projection multiply: A = (A * B) / 128
;   Entry: A = coordinate (signed), B = scale from RXTAB/RYTAB (unsigned)
;   Exit:  A = result. B corrupted.
;
;   Like MULS7, but only A can be negative, so: make A positive, MUL,
;   divide by 128 the same way (ASLB/ROLA leaves D/128 in A), and negate
;   the answer if A was negative.
; ---------------------------------------------------------------------------
PMUL            TSTA
                BPL     PM_1
                NEGA                    ; negative coordinate:
                MUL                     ;  |A| * B
                ASLB                    ;  / 128
                ROLA
                NEGA                    ;  and make it negative again
                RTS
PM_1            MUL                     ; positive coordinate: A * B
                ASLB                    ;  / 128
                ROLA
                RTS

; ---------------------------------------------------------------------------
; EDGES - draw the 12 edges
;
;   EDGETAB lists the 12 edges as pairs of corner numbers. For each pair,
;   look up both corners' screen positions in PX/PY and draw a line.
;   TGL_LINEC (the clipped line) is used because, when the cube is zoomed
;   right in, some corners land off the screen.
;
;   Y walks through EDGETAB two bytes at a time: 0,Y is the start corner,
;   1,Y the end corner.
; ---------------------------------------------------------------------------
EDGES           LEAY    EDGETAB,PCR
                LDA     #12             ; 12 edges to draw
                STA     <EC
ED_LOOP         LDX     #PX             ; end corner's position -> U
                LDB     1,Y             ;  X -> PX + end corner
                ABX
                LDA     ,X              ;  A = its x
                LDB     8,X             ;  B = its y (PY = PX + 8)
                TFR     D,U             ;  park x1:y1 in U for now
                LDX     #PX             ; start corner's position -> A, B
                LDB     ,Y
                ABX
                LDA     ,X              ;  A = x0
                LDB     8,X             ;  B = y0
                TFR     U,X             ; X = x1:y1, the packed end point
                JSR     TGL_LINEC
                LEAY    2,Y             ; next pair
                DEC     <EC
                BNE     ED_LOOP
                RTS

; ---------------------------------------------------------------------------
; The 12 edges, as pairs of corner numbers. Corners differing only in bit 0
; are joined by an edge running along x; bit 1 along y; bit 2 along z.
; ---------------------------------------------------------------------------
EDGETAB         FCB     0,1,2,3,4,5,6,7         ; edges along x
                FCB     0,2,1,3,4,6,5,7         ; edges along y
                FCB     0,4,1,5,2,6,3,7         ; edges along z

; Sine table and perspective tables, generated by tools/gen_cube_tables.py
                INCLUDE "cube_tables.asm"
