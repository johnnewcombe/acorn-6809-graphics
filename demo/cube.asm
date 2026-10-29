; ===========================================================================
; Rotating cube demo for the teletext graphics library
;
;   A wireframe cube that tumbles about two axes and slowly zooms in and
;   out, drawn in perspective with its hidden lines removed, so it looks
;   solid. Press the space bar to switch hidden-line removal off and on
;   (to see the full wireframe); any other key exits.
;
;   Loading: tgl.bin at $1000 (TGL_BASE in cube_defs.inc), cube.bin at
;   $2000 (its ORG). Run from START ($2000). Works with either machine's
;   library build.
;
;   This is the simplest of three cube demos sharing the same code:
;     cube.asm   - this one: edges only, hidden lines removed
;     cubep.asm  - each face filled with its own pattern
;     cubed.asm  - a die: white faces, black spots and edges
;   The shared settings and variables are in cube_defs.inc, and the
;   rotation, projection, face visibility and edge drawing in cube_core.asm,
;   which also explains the maths.
;
;   Each frame:
;     1. clear the off-screen buffer                       (TGL_CLS)
;     2. work out this frame's size from the zoom phase    (ZOOMSZ)
;     3. build the rotation for this frame's angles        (MATRIX)
;     4. rotate the 8 corners and project them to screen   (CORNERS)
;     5. work out which of the 6 faces point at the viewer (FACES)
;     6. draw the 12 edges, skipping edges whose two faces
;        are both hidden (unless in wireframe)             (EDGES)
;     7. wait for the frame period to run out              (TGL_PACE)
;     8. copy the buffer to the screen                     (TGL_BLIT)
;     9. advance the angles and zoom, check for a key, repeat
;
;   Build with -D TESTFRAMES=n to stop after n frames (emulator tests), and
;   -D WIREFRAME to start with hidden-line removal off.
; ===========================================================================
                INCLUDE "cube_defs.inc"

PACE_TICKS      EQU     2               ; frame length in 50Hz ticks: 2 = 25
                                        ;  frames per second

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
                IFDEF   WIREFRAME
                LDA     #$FF            ; start showing every edge
                ELSE
                CLRA                    ; start with hidden lines removed
                ENDC
                STA     <WIRE
                CLRA                    ; status row: how to use the keys
                LDX     #KEYHELP
                JSR     TGL_TEXT

; ---------------------------------------------------------------------------
; Main loop: one pass per frame
; ---------------------------------------------------------------------------
FRAME           JSR     TGL_CLS         ; blank the buffer
                LBSR    ZOOMSZ          ; SIZE for this frame
                LBSR    MATRIX          ; terms TX, TY, TZ for this frame
                LBSR    CORNERS         ; screen positions PX, PY
                LBSR    FACES           ; which faces can be seen
                LBSR    EDGES           ; draw into the buffer
                LDA     #PACE_TICKS     ; wait for the frame period, so every
                JSR     TGL_PACE        ;  frame takes the same time
                JSR     TGL_BLIT        ; show it

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

; Keys: space toggles hidden-line removal, anything else exits.
; TGL_INKEY returns Z set if no key is waiting, else the key in A.
                JSR     TGL_INKEY
                BEQ     NOKEY
                CMPA    #' '
                LBNE    TGL_EXIT        ; not space: exit (never returns)
                COM     <WIRE           ; space: 0 <-> $FF
NOKEY
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

; Status row help. $83 yellow, $87 white, $86 cyan text codes.
KEYHELP         FCB     $83
                FCC     "SPACE"
                FCB     $87
                FCC     "WIREFRAME"
                FCB     $86
                FCC     "OTHER KEY EXITS"
                FCB     0

                INCLUDE "cube_core.asm"
