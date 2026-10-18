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

TGL_BUFSIZE     EQU     960
TGL_MODE_SET    EQU     0
TGL_MODE_CLEAR  EQU     1
TGL_MODE_XOR    EQU     2
