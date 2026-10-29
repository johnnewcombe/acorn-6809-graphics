; ===========================================================================
; Die demo for the teletext graphics library
;
;   The tumbling, zooming cube from cube.asm, drawn as a die: white faces
;   with black spots and black edges. The spots are points on the cube's
;   surface, so they turn, tilt and bunch up with the faces in perspective.
;   Opposite faces add up to seven, as on a real die. Press any key to exit.
;
;   Loading: tgl.bin at $1000, cubed.bin at $2000. Run from START ($2000).
;
;   Shares its code with cube.asm (see there for the list): the face
;   filling is in cube_fill.asm, the rest in cube_core.asm. The spots are
;   here.
;
;   Each frame is as cube.asm's, except that after working out which faces
;   can be seen: FILLS fills the visible faces white, then in CLEAR mode
;   (so they come out black) PIPS cuts out each face's spots and EDGES
;   draws the edges, which keeps neighbouring white faces distinct.
;
;   Spots. Each spot's centre is a point on the cube's surface: on the +x
;   face, for example, a corner spot is at (S, S/2, -S/2). The rotated
;   position of any point is a sum of the per-axis terms TX/TY/TZ scaled by
;   the point's coordinates, and here those are only S, S/2, 0, -S/2 and
;   -S - so a spot's rotated position needs only the terms, the terms
;   halved (HX/HY/HZ), and additions. It is then projected exactly like a
;   corner, so spots sit correctly in perspective. Each spot is drawn as a
;   small square of clipped plots, 1, 2 or 3 pixels across depending on
;   the zoom.
;
;   Build with -D TESTFRAMES=n to stop after n frames (emulator tests).
; ===========================================================================
                INCLUDE "cube_defs.inc"

PACE_TICKS      EQU     3               ; frame length in 50Hz ticks: 3 =
                                        ;  about 17 frames per second

; Variables for the spots (cube_defs.inc uses $80-$C2)
HX              EQU     TX+$40          ; the terms halved: HX = TX / 2 etc.
HY              EQU     TY+$40          ;  ($C6-$CE; kept $40 above the terms
HZ              EQU     TZ+$40          ;  so one index register reaches both)
PA              EQU     $D0             ; spotting a face: its axis (0-2) ...
PB              EQU     $D1             ;  ... and its two in-face axes
PC              EQU     $D2
PS              EQU     $D3             ;  +1 for the + face, -1 for the -
PPB             EQU     $D4             ; spot position along PB: -1, 0, +1
PPC             EQU     $D5             ;  ... and along PC (in halves of S)
PIPN            EQU     $D6             ; spots left on this face
PIPP            EQU     $D7             ; 2  pointer to the next spot
PIPSZ           EQU     $D9             ; spot size in pixels (1-3)
PCX             EQU     $DA             ; spot centre on screen
PCY             EQU     $DB

                ORG     $2000

; ---------------------------------------------------------------------------
; Set up
; ---------------------------------------------------------------------------
START           LDS     #STACK_TOP
                CLRA                    ; DP = $00: the library (and our
                TFR     A,DP            ;  variables) use direct addressing
                SETDP   $00             ;  in page zero
                ANDCC   #$EF            ; enable IRQs: the keyboard is read
                                        ;  under interrupt
                JSR     TGL_INIT        ; reset CRTC start, hide cursor
                LDX     #BUFFER         ; draw into our buffer at $3000
                JSR     TGL_SETBUF
                CLR     <ANG_A          ; start square-on, mid zoom
                CLR     <ANG_B
                CLR     <FRAMES
                CLR     <ZOOM
                CLR     <WIRE           ; edges of hidden faces are skipped
                CLRA                    ; status row title
                LDX     #TITLE
                JSR     TGL_TEXT

; ---------------------------------------------------------------------------
; Main loop: one pass per frame
; ---------------------------------------------------------------------------
FRAME           JSR     TGL_CLS
                LDA     #TGL_MODE_SET   ; faces in white ...
                JSR     TGL_SETMODE
                LBSR    ZOOMSZ
                LBSR    MATRIX
                LBSR    CORNERS
                LBSR    FACES
                LBSR    FILLS           ; fill the visible faces white
                LDA     #TGL_MODE_CLEAR ; ... spots and edges in black
                JSR     TGL_SETMODE
                LBSR    PIPS            ; cut out the spots
                LBSR    EDGES           ; and the edges
                LDA     #PACE_TICKS
                JSR     TGL_PACE
                JSR     TGL_BLIT

