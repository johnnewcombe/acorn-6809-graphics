; ---------------------------------------------------------------------------
; Circles - outlined and filled, corrected for the pixel shape
;   Entry: A = centre x, B = centre y (signed, -128..127),
;          X = radius in vertical pixels (0-127; larger values count as 127)
;          DP = $00
;   Exit:  all registers preserved
;   Both clip to the screen and use the current plot mode.
;
;   Teletext pixels are about 1.2 times wider than they are tall, so a
;   shape that is round in pixels looks squashed. Every half-width is
;   therefore scaled by 13/16 (0.81), the same correction the cube demo's
;   projection uses, so circles look round on screen.
;
;   The circle is worked out a row at a time, from the centre row outwards.
;   For row offset y, the unscaled half-width x is the largest x with
;   x^2 + y^2 <= r^2 + r (the midpoint rule, which rounds to the nearest
;   pixel). Moving to the next row only ever shrinks x, and the test can be
;   kept up to date with additions alone:
;       f = x^2 + y^2 - r^2 - r       (start: x = r, y = 0, so f = -r)
;       next row:     f = f + 2y + 1, then y = y + 1
;       while f > 0:  f = f - (2x - 1), x = x - 1
;
;   Outline: each row draws the run of pixels from just beyond the next
;   row's edge out to this row's edge (at least one pixel), on both sides,
;   for the rows above and below the centre. That joins the rows into an
;   unbroken outline and draws every pixel exactly once, so XOR works.
;   Filled: each row draws one span from edge to edge.
;   Runs and spans are drawn by HSPAN, a lean one-row fill.
; ---------------------------------------------------------------------------

T_CIRC          PSHS    D,X,Y,U
                LBSR    CI_SETUP
                CLR     <C_FILL         ; outline
                LDA     #$0F            ; outlines are always solid
                STA     <H_PAT
                BRA     CI_RUN

T_CIRCF         PSHS    D,X,Y,U
                LBSR    CI_SETUP
                LDA     #1              ; filled
                STA     <C_FILL
                LDA     <U_PAT          ; filled circles use the fill pattern
                STA     <H_PAT

CI_RUN          CLR     <C_ROW          ; start at the centre row
                LDB     <C_R            ; x = r
                STB     <C_X
                CLRA                    ; f = -r
                COMA                    ;  (negate D: complement, add 1)
                COMB
                ADDD    #1
                STD     <C_F
                LDA     <C_X            ; half-width of the centre row
                LBSR    SCALEX
                STA     <C_HC

CI_LOOP         LDA     <C_ROW          ; on the outermost row there is no
                CMPA    <C_R            ;  next row: draw it edge to edge
                BEQ     CI_TOP
                LBSR    NEXTX           ; next row's half-width
                STA     <C_HN
                INCA                    ; this row's run starts just beyond
                CMPA    <C_HC           ;  the next row's edge, but never
                BLS     CI_S1           ;  past this row's own edge
                LDA     <C_HC
CI_S1           STA     <C_ST
                BRA     CI_DRAW
CI_TOP          CLR     <C_ST           ; start 0 = one span, edge to edge

CI_DRAW         TST     <C_FILL         ; filled circles always draw the
                BEQ     CI_ROWS         ;  full span
                CLR     <C_ST

CI_ROWS         LDA     <C_CY           ; the row below the centre (screen y
                ADDA    <C_ROW          ;  grows downwards). Saturate rather
                BVC     CI_Y1           ;  than wrap: a row that far out is
                LDA     #127            ;  off screen and gets clipped anyway
CI_Y1           STA     <C_Y
                BSR     CI_ROWDRAW
                TST     <C_ROW          ; the row above, except for the
                BEQ     CI_NEXT         ;  centre row itself
                LDA     <C_CY
                SUBA    <C_ROW
                BVC     CI_Y2
                LDA     #-128
CI_Y2           STA     <C_Y
                BSR     CI_ROWDRAW

CI_NEXT         LDA     <C_ROW          ; done the outermost row?
                CMPA    <C_R
                BEQ     CI_END
                INC     <C_ROW
                LDA     <C_HN           ; next row's half-width becomes
                STA     <C_HC           ;  this row's
                BRA     CI_LOOP
CI_END          PULS    D,X,Y,U,PC

