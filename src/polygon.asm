; ---------------------------------------------------------------------------
; Filled convex polygons, and fill patterns
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; T_SETPAT - choose the fill pattern for TGL_POLYF and TGL_CIRCF
;   Entry: A = pattern (only the low 4 bits are used), DP = $00
;   Exit:  all registers preserved
;   The pattern is a 2x2 block of pixels repeated across the screen:
;     bit 0 = even x, even y    bit 1 = odd x, even y
;     bit 2 = even x, odd y     bit 3 = odd x, odd y
;   15 is solid, 9 a checkerboard, 0 draws nothing. Outlines, lines,
;   plots and rectangles are not affected.
; ---------------------------------------------------------------------------
T_SETPAT        PSHS    A
                ANDA    #$0F
                STA     <U_PAT
                PULS    A,PC

; ---------------------------------------------------------------------------
; T_POLYF - filled convex polygon
;   Entry: X -> corner count n (3 or more), then n pairs x, y (signed bytes,
;          -128..127), in either winding order. DP = $00
;   Exit:  all registers preserved
;   Clips to the screen; uses the current plot mode and fill pattern.
;   The polygon must be convex (every corner pointing outwards); anything
;   else gives an odd-looking but harmless result.
;
;   Fill rule: a pixel is filled when its top-left corner is inside the
;   polygon, i.e. the polygon includes its top and left edges but not its
;   bottom and right ones. Polygons that share an edge therefore neither
;   overlap nor leave a gap, so faces fit together exactly and XOR works
;   across shared edges. (A square from (0,0) to (10,10) fills 10 x 10
;   pixels.)
;
;   How it works: the fill sweeps down a row at a time from the top corner.
;   Two edge walkers set off from the top corner, one going forwards round
;   the corner list and one going backwards; for a convex polygon one runs
;   down the left side and one down the right. Each walker tracks where its
;   edge crosses the current row as a whole part q and a remainder r (the
;   crossing is exactly q + r/dy), so it needs one division when it starts
;   an edge and only additions after that, with no rounding drift. On each
;   row the span runs from the smaller crossing (rounded up) to just before
;   the larger.
;
;   Spans are not drawn a pixel row at a time, which would write every
;   character cell three times. The three spans of a character row are
;   collected first, then CELLROW writes each cell once: the cells all
;   three rows cover completely get one combined mask in a single fast run,
;   and the few cells at the ends get a mask built from exactly the pixels
;   the spans cover.
;
;   Edge walker layout (at CHA and CHB):
CH_CUR          EQU     0               ; corner the current edge starts at
CH_NXT          EQU     1               ; corner it ends at
CH_YB           EQU     2               ; y of the end corner
CH_Q            EQU     3               ; 2  crossing: whole part (signed)
CH_QD           EQU     5               ; 2  added to q each row
CH_R            EQU     7               ; 1  crossing: remainder, 0..dy-1
CH_RD           EQU     8               ; 1  added to r each row
CH_DY           EQU     9               ; 1  edge height
CH_DIR          EQU     10              ; 1  +1 forwards, -1 backwards
; Temporaries borrowed from the clipping code:
P_XC            EQU     I_U0            ; corner x/y while setting up an edge
P_XN            EQU     I_U1
P_YC            EQU     I_V0
P_YN            EQU     I_V1
P_CNT           EQU     I_E             ; guard count while skipping
P_CA            EQU     R_X0            ; the two crossings on this row
P_CB            EQU     R_Y0
; Character-row compositor (CELLROW) temporaries, also borrowed:
S_A             EQU     T_BUF           ; 3  left end of each pixel row's span
S_B             EQU     T_BUF+3         ; 3  right end (S_A + 3)
S_P             EQU     T_DIG           ; 3  span present? (S_A + 6: T_DIG,
                                        ;    T_LEAD, K_FIRST)
