; ---------------------------------------------------------------------------
; Dashed lines and rectangles ("marching ants")
;
;   A dash pattern of 1-8 pixels repeats along the line. Pixels where the
;   pattern bit is 1 are drawn in the current plot mode; pixels where it is
;   0 (the gaps) get the opposite: cleared in SET mode, set in CLEAR mode,
;   and left alone in XOR mode (so XOR ants can run over a picture without
;   harming it).
;
;   The pattern runs from the start point given towards the end point (for
;   a rectangle, clockwise from the top-left corner). Adding 1 to the phase
;   each frame moves the dashes forward one pixel, so they appear to march.
;
;   Both drawing routines take signed coordinates (-128..127) and clip a
;   pixel at a time, so the pattern stays anchored to the true start point
;   even when part of the shape is off screen. They use a plain line loop
;   of their own (TGL_LINE's fast loops are untouched).
; ---------------------------------------------------------------------------

; The dash settings live here in the library (it is RAM-resident), as the
; page-zero workspace is full. Set by TGL_SETDASH; TGL_INIT sets the default.
DASH_PAT        FCB     %011            ; pattern: bit 0 is the first pixel
DASH_LEN        FCB     3               ; pattern length, 1-8
DASH_PH         FCB     0               ; phase, 0 .. length-1

; Workspace borrowed from routines that never run at the same time
D_X             EQU     I_U0            ; current pixel
D_Y             EQU     I_U1
D_X1            EQU     I_V0            ; end point
D_Y1            EQU     I_V1
D_SX            EQU     I_E             ; x step, +1 or -1
D_SY            EQU     I_SGN           ; y step
D_DX            EQU     F_CX0           ; 2  |dx|
D_DY            EQU     F_PL            ; 2  -|dy|
D_ERR           EQU     F_SGL           ; 2  error term
D_E2            EQU     F_RN            ; 2  error term * 2
D_PATC          EQU     F_BOTL          ; the pattern, copied here for speed
D_LENC          EQU     F_ML            ; its length
D_BIT           EQU     F_MR            ; this pixel's bit in the pattern
D_CNT           EQU     W_FM            ; pixels left in this repeat

; ---------------------------------------------------------------------------
; T_SETDASH - set the dash pattern
;   Entry: A = pattern (bit 0 = first pixel of each repeat; 1 = drawn,
;          0 = gap), B = length in pixels (1-8; 0 or more than 8 means 8),
;          X = phase (low byte, taken modulo the length), DP = $00
;   Exit:  all registers preserved
; ---------------------------------------------------------------------------
T_SETDASH       PSHS    D,X
                STA     DASH_PAT,PCR
                TSTB                    ; length: 0 or over 8 means 8
                BEQ     SD_8
                CMPB    #8
                BLS     SD_1
SD_8            LDB     #8
SD_1            STB     DASH_LEN,PCR
                TFR     X,D             ; phase mod length (B = phase)
SD_MOD          CMPB    DASH_LEN,PCR
                BLO     SD_2
                SUBB    DASH_LEN,PCR
                BRA     SD_MOD
SD_2            STB     DASH_PH,PCR
                PULS    D,X,PC

; ---------------------------------------------------------------------------
; DSETUP - get ready to draw dashes:
;   - copy the pattern and length into page zero
;   - the first pixel is (length - phase) mod length into the pattern (so
;     moving the phase on moves the dashes forward): D_BIT is that
;     position's bit, D_CNT the pixels left before the pattern repeats
;   - patch the operations for drawn pixels and gaps into DOP: drawn
;     pixels use the current mode; gaps use SET <-> CLEAR swapped, and in
;     XOR mode are left alone (LDA ,X then STA ,X)
; ---------------------------------------------------------------------------
DSETUP          LDA     DASH_PAT,PCR
                STA     <D_PATC
                LDA     DASH_LEN,PCR
                STA     <D_LENC
                SUBA    DASH_PH,PCR     ; start position = length - phase
                CMPA    <D_LENC         ;  (phase 0: position 0)
                BLO     DSU_1
                CLRA
DSU_1           PSHS    A
                LDB     <D_LENC         ; pixels left in this repeat
                SUBB    ,S
                STB     <D_CNT
                LEAX    DP_BITS,PCR     ; that position's bit
                PULS    B
                LDA     B,X
                STA     <D_BIT
                LDB     <W_MODE         ; drawn pixels: the current mode
                LEAX    DS_OPS,PCR
                ASLB
                ABX
                LDD     ,X
                STA     DON_PRE,PCR
                STB     DON_OP,PCR
                LDB     <W_MODE         ; gaps: the opposite
                LEAX    DS_GAPS,PCR
                ASLB
                ABX
                LDD     ,X
                STA     DOF_PRE,PCR
                STB     DOF_OP,PCR
                RTS

; pre-op byte and operation opcode (indexed ,X) for each mode
DS_OPS          FCB     $12,$AA         ; SET:   NOP,  ORA  ,X
                FCB     $43,$A4         ; CLEAR: COMA, ANDA ,X
                FCB     $12,$A8         ; XOR:   NOP,  EORA ,X
DS_GAPS         FCB     $43,$A4         ; SET's gaps are cleared
                FCB     $12,$AA         ; CLEAR's gaps are set
                FCB     $12,$A6         ; XOR's gaps: LDA ,X (no change)

; ---------------------------------------------------------------------------
; DOP - apply one dashed pixel and move on in the pattern
;   Entry: A = the pixel's mask, X -> its cell   Exit: A, B corrupted
; ---------------------------------------------------------------------------
DOP             LDB     <D_PATC         ; drawn or gap?
                ANDB    <D_BIT
                BEQ     DOF_PRE
DON_PRE         NOP                     ; patched: drawn pixels' operation
DON_OP          ORA     ,X
                STA     ,X
                BRA     ADV1
DOF_PRE         NOP                     ; patched: gaps' operation
DOF_OP          ORA     ,X
                STA     ,X
                ; fall into ADV1

; ADV1 - move on one pixel in the pattern (A, B kept)
ADV1            ASL     <D_BIT
                DEC     <D_CNT
                BNE     AD_X
                PSHS    A
                LDA     <D_LENC         ; start the pattern again
                STA     <D_CNT
                LDA     #1
                STA     <D_BIT
                PULS    A
AD_X            RTS

DP_BITS         FCB     1,2,4,8,16,32,64,128

; ---------------------------------------------------------------------------
; T_LINED - dashed line
;   Entry: A = x0, B = y0, X = x1 (high byte) : y1 (low byte), all signed,
;          DP = $00
;   Exit:  all registers preserved
; ---------------------------------------------------------------------------
T_LINED         PSHS    D,X,Y,U
                STD     <D_X
                STX     <D_X1
                LBSR    DSETUP
                BSR     DLINE
                PULS    D,X,Y,U,PC

; ---------------------------------------------------------------------------
; DLINE - the dashed line from (D_X,D_Y) to (D_X1,D_Y1), carrying on in the
;   pattern from wherever it is (and leaving it after the last pixel)
;
;   A standard all-directions Bresenham loop, in 16 bits as dx and dy can
;   each be up to 255:
;       err = dx - dy;  each pixel: e2 = 2*err;
;       if e2 >= -dy, err -= dy and step x;  if e2 <= dx, err += dx and
;       step y
;   U follows y through the row table PTAB (4 bytes a row), so a pixel's
;   cell and mask need no lookup: U is only used when y is on screen, but
;   is kept in step (PTAB + 4y) even when it isn't. Off-screen pixels are
;   skipped, but still move the pattern on.
; ---------------------------------------------------------------------------
DLINE           LDA     #1              ; x step and |dx|
                STA     <D_SX
                LDB     <D_X1
                SEX
                PSHS    D
                LDB     <D_X
                SEX
                PSHS    D
                LDD     2,S             ; dx = x1 - x0
                SUBD    ,S++
                LEAS    2,S
                BPL     DL_1
                NEG     <D_SX           ; going left
                COMA
                COMB
                ADDD    #1
DL_1            STD     <D_DX
                LDA     #1              ; y step and -|dy|
                STA     <D_SY
                LDB     <D_Y1
                SEX
                PSHS    D
                LDB     <D_Y
                SEX
                PSHS    D
                LDD     2,S             ; dy = y1 - y0
                SUBD    ,S++
                LEAS    2,S
                BPL     DL_2
                NEG     <D_SY           ; going up
                COMA
                COMB
                ADDD    #1
DL_2            COMA                    ; keep -|dy|
                COMB
                ADDD    #1
                STD     <D_DY
                ADDD    <D_DX           ; err = dx + (-|dy|)
                STD     <D_ERR
                LDB     <D_Y            ; U = PTAB + 4 * y (y signed)
                SEX
                ASLB
                ROLA
                ASLB
                ROLA
                LEAU    PTAB,PCR
                LEAU    D,U
                LDD     <D_DY           ; horizontal? (no y change)
                LBEQ    DHZ
                LDD     <D_DX           ; vertical? (no x change)
                LBEQ    DVT

DL_LOOP         LDA     <D_X            ; this pixel: on screen?
                CMPA    #XMAX           ;  (unsigned compares catch
                BHI     DL_OFF          ;  negatives too)
                LDB     <D_Y
                CMPB    #YMAX
                BHI     DL_OFF
                LDD     ,U              ; X -> its cell
                ADDD    <W_BUF
                TFR     D,X
                LDB     <D_X
                LSRB                    ; carry = right pixel
                ABX                     ;  (ABX leaves the carry)
                LDA     2,U             ; its mask
                BCC     DL_ON
                LDA     3,U