; ---------------------------------------------------------------------------
; CI_ROWDRAW - draw one row (screen y in C_Y)
;   C_ST = 0: one span from cx - half-width to cx + half-width.
;   C_ST > 0: two runs, cx + C_ST .. cx + half-width on the right and its
;   mirror image on the left.
;   Screen x values saturate at -128 / 127 instead of wrapping; anything
;   that far out is off screen and clipped anyway.
; ---------------------------------------------------------------------------
CI_ROWDRAW      TST     <C_ST
                BNE     RD_TWO
                LDA     <C_CX           ; one span: left end ...
                SUBA    <C_HC
                BVC     RD_1
                LDA     #-128
RD_1            PSHS    A
                LDA     <C_CX           ; ... right end
                ADDA    <C_HC
                BVC     RD_2
                LDA     #127
RD_2            TFR     A,B
                PULS    A
                BRA     DRUN

RD_TWO          LDA     <C_CX           ; right-hand run: cx + start ...
                ADDA    <C_ST
                BVC     RD_3
                LDA     #127
RD_3            PSHS    A
                LDA     <C_CX           ; ... to cx + half-width
                ADDA    <C_HC
                BVC     RD_4
                LDA     #127
RD_4            TFR     A,B
                PULS    A
                BSR     DRUN
                LDA     <C_CX           ; left-hand run: cx - half-width ...
                SUBA    <C_HC
                BVC     RD_5
                LDA     #-128
RD_5            PSHS    A
                LDA     <C_CX           ; ... to cx - start
                SUBA    <C_ST
                BVC     RD_6
                LDA     #-128
RD_6            TFR     A,B
                PULS    A
                ; fall into DRUN