S_ML            EQU     C_CX            ; 3  left-pixel mask of each pixel row
S_MR            EQU     C_CX+3          ; 3  right-pixel mask (S_ML + 3)
P_MODD          EQU     C_CX+6          ; 6  pattern masks for odd character
                                        ;    rows (C_F+1 .. C_FILL)
CR_C0           EQU     F_CX0           ; first cell all three rows cover
CR_C1           EQU     F_CX1           ; last cell all three rows cover
CR_CMIN         EQU     F_PL            ; first cell any row touches
CR_CMAX         EQU     F_PR            ; last cell any row touches
CR_C            EQU     F_RS            ; cell being worked on
CR_END          EQU     F_RN            ; last cell of the current range
CR_IDX          EQU     F_TOP           ; character row number
CR_S            EQU     F_BOTL          ; pixel row within it, $FF = none yet
CR_ROW          EQU     F_ROW           ; 2  address of the character row
; ---------------------------------------------------------------------------
T_POLYF         PSHS    D,X,Y,U
                STX     <P_PTR
                LDA     ,X              ; fewer than 3 corners: nothing
                STA     <P_N
                CMPA    #3
                LBLO    PF_X
                LDA     <U_PAT          ; polygons use the fill pattern
                STA     <H_PAT
                LBSR    PF_MASKS        ; work out its masks once

; Find the top corner (smallest y) and the bottom y
                LDA     #127
                STA     <P_Y
                LDA     #-128
                STA     <P_YMAX
                CLRB                    ; B = corner index
PF_FIND         PSHS    B
                LBSR    VTX             ; A,B = x,y of corner B
                CMPB    <P_Y            ; higher than the top so far?
                BGE     PF_F1
                STB     <P_Y
                LDA     ,S
                STA     <P_TOP
PF_F1           CMPB    <P_YMAX         ; lower than the bottom so far?
                BLE     PF_F2
                STB     <P_YMAX
PF_F2           PULS    B
                INCB
                CMPB    <P_N
                BLO     PF_FIND

; Start both edge walkers at the top corner
                LDU     #CHA
                LDA     <P_TOP
                STA     CH_CUR,U
                LDA     #1              ; forwards round the list
                STA     CH_DIR,U
                LBSR    CH_SETUP
                LDU     #CHB
                LDA     <P_TOP
                STA     CH_CUR,U
                LDA     #-1             ; backwards
                STA     CH_DIR,U
                LBSR    CH_SETUP
                LDA     #$FF            ; no character row started yet
                STA     <CR_S

; One pixel row per pass, from the top corner down to (not including) the
; bottom corner
PF_ROW          LDA     <P_Y
                CMPA    <P_YMAX         ; reached the bottom corner?
                LBGE    PF_END
                CMPA    #YMAX           ; gone off the bottom of the screen?
                LBGT    PF_END
                LDU     #CHA            ; move each walker on to its next
                LBSR    CH_CHECK        ;  edge if this one has ended
                LDU     #CHB
                LBSR    CH_CHECK
                LDU     #CHA            ; the two crossings, rounded up
                LBSR    CH_CEIL
                STB     <P_CA
                LDU     #CHB
                LBSR    CH_CEIL
                STB     <P_CB
                LDA     <P_Y            ; rows above the screen: just step
                LBMI    PF_STEP
                LDA     <CR_S           ; first row on screen: start the
                CMPA    #$FF            ;  character row it falls in
                BNE     PF_HAVE
                LBSR    CR_START
PF_HAVE         LDA     <P_CA           ; span from the smaller crossing ...
                LDB     <P_CB
                PSHS    B
                CMPA    ,S+
                BEQ     PF_NEXTS        ; equal: nothing on this row
                BLT     PF_1
                EXG     A,B             ; A = smaller, B = larger
PF_1            DECB                    ; ... to just before the larger (no
                TSTA                    ;  overflow: larger > smaller)
                BPL     PF_2            ; clip to the screen: left end ...
                CLRA
PF_2            CMPB    #XMAX           ; ... right end
                BLE     PF_3
                LDB     #XMAX
