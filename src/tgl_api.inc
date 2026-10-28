; ---------------------------------------------------------------------------
; Acorn System 3 Teletext Graphics Library - caller interface
;
; Define TGL_BASE as the address the library binary is loaded at, then
; INCLUDE this file. Entry points are fixed offsets from the load address.
;
; All routines: enter with DP = $00. Registers are preserved unless stated.
; ---------------------------------------------------------------------------
TGL_INIT        EQU     TGL_BASE+0      ; initialise; buffer = end of library
TGL_SETBUF      EQU     TGL_BASE+3      ; X = off-screen buffer address
TGL_CLS         EQU     TGL_BASE+6      ; clear buffer to blank graphics
TGL_SETMODE     EQU     TGL_BASE+9      ; A = plot mode (TGL_MODE_xxx)
TGL_PLOT        EQU     TGL_BASE+12     ; A = x (0-77), B = y (0-71)
TGL_LINE        EQU     TGL_BASE+15     ; A,B = x0,y0  X = x1:y1 (hi:lo)
TGL_BLIT        EQU     TGL_BASE+18     ; copy buffer to screen rows 0-23
TGL_PLOTC       EQU     TGL_BASE+21     ; clipped plot: A,B = signed x,y
TGL_LINEC       EQU     TGL_BASE+24     ; clipped line: signed coordinates
TGL_DONE        EQU     TGL_BASE+27     ; restore text display (clears screen)
TGL_INKEY       EQU     TGL_BASE+30     ; key waiting? Z set: none; else A = key
TGL_EXIT        EQU     TGL_BASE+33     ; restore display, back to FLEX/monitor
TGL_RECT        EQU     TGL_BASE+36     ; outline rectangle: corners as TGL_LINEC
TGL_RECTF       EQU     TGL_BASE+39     ; filled rectangle: corners as TGL_LINEC
TGL_CIRC        EQU     TGL_BASE+42     ; outline circle: A,B = centre, X = radius
TGL_CIRCF       EQU     TGL_BASE+45     ; filled circle: A,B = centre, X = radius
TGL_TEXT        EQU     TGL_BASE+48     ; status row text: A = column, X -> string
TGL_TCLR        EQU     TGL_BASE+51     ; clear the status row
TGL_TNUM        EQU     TGL_BASE+54     ; status row number: A = column, X = value
TGL_COLOUR      EQU     TGL_BASE+57     ; row colour: A,B = first,last row, X = colour

TGL_BUFSIZE     EQU     960
TGL_MODE_SET    EQU     0
TGL_MODE_CLEAR  EQU     1
TGL_MODE_XOR    EQU     2

; Colours for TGL_COLOUR
TGL_RED         EQU     1
TGL_GREEN       EQU     2
TGL_YELLOW      EQU     3
TGL_BLUE        EQU     4
TGL_MAGENTA     EQU     5
TGL_CYAN        EQU     6
TGL_WHITE       EQU     7
