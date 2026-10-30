; ---------------------------------------------------------------------------
; T_FLIPH - flip the picture left-to-right, as an animated card turn
;   Entry: A = frame length in 50Hz ticks (1-3: 2 is about 0.65 seconds in
;          all, 3 about 1 second), DP = $00
;   Exit:  all registers preserved. The buffer now holds the mirror image,
;          and the screen shows it.
;   Uses about 90 bytes of stack.
;
;   Animates whatever is in the off-screen buffer: the picture narrows
;   towards the centre line, goes edge-on, and opens out again mirror
;   reversed, like a card turning over. It runs for 15 frames drawn
;   straight onto the screen, each paced by TGL_PACE (so a NOPACE build
;   runs it as fast as it can), then the buffer is mirrored for real and
;   blitted. Row colours (column 0) are left as they are.
;
;   Each frame, the width follows a cosine curve (the way a turning card
;   looks), so screen pixel column X shows source column
;       c + (X - c) * s,   s = 1 / cos(angle)
;   where c is the centre: 38.5 (or 37.5 in a separated build, 76 pixels
;   wide). CELLS, COL1 and XMAX (consts.inc) give the geometry.
;   with s < 0 in the second half giving the mirror image. FL_MAP works
;   this out for all 78 columns into a table on the stack, stepping out
;   from the centre by s each column (no division). FL_DRAW then builds
;   each screen cell from its two source pixels using four lookup tables -
;   left pixel to left, right to left, left to right, right to right - in
;   a row loop whose offsets are patched in for each column.
;
;   Workspace borrowed from routines that never run at the same time:
FL_TICKS        EQU     R_X1            ; frame length (for TGL_PACE)
FL_K            EQU     R_Y1            ; frame number, 1-15
FL_S            EQU     I_U0            ; 2  this frame's s (8.8 fixed point)
FL_O            EQU     I_V0            ; 2  distance from the centre, source
FL_J            EQU     I_E             ; column counter
FL_COL          EQU     I_SGN           ; screen cell column, 0 .. CELLS-1
FL_CNT          EQU     I_DU            ; row counter
FL_PL           EQU     F_CX1           ; source pixel for a cell's left half
FL_PR           EQU     F_PL            ;  ... and its right half
FL_SRC          EQU     F_ROW           ; 2  address of the column map
; ---------------------------------------------------------------------------
T_FLIPH         PSHS    D,X,Y,U
                STA     <FL_TICKS
                LEAS    -78,S           ; the column map: 78 bytes of stack
                STS     <FL_SRC
                LDX     <W_BUF          ; row control codes onto the screen
                LDU     #VDU_BASE       ;  (columns before COL1 never change)
                LDB     #ROWS
FL_C0           LDA     ,X
                STA     ,U
                IFDEF   TGL_SEPARATED
                LDA     1,X
                STA     1,U
                ENDC
                LEAX    COLS,X
                LEAU    COLS,U
                DECB
                BNE     FL_C0
                LDA     #1
                STA     <FL_K
FL_FRAME        LEAX    FL_STAB-2,PCR   ; s for this frame
                LDB     <FL_K
                ASLB
                ABX
                LDD     ,X
                STD     <FL_S
                LBSR    FL_MAP          ; which source column for each column
                LBSR    FL_DRAW         ; draw the frame on the screen
                LDA     <FL_TICKS       ; and pace it
                LBSR    T_PACE
                INC     <FL_K
                LDA     <FL_K
                CMPA    #16
                BLO     FL_FRAME
                LBSR    FL_MIRROR       ; the buffer becomes the mirror image
                LEAS    78,S
                LBSR    T_BLIT          ; and the screen shows it
                PULS    D,X,Y,U,PC

; ---------------------------------------------------------------------------
; FL_MAP - fill the column map: for each screen pixel column X (0-XMAX),
;   the source pixel column it shows, or $FF for none (beyond the picture).
;   Works out from the centre c (= CELLS - 0.5): at distance j + 0.5 the
;   source is at c +/- o with o = (j + 0.5) * s, so o starts at s/2 and
;   grows by s each column. Rounded to the nearest column:
;   source = (CELLS*256 +/- o) / 256 in 8.8 fixed point. Stops once o is
;   beyond the picture's edge.
; ---------------------------------------------------------------------------
FL_MAP          LDX     <FL_SRC         ; start with every column blank
                LDA     #$FF
                LDB     #2*CELLS