; Advance the angles and zoom phase. Being bytes, they wrap from 255 back
; to 0 by themselves, which is exactly one full turn.
                LDA     <ANG_A
                ADDA    #STEP_A
                STA     <ANG_A
                LDA     <ANG_B
                ADDA    #STEP_B
                STA     <ANG_B
                LDA     <ZOOM
                ADDA    #STEP_Z
                STA     <ZOOM

                JSR     TGL_INKEY       ; any key exits
                LBNE    TGL_EXIT
; Test builds stop after TESTFRAMES frames so the emulator can inspect
; the result. Normal builds skip this.
                IFDEF   TESTFRAMES
                INC     <FRAMES
                LDA     <FRAMES
                CMPA    #TESTFRAMES
                BEQ     DONE
                ENDC
                LBRA    FRAME
DONE            BRA     DONE

; ---------------------------------------------------------------------------
; PIPS - cut out the spots on each visible face (plot mode is CLEAR)
; ---------------------------------------------------------------------------
PIPS            LDX     #TX             ; halve the nine terms: HX = TX/2 ...
                LDB     #9
PP_HALF         LDA     ,X
                ASRA                    ;  (ASR keeps the sign)
                STA     $40,X
                LEAX    1,X
                DECB
                BNE     PP_HALF
                LDA     #1              ; spot size from the zoom: 1, 2 or 3
                LDB     <SIZE           ;  pixels across
                CMPB    #14
                BLO     PP_SZ
                INCA
                CMPB    #26
                BLO     PP_SZ
                INCA
PP_SZ           STA     <PIPSZ
                LEAY    PIPTAB,PCR      ; Y -> this face's spots
                CLR     <FACEN
PP_FACE         LDX     #VIS            ; skip faces that can't be seen
                LDB     <FACEN
                ABX
                TST     ,X
                BEQ     PP_NEXTF
                LEAX    FACEAX,PCR      ; the face's axes and sign
                LDB     <FACEN
                ASLB
                ASLB
                ABX
                LDD     ,X
                STD     <PA             ; PA, PB
                LDD     2,X
                STD     <PC             ; PC, PS
                LDA     ,Y              ; number of spots
                STA     <PIPN
                LEAX    1,Y             ; then their positions
                STX     <PIPP
PP_PIP          LDX     <PIPP           ; next spot's position on the face
                LDD     ,X++
                STX     <PIPP
                STD     <PPB            ; PPB, PPC
                BSR     PIPPOS          ; A,B = its screen x, y
                LBSR    PIPDRAW
                DEC     <PIPN
                BNE     PP_PIP
PP_NEXTF        LEAY    PIPREC,Y        ; next face
                INC     <FACEN
                LDA     <FACEN
                CMPA    #6
                BLO     PP_FACE
                RTS

; ---------------------------------------------------------------------------
; PIPPOS - screen position of a spot centre
;   The point is S along the face's axis PA (signed by PS), plus PPB and
;   PPC halves of S along the in-face axes PB and PC. Each rotated
;   coordinate is then PS*T[PA] + PPB*H[PB] + PPC*H[PC], using that row's
;   terms T and halved terms H (PROWV). Projected as in CORNERS.
;   Exit: A = screen x, B = screen y (signed)
; ---------------------------------------------------------------------------
PIPPOS          LDX     #TX             ; rotated x
                BSR     PROWV
                STA     <VX
                LDX     #TZ             ; rotated z -> depth table index
                BSR     PROWV
                ADDA    #64
                STA     <ZI
                LDX     #TY             ; rotated y
                BSR     PROWV
                LEAX    RYTAB,PCR       ; screen y = CY + y * RY[z] / 128
                LDB     <ZI
                ABX
                LDB     ,X
                LBSR    PMUL
                ADDA    #CY
                PSHS    A
                LEAX    RXTAB,PCR       ; screen x = CX + x * RX[z] / 128
                LDB     <ZI
                ABX
                LDB     ,X
                LDA     <VX
                LBSR    PMUL
                ADDA    #CX
                PULS    B,PC