DL_ON           LBSR    DOP
                BRA     DL_STEP
DL_OFF          LBSR    ADV1            ; off screen: just move on
DL_STEP         LDA     <D_X            ; reached the end?
                CMPA    <D_X1
                BNE     DL_3
                LDA     <D_Y
                CMPA    <D_Y1
                BEQ     DL_X
DL_3            LDD     <D_ERR          ; e2 = 2 * err
                ASLB
                ROLA
                STD     <D_E2
                CMPD    <D_DY           ; e2 >= -|dy|: step x
                BLT     DL_4
                LDD     <D_ERR
                ADDD    <D_DY
                STD     <D_ERR
                LDA     <D_X
                ADDA    <D_SX
                STA     <D_X
DL_4            LDD     <D_E2           ; e2 <= |dx|: step y
                CMPD    <D_DX
                BGT     DL_LOOP
                LDD     <D_ERR
                ADDD    <D_DX
                STD     <D_ERR
                LDA     <D_Y
                ADDA    <D_SY
                STA     <D_Y
                LEAU    4,U             ; U follows y down ...
                TST     <D_SY
                BPL     DL_LOOP
                LEAU    -8,U            ; ... or up
                BRA     DL_LOOP
DL_X            RTS

; DHZ - horizontal: y is fixed, so the row's address (Y) is worked out once
;   and each pixel just steps x. If the row is off screen, every pixel is.
DHZ             LDB     <D_Y
                CMPB    #YMAX
                BHI     DHZ_OFF
                LDD     ,U              ; Y -> column 1 of the row
                ADDD    <W_BUF
                TFR     D,Y