FM_CLR          STA     ,X+
                DECB
                BNE     FM_CLR
                LDD     <FL_S           ; o = s / 2
                ASRA
                RORB
                STD     <FL_O
                CLR     <FL_J
FM_LOOP         LDD     <FL_O           ; |o| beyond the picture? stop
                BPL     FM_1
                COMA
                COMB
                ADDD    #1
FM_1            CMPD    #(CELLS+1)*256
                BHI     FM_X
                LDD     #CELLS*256      ; right side: X = CELLS + j shows
                ADDD    <FL_O           ;  CELLS*256 + o
                BMI     FM_2            ;  (off the left of the picture)
                CMPD    #2*CELLS*256
                BGE     FM_2            ;  (off the right)
                LDX     <FL_SRC         ; A = source column
                LDB     <FL_J
                ABX
                STA     CELLS,X
FM_2            LDD     #CELLS*256      ; left side: X = CELLS - 1 - j shows
                SUBD    <FL_O           ;  CELLS*256 - o
                BMI     FM_3
                CMPD    #2*CELLS*256
                BGE     FM_3
                LDX     <FL_SRC
                LDB     #CELLS-1
                SUBB    <FL_J
                ABX
                STA     ,X
FM_3            LDD     <FL_O           ; next column out
                ADDD    <FL_S
                STD     <FL_O
                INC     <FL_J
                LDA     <FL_J
                CMPA    #CELLS
                BLO     FM_LOOP
FM_X            RTS

; ---------------------------------------------------------------------------
; FL_DRAW - draw one frame onto the screen from the buffer and column map
;   For each screen cell column: its left pixel shows source pixel PL and
;   its right pixel source pixel PR. Source pixel p is the left (p even) or
;   right (p odd) pixel of source cell p/2, so the left half of each screen
;   cell is LLT[byte] or RLT[byte] of that source cell (U points at the
;   table) and the right half LRT[byte] or RRT[byte] (Y). A blank half uses
;   a table of constants instead (all $20 on the left, all 0 on the right).
;   The cell offsets and screen offsets are patched into a row loop that
;   does three rows per pass; columns with both halves blank just get
;   spaces.
; ---------------------------------------------------------------------------
FL_DRAW         CLR     <FL_COL
FD_COL          LDX     <FL_SRC         ; PL, PR for this cell column
                LDB     <FL_COL
                ASLB
                ABX
                LDD     ,X
                STD     <FL_PL
                LDD     #VDU_BASE       ; screen offset from the buffer row:
                SUBD    <W_BUF          ;  VDU_BASE + column - W_BUF (it can
                ADDB    <FL_COL         ;  wrap round 64K, which is fine)
                ADCA    #0
                LDX     <W_BUF          ; X -> first pixel column of buffer
                LEAX    COL1,X          ;  row 0
                LDU     <FL_PL          ; both halves blank: spaces
                CMPU    #$FFFF
                LBEQ    FD_BLANK
                STD     FG_D0+2,PCR     ; screen offsets for the 3 rows
                ADDD    #COLS
                STD     FG_D1+2,PCR
                ADDD    #COLS
                STD     FG_D2+2,PCR

                LDA     <FL_PL          ; left half
                CMPA    #$FF
                BNE     FD_L1
                LEAU    FL_K20-$20,PCR  ; blank: a constant $20
                CLRA                    ;  (any cell will do)
                BRA     FD_L2
FD_L1           LSRA                    ; A = source cell, carry = right pixel
                LEAU    FL_LLT-$20,PCR  ; source left pixel -> left (LEA
                BCC     FD_L2           ;  leaves the carry)
                LEAU    FL_RLT-$20,PCR  ; source right pixel -> left