; PROWV - one rotated coordinate of the spot. Entry: X -> a row's terms
;   (TX, TY or TZ); its halved terms are at $40,X. Exit: A.
PROWV           LDB     <PA             ; PS * T[PA]
                LDA     B,X
                TST     <PS
                BPL     PV_1
                NEGA
PV_1            LEAU    $40,X           ; U -> the halved terms
                LDB     <PB             ; + PPB * H[PB]
                TST     <PPB
                BEQ     PV_3
                BMI     PV_2
                ADDA    B,U
                BRA     PV_3
PV_2            SUBA    B,U
PV_3            LDB     <PC             ; + PPC * H[PC]
                TST     <PPC
                BEQ     PV_5
                BMI     PV_4
                ADDA    B,U
                RTS
PV_4            SUBA    B,U
PV_5            RTS

; ---------------------------------------------------------------------------
; PIPDRAW - draw a spot: a square PIPSZ pixels across, centred on (A, B),
;   with clipped plots (so spots near the screen edge are safe)
; ---------------------------------------------------------------------------
PIPDRAW         LDX     #0              ; top-left corner = centre - (size-1)/2
                PSHS    A
                LDA     <PIPSZ
                DECA
                LSRA
                STA     <PCX            ;  (PCX as a temporary)
                PULS    A
                SUBA    <PCX
                SUBB    <PCX
                STD     <PCX            ; PCX, PCY = top-left
                LDB     <PIPSZ          ; rows
PD_ROW          PSHS    B
                LDB     <PIPSZ          ; columns
PD_COL          PSHS    B
                LDA     <PCX
                ADDA    ,S              ; x = left + (columns left - 1)
                DECA
                LDB     <PCY
                ADDB    1,S             ; y = top + (rows left - 1)
                DECB
                JSR     TGL_PLOTC
                PULS    B
                DECB
                BNE     PD_COL
                PULS    B
                DECB
                BNE     PD_ROW
                RTS

; Every face is filled solid white (FILLS takes each face's pattern from
; here)
FACEPAT         FCB     TGL_PAT_SOLID,TGL_PAT_SOLID,TGL_PAT_SOLID
                FCB     TGL_PAT_SOLID,TGL_PAT_SOLID,TGL_PAT_SOLID

; Each face's axis, its two in-face axes, and its sign (+1 for the + face,
; -1 for the - face). Axes: 0 x, 1 y, 2 z.
FACEAX          FCB     0,1,2,1                 ; +x
                FCB     0,1,2,-1                ; -x
                FCB     1,0,2,1                 ; +y
                FCB     1,0,2,-1                ; -y
                FCB     2,0,1,1                 ; +z
                FCB     2,0,1,-1                ; -z

; Each face's spots: a count, then each spot's position along the face's
; two in-face axes, in halves of S (-1, 0 or +1). Records are PIPREC bytes
; apart (room for six spots). Opposite faces add up to seven.
PIPREC          EQU     13
PIPTAB          FCB     1,0,0,0,0,0,0,0,0,0,0,0,0                       ; +x: 1
                FCB     6,-1,-1,-1,0,-1,1,1,-1,1,0,1,1                  ; -x: 6
                FCB     2,-1,-1,1,1,0,0,0,0,0,0,0,0                     ; +y: 2
                FCB     5,-1,-1,1,-1,0,0,-1,1,1,1,0,0                   ; -y: 5
                FCB     3,-1,-1,0,0,1,1,0,0,0,0,0,0                     ; +z: 3
                FCB     4,-1,-1,1,-1,-1,1,1,1,0,0,0,0                   ; -z: 4

; Status row title. $87 white, $83 yellow text codes.
TITLE           FCB     $83
                FCC     "CUBE DEMO"
                FCB     $86
                FCC     "DIE"
                FCB     0

                INCLUDE "cube_fill.asm"
                INCLUDE "cube_core.asm"
