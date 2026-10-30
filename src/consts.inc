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

; Separated-graphics build (-D TGL_SEPARATED): column 1 of every row holds
; the separated-graphics code as well as column 0 the colour code, so the
; pixels start at column 2 and the screen is 76 pixels wide, not 78
                IFDEF   TGL_SEPARATED
COL1            EQU     2               ; first pixel column
                ELSE
COL1            EQU     1
                ENDC
CELLS           EQU     COLS-COL1       ; pixel cells per row: 39, or 38
XMAX            EQU     2*CELLS-1       ; largest visible x: 77, or 75
GFX_SEP         EQU     $9A             ; separated graphics control code
YMAX            EQU     71              ; largest visible y
STATUS_ROW      EQU     24              ; the status (text) row: below the
                                        ;  graphics, never touched by the blit

; VIA registers used by TGL_PACE (offsets from VIA_BASE)
VIA_T2L         EQU     8               ; Timer 2 low byte (write: latch)
VIA_T2H         EQU     9               ; Timer 2 high byte (write: start)
VIA_ACR         EQU     $B              ; auxiliary control register
VIA_IFR         EQU     $D              ; interrupt flag register
T2_FLAG         EQU     $20             ; IFR bit 5: Timer 2 has timed out
ACR_T2COUNT     EQU     $20             ; ACR bit 5: Timer 2 counts pulses
TICK            EQU     20000           ; one 50Hz tick in VIA clocks (1MHz)