FD_L2           STA     FG_L0+2,PCR     ; patch the source offsets for the
                ADDA    #COLS           ;  3 rows
                STA     FG_L1+2,PCR
                ADDA    #COLS
                STA     FG_L2+2,PCR

                LDA     <FL_PR          ; right half
                CMPA    #$FF
                BNE     FD_R1
                LEAY    FL_K00-$20,PCR  ; blank: a constant 0
                CLRA
                BRA     FD_R2
FD_R1           LSRA
                LEAY    FL_LRT-$20,PCR  ; source left pixel -> right
                BCC     FD_R2
                LEAY    FL_RRT-$20,PCR  ; source right pixel -> right
FD_R2           STA     FG_R0+2,PCR
                ADDA    #COLS
                STA     FG_R1+2,PCR
                ADDA    #COLS
                STA     FG_R2+2,PCR

                LDA     #ROWS/3         ; 8 passes of 3 rows
                STA     <FL_CNT
FG_LOOP
FG_L0           LDB     <0,X            ; row 0: left half from its table ...
                LDA     B,U
FG_R0           LDB     <0,X            ; ... OR the right half from its
                ORA     B,Y             ;  table ...
FG_D0           STA     >0,X            ; ... onto the screen
FG_L1           LDB     <COLS,X         ; row 1
                LDA     B,U
FG_R1           LDB     <COLS,X
                ORA     B,Y
FG_D1           STA     >COLS,X
FG_L2           LDB     <2*COLS,X       ; row 2
                LDA     B,U
FG_R2           LDB     <2*COLS,X
                ORA     B,Y
FG_D2           STA     >2*COLS,X
                LEAX    3*COLS,X        ; next 3 rows
                DEC     <FL_CNT
                BNE     FG_LOOP
FD_NEXT         INC     <FL_COL
                LDA     <FL_COL
                CMPA    #CELLS
                LBLO    FD_COL
                RTS

FD_BLANK        LEAX    D,X             ; X -> the screen cell in row 0
                LDA     #$20            ; 24 spaces down the column
                LDB     #ROWS/3
FB_LOOP         STA     ,X
                STA     COLS,X
                STA     2*COLS,X
                LEAX    3*COLS,X
                DECB
                BNE     FB_LOOP
                BRA     FD_NEXT

; ---------------------------------------------------------------------------
; FL_MIRROR - mirror the buffer left-to-right in place: in each row, swap
;   the pixel cells in pairs from the outside in (1-19 with 39-21, or in a
;   separated build 2-20 with 39-21), mirroring each (its left and right
;   pixels swapped), and mirror the middle cell, if there is one (cell 20)
; ---------------------------------------------------------------------------
FL_MIRROR       LDX     <W_BUF
                LDA     #ROWS
                STA     <FL_CNT
MR_ROW          PSHS    X
                LEAY    COLS-1,X        ; Y -> column 39
                LEAX    COL1,X          ; X -> the first pixel column
                LDA     #CELLS/2
                STA     <FL_J
MR_LOOP         LDB     ,Y              ; mirror of the right-hand cell ...
                BSR     MIRB
                PSHS    A
                LDB     ,X              ; ... and of the left-hand one
                BSR     MIRB
                STA     ,Y              ; swap them
                PULS    A
                STA     ,X+
                LEAY    -1,Y
                DEC     <FL_J
                BNE     MR_LOOP
                IFNE    CELLS&1         ; an odd number of cells: the middle
                LDB     ,X              ;  one (column 20)
                BSR     MIRB
                STA     ,X
                ENDC
                PULS    X
                LEAX    COLS,X
                DEC     <FL_CNT
                BNE     MR_ROW
                RTS

; MIRB - Entry: B = sixel cell   Exit: A = its mirror image
MIRB            PSHS    U
                LEAU    FL_RLT-$20,PCR  ; right pixels moved left (with
                LDA     B,U             ;  bit 5) ...
                LEAU    FL_LRT-$20,PCR  ; ... and left pixels moved right
                ORA     B,U
                PULS    U,PC

; s = 1 / cos(angle) for frames 1-15 (angle = 180 degrees * frame / 16), in
; 8.8 fixed point, limited to +/-80 near edge-on (frame 8)
FL_STAB         FDB     261,277,308,362,461,669,1312,20480,-1312,-669,-461,-362,-308,-277,-261

