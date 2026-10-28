; ---------------------------------------------------------------------------
; T_COLOUR - set the graphics colour of a band of rows
;   Entry: A = first row, B = last row (0-23, cell rows: row r covers
;          pixel rows y = 3r to 3r+2), X = colour (1 red, 2 green,
;          3 yellow, 4 blue, 5 magenta, 6 cyan, 7 white; only the low
;          3 bits are used, and 0 counts as white), DP = $00
;   Exit:  all registers preserved
;
;   Teletext colours a row by the control code at its start: $91-$97 mean
;   "graphics in red ... white from here on". The library keeps column 0
;   of every buffer row for that code, so changing a row's colour costs no
;   pixels and no drawing time. The new code is written into the buffer
;   straight away (it shows at the next blit) and remembered in ROWCOL, so
;   TGL_CLS keeps it.
;   A first row beyond 23 does nothing; a last row beyond 23 counts as 23;
;   if first > last nothing changes.
; ---------------------------------------------------------------------------
T_COLOUR        PSHS    D,X,U
                CMPA    #ROWS-1         ; first row off the bottom?
                BHI     CO_X
                CMPB    #ROWS-1         ; clamp the last row
                BLS     CO_1
                LDB     #ROWS-1
CO_1            STA     <K_FIRST
                STB     <K_LAST
                CMPA    <K_LAST         ; empty band?
                BHI     CO_X
                TFR     X,D             ; B = colour
                ANDB    #7
                BNE     CO_2
                LDB     #7              ; 0 counts as white
CO_2            ORB     #$90            ; $91-$97: graphics colour codes
                STB     <K_CODE

                LDA     <K_FIRST        ; U -> ROWCOL entry for the first row
                LDU     #ROWCOL
                LEAU    A,U
                LDB     #COLS           ; X -> column 0 of that buffer row
                MUL                     ;  (first row * 40)
                ADDD    <W_BUF
                TFR     D,X
                LDB     <K_FIRST        ; B counts rows
CO_LOOP         LDA     <K_CODE
                STA     ,U+             ; remember it ...
                STA     ,X              ; ... and put it in the buffer
                LEAX    COLS,X          ; next buffer row
                CMPB    <K_LAST         ; was that the last row? (carry set
                INCB                    ;  if not; INCB leaves the carry
                BLO     CO_LOOP         ;  alone, so BLO still sees it)
CO_X            PULS    D,X,U,PC