DHZ_LOOP         LDA     <D_X            ; on screen?
                CMPA    #XMAX
                BHI     DHZ_SKIP
                LSRA                    ; X -> the cell, carry = right pixel
                LEAX    A,Y             ;  (LEA leaves the carry)
                LDA     2,U             ; its mask
                BCC     DHZ_ON
                LDA     3,U
DHZ_ON           LBSR    DOP
                BRA     DHZ_STEP
DHZ_SKIP         LBSR    ADV1
DHZ_STEP         LDA     <D_X            ; reached the end?
                CMPA    <D_X1
                BEQ     DHZ_X
                ADDA    <D_SX
                STA     <D_X
                BRA     DHZ_LOOP
DHZ_OFF          LBSR    ADV1            ; row off screen: just move on, one
                LDA     <D_X            ;  pixel at a time
                CMPA    <D_X1
                BEQ     DHZ_X
                ADDA    <D_SX
                STA     <D_X
                BRA     DHZ_OFF
DHZ_X            RTS

; DVT - vertical: x is fixed, so its offset in the row (D_X1, no longer
;   needed) and which mask to use (D_E2: 2 left, 3 right) are worked out
;   once, and each pixel just steps U through the row table. If the column
;   is off screen, every pixel is.
DVT             LDA     <D_X
                CMPA    #XMAX
                BHI     DVT_OFF
                LDB     #2              ; left or right pixel's mask
                LSRA
                ADCB    #0
                STA     <D_X1           ; offset of the cell in the row
                STB     <D_E2           ;  (and which mask)