; Constant tables for blank halves: $20 (bit 5, no pixels) and 0
FL_K20          FCB     $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
                FCB     $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
                FCB     $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
                FCB     $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
                FCB     $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
                FCB     $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
FL_K00          FCB     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                FCB     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                FCB     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                FCB     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                FCB     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                FCB     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; Pixel-moving tables, for cells $20-$7F (each is indexed from $20).
; LLT: left pixels, kept on the left (plus bit 5). RLT: right pixels,
; moved to the left (plus bit 5). LRT: left pixels moved to the right.
; RRT: right pixels, kept on the right.
FL_LLT          FCB     $20,$21,$20,$21,$24,$25,$24,$25,$20,$21,$20,$21,$24,$25,$24,$25
                FCB     $30,$31,$30,$31,$34,$35,$34,$35,$30,$31,$30,$31,$34,$35,$34,$35
                FCB     $20,$21,$20,$21,$24,$25,$24,$25,$20,$21,$20,$21,$24,$25,$24,$25
                FCB     $30,$31,$30,$31,$34,$35,$34,$35,$30,$31,$30,$31,$34,$35,$34,$35
                FCB     $20,$21,$20,$21,$24,$25,$24,$25,$20,$21,$20,$21,$24,$25,$24,$25
                FCB     $30,$31,$30,$31,$34,$35,$34,$35,$30,$31,$30,$31,$34,$35,$34,$35
FL_RLT          FCB     $20,$20,$21,$21,$20,$20,$21,$21,$24,$24,$25,$25,$24,$24,$25,$25
                FCB     $20,$20,$21,$21,$20,$20,$21,$21,$24,$24,$25,$25,$24,$24,$25,$25
                FCB     $30,$30,$31,$31,$30,$30,$31,$31,$34,$34,$35,$35,$34,$34,$35,$35
                FCB     $30,$30,$31,$31,$30,$30,$31,$31,$34,$34,$35,$35,$34,$34,$35,$35
                FCB     $30,$30,$31,$31,$30,$30,$31,$31,$34,$34,$35,$35,$34,$34,$35,$35
                FCB     $30,$30,$31,$31,$30,$30,$31,$31,$34,$34,$35,$35,$34,$34,$35,$35
FL_LRT          FCB     $00,$02,$00,$02,$08,$0A,$08,$0A,$00,$02,$00,$02,$08,$0A,$08,$0A
                FCB     $40,$42,$40,$42,$48,$4A,$48,$4A,$40,$42,$40,$42,$48,$4A,$48,$4A
                FCB     $00,$02,$00,$02,$08,$0A,$08,$0A,$00,$02,$00,$02,$08,$0A,$08,$0A
                FCB     $40,$42,$40,$42,$48,$4A,$48,$4A,$40,$42,$40,$42,$48,$4A,$48,$4A
                FCB     $00,$02,$00,$02,$08,$0A,$08,$0A,$00,$02,$00,$02,$08,$0A,$08,$0A
                FCB     $40,$42,$40,$42,$48,$4A,$48,$4A,$40,$42,$40,$42,$48,$4A,$48,$4A
FL_RRT          FCB     $00,$00,$02,$02,$00,$00,$02,$02,$08,$08,$0A,$0A,$08,$08,$0A,$0A
                FCB     $00,$00,$02,$02,$00,$00,$02,$02,$08,$08,$0A,$0A,$08,$08,$0A,$0A
                FCB     $40,$40,$42,$42,$40,$40,$42,$42,$48,$48,$4A,$4A,$48,$48,$4A,$4A
                FCB     $40,$40,$42,$42,$40,$40,$42,$42,$48,$48,$4A,$4A,$48,$48,$4A,$4A
                FCB     $40,$40,$42,$42,$40,$40,$42,$42,$48,$48,$4A,$4A,$48,$48,$4A,$4A
                FCB     $40,$40,$42,$42,$40,$40,$42,$42,$48,$48,$4A,$4A,$48,$48,$4A,$4A
