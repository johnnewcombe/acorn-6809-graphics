; ===========================================================================
; Patterned cube demo for the teletext graphics library
;
;   The tumbling, zooming cube from cube.asm, drawn as a solid object: each
;   visible face is filled with its own pattern (TGL_POLYF and TGL_SETPAT),
;   so you can follow the faces round as it turns, with the edges drawn on
;   top. Press any key to exit.
;
;   Loading: tgl.bin at $1000, cubep.bin at $2000. Run from START ($2000).
;
;   Shares its code with cube.asm (see there for the list): the face
;   filling is in cube_fill.asm, the rest in cube_core.asm.
;
;   Each frame is as cube.asm's, with one addition: after working out which
;   faces can be seen, FILLS fills each visible face with its pattern from
;   FACEPAT, before the edges are drawn.
;
;   The patterns are fixed to the screen, not the faces: a face slides
;   across its pattern as it turns. (cubed.asm draws marks that turn with
;   the faces instead.)
;
;   Build with -D TESTFRAMES=n to stop after n frames (emulator tests).
; ===========================================================================
                INCLUDE "cube_defs.inc"

PACE_TICKS      EQU     3               ; frame length in 50Hz ticks: 3 =
                                        ;  about 17 frames per second

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
                LBSR    ZOOMSZ
                LBSR    MATRIX
                LBSR    CORNERS
                LBSR    FACES
                LBSR    FILLS           ; fill the visible faces
                LBSR    EDGES           ; then the edges on top
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

; Each face's fill pattern. A cube never shows two opposite faces at once,
; so the faces in view are always neighbours; each face is paired with a
; contrasting opposite (dense with sparse, horizontal with vertical) so the
; three faces you can see always look clearly different.
FACEPAT         FCB     TGL_PAT_SOLID           ; +x
                FCB     TGL_PAT_25              ; -x
                FCB     TGL_PAT_HLINES          ; +y
                FCB     TGL_PAT_VLINES          ; -y
                FCB     TGL_PAT_50              ; +z
                FCB     TGL_PAT_75              ; -z

; Status row title. $86 cyan, $83 yellow text codes.
TITLE           FCB     $86
                FCC     "PATTERNED CUBE"
                FCB     $83
                FCC     "ANY KEY EXITS"
                FCB     0

                INCLUDE "cube_fill.asm"
                INCLUDE "cube_core.asm"
