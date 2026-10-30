; ---------------------------------------------------------------------------
; T_CLS - clear the off-screen buffer
;   Each row: its graphics colour code in column 0 (white unless changed
;   with TGL_COLOUR), blank sixel cells in 1-39. In a separated build,
;   column 1 holds the separated-graphics code instead.
;   Fills the whole buffer with blank cells using PSHU from three registers
;   (six bytes per instruction, working down from the end), then writes the
;   colour code into column 0 of each row. Roughly 2,100 cycles, about a
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
                                        ; U = buffer start: put each row's
                                        ;  colour code in column 0
                LDA     <ROWCOL+0
                STA     0*COLS,U
                LDA     <ROWCOL+1
                STA     1*COLS,U
                LDA     <ROWCOL+2
                STA     2*COLS,U
                LDA     <ROWCOL+3
                STA     3*COLS,U
                LDA     <ROWCOL+4
                STA     4*COLS,U
                LDA     <ROWCOL+5
                STA     5*COLS,U
                LDA     <ROWCOL+6
                STA     6*COLS,U
                LDA     <ROWCOL+7
                STA     7*COLS,U
                LDA     <ROWCOL+8
                STA     8*COLS,U
                LDA     <ROWCOL+9
                STA     9*COLS,U
                LDA     <ROWCOL+10
                STA     10*COLS,U
                LDA     <ROWCOL+11
                STA     11*COLS,U
                LDA     <ROWCOL+12
                STA     12*COLS,U
                LDA     <ROWCOL+13
                STA     13*COLS,U
                LDA     <ROWCOL+14
                STA     14*COLS,U
                LDA     <ROWCOL+15
                STA     15*COLS,U
                LDA     <ROWCOL+16
                STA     16*COLS,U
                LDA     <ROWCOL+17
                STA     17*COLS,U
                LDA     <ROWCOL+18
                STA     18*COLS,U
                LDA     <ROWCOL+19
                STA     19*COLS,U
                LDA     <ROWCOL+20
                STA     20*COLS,U
                LDA     <ROWCOL+21
                STA     21*COLS,U
                LDA     <ROWCOL+22
                STA     22*COLS,U
                LDA     <ROWCOL+23
                STA     23*COLS,U
                IFDEF   TGL_SEPARATED   ; and the separated code in column 1
                LDA     #GFX_SEP
                STA     0*COLS+1,U
                STA     1*COLS+1,U
                STA     2*COLS+1,U
                STA     3*COLS+1,U
                STA     4*COLS+1,U
                STA     5*COLS+1,U
                STA     6*COLS+1,U
                STA     7*COLS+1,U
                STA     8*COLS+1,U
                STA     9*COLS+1,U
                STA     10*COLS+1,U
                STA     11*COLS+1,U
                STA     12*COLS+1,U
                STA     13*COLS+1,U
                STA     14*COLS+1,U
                STA     15*COLS+1,U
                STA     16*COLS+1,U
                STA     17*COLS+1,U
                STA     18*COLS+1,U
                STA     19*COLS+1,U
                STA     20*COLS+1,U
                STA     21*COLS+1,U
                STA     22*COLS+1,U
                STA     23*COLS+1,U
                ENDC
                PULS    D,X,Y,U,PC
