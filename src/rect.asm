; ---------------------------------------------------------------------------
; Rectangles - outlined and filled
;   Both take two opposite corners in the same registers as TGL_LINEC:
;   A = x0, B = y0, X = x1 (high byte) : y1 (low byte). Coordinates are
;   signed (-128..127), the corners can be in any order, and anything off
;   screen is clipped. Both use the current plot mode.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; T_RECT - outlined rectangle
;   Entry: A = x0, B = y0, X = x1:y1 (signed), DP = $00
;   Exit:  all registers preserved
;
;   Drawn as up to four thin filled rectangles that never overlap, so every
;   pixel is drawn exactly once (XOR mode can then remove the rectangle
;   again), and the fill's cell-at-a-time speed and clipping come for free:
;     top     (x0,y0)   - (x1,y0)
;     bottom  (x0,y1)   - (x1,y1)     only if y1 > y0
;     left    (x0,y0+1) - (x0,y1-1)   only if y1 - y0 >= 2
;     right   (x1,y0+1) - (x1,y1-1)   likewise, and only if x1 > x0
;   T_RECTF reuses the R_ variables, so the sorted corners are kept on the
;   stack: 0,S = x0, 1,S = y0, 2,S = x1, 3,S = y1.
; ---------------------------------------------------------------------------
T_RECT          PSHS    D,X,Y,U
                LBSR    R_SORT          ; corners sorted into R_X0..R_Y1
                LDD     <R_X0           ; keep a copy on the stack
                LDX     <R_X1
                PSHS    D,X

                LDA     2,S             ; top edge
                LDB     1,S
                TFR     D,X             ; X = x1:y0
                LDA     ,S              ; A,B = x0,y0
                LBSR    T_RECTF

                LDA     3,S             ; bottom edge, if a different row
                CMPA    1,S
                BLE     RC_X
                LDA     2,S
                LDB     3,S
                TFR     D,X             ; X = x1:y1
                LDA     ,S              ; A,B = x0,y1
                LBSR    T_RECTF

                LDA     3,S             ; sides, only if there is a gap
                DECA                    ;  between top and bottom
                CMPA    1,S             ;  (y1-1 > y0; no overflow, as
                BLE     RC_X            ;  y1 > y0 here)
                LDA     ,S              ; left side
                LDB     3,S
                DECB
                TFR     D,X             ; X = x0:y1-1
                LDB     1,S
                INCB                    ; A,B = x0,y0+1
                LBSR    T_RECTF

                LDA     2,S             ; right side, if a different column
                CMPA    ,S
                BLE     RC_X
                LDB     3,S
                DECB
                TFR     D,X             ; X = x1:y1-1
                LDB     1,S
                INCB                    ; A,B = x1,y0+1
                LBSR    T_RECTF
RC_X            LEAS    4,S             ; drop the copy
                PULS    D,X,Y,U,PC

; ---------------------------------------------------------------------------
; T_RECTF - filled rectangle
;   Entry: A = x0, B = y0, X = x1:y1 (signed), DP = $00
;   Exit:  all registers preserved
;
;   Works a cell row (three sixel rows) at a time. In each cell row the
;   rectangle covers sixel rows top..bottom of every cell, which gives a
;   mask for the cell's left pixels (F_ML) and right pixels (F_MR). Along
;   the row:
;     - if x0 is odd, the first cell gets only its right pixels
;     - the cells in between get both: F_ML | F_MR, applied as one run
;     - if x1 is even, the last cell gets only its left pixels
;     - if the whole width falls in one cell, that cell gets whichever of
;       its pixels are inside
;   Only the first and last cell rows can be partial vertically (top > 0
;   or bottom < 2); every row in between covers all three sixel rows, so
;   its masks are constants and need no lookup.
; ---------------------------------------------------------------------------
T_RECTF         PSHS    D,X,Y,U
                LBSR    R_SORT

