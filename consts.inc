; ---------------------------------------------------------------------------
; Screen geometry and teletext constants (target independent)
; ---------------------------------------------------------------------------
COLS            EQU     40              ; characters per row
ROWS            EQU     24              ; graphics rows (row 24 left for status)
BUFSIZE         EQU     COLS*ROWS       ; 960 bytes - off-screen buffer size

GFX_WHITE       EQU     $97             ; white graphics control code
SIXEL_BLANK     EQU     $20             ; graphics cell, no pixels set
SIXEL_FULL      EQU     $7F             ; graphics cell, all six pixels set

; Plot modes (see TGL_SETMODE)
MODE_SET        EQU     0
MODE_CLEAR      EQU     1
MODE_XOR        EQU     2
