; ---------------------------------------------------------------------------
; T_CLS - clear the off-screen buffer
;   Each row: white graphics code in column 0, blank sixel cells in 1-39.
;   Entry: DP = $00            Exit: all registers preserved
;   TODO: speed up (unrolled 16-bit stores) once plotting is in place
; ---------------------------------------------------------------------------
T_CLS           PSHS    D,X,Y
                LDX     <W_BUF
                LDY     #ROWS
CLS_ROW         LDA     #GFX_WHITE
                STA     ,X+
                LDA     #SIXEL_BLANK
                LDB     #COLS-1
CLS_COL         STA     ,X+
                DECB
                BNE     CLS_COL
                LEAY    -1,Y
                BNE     CLS_ROW
                PULS    D,X,Y,PC