; ---------------------------------------------------------------------------
; DRUN - draw a horizontal run of pixels on row C_Y
;   Entry: A = left x, B = right x (signed, A <= B)
;   A single pixel (most of an outline) goes to the clipped plot, which is
;   cheaper; anything longer, or anything patterned, goes to HSPAN.
; ---------------------------------------------------------------------------
DRUN            PSHS    B
                CMPA    ,S+
                BNE     HSPAN
                PSHS    B               ; patterned: HSPAN applies the pattern
                LDB     <H_PAT          ;  (keep B, the run's right end;
                CMPB    #$0F            ;  PULS leaves the flags alone)
                PULS    B
                BNE     HSPAN
                LDB     <C_Y            ; one solid pixel: A,B = x,y
                LBRA    T_PLOTC

; ---------------------------------------------------------------------------
; HSPAN - draw a horizontal run of pixels on row C_Y
;   Entry: A = left x, B = right x (signed, A <= B)
;   Exit:  A, B, X, U corrupted
;
;   A lean, single-row version of the rectangle fill, which also applies
;   the fill pattern in H_PAT (15 = solid). Used by the circles and the
;   polygon fill; the caller sets H_PAT. The row's left and
;   right pixel masks come straight from PTAB, so there is no sorting, no
;   multiply and no mask lookup: clip, find the cells, then
;     - if the run starts on a right-hand pixel, that cell gets only its
;       right pixel
;     - whole cells in between get both pixels, via the shared FILLSEG loop
;     - if the run ends on a left-hand pixel, that cell gets only its left
;   (or, when the run lies within one cell, whichever of its pixels count).
; ---------------------------------------------------------------------------
HSPAN           PSHS    A,B             ; 0,S = left x, 1,S = right x
                LDB     <C_Y            ; row off screen? (unsigned compare
                CMPB    #YMAX           ;  catches negative rows too)
                LBHI    HS_X
                LDA     1,S             ; run entirely left of the screen?
                LBMI    HS_X
                LDA     ,S              ; entirely right of it?
                CMPA    #XMAX
                LBGT    HS_X
                TSTA                    ; clip the left end
                BPL     HS_1
                CLR     ,S
HS_1            LDA     1,S             ; clip the right end
                CMPA    #XMAX
                BLE     HS_2
                LDA     #XMAX
                STA     1,S

HS_2            LBSR    PT_ENTRY        ; U -> PTAB entry for this row (B = y)
                LDD     ,U              ; X -> first cell of the cell row
                ADDD    <W_BUF
                TFR     D,X
                LDA     2,U             ; this sixel row's masks
                STA     <F_ML
                LDA     3,U
                STA     <F_MR

                LDB     <H_PAT          ; apply the fill pattern: odd rows use
                LDA     <C_Y            ;  bits 2-3, even rows bits 0-1;
                BITA    #1              ;  the low bit is for left (even x)
                BEQ     HS_P1           ;  pixels, the next for right (odd x)
                LSRB
                LSRB
HS_P1           BITB    #1
                BNE     HS_P2
                CLR     <F_ML
HS_P2           BITB    #2
                BNE     HS_P3
                CLR     <F_MR
HS_P3           LDA     <F_ML           ; nothing left to draw on this row?
                ORA     <F_MR
                LBEQ    HS_X

                LDA     ,S              ; first cell, and does the run start
                LSRA                    ;  on its right pixel (x odd)?
                STA     <F_CX0
                LDA     #0              ; (not CLRA: keep the carry)
                ROLA
                STA     <F_PL
                LDA     1,S             ; last cell, and does the run end
                LSRA                    ;  on its left pixel (x even)?
                STA     <F_CX1
                LDA     #0
                ROLA
                EORA    #1
                STA     <F_PR

                LDA     <F_CX0          ; all within one cell?
                CMPA    <F_CX1
                BNE     HS_MULTI
                CLRA                    ; its left pixel counts if the run
                TST     <F_PL           ;  starts on it, its right pixel
                BNE     HS_3            ;  if the run ends on it
                ORA     <F_ML
HS_3            TST     <F_PR
                BNE     HS_4
                ORA     <F_MR
HS_4            LDB     <F_CX0
                ABX
                LDB     #1
                LBSR    FILLSEG
                BRA     HS_X

HS_MULTI        TST     <F_PL           ; partial first cell: right pixel
                BEQ     HS_5
                PSHS    X
                LDB     <F_CX0
                ABX
                LDA     <F_MR
                LDB     #1
                LBSR    FILLSEG
                PULS    X
HS_5            LDA     <F_CX0          ; whole cells: from the first (or the
                ADDA    <F_PL           ;  one after) to the last (or the
                STA     <F_RS           ;  one before)
                LDA     <F_CX1
                SUBA    <F_PR
                SUBA    <F_RS
                INCA
                BEQ     HS_6            ; none
                STA     <F_RN
                PSHS    X
                LDB     <F_RS
                ABX
                LDA     <F_ML
                ORA     <F_MR
                LDB     <F_RN
                LBSR    FILLSEG
                PULS    X
HS_6            TST     <F_PR           ; partial last cell: left pixel
                BEQ     HS_X
                LDB     <F_CX1
                ABX
                LDA     <F_ML
                LDB     #1
                LBSR    FILLSEG
HS_X            PULS    A,B,PC

; ---------------------------------------------------------------------------
; NEXTX - move on to the next row: update f and x, return the next row's
;   scaled half-width in A. (C_ROW still holds the current row offset y.)
; ---------------------------------------------------------------------------
NEXTX           LDB     <C_ROW          ; f = f + 2y + 1
                CLRA
                ASLB
                ROLA
                ADDD    #1
                ADDD    <C_F
                STD     <C_F
NX_LOOP         LDD     <C_F            ; while f > 0 (and x > 0) ...
                BLE     NX_DONE
                TST     <C_X
                BEQ     NX_DONE
                LDB     <C_X            ; ... f = f - (2x - 1)
                CLRA
                ASLB
                ROLA
                SUBD    #1
                PSHS    D
                LDD     <C_F
                SUBD    ,S++
                STD     <C_F
                DEC     <C_X            ; ... x = x - 1
                BRA     NX_LOOP
NX_DONE         LDA     <C_X
                ; fall into SCALEX

; ---------------------------------------------------------------------------
; SCALEX - aspect correction: A = (A * 13 + 8) / 16, rounded
;   Entry: A = 0-127   Exit: A = 0-103. B corrupted.
; ---------------------------------------------------------------------------
SCALEX          LDB     #13
                MUL                     ; D = x * 13
                ADDD    #8              ; round
                LSRA                    ; divide by 16
                RORB
                LSRA
                RORB
                LSRA
                RORB
                LSRA
                RORB
                TFR     B,A
                RTS

; ---------------------------------------------------------------------------
; CI_SETUP - store the centre and radius (radius clamped to 0-127)
; ---------------------------------------------------------------------------
CI_SETUP        STA     <C_CX
                STB     <C_CY
                TFR     X,D             ; radius is X; anything over 127
                TSTA                    ;  becomes 127
                BNE     CS_BIG
                TSTB
                BPL     CS_OK
CS_BIG          LDB     #127
CS_OK           STB     <C_R
                RTS
