; ---------------------------------------------------------------------------
; Workspace - lives in the direct page. Callers must enter every library
; routine with DP = $00.
; ---------------------------------------------------------------------------
WS              EQU     $00             ; workspace base within page zero

W_BUF           EQU     WS+0            ; 2  off-screen buffer address
W_SAVSP         EQU     WS+2            ; 2  caller's S, saved during blit
W_COUNT         EQU     WS+4            ; 1  general loop counter
W_MODE          EQU     WS+5            ; 1  current plot mode
WS_SIZE         EQU     6
