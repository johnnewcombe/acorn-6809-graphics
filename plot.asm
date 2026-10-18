; ---------------------------------------------------------------------------
; T_SETMODE - select plot mode
;   Patches the pre-op and operation bytes in T_PLOT, so the plot itself
;   never tests the mode. Out-of-range modes are ignored.
;   Entry: A = MODE_SET, MODE_CLEAR or MODE_XOR, DP = $00
;   Exit:  all registers preserved
; ---------------------------------------------------------------------------
T_SETMODE       CMPA    #MODE_XOR
                BHI     SETM_X
                PSHS    D,X
                STA     <W_MODE
                LEAX    MODETAB,PCR
                ASLA
                LDD     A,X             ; A = pre-op byte, B = opcode
                STA     PLOT_PRE,PCR
                STB     PLOT_OP,PCR
                PULS    D,X
SETM_X          RTS

; ---------------------------------------------------------------------------
; T_PLOT - plot one sixel pixel in the off-screen buffer
;   Entry: A = x (0-77), B = y (0-71), DP = $00
;   Exit:  all registers preserved
;   No range checking - out-of-range coordinates write outside the buffer.
;
;   cell = buffer + (y/3)*40 + 1 + x/2,  mask from (x&1, y%3)
; ---------------------------------------------------------------------------
T_PLOT          PSHS    D,X,Y
                LEAY    PTAB,PCR
                CLRA                    ; D = y
                ASLB                    ; D = y*4 (entries are 4 bytes)
                ROLA
                ASLB
                ROLA
                LEAY    D,Y             ; Y -> PTAB entry for this y
                LDD     ,Y              ; offset of column 1 of the cell row
                ADDD    <W_BUF
                TFR     D,X
                LDB     ,S              ; x (caller's A, saved on the stack)
                LSRB                    ; B = x/2, C = x&1
                ABX                     ; X -> cell (ABX leaves C alone)
                BCS     PLOT_R
                LDA     2,Y             ; left pixel mask
                BRA     PLOT_PRE
PLOT_R          LDA     3,Y             ; right pixel mask
PLOT_PRE        NOP                     ; patched: NOP or COMA
PLOT_OP         ORA     ,X              ; patched: ORA / ANDA / EORA ,X
                STA     ,X
                PULS    D,X,Y,PC