PF_3            PSHS    B               ; anything left on screen?
                CMPA    ,S+
                BGT     PF_NEXTS
                LDX     #S_A            ; keep it as this pixel row's span:
                PSHS    B               ;  X -> S_A[s]
                LDB     <CR_S
                ABX
                PULS    B
                STA     ,X              ;  S_A[s] = left
                STB     3,X             ;  S_B[s] = right
                LDA     #1
                STA     6,X             ;  S_P[s] = present
PF_NEXTS        LDA     <CR_S           ; next pixel row; after the third,
                INCA                    ;  write the character row and move
                CMPA    #3              ;  on to the next one
                BLO     PF_4
                LBSR    CELLROW
                LBSR    CR_NEXT
                CLRA
PF_4            STA     <CR_S
PF_STEP         LDU     #CHA            ; both walkers down a row
                LBSR    CH_STEP
                LDU     #CHB
                LBSR    CH_STEP
                INC     <P_Y
                LBRA    PF_ROW
PF_END          LDA     <CR_S           ; write the last, partly collected,
                CMPA    #$FF            ;  character row (if any)
                BEQ     PF_X
                LBSR    CELLROW
PF_X            PULS    D,X,Y,U,PC

; ---------------------------------------------------------------------------
; PF_MASKS - work out the pattern's masks for even and odd character rows
;   Pixel row s of character row r is screen row 3r + s, which is odd when
;   r + s is odd. The pattern uses bits 0-1 on even screen rows and bits
;   2-3 on odd ones (left pixel, right pixel). For each kind of character
;   row this gives 3 left-pixel masks then 3 right-pixel masks.
; ---------------------------------------------------------------------------
PF_MASKS        LDU     #P_MEVEN        ; even character rows: screen rows
                LDA     <H_PAT          ;  even, odd, even
                BSR     PM_ROW0
                LDA     <H_PAT
                LSRA
                LSRA
                BSR     PM_ROW1
                LDA     <H_PAT
                BSR     PM_ROW2
                LDU     #P_MODD         ; odd character rows: odd, even, odd
                LDA     <H_PAT
                LSRA
                LSRA
                BSR     PM_ROW0
                LDA     <H_PAT
                BSR     PM_ROW1
                LDA     <H_PAT
                LSRA
                LSRA
                ; fall into PM_ROW2

; PM_ROWn - Entry: A = pattern bits for the screen row (bit 0 left, bit 1
;   right), U -> mask set. Sets that pixel row's left and right masks.
PM_ROW2         LDB     #2
                BRA     PM_ROW
PM_ROW1         LDB     #1
                BRA     PM_ROW
PM_ROW0         CLRB
PM_ROW          PSHS    U
                LEAU    B,U             ; U -> left mask for pixel row B
                LEAX    CW_LBIT,PCR
                CLR     ,U
                BITA    #1              ; left pixels allowed?
                BEQ     PM_1
                PSHS    A
                LDA     B,X
                STA     ,U
                PULS    A
PM_1            CLR     3,U
                BITA    #2              ; right pixels allowed?
                BEQ     PM_2
                LEAX    CW_RBIT,PCR
                LDA     B,X
                STA     3,U
PM_2            PULS    U,PC

; ---------------------------------------------------------------------------
; CR_START - start collecting at pixel row P_Y (on screen): work out which
;   character row it is in, and where, and that row's address
; ---------------------------------------------------------------------------
CR_START        LDA     <P_Y            ; character row = y / 3 and pixel
                CLRB                    ;  row within it = y mod 3, by
CS3_LOOP        CMPA    #3              ;  repeated subtraction (y <= 71)
                BLO     CS3_DONE
                SUBA    #3
                INCB
                BRA     CS3_LOOP
CS3_DONE        STA     <CR_S
                STB     <CR_IDX
                LDA     #COLS           ; address = buffer + COL1 + row * 40
                MUL
                ADDD    <W_BUF
                ADDD    #COL1
                STD     <CR_ROW
                BRA     CR_CLEAR

