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
W_C0            EQU     WS+13           ; 1  clip: outcode of start point
W_C1            EQU     WS+14           ; 1  clip: outcode of end point
I_U0            EQU     WS+15           ; 1  clip intersection: u0, u1, v0, v1
I_U1            EQU     WS+16           ; 1    (u = axis being solved for,
I_V0            EQU     WS+17           ; 1     v = axis of the edge)
I_V1            EQU     WS+18           ; 1
I_E             EQU     WS+19           ; 1  clip: edge position
I_SGN           EQU     WS+20           ; 1  clip: sign of the result offset
I_DU            EQU     WS+21           ; 1  clip: |u1-u0|
I_DV            EQU     WS+22           ; 1  clip: |v1-v0| (divisor)
I_CNT           EQU     WS+23           ; 1  clip: divide loop counter
WS_SIZE         EQU     24