DVT_LOOP         LDB     <D_Y            ; on screen?
                CMPB    #YMAX
                BHI     DVT_SKIP
                LDD     ,U              ; X -> the cell
                ADDD    <W_BUF
                TFR     D,X
                LDB     <D_X1
                ABX
                LDB     <D_E2           ; its mask
                LDA     B,U
                LBSR    DOP
                BRA     DVT_STEP
DVT_SKIP         LBSR    ADV1
DVT_STEP         LDA     <D_Y            ; reached the end?
                CMPA    <D_Y1
                BEQ     DVT_X
                ADDA    <D_SY
                STA     <D_Y
                LEAU    4,U             ; U follows y down ...
                TST     <D_SY
                BPL     DVT_LOOP
                LEAU    -8,U            ; ... or up
                BRA     DVT_LOOP
DVT_OFF          LBSR    ADV1            ; column off screen: just move on
                LDA     <D_Y
                CMPA    <D_Y1
                BEQ     DVT_X
                ADDA    <D_SY
                STA     <D_Y
                BRA     DVT_OFF
DVT_X            RTS

; ---------------------------------------------------------------------------
; T_RECTD - dashed rectangle outline ("marching ants")
;   Entry: A = x0, B = y0, X = x1:y1 (signed, any opposite corners),
;          DP = $00
;   Exit:  all registers preserved
;   Drawn clockwise from the top-left corner, with the pattern carrying on
;   round the corners, and every pixel drawn once (as TGL_RECT):
;     top     (x0,y0)   -> (x1,y0)
;     right   (x1,y0+1) -> (x1,y1)       if y1 > y0
;     bottom  (x1-1,y1) -> (x0,y1)       if y1 > y0 and x1 > x0
;     left    (x0,y1-1) -> (x0,y0+1)     if x1 > x0 and y1 - y0 >= 2
; ---------------------------------------------------------------------------
T_RECTD         PSHS    D,X,Y,U
                LBSR    R_SORT          ; R_X0 <= R_X1, R_Y0 <= R_Y1
                LBSR    DSETUP
                LDD     <R_X0           ; top
                STD     <D_X
                LDA     <R_X1
                LDB     <R_Y0
                STD     <D_X1
                LBSR    DLINE
                LDA     <R_Y1           ; right, if more than one row
                CMPA    <R_Y0
                BLE     RD_X
                LDA     <R_X1
                LDB     <R_Y0
                INCB
                STD     <D_X
                LDA     <R_X1
                LDB     <R_Y1
                STD     <D_X1
                LBSR    DLINE
                LDA     <R_X1           ; bottom, if more than one column
                CMPA    <R_X0
                BLE     RD_X
                DECA
                LDB     <R_Y1
                STD     <D_X
                LDA     <R_X0
                LDB     <R_Y1
                STD     <D_X1
                LBSR    DLINE
                LDA     <R_Y1           ; left, if a gap between top and
                DECA                    ;  bottom
                CMPA    <R_Y0
                BLE     RD_X
                LDA     <R_X0
                LDB     <R_Y1
                DECB
                STD     <D_X
                LDA     <R_X0
                LDB     <R_Y0
                INCB
                STD     <D_X1
                LBSR    DLINE
RD_X            PULS    D,X,Y,U,PC