; CR_NEXT - move on to the next character row down
CR_NEXT         INC     <CR_IDX
                LDD     <CR_ROW
                ADDD    #COLS
                STD     <CR_ROW
                ; fall into CR_CLEAR

; CR_CLEAR - no spans collected yet in this character row
CR_CLEAR        CLR     <S_P
                CLR     <S_P+1
                CLR     <S_P+2
                RTS

; ---------------------------------------------------------------------------
; CELLROW - write one character row from up to three collected spans
;   S_P[s], S_A[s], S_B[s] (s = pixel row 0-2): is there a span on that
;   pixel row, and its ends (clipped to 0-77, left <= right). Each cell is
;   written once, through FILLSEG so the plot mode applies, with exactly
;   the pixels the spans cover, filtered by the fill pattern.
; ---------------------------------------------------------------------------
CELLROW         LDA     <S_P            ; nothing collected: nothing to do
                ORA     <S_P+1
                ORA     <S_P+2
                LBEQ    CW_X

; This character row's masks: the even or odd set worked out by PF_MASKS
                LDX     #P_MEVEN        ; even character row
                LDA     <CR_IDX
                BITA    #1
                BEQ     CW_M1
                LDX     #P_MODD         ; odd character row
CW_M1           LDD     ,X              ; copy the 6 masks into S_ML/S_MR
                STD     <S_ML
                LDD     2,X
                STD     <S_ML+2
                LDD     4,X
                STD     <S_ML+4

; The cells any span touches: CR_CMIN to CR_CMAX
                LDA     #$FF
                STA     <CR_CMIN
                CLR     <CR_CMAX
                CLRB
CW_RNG          LDX     #S_A
                ABX
                TST     6,X             ; S_P[s]
                BEQ     CW_RN
                LDA     ,X              ; first cell this span touches
                LSRA
                CMPA    <CR_CMIN
                BHS     CW_R1
                STA     <CR_CMIN
CW_R1           LDA     3,X             ; last cell it touches
                LSRA
                CMPA    <CR_CMAX
                BLS     CW_RN
                STA     <CR_CMAX
CW_RN           INCB
                CMPB    #3
                BLO     CW_RNG

; If all three pixel rows have a span, the cells all three cover completely
; (both pixels): CR_C0 to CR_C1
                LDA     <S_P
                ANDA    <S_P+1
                ANDA    <S_P+2
                BEQ     CW_NOFULL
                CLR     <CR_C0
                LDA     #127
                STA     <CR_C1
                CLRB
CW_FR           LDX     #S_A
                ABX
                LDA     ,X              ; first cell this span covers
                INCA                    ;  completely: (left + 1) / 2
                LSRA
                CMPA    <CR_C0          ; keep the largest
                BLS     CW_F1
                STA     <CR_C0
CW_F1           LDA     3,X             ; last cell it covers completely:
                INCA                    ;  (right + 1) / 2 - 1, which can
                LSRA                    ;  be -1 (none)
                DECA
                CMPA    <CR_C1          ; keep the smallest (signed)
                BGE     CW_F2
                STA     <CR_C1
CW_F2           INCB
                CMPB    #3
                BLO     CW_FR
                LDA     <CR_C0          ; any fully covered cells?
                CMPA    <CR_C1
                BGT     CW_NOFULL

; Fully covered cells: one combined mask, one run
                LDA     <S_ML
                ORA     <S_ML+1
                ORA     <S_ML+2
                ORA     <S_MR
                ORA     <S_MR+1
                ORA     <S_MR+2
                BEQ     CW_EDGES        ; pattern leaves nothing to draw
                LDX     <CR_ROW
                LDB     <CR_C0
                ABX
                LDB     <CR_C1
                SUBB    <CR_C0
                INCB
                LBSR    FILLSEG
CW_EDGES        LDA     <CR_CMIN        ; cells before them ...
                LDB     <CR_C0
                DECB
                BSR     CW_CELLS
                LDA     <CR_C1          ; ... and after them
                INCA
                LDB     <CR_CMAX
                BRA     CW_CELLS

