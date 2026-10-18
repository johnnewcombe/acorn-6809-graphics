; ---------------------------------------------------------------------------
; Workspace - lives in the direct page. Callers must enter every library
; routine with DP = $00.
; ---------------------------------------------------------------------------
WS              EQU     $00             ; workspace base within page zero

W_BUF           EQU     WS+0            ; 2  off-screen buffer address
W_SAVSP         EQU     WS+2            ; 2  caller's S, saved during blit
W_COUNT         EQU     WS+4            ; 1  general loop counter
W_MODE          EQU     WS+5            ; 1  current plot mode
W_X0            EQU     WS+6            ; 1  line start x  } W_X0/W_Y0 and
W_Y0            EQU     WS+7            ; 1  line start y  } W_X1/W_Y1 are
W_X1            EQU     WS+8            ; 1  line end x    } used as 16-bit
W_Y1            EQU     WS+9            ; 1  line end y    } pairs
W_ADX           EQU     WS+10           ; 1  |dx|
W_ADY           EQU     WS+11           ; 1  |dy|
W_ERR           EQU     WS+12           ; 1  Bresenham error term
WS_SIZE         EQU     13
