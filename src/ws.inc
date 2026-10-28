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
R_X0            EQU     WS+24           ; 1  rectangle corners, sorted so
R_Y0            EQU     WS+25           ; 1   R_X0 <= R_X1 and R_Y0 <= R_Y1
R_X1            EQU     WS+26           ; 1   (R_X0/R_Y0 and R_X1/R_Y1 are
R_Y1            EQU     WS+27           ; 1    used as 16-bit pairs)
F_CX0           EQU     WS+28           ; 1  fill: first cell column
F_CX1           EQU     WS+29           ; 1  fill: last cell column
F_PL            EQU     WS+30           ; 1  fill: first cell is right pixel only
F_PR            EQU     WS+31           ; 1  fill: last cell is left pixel only
F_SGL           EQU     WS+32           ; 1  fill: whole width is one cell
F_RS            EQU     WS+33           ; 1  fill: first full-width cell
F_RN            EQU     WS+34           ; 1  fill: number of full-width cells
F_TOP           EQU     WS+35           ; 1  fill: top sixel row in this cell row
F_BOTL          EQU     WS+36           ; 1  fill: bottom sixel row of last row
F_ML            EQU     WS+37           ; 1  fill: left-pixel mask for this row
F_MR            EQU     WS+38           ; 1  fill: right-pixel mask for this row
W_FM            EQU     WS+39           ; 1  fill: mask being applied
F_ROW           EQU     WS+40           ; 2  fill: address of this cell row
F_LAST          EQU     WS+42           ; 2  fill: address of the last cell row
C_CX            EQU     WS+44           ; 1  circle: centre x (signed)
C_CY            EQU     WS+45           ; 1  circle: centre y (signed)
C_R             EQU     WS+46           ; 1  circle: radius (0-127)
C_ROW           EQU     WS+47           ; 1  circle: row offset being drawn
C_X             EQU     WS+48           ; 1  circle: unscaled half-width
C_F             EQU     WS+49           ; 2  circle: midpoint error term
C_HC            EQU     WS+51           ; 1  circle: scaled half-width, this row
C_HN            EQU     WS+52           ; 1  circle: scaled half-width, next row
C_ST            EQU     WS+53           ; 1  circle: where this row's run starts
C_Y             EQU     WS+54           ; 1  circle: screen y being drawn
C_FILL          EQU     WS+55           ; 1  circle: 0 outline, else filled
T_BUF           EQU     WS+56           ; 6  text: number being formatted
T_DIG           EQU     WS+62           ; 1  text: digit being counted
T_LEAD          EQU     WS+63           ; 1  text: non-zero digit seen yet
K_FIRST         EQU     WS+64           ; 1  colour: first row
K_LAST          EQU     WS+65           ; 1  colour: last row
K_CODE          EQU     WS+66           ; 1  colour: control code
ROWCOL          EQU     WS+67           ; 24 each row's graphics control code,
                                        ;    written into column 0 by TGL_CLS
P_RUN           EQU     WS+91           ; 1  pace: a frame period is running
WS_SIZE         EQU     92