; Nothing to do if the rectangle is entirely off one side of the screen
                LDA     <R_X1
                LBMI    RF_X            ; right edge left of the screen
                LDA     <R_Y1
                LBMI    RF_X            ; bottom edge above the screen
                LDA     <R_X0
                CMPA    #XMAX
                LBGT    RF_X            ; left edge right of the screen
                LDA     <R_Y0
                CMPA    #YMAX
                LBGT    RF_X            ; top edge below the screen

; Clip by clamping the edges to the screen
                LDA     <R_X0
                BPL     RF_1
                CLR     <R_X0
RF_1            LDA     <R_Y0
                BPL     RF_2
                CLR     <R_Y0
RF_2            LDA     <R_X1
                CMPA    #XMAX
                BLE     RF_3
                LDA     #XMAX
                STA     <R_X1
RF_3            LDA     <R_Y1
                CMPA    #YMAX
                BLE     RF_4
                LDA     #YMAX
                STA     <R_Y1

; Work out the column plan once: it is the same for every row
RF_4            LDA     <R_X0           ; first cell = x0/2, and is x0 odd?
                LSRA
                STA     <F_CX0
                LDA     #0              ; (not CLRA: that would clear carry)
                ROLA                    ; carry (x0 odd) -> bit 0
                STA     <F_PL
                LDA     <R_X1           ; last cell = x1/2, and is x1 even?
                LSRA
                STA     <F_CX1
                LDA     #0              ; keep carry (x1 odd)
                ROLA
                EORA    #1              ; 1 if x1 even
                STA     <F_PR
                CLR     <F_SGL
                LDA     <F_CX0
                CMPA    <F_CX1
                BNE     RF_5
                INC     <F_SGL          ; one cell wide
                BRA     RF_6
RF_5            LDA     <F_CX0          ; full-width run: from the first cell
                ADDA    <F_PL           ;  (or the one after, if partial)
                STA     <F_RS
                LDA     <F_CX1          ;  to the last (or the one before)
                SUBA    <F_PR
                SUBA    <F_RS
                INCA
                STA     <F_RN           ; number of cells, may be 0

; Find the first and last cell rows, and where y0 and y1 fall within them
RF_6            LDB     <R_Y0
                LBSR    PT_ENTRY        ; U -> PTAB entry for y0
                LDD     ,U
                ADDD    <W_BUF
                STD     <F_ROW          ; first cell row (column 1)
                LDA     2,U
                LBSR    SUBROW
                STA     <F_TOP          ; y0 mod 3
                LDB     <R_Y1
                LBSR    PT_ENTRY
                LDD     ,U
                ADDD    <W_BUF
                STD     <F_LAST         ; last cell row
                LDA     2,U
                LBSR    SUBROW
                STA     <F_BOTL         ; y1 mod 3

; One cell row per pass
RF_ROW          LDX     <F_ROW          ; is this the last cell row?
                CMPX    <F_LAST
                BEQ     RF_LASTR
                TST     <F_TOP          ; a middle row: all three sixel rows
                BNE     RF_FIRST        ;  are covered, so the masks are
                LDA     #$15            ;  constants (left pixels 1+4+16,
                STA     <F_ML           ;  right pixels 2+8+64) - no need
                LDA     #$4A            ;  to look them up
                STA     <F_MR
                BRA     RF_COLS
RF_FIRST        LDB     #2              ; first row (starts part-way down):
                BRA     RF_7            ;  sixel rows top..2
RF_LASTR        LDB     <F_BOTL         ; last row: sixel rows top..y1 mod 3
RF_7            LDA     <F_TOP          ; index = top*3 + bottom
                PSHS    B
                LDB     #3
                MUL                     ; B = top*3 (A is 0)
                ADDB    ,S+
                LEAU    LTAB,PCR        ; masks for this cell row
                LDA     B,U
                STA     <F_ML
                LEAU    RTAB,PCR
                LDA     B,U
                STA     <F_MR

RF_COLS         TST     <F_SGL          ; one cell wide?
                BEQ     RF_MULTI
                CLRA                    ; its left pixels count if x0 even,
                TST     <F_PL           ;  its right pixels if x1 odd
                BNE     RF_8
                ORA     <F_ML
