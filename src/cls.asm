; ---------------------------------------------------------------------------
; T_CLS - clear the off-screen buffer
;   Each row: white graphics code in column 0, blank sixel cells in 1-39.
;   Fills the whole buffer with blank cells using PSHU from three registers
;   (six bytes per instruction, working down from the end), then writes the
;   graphics code into column 0 of each row. Roughly 2,100 cycles, about a
;   fifth of a simple byte loop.
;   Entry: DP = $00            Exit: all registers preserved
; ---------------------------------------------------------------------------
T_CLS           PSHS    D,X,Y,U
                LDA     #BUFSIZE/48     ; 20 iterations x 48 bytes
                STA     <W_COUNT
                LDU     <W_BUF
                LEAU    BUFSIZE,U       ; PSHU fills downwards from the end
                LDD     #SIXEL_BLANK*$101
                TFR     D,X
                TFR     D,Y
CLS_FILL
                PSHU    D,X,Y
                PSHU    D,X,Y
                PSHU    D,X,Y
                PSHU    D,X,Y
                PSHU    D,X,Y
                PSHU    D,X,Y
                PSHU    D,X,Y
                PSHU    D,X,Y
                DEC     <W_COUNT
                BNE     CLS_FILL
                LDA     #GFX_WHITE      ; U = buffer start
                STA     0*COLS,U
                STA     1*COLS,U
                STA     2*COLS,U
                STA     3*COLS,U
                STA     4*COLS,U
                STA     5*COLS,U
                STA     6*COLS,U
                STA     7*COLS,U
                STA     8*COLS,U
                STA     9*COLS,U
                STA     10*COLS,U
                STA     11*COLS,U
                STA     12*COLS,U
                STA     13*COLS,U
                STA     14*COLS,U
                STA     15*COLS,U
                STA     16*COLS,U
                STA     17*COLS,U
                STA     18*COLS,U
                STA     19*COLS,U
                STA     20*COLS,U
                STA     21*COLS,U
                STA     22*COLS,U
                STA     23*COLS,U
                PULS    D,X,Y,U,PC
