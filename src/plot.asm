; ---------------------------------------------------------------------------
; T_SETMODE - select plot mode
;   Entry: A = MODE_SET, MODE_CLEAR or MODE_XOR, DP = $00
;   Exit:  all registers preserved
;   TODO: patch the operation opcode in T_PLOT (self-modifying, via ,PCR)
; ---------------------------------------------------------------------------
T_SETMODE       STA     <W_MODE
                RTS

; ---------------------------------------------------------------------------
; T_PLOT - plot one sixel pixel in the off-screen buffer
;   Entry: A = x (0-79), B = y (0-71), DP = $00
;   Exit:  all registers preserved
;   TODO: port from teletextr - cell = buffer + (y/3)*40 + 1 + x/2,
;         mask from (x&1, y%3), apply SET/CLEAR/XOR
; ---------------------------------------------------------------------------
T_PLOT          RTS
