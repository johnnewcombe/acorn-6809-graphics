; ===========================================================================
; cube_defs.inc - settings and variables shared by the cube demos
;   (cube.asm, cubep.asm, cubed.asm). Included at the top of each.
; ===========================================================================

; ---------------------------------------------------------------------------
; Library entry points (see tgl_api.inc)
; ---------------------------------------------------------------------------
TGL_BASE        EQU     $1000
                INCLUDE "tgl_api.inc"

; ---------------------------------------------------------------------------
; Memory
; ---------------------------------------------------------------------------
BUFFER          EQU     $3000           ; off-screen buffer (960 bytes)
STACK_TOP       EQU     $0200           ; stack $0100-$01FF

; ---------------------------------------------------------------------------
; Settings you can change
; ---------------------------------------------------------------------------
SIZE_MID        EQU     21              ; middle of the zoom range; the half
                                        ;  edge length pulses 5..36 around it
CX              EQU     39              ; screen position of the cube's centre
CY              EQU     36
STEP_A          EQU     2               ; rotation speed about x (per frame,
STEP_B          EQU     3               ;  and about y; 256 = a full turn)
STEP_Z          EQU     1               ; zoom speed (256 steps per in-and-out)

; ---------------------------------------------------------------------------
; Variables, in page zero so they can use fast direct addressing.
; The library's own workspace is $00-$7F, so these start at $80.
; ---------------------------------------------------------------------------
ANG_A           EQU     $80             ; rotation angle about x (0-255)
ANG_B           EQU     $81             ; rotation angle about y (0-255)
SA              EQU     $82             ; sin(ANG_A)   (127 = 1.0)
CA              EQU     $83             ; cos(ANG_A)
SB              EQU     $84             ; sin(ANG_B)
CB              EQU     $85             ; cos(ANG_B)
TX              EQU     $86             ; 3 bytes: terms for rotated x
TY              EQU     $89             ; 3 bytes: terms for rotated y
TZ              EQU     $8C             ; 3 bytes: terms for rotated z
VI              EQU     $8F             ; corner number being worked on (0-7)
VX              EQU     $90             ; that corner's rotated x
ZI              EQU     $91             ; its depth, as an index into RXTAB/RYTAB
EC              EQU     $92             ; edges left to draw
FRAMES          EQU     $93             ; frame counter (test builds only)
SIZE            EQU     $94             ; this frame's half edge length (S)
ZOOM            EQU     $95             ; zoom phase (0-255, like an angle)
EX              EQU     $96             ; the viewer's eye, in cube
EY              EQU     $97             ;  coordinates
EZ              EQU     $98
WIRE            EQU     $99             ; 0: skip hidden edges, else draw all
PX              EQU     $A0             ; 8 bytes: screen x of corners 0-7
PY              EQU     $A8             ; 8 bytes: screen y of corners 0-7.
                                        ;  PY is exactly PX+8, so if X points
                                        ;  at a corner's PX entry, its PY is
                                        ;  at 8,X
VIS             EQU     $B0             ; 6 bytes: per face, $FF if visible.
                                        ;  Faces: 0 +x, 1 -x, 2 +y, 3 -y,
                                        ;  4 +z, 5 -z
POLY            EQU     $B8             ; 9 bytes: corner list for TGL_POLYF
                                        ;  (count, then 4 x,y pairs)
FACEN           EQU     $C2             ; face being filled or spotted
; (the die demo uses $C6-$DB for its own variables)
