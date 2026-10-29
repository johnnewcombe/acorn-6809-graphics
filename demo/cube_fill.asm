; ===========================================================================
; cube_fill.asm - fill the cube's visible faces (used by cubep.asm and
;   cubed.asm). FILLS sets each face's pattern from the demo's FACEPAT
;   table, so the demo must provide one.
; ===========================================================================

; ---------------------------------------------------------------------------
; FILLS - fill each visible face with its pattern
;   For each visible face: select its pattern from the demo's FACEPAT
;   table, copy its four corners' screen positions into the POLY corner
;   list, and fill it with TGL_POLYF. FACETAB gives each face's corners in
;   order round the face. Visible faces never overlap on a convex shape,
;   so they can be filled in any order.
; ---------------------------------------------------------------------------
FILLS           LEAY    FACETAB,PCR
                CLR     <FACEN
FL_LOOP         LDX     #VIS            ; skip faces that can't be seen
                LDB     <FACEN
                ABX
                TST     ,X
                BEQ     FL_NEXT
                LEAX    FACEPAT,PCR     ; this face's pattern
                LDB     <FACEN
                LDA     B,X
                JSR     TGL_SETPAT
                LDA     #4              ; corner list: 4 corners ...
                STA     <POLY
                LDU     #POLY+1
                LDB     ,Y              ; ... each copied from PX, PY
                BSR     FL_CORNER
                LDB     1,Y
                BSR     FL_CORNER
                LDB     2,Y
                BSR     FL_CORNER
                LDB     3,Y
                BSR     FL_CORNER
                LDX     #POLY
                JSR     TGL_POLYF
FL_NEXT         LEAY    4,Y             ; next face
                INC     <FACEN
                LDA     <FACEN
                CMPA    #6
                BLO     FL_LOOP
                RTS

; FL_CORNER - Entry: B = corner number, U -> next slot in POLY.
;   Stores that corner's screen x, y; U += 2.
FL_CORNER       LDX     #PX
                ABX
                LDA     ,X              ; x
                LDB     8,X             ; y (PY = PX + 8)
                STD     ,U++
                RTS

; The six faces' corners, in order round each face (for TGL_POLYF):
; the four corners sharing the face's bit, going round.
FACETAB         FCB     1,3,7,5                 ; +x (bit 0 set)
                FCB     0,2,6,4                 ; -x (bit 0 clear)
                FCB     2,3,7,6                 ; +y (bit 1 set)
                FCB     0,1,5,4                 ; -y (bit 1 clear)
                FCB     4,5,7,6                 ; +z (bit 2 set)
                FCB     0,1,3,2                 ; -z (bit 2 clear)