RF_8            TST     <F_PR
                BNE     RF_9
                ORA     <F_MR
RF_9            LDX     <F_ROW
                LDB     <F_CX0
                ABX
                LDB     #1
                BSR     FILLSEG
                BRA     RF_NEXT

RF_MULTI        TST     <F_PL           ; partial first cell: right pixels
                BEQ     RF_10
                LDX     <F_ROW
                LDB     <F_CX0
                ABX
                LDA     <F_MR
                LDB     #1
                BSR     FILLSEG
RF_10           LDB     <F_RN           ; the full-width run
                BEQ     RF_11
                LDX     <F_ROW
                LDB     <F_RS
                ABX
                LDA     <F_ML
                ORA     <F_MR
                LDB     <F_RN
                BSR     FILLSEG
RF_11           TST     <F_PR           ; partial last cell: left pixels
                BEQ     RF_NEXT
                LDX     <F_ROW
                LDB     <F_CX1
                ABX
                LDA     <F_ML
                LDB     #1
                BSR     FILLSEG

RF_NEXT         CLR     <F_TOP          ; later rows start at sixel row 0
                LDX     <F_ROW
                CMPX    <F_LAST         ; done the last cell row?
                BEQ     RF_X
                LEAX    COLS,X          ; next cell row down
                STX     <F_ROW
                LBRA    RF_ROW
RF_X            PULS    D,X,Y,U,PC

; ---------------------------------------------------------------------------
; FILLSEG - apply a mask to a run of cells
;   Entry: X -> first cell, B = number of cells (1 or more), A = mask
;   Exit:  X -> cell after the run. A, B corrupted.
;   T_SETMODE patches the pre-op (NOP, or COMA for CLEAR) and the operation
;   (ORA / ANDA / EORA), so the loop never tests the mode. About 19 cycles
;   per cell, i.e. roughly 3 cycles per pixel.
; ---------------------------------------------------------------------------
FILLSEG
FS_PRE          NOP                     ; patched: NOP or COMA
                STA     <W_FM
FS_LOOP         LDA     ,X
FS_OP           ORA     <W_FM           ; patched: ORA / ANDA / EORA <W_FM
                STA     ,X+
                DECB
                BNE     FS_LOOP
                RTS

; ---------------------------------------------------------------------------
; R_SORT - store the corners in R_X0..R_Y1 with R_X0 <= R_X1, R_Y0 <= R_Y1
;   Entry: A = x0, B = y0, X = x1:y1 (signed)    Exit: A, B corrupted
; ---------------------------------------------------------------------------
R_SORT          STD     <R_X0
                STX     <R_X1
                LDA     <R_X0
                CMPA    <R_X1
                BLE     RS_1
                LDB     <R_X1           ; swap the x coordinates
                STB     <R_X0
                STA     <R_X1
RS_1            LDA     <R_Y0
                CMPA    <R_Y1
                BLE     RS_2
                LDB     <R_Y1           ; swap the y coordinates
                STB     <R_Y0
                STA     <R_Y1
RS_2            RTS

; ---------------------------------------------------------------------------
; PT_ENTRY - Entry: B = y (0-71)   Exit: U -> PTAB entry. A, B corrupted
; ---------------------------------------------------------------------------
PT_ENTRY        LEAU    PTAB,PCR
                CLRA
                ASLB                    ; D = y * 4
                ROLA
                ASLB
                ROLA
                LEAU    D,U
                RTS

; ---------------------------------------------------------------------------
; SUBROW - which sixel row a left-pixel mask is on
;   Entry: A = left-pixel mask from PTAB (1, 4 or 16)   Exit: A = 0, 1 or 2
; ---------------------------------------------------------------------------
SUBROW          CMPA    #4
                BLO     SR_0
                BEQ     SR_1
                LDA     #2
                RTS
SR_1            LDA     #1
                RTS
SR_0            CLRA
                RTS
