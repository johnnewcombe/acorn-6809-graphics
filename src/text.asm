; ---------------------------------------------------------------------------
; Status row text
;   The status row is screen row 24, below the 24 rows of graphics. The
;   blit never touches it, so text written there stays put while the
;   graphics above it change. Text is written straight to the screen (not
;   the off-screen buffer), so it appears immediately.
;
;   Strings are zero-terminated and may contain teletext control codes to
;   colour the text that follows them on the row, e.g. $81 red, $82 green,
;   $83 yellow, $84 blue, $85 magenta, $86 cyan, $87 white ($01-$07 work
;   too: the SAA5050 ignores the top bit). Each control code takes up one
;   character position and shows as a space. Text starts white at the
;   left of the row.
; ---------------------------------------------------------------------------

STATUS          EQU     VDU_BASE+STATUS_ROW*COLS        ; first byte of row 24

; ---------------------------------------------------------------------------
; T_TEXT - write a string to the status row
;   Entry: A = column (0-39), X -> zero-terminated string, DP = $00
;   Exit:  all registers preserved
;   Stops at the right-hand edge rather than wrapping. A column beyond 39
;   writes nothing.
; ---------------------------------------------------------------------------
T_TEXT          PSHS    D,X,U
                CMPA    #COLS-1         ; column off the end of the row?
                BHI     TX_X
                LDU     #STATUS         ; U -> screen position
                LEAU    A,U             ;  (A is 0-39, so the add is safe)
                TFR     A,B             ; B = column, to stop at the edge
TX_LOOP         LDA     ,X+             ; next character
                BEQ     TX_X            ; zero: end of string
                STA     ,U+
                INCB
                CMPB    #COLS           ; reached the right-hand edge?
                BLO     TX_LOOP
TX_X            PULS    D,X,U,PC

; ---------------------------------------------------------------------------
; T_TCLR - clear the status row to spaces
;   Entry: DP = $00    Exit: all registers preserved
; ---------------------------------------------------------------------------
T_TCLR          PSHS    D,X
                LDX     #STATUS
                LDD     #$2020          ; two spaces at a time
TC_LOOP         STD     ,X++
                CMPX    #STATUS+COLS
                BLO     TC_LOOP
                PULS    D,X,PC

; ---------------------------------------------------------------------------
; T_TNUM - write a number to the status row
;   Entry: A = column (0-39), X = value (0-65535, unsigned), DP = $00
;   Exit:  all registers preserved
;   Always five characters, right-aligned with leading spaces, so a value
;   that shrinks (e.g. from 100 to 99) leaves no stray digits behind.
;
;   Each digit is found by counting how many times the matching power of
;   ten can be subtracted (10000, 1000, 100, 10); what is left is the last
;   digit. Leading zeros become spaces; the last digit is always shown.
; ---------------------------------------------------------------------------
T_TNUM          PSHS    D,X,Y,U
                TFR     X,D             ; D = value
                LEAU    POW10,PCR       ; U -> 10000, 1000, 100, 10
                LDY     #T_BUF          ; Y -> where the characters go
                CLR     <T_LEAD         ; no non-zero digit yet
TN_DIGIT        CLR     <T_DIG
TN_SUB          CMPD    ,U              ; can this power be subtracted?
                BLO     TN_PUT          ;  (unsigned compare)
                SUBD    ,U
                INC     <T_DIG
                BRA     TN_SUB
TN_PUT          PSHS    D               ; keep the remainder
                LDA     <T_DIG
                BNE     TN_NZ           ; a zero before any other digit
                TST     <T_LEAD         ;  is a leading zero: a space
                BNE     TN_CH
                LDA     #' '
                BRA     TN_ST
TN_NZ           INC     <T_LEAD
TN_CH           ADDA    #'0'
TN_ST           STA     ,Y+
                PULS    D
                LEAU    2,U             ; next power of ten
                LEAX    POW10E,PCR
                PSHS    X
                CMPU    ,S++            ; done all four powers?
                BLO     TN_DIGIT
                ADDB    #'0'            ; the last digit, always shown
                STB     ,Y+
                CLR     ,Y              ; end of string
                LDA     ,S              ; column (caller's A, on the stack)
                LDX     #T_BUF
                BSR     T_TEXT
                PULS    D,X,Y,U,PC

POW10           FDB     10000,1000,100,10
POW10E
