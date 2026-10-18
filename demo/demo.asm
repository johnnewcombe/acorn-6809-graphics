; ===========================================================================
; Demo / smoke test for the teletext graphics library
;
;   Draws a border round the screen and a starburst of lines from the centre
;   to points round the edge, shows it, then waits for a key and exits.
;
;   Loading: tgl.bin at $1000 (TGL_BASE below), demo.bin at $2000 (its ORG).
;   Run from START ($2000). Press any key to exit.
;
;   The same demo.bin works on both machines: everything machine-specific
;   (screen address, CRTC, monitor vectors) lives inside the library build.
;
;   How drawing works with this library:
;     1. TGL_INIT / TGL_SETBUF  set things up and choose an off-screen buffer
;     2. TGL_CLS               blank the buffer
;     3. TGL_PLOT / TGL_LINE   draw into the buffer (nothing visible yet)
;     4. TGL_BLIT              copy the finished buffer to the screen at once
;   Because all the drawing happens off-screen, you never see a half-drawn
;   picture.
;
;   Screen coordinates: x 0-77 (left to right), y 0-71 (top to bottom).
;   Each teletext character cell holds a 2 x 3 block of these pixels.
; ===========================================================================

; ---------------------------------------------------------------------------
; Library entry points
;   TGL_BASE is where tgl.bin is loaded. tgl_api.inc turns that into the
;   address of each routine (TGL_INIT = TGL_BASE+0, TGL_LINE = +15, ...),
;   so this program just does JSR TGL_LINE etc.
; ---------------------------------------------------------------------------
TGL_BASE        EQU     $1000
                INCLUDE "tgl_api.inc"

; ---------------------------------------------------------------------------
; Memory and constants
; ---------------------------------------------------------------------------
DEMOBUF         EQU     $3000           ; off-screen buffer: 960 bytes
                                        ;  (24 rows x 40 characters)
STACK_TOP       EQU     $0200           ; stack occupies $0100-$01FF; the 6809
                                        ;  pre-decrements, so the first push
                                        ;  lands at $01FF
D_N             EQU     $80             ; loop counter, in page zero. The
                                        ;  library's own workspace is $00-$17,
                                        ;  so $80 upwards is safe for us
CX              EQU     38              ; centre of the starburst
CY              EQU     35

                ORG     $2000

; ---------------------------------------------------------------------------
; Set up
; ---------------------------------------------------------------------------
START           LDS     #STACK_TOP      ; our own stack

; The library keeps its variables in page zero and uses direct addressing
; ("<name") to reach them quickly, so every library call must be made with
; the direct page register DP = $00.
                CLRA
                TFR     A,DP            ; DP = $00 (there is no LDDP, so via A)
                SETDP   $00             ; tell the assembler, so "<D_N" etc.
                                        ;  assemble as direct-page addresses

; The monitor reads the keyboard from an interrupt, so IRQs must be enabled
; for TGL_INKEY to see key presses. ANDCC #$EF clears the I (IRQ mask) bit.
                ANDCC   #$EF

                JSR     TGL_INIT        ; reset the 6845 start address, hide
                                        ;  the cursor, select SET plot mode
                LDX     #DEMOBUF        ; use our own buffer at $3000
                JSR     TGL_SETBUF
                JSR     TGL_CLS         ; blank it

; ---------------------------------------------------------------------------
; Border round the whole graphics area
;
; TGL_LINE takes the start point in A (x) and B (y), and the end point
; packed into X: x1 in the high byte, y1 in the low byte. So LDX #$4D00
; means x1 = $4D (77), y1 = $00 (0).
;
; Library routines preserve all registers, so after one line A and B still
; hold the same start point and can be reused for the next line.
; ---------------------------------------------------------------------------
                CLRA                    ; start (0,0): top-left corner
                CLRB
                LDX     #$4D00          ; to (77,0): top edge
                JSR     TGL_LINE
                LDX     #$0047          ; to (0,71): left edge ($47 = 71)
                JSR     TGL_LINE
                LDA     #77             ; start (77,71): bottom-right corner
                LDB     #71
                LDX     #$4D00          ; to (77,0): right edge
                JSR     TGL_LINE
                LDX     #$0047          ; to (0,71): bottom edge
                JSR     TGL_LINE

; ---------------------------------------------------------------------------
; Starburst: lines from the centre (CX,CY) out to every 7th point round
; the border.
;
; Building the packed end point: put x in A and y in B, then TFR D,X.
; D is simply A:B as one 16-bit register (A is the high byte), so this
; gives X = x:y in a single instruction.
; ---------------------------------------------------------------------------

; First pass: top and bottom edges. D_N steps along x: 0, 7, 14 ... 77.
                CLR     <D_N            ; n = 0
D_TB            LDA     <D_N            ; end point (n, 0) on the top edge
                CLRB
                TFR     D,X             ; X = n:0
                LDA     #CX             ; start at the centre
                LDB     #CY
                JSR     TGL_LINE
                LDA     <D_N            ; end point (n, 71) on the bottom edge
                LDB     #71
                TFR     D,X
                LDA     #CX
                LDB     #CY
                JSR     TGL_LINE
                LDA     <D_N            ; n = n + 7
                ADDA    #7
                STA     <D_N
                CMPA    #78             ; carry on while n < 78 (BLO is an
                BLO     D_TB            ;  unsigned "branch if lower")

; Second pass: left and right edges. D_N steps down y: 0, 7, 14 ... 70.
                CLR     <D_N
D_LR            CLRA                    ; end point (0, n) on the left edge
                LDB     <D_N
                TFR     D,X
                LDA     #CX
                LDB     #CY
                JSR     TGL_LINE
                LDA     #77             ; end point (77, n) on the right edge
                LDB     <D_N
                TFR     D,X
                LDA     #CX
                LDB     #CY
                JSR     TGL_LINE
                LDA     <D_N            ; n = n + 7, while n < 72
                ADDA    #7
                STA     <D_N
                CMPA    #72
                BLO     D_LR

; ---------------------------------------------------------------------------
; Everything so far was drawn into the buffer. Now copy it to the screen.
; ---------------------------------------------------------------------------
                JSR     TGL_BLIT

; ---------------------------------------------------------------------------
; Wait for a key, then exit.
;   TGL_INKEY doesn't wait: it returns Z set if no key is waiting, or Z clear
;   with the key in A. So loop until Z is clear.
;   TGL_EXIT restores the normal text display and returns to FLEX (or the
;   monitor on a standard System 3). It never comes back, so JMP not JSR.
; ---------------------------------------------------------------------------
DONE            JSR     TGL_INKEY
                BEQ     DONE            ; no key yet: keep checking
                JMP     TGL_EXIT
