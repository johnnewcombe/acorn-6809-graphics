; ---------------------------------------------------------------------------
; Clipped drawing - coordinates are signed bytes (-128..127); anything
; outside x 0-77, y 0-71 is not drawn.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; T_PLOTC - plot a pixel if it is on screen
;   Entry: A = x, B = y (signed), DP = $00
;   Exit:  all registers preserved
;   A negative signed value is above XMAX/YMAX when compared unsigned, so
;   one unsigned compare per axis rejects both sides.
; ---------------------------------------------------------------------------
T_PLOTC         CMPA    #XMAX
                BHI     PC_X
                CMPB    #YMAX
                BHI     PC_X
                LBRA    T_PLOT          ; tail call
PC_X            RTS

; ---------------------------------------------------------------------------
; T_LINEC - draw the visible part of a line (Cohen-Sutherland)
;   Entry: A = x0, B = y0, X = x1 (high byte) : y1 (low byte), all signed
;          DP = $00
;   Exit:  all registers preserved
;
;   Each endpoint gets an outcode (bit 0 left, 1 right, 2 top, 3 bottom).
;   Both zero: draw. Common bit: entirely off one side, nothing to draw.
;   Otherwise move an outside endpoint onto the edge it is beyond, and
;   repeat. The intersection always interpolates between the two current
;   endpoints, so a point never moves back outside an edge already
;   satisfied, and the loop ends after at most four moves per endpoint.
;   The trimmed line is drawn by T_LINE.
; ---------------------------------------------------------------------------
T_LINEC         PSHS    D,X,Y,U
                STD     <W_X0
                STX     <W_X1
LC_LOOP         LDD     <W_X0
                BSR     OUTCODE
                STA     <W_C0
                LDD     <W_X1
                BSR     OUTCODE
                STA     <W_C1
                ORA     <W_C0
                BEQ     LC_DRAW         ; both inside
                LDA     <W_C0
                ANDA    <W_C1
                BNE     LC_EXIT         ; both beyond the same edge
                LDA     <W_C0
                BEQ     LC_P1
                BSR     LC_CLIP         ; move the start point
                STD     <W_X0
                BRA     LC_LOOP
LC_P1           LDA     <W_C1
                BSR     LC_CLIP         ; move the end point
                STD     <W_X1
                BRA     LC_LOOP
LC_DRAW         LDD     <W_X0
                LDX     <W_X1
                LBSR    T_LINE
LC_EXIT         PULS    D,X,Y,U,PC

; ---------------------------------------------------------------------------
; OUTCODE - Entry: A = x, B = y (signed)   Exit: A = outcode, B corrupted
; ---------------------------------------------------------------------------
OUTCODE         PSHS    B
                CLRB
                TSTA
                BPL     OC_1
                ORB     #1              ; left
                BRA     OC_2
OC_1            CMPA    #XMAX
                BLS     OC_2
                ORB     #2              ; right
OC_2            LDA     ,S+             ; y
                BPL     OC_3
                ORB     #4              ; top
                BRA     OC_4
OC_3            CMPA    #YMAX
                BLS     OC_4
                ORB     #8              ; bottom
OC_4            TFR     B,A
                RTS

; ---------------------------------------------------------------------------
; LC_CLIP - move a point onto the first edge in its outcode
;   Entry: A = outcode of the point being moved
;   Exit:  A = new x, B = new y
; ---------------------------------------------------------------------------
LC_CLIP         BITA    #4
                BEQ     LCC_1
                CLRB                    ; top edge, y = 0
                BRA     LCC_H
LCC_1           BITA    #8
                BEQ     LCC_2
                LDB     #YMAX           ; bottom edge
LCC_H           STB     <I_E            ; horizontal edge: solve for x
                LDD     <W_X0
                STA     <I_U0
                STB     <I_V0
                LDD     <W_X1
                STA     <I_U1
                STB     <I_V1
                BSR     ISECT
                LDB     <I_E
                RTS
LCC_2           BITA    #2
                BEQ     LCC_3
                LDB     #XMAX           ; right edge
                BRA     LCC_V
LCC_3           CLRB                    ; left edge, x = 0
LCC_V           STB     <I_E            ; vertical edge: solve for y
                LDD     <W_X0
                STA     <I_V0
                STB     <I_U0
                LDD     <W_X1
                STA     <I_V1
                STB     <I_U1
                BSR     ISECT
                TFR     A,B
                LDA     <I_E
                RTS

; ---------------------------------------------------------------------------
; ISECT - A = u0 + (u1-u0) * (e-v0) / (v1-v0)
;   Rounded to the nearest pixel, which keeps trimmed lines closer to the
;   path the unclipped line would take (never more than one pixel off).
;   Worked in sign and magnitude: each difference is at most 255, and
;   |e-v0| <= |v1-v0| because the edge lies between the endpoints, so the
;   product fits 16 bits and the quotient fits 8. The result lies between
;   u0 and u1, so plain 8-bit addition gives the right signed value.
;   B corrupted.
; ---------------------------------------------------------------------------
ISECT           CLR     <I_SGN
                LDA     <I_U1           ; |u1-u0|
                SUBA    <I_U0
                LDB     <I_U1
                CMPB    <I_U0
                BGE     IS_1
                NEGA
                COM     <I_SGN
IS_1            STA     <I_DU
                LDA     <I_E            ; |e-v0|
                SUBA    <I_V0
                LDB     <I_E
                CMPB    <I_V0
                BGE     IS_2
                NEGA
                COM     <I_SGN
IS_2            LDB     <I_DU
                MUL                     ; D = |u1-u0| * |e-v0|
                PSHS    D
                LDA     <I_V1           ; |v1-v0|
                SUBA    <I_V0
                LDB     <I_V1
                CMPB    <I_V0
                BGE     IS_3
                NEGA
                COM     <I_SGN
IS_3            STA     <I_DV
                LSRA                    ; round: add |v1-v0|/2 before dividing
                STA     <I_CNT          ;  (I_CNT as a temporary; DIV8 resets it)
                PULS    D
                ADDB    <I_CNT
                ADCA    #0
                BSR     DIV8            ; B = rounded quotient
                LDA     <I_U0
                PSHS    B
                TST     <I_SGN
                BNE     IS_4
                ADDA    ,S+
                RTS
IS_4            SUBA    ,S+
                RTS

; ---------------------------------------------------------------------------
; DIV8 - unsigned D / I_DV, needs A < I_DV (quotient fits 8 bits)
;   Exit: B = quotient, A = remainder
; ---------------------------------------------------------------------------
DIV8            PSHS    A
                LDA     #8
                STA     <I_CNT
                PULS    A
DV_LOOP         ASLB                    ; shift dividend left; quotient
                ROLA                    ;  bits enter B from the right
                BCS     DV_SUB
                CMPA    <I_DV
                BLO     DV_NEXT
DV_SUB          SUBA    <I_DV
                INCB
DV_NEXT         DEC     <I_CNT
                BNE     DV_LOOP
                RTS
