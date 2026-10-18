; ---------------------------------------------------------------------------
; T_LINE - draw a line in the off-screen buffer (Bresenham)
;   Entry: A = x0, B = y0, X = x1 (high byte) : y1 (low byte), DP = $00
;          x 0-77, y 0-71, no range checking. Uses the current plot mode.
;   Exit:  all registers preserved
;
;   Rather than calling the plot routine per pixel, the loop tracks the
;   cell pointer (X) and an internal pixel mask (B) and steps them directly.
;   Internal masks put the bottom-right pixel in bit 5, so every step is a
;   plain shift:
;
;        left right                 x step: shift 1   (cross cell: X +/- 1)
;   top     1    2                  y step: shift 2   (cross row:  X +/- 40)
;   middle  4    8
;   bottom 16   32 (screen bit 6)   MASKREAL converts internal -> screen
;
;   Endpoints are swapped so the major axis always runs positive, leaving
;   four loops: x-major with y up/down, y-major with x left/right. The
;   chosen loop's |dx| and |dy| are patched into it as immediates, and
;   T_SETMODE patches each loop's pixel operation.
;   Error term stays within -77..+77, so it fits a signed byte.
; ---------------------------------------------------------------------------

; Write the pixel at X with internal mask B (U -> MASKREAL)
LN_PIXEL        MACRO
                LDA     B,U             ; screen mask
\1_PRE          NOP                     ; patched by T_SETMODE
\1_OP           ORA     ,X              ; patched by T_SETMODE
                STA     ,X
                ENDM

; Step one pixel right / left / down / up
LN_RIGHT        MACRO
                BITB    #$15            ; left pixel?
                BEQ     \1_RN
                ASLB                    ; -> right pixel, same cell
                BRA     \1_RD
\1_RN           LSRB                    ; -> left pixel of next cell
                LEAX    1,X
\1_RD
                ENDM

LN_LEFT         MACRO
                BITB    #$2A            ; right pixel?
                BEQ     \1_LN
                LSRB                    ; -> left pixel, same cell
                BRA     \1_LD
\1_LN           ASLB                    ; -> right pixel of previous cell
                LEAX    -1,X
\1_LD
                ENDM

LN_DOWN         MACRO
                BITB    #$30            ; bottom sixel row?
                BNE     \1_DN
                ASLB                    ; -> next sixel row, same cell
                ASLB
                BRA     \1_DD
\1_DN           LSRB                    ; -> top sixel row, cell below
                LSRB
                LSRB
                LSRB
                LEAX    COLS,X
\1_DD
                ENDM

LN_UP           MACRO
                BITB    #$03            ; top sixel row?
                BNE     \1_UN
                LSRB                    ; -> previous sixel row, same cell
                LSRB
                BRA     \1_UD
\1_UN           ASLB                    ; -> bottom sixel row, cell above
                ASLB
                ASLB
                ASLB
                LEAX    -COLS,X
\1_UD
                ENDM

; One loop: \1 = name, \2 = major step, \3 = minor step
LN_LOOP         MACRO
\1              LN_PIXEL \1
                LEAY    -1,Y
                BEQ     \1_X           ; local exit keeps this a short branch
                \2      \1
                LDA     <W_ERR
\1_SUB          SUBA    #0              ; patched: minor length
                BPL     \1_NS
\1_ADD          ADDA    #0              ; patched: major length
                STA     <W_ERR
                \3      \1
                BRA     \1
\1_NS           STA     <W_ERR
                BRA     \1
\1_X            PULS    D,X,Y,U,PC
                ENDM

; ---------------------------------------------------------------------------
T_LINE          PSHS    D,X,Y,U
                STD     <W_X0           ; W_X0 = x0, W_Y0 = y0
                STX     <W_X1           ; W_X1 = x1, W_Y1 = y1
                LDA     <W_X1           ; |dx|
                SUBA    <W_X0
                BPL     LN_1
                NEGA
LN_1            STA     <W_ADX
                LDA     <W_Y1           ; |dy|
                SUBA    <W_Y0
                BPL     LN_2
                NEGA
LN_2            STA     <W_ADY
                CMPA    <W_ADX
                BHI     LN_YMAJ

; --- x-major: make x1 >= x0, then the loop always steps right
                LDA     <W_X1
                CMPA    <W_X0
                BHS     LN_3
                LBSR    LN_SWAP
LN_3            LBSR    LN_START        ; X = cell, B = internal mask
                PSHS    B
                LDA     <W_ADX
                LSRA
                STA     <W_ERR          ; error = major/2
                LDB     <W_ADX          ; Y = pixel count = |dx|+1
                CLRA
                ADDD    #1
                TFR     D,Y
                LDA     <W_Y1
                CMPA    <W_Y0
                BLO     LN_XUP
                LDA     <W_ADY          ; y increasing: down the screen
                STA     LXD_SUB+1,PCR
                LDA     <W_ADX
                STA     LXD_ADD+1,PCR
                LEAU    MASKREAL,PCR
                PULS    B
                BRA     LXD
LN_XUP          LDA     <W_ADY
                STA     LXU_SUB+1,PCR
                LDA     <W_ADX
                STA     LXU_ADD+1,PCR
                LEAU    MASKREAL,PCR
                PULS    B
                LBRA    LXU

; --- y-major: make y1 >= y0, then the loop always steps down
LN_YMAJ         LDA     <W_Y1
                CMPA    <W_Y0
                BHS     LN_4
                LBSR    LN_SWAP
LN_4            LBSR    LN_START
                PSHS    B
                LDA     <W_ADY
                LSRA
                STA     <W_ERR
                LDB     <W_ADY
                CLRA
                ADDD    #1
                TFR     D,Y
                LDA     <W_X1
                CMPA    <W_X0
                BLO     LN_YLT
                LDA     <W_ADX          ; x increasing
                STA     LYR_SUB+1,PCR
                LDA     <W_ADY
                STA     LYR_ADD+1,PCR
                LEAU    MASKREAL,PCR
                PULS    B
                LBRA    LYR
LN_YLT          LDA     <W_ADX
                STA     LYL_SUB+1,PCR
                LDA     <W_ADY
                STA     LYL_ADD+1,PCR
                LEAU    MASKREAL,PCR
                PULS    B
                LBRA    LYL

; --- the four loops
                LN_LOOP LXD,LN_RIGHT,LN_DOWN
                LN_LOOP LXU,LN_RIGHT,LN_UP
                LN_LOOP LYR,LN_DOWN,LN_RIGHT
                LN_LOOP LYL,LN_DOWN,LN_LEFT

; ---------------------------------------------------------------------------
; LN_SWAP - exchange the line's endpoints
; ---------------------------------------------------------------------------
LN_SWAP         LDD     <W_X0
                LDX     <W_X1
                STX     <W_X0
                STD     <W_X1
                RTS

; ---------------------------------------------------------------------------
; LN_START - locate the start pixel (W_X0, W_Y0)
;   Exit: X = cell address, B = internal mask. A, U corrupted.
; ---------------------------------------------------------------------------
LN_START        LEAU    PTAB,PCR
                CLRA
                LDB     <W_Y0
                ASLB
                ROLA
                ASLB
                ROLA
                LEAU    D,U
                LDD     ,U
                ADDD    <W_BUF
                TFR     D,X
                LDB     <W_X0
                LSRB
                ABX
                BCS     LS_R
                LDB     2,U
                RTS
LS_R            LDB     3,U
                CMPB    #$40
                BNE     LS_X
                LDB     #$20            ; bottom-right is bit 5 internally
LS_X            RTS
