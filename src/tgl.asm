; ===========================================================================
; Acorn System 3 Teletext Graphics Library (working name)
; 6809 sixel graphics for the Acorn teletext VDU (6845 + SAA5050)
;
; Build with -D TARGET_FLEX for the FLEX machine; default is a standard
; System 3. The binary is position-independent: load it anywhere and call
; the entry points as fixed offsets from the load address (tgl_api.inc).
;
; Rules that keep it position-independent:
;   - references to the library's own code/data use ,PCR
;   - the jump table uses LBRA
;   - only hardware (VDU, CRTC) and page-zero workspace are absolute
; The Makefile assembles at two origins and fails if the binaries differ.
; ===========================================================================

                IFDEF   TARGET_FLEX
                INCLUDE "target/flex.inc"
                ELSE
                INCLUDE "target/sys3.inc"
                ENDC

                INCLUDE "consts.inc"
                INCLUDE "ws.inc"

                SETDP   $00
                ORG     TGL_ORG

; ---------------------------------------------------------------------------
; Jump table - order and offsets must match tgl_api.inc
; ---------------------------------------------------------------------------
TGL_START
J_INIT          LBRA    T_INIT          ; +0
J_SETBUF        LBRA    T_SETBUF        ; +3
J_CLS           LBRA    T_CLS           ; +6
J_SETMODE       LBRA    T_SETMODE       ; +9
J_PLOT          LBRA    T_PLOT          ; +12
J_LINE          LBRA    T_LINE          ; +15
J_BLIT          LBRA    T_BLIT          ; +18
J_PLOTC         LBRA    T_PLOTC         ; +21
J_LINEC         LBRA    T_LINEC         ; +24
J_DONE          LBRA    T_DONE          ; +27
J_INKEY         LBRA    T_INKEY         ; +30
J_EXIT          LBRA    T_EXIT          ; +33
J_RECT          LBRA    T_RECT          ; +36
J_RECTF         LBRA    T_RECTF         ; +39
J_CIRC          LBRA    T_CIRC          ; +42
J_CIRCF         LBRA    T_CIRCF         ; +45
J_TEXT          LBRA    T_TEXT          ; +48
J_TCLR          LBRA    T_TCLR          ; +51
J_TNUM          LBRA    T_TNUM          ; +54
J_COLOUR        LBRA    T_COLOUR        ; +57
J_PACE          LBRA    T_PACE          ; +60
J_POLYF         LBRA    T_POLYF         ; +63
J_SETPAT        LBRA    T_SETPAT        ; +66
J_FLIPH         LBRA    T_FLIPH         ; +69

; Check the table against the published interface
TGL_BASE        EQU     TGL_START
                INCLUDE "tgl_api.inc"
                IFNE    (J_SETBUF-TGL_SETBUF)|(J_CLS-TGL_CLS)|(J_SETMODE-TGL_SETMODE)
                ERROR   "Jump table does not match tgl_api.inc"
                ENDC
                IFNE    (J_PLOT-TGL_PLOT)|(J_LINE-TGL_LINE)|(J_BLIT-TGL_BLIT)
                ERROR   "Jump table does not match tgl_api.inc"
                ENDC
                IFNE    (J_PLOTC-TGL_PLOTC)|(J_LINEC-TGL_LINEC)
                ERROR   "Jump table does not match tgl_api.inc"
                ENDC
                IFNE    (J_DONE-TGL_DONE)|(J_INKEY-TGL_INKEY)|(J_EXIT-TGL_EXIT)
                ERROR   "Jump table does not match tgl_api.inc"
                ENDC
                IFNE    (J_RECT-TGL_RECT)|(J_RECTF-TGL_RECTF)
                ERROR   "Jump table does not match tgl_api.inc"
                ENDC
                IFNE    (J_CIRC-TGL_CIRC)|(J_CIRCF-TGL_CIRCF)
                ERROR   "Jump table does not match tgl_api.inc"
                ENDC
                IFNE    (J_TEXT-TGL_TEXT)|(J_TCLR-TGL_TCLR)|(J_TNUM-TGL_TNUM)
                ERROR   "Jump table does not match tgl_api.inc"
                ENDC
                IFNE    (J_COLOUR-TGL_COLOUR)|(J_PACE-TGL_PACE)|(J_POLYF-TGL_POLYF)|(J_SETPAT-TGL_SETPAT)|(J_FLIPH-TGL_FLIPH)
                ERROR   "Jump table does not match tgl_api.inc"
                ENDC

; ---------------------------------------------------------------------------
; Modules
; ---------------------------------------------------------------------------
                INCLUDE "init.asm"
                INCLUDE "cls.asm"
                INCLUDE "plot.asm"
                INCLUDE "line.asm"
                INCLUDE "blit.asm"
                INCLUDE "clip.asm"
                INCLUDE "rect.asm"
                INCLUDE "circle.asm"
                INCLUDE "text.asm"
                INCLUDE "colour.asm"
                INCLUDE "pace.asm"
                INCLUDE "polygon.asm"
                INCLUDE "flip.asm"
                INCLUDE "system.asm"
                INCLUDE "tables.asm"

TGL_END                                 ; default buffer starts here

; The demos load at $2800, leaving the library 6K from $1000
                IFGT    TGL_END-TGL_START-$1800
                ERROR   "Library is larger than 6K: it would overlap the demos at $2800"
                ENDC