CW_NOFULL       LDA     <CR_CMIN        ; no fully covered cells: build every
                LDB     <CR_CMAX        ;  cell's mask
                ; fall into CW_CELLS

; ---------------------------------------------------------------------------
; CW_CELLS - write cells A to B (signed; nothing if A > B), each with a mask
;   built from the spans: a cell's left pixel (x = 2c) is included on pixel
;   row s if S_A[s] <= x <= S_B[s], and its right pixel (x + 1) likewise.
;   The three pixel rows are written out in full (CW_ROWBITS, a macro) with
;   direct addressing, building the mask in B, as this is the slowest part
;   of the fill for shapes with slanted edges.
; ---------------------------------------------------------------------------
CW_ROWBITS      MACRO
                TST     <S_P+\1         ; a span on pixel row \1?
                BEQ     \2_N
                CMPA    <S_A+\1         ; left pixel within it?
                BLO     \2_R
                CMPA    <S_B+\1
                BHI     \2_R
                ORB     <S_ML+\1
\2_R            INCA                    ; right pixel within it?
                CMPA    <S_A+\1
                BLO     \2_D
                CMPA    <S_B+\1
                BHI     \2_D
                ORB     <S_MR+\1
\2_D            DECA
\2_N
                ENDM

CW_CELLS        STA     <CR_C
                STB     <CR_END
CC_LOOP         LDA     <CR_C
                CMPA    <CR_END
                BGT     CW_X
                ASLA                    ; A = x of the cell's left pixel
                CLRB                    ; B = mask
                CW_ROWBITS 0,CR0
                CW_ROWBITS 1,CR1
                CW_ROWBITS 2,CR2
                TSTB                    ; write the cell (if anything to do)
                BEQ     CC_SKIP
                TFR     B,A             ; FILLSEG: A = mask, B = 1 cell
                LDX     <CR_ROW
                LDB     <CR_C
                ABX
                LDB     #1
                LBSR    FILLSEG
CC_SKIP         INC     <CR_C
                BRA     CC_LOOP
CW_X            RTS

; Sixel bits for the left and right pixel of pixel rows 0, 1 and 2
CW_LBIT         FCB     $01,$04,$10
CW_RBIT         FCB     $02,$08,$40

; ---------------------------------------------------------------------------
; VTX - Entry: B = corner index   Exit: A = x, B = y of that corner
;   X corrupted.
; ---------------------------------------------------------------------------
VTX             LDX     <P_PTR
                LEAX    1,X
                ASLB                    ; 2 bytes per corner
                ABX
                LDD     ,X
                RTS

