; ===========================================================================
; Demo / smoke test for the teletext graphics library
;   Load tgl.bin at TGL_BASE and demo.bin at its ORG, then run from START.
;   Draws a border and a starburst with TGL_LINE, then blits.
;   Target independent: the library binary carries the VDU address.
; ===========================================================================
TGL_BASE        EQU     $1000           ; where tgl.bin is loaded
                INCLUDE "tgl_api.inc"

DEMOBUF         EQU     $3000           ; off-screen buffer (960 bytes)
STACK_TOP       EQU     $0200           ; user stack $0100-$01FF
D_N             EQU     $80             ; demo variable (clear of library workspace)
CX              EQU     38              ; starburst centre
CY              EQU     35

                ORG     $2000
START           LDS     #STACK_TOP
                CLRA
                TFR     A,DP
                SETDP   $00

                JSR     TGL_INIT        ; resets 6845 start address
                LDX     #DEMOBUF
                JSR     TGL_SETBUF
                JSR     TGL_CLS

; Border round the whole graphics area (x 0-77, y 0-71)
                CLRA                    ; from (0,0)
                CLRB
                LDX     #$4D00          ; to (77,0)
                JSR     TGL_LINE
                LDX     #$0047          ; to (0,71)
                JSR     TGL_LINE
                LDA     #77             ; from (77,71)
                LDB     #71
                LDX     #$4D00          ; to (77,0)
                JSR     TGL_LINE
                LDX     #$0047          ; to (0,71)
                JSR     TGL_LINE

; Starburst from the centre to every 7th point round the border
                CLR     <D_N
D_TB            LDA     <D_N            ; to (n,0) and (n,71)
                CLRB
                TFR     D,X
                LDA     #CX
                LDB     #CY
                JSR     TGL_LINE
                LDA     <D_N
                LDB     #71
                TFR     D,X
                LDA     #CX
                LDB     #CY
                JSR     TGL_LINE
                LDA     <D_N
                ADDA    #7
                STA     <D_N
                CMPA    #78
                BLO     D_TB
                CLR     <D_N
D_LR            CLRA                    ; to (0,n) and (77,n)
                LDB     <D_N
                TFR     D,X
                LDA     #CX
                LDB     #CY
                JSR     TGL_LINE
                LDA     #77
                LDB     <D_N
                TFR     D,X
                LDA     #CX
                LDB     #CY
                JSR     TGL_LINE
                LDA     <D_N
                ADDA    #7
                STA     <D_N
                CMPA    #72
                BLO     D_LR

                JSR     TGL_BLIT

; Replace with a return to the monitor, or JMP $CD03 (FLEX warm start)
DONE            BRA     DONE