; ---------------------------------------------------------------------------
; CH_CHECK - move the walker at U on while its edge has ended (the current
;   row has reached the edge's end corner)
; ---------------------------------------------------------------------------
CH_CHECK        LDA     <P_Y
                CMPA    CH_YB,U
                BLT     CC_X
                LDA     CH_NXT,U        ; start the next edge from where this
                STA     CH_CUR,U        ;  one ended
                BSR     CH_SETUP
                BRA     CH_CHECK
CC_X            RTS

; ---------------------------------------------------------------------------
; CH_SETUP - start the walker at U on the edge leaving corner CH_CUR in
;   direction CH_DIR, skipping flat edges. For an edge from (xc,yc) down to
;   (xn,yn): dy = yn - yc, and the crossing moves by dx/dy = qd + rd/dy
;   per row, where qd and rd come from one division (rounded down, so rd
;   is never negative).
; ---------------------------------------------------------------------------
CH_SETUP        LDA     <P_N            ; guard: never skip more than n flat
                STA     <P_CNT          ;  edges
CS_LOOP         LDA     CH_CUR,U        ; next corner = cur + dir, wrapping
                ADDA    CH_DIR,U        ;  round the list
                BPL     CS_1
                ADDA    <P_N
CS_1            CMPA    <P_N
                BLO     CS_2
                SUBA    <P_N
CS_2            STA     CH_NXT,U
                LDB     CH_NXT,U        ; fetch both corners
                BSR     VTX
                STA     <P_XN
                STB     <P_YN
                LDB     CH_CUR,U
                BSR     VTX
                STA     <P_XC
                STB     <P_YC
                CMPB    <P_YN           ; does the edge go down?
                BLT     CS_DOWN
                BGT     CS_STOP         ; going up: no more edges this side
                LDA     CH_NXT,U        ; flat: skip it
                STA     CH_CUR,U
                DEC     <P_CNT
                BNE     CS_LOOP
CS_STOP         LDA     #127            ; no edge: freeze this walker, so it
                STA     CH_YB,U         ;  never moves on again
                LDB     <P_XC
                SEX
                STD     CH_Q,U
                LDD     #0
                STD     CH_QD,U
                STA     CH_R,U
                STA     CH_RD,U
                LDA     #1
                STA     CH_DY,U
                RTS

CS_DOWN         LDA     <P_YN           ; end of the edge, and its height
                STA     CH_YB,U
                SUBA    <P_YC
                STA     CH_DY,U         ; dy = 1..255
                STA     <I_DV           ;  (the divisor, for DIV8)
                LDB     <P_XC           ; crossing starts at xc exactly
                SEX
                STD     CH_Q,U
                CLR     CH_R,U
                LDB     <P_XN           ; D = dx = xn - xc (-255..255)
                SEX
                SUBD    CH_Q,U
                BMI     CS_NEG
                LBSR    DIV8            ; dx >= 0: qd = dx / dy, rd = dx mod dy
                STA     CH_RD,U         ;  (B = quotient, A = remainder)
                CLRA
                STD     CH_QD,U
                RTS
CS_NEG          COMA                    ; dx < 0: divide |dx| ...
                COMB
                ADDD    #1
                LBSR    DIV8            ; B = |dx| / dy, A = remainder
                TSTA
                BEQ     CS_EXACT
                PSHS    A               ; ... and round down: qd = -(q+1),
                LDA     CH_DY,U         ;  rd = dy - remainder
                SUBA    ,S+
                STA     CH_RD,U
                INCB                    ; (q + 1 is at most 128 here)
                BRA     CS_NEGQ
CS_EXACT        CLR     CH_RD,U         ; divides exactly: qd = -q, rd = 0
CS_NEGQ         CLRA                    ; qd = -B
                COMA
                COMB
                ADDD    #1
                STD     CH_QD,U
                RTS

; ---------------------------------------------------------------------------
; CH_CEIL - the walker's crossing, rounded up: B = q + (r > 0 ? 1 : 0)
;   (A corrupted; the value always fits a signed byte)
; ---------------------------------------------------------------------------
CH_CEIL         LDD     CH_Q,U
                TST     CH_R,U
                BEQ     CE_X
                ADDD    #1
CE_X            RTS

; ---------------------------------------------------------------------------
; CH_STEP - move the walker's crossing down one row:
;   q = q + qd, r = r + rd, and if r reaches dy, r = r - dy and q = q + 1
; ---------------------------------------------------------------------------
CH_STEP         LDD     CH_Q,U
                ADDD    CH_QD,U
                STD     CH_Q,U
                LDB     CH_R,U          ; D = r + rd (up to 2 * 254, so
                CLRA                    ;  worked in 16 bits)
                ADDB    CH_RD,U
                ADCA    #0
                TSTA                    ; 256 or more: certainly >= dy
                BNE     ST_SUB
                CMPB    CH_DY,U
                BLO     ST_OK
ST_SUB          SUBB    CH_DY,U         ; r - dy (always fits in B)
                PSHS    B
                LDD     CH_Q,U          ; and carry one into q
                ADDD    #1
                STD     CH_Q,U
                PULS    B
ST_OK           STB     CH_R,U
                RTS
