; ===========================================================================
; Demo / smoke test for the teletext graphics library
;   Load tgl.bin at TGL_BASE and demo.bin at its ORG, then run from START.
;   Draws horizontal stripes (every other row fully lit) and blits them.
;   Target independent: the library binary carries the VDU address.
; ===========================================================================
TGL_BASE        EQU     $1000           ; where tgl.bin is loaded
                INCLUDE "tgl_api.inc"

DEMOBUF         EQU     $3000           ; off-screen buffer (960 bytes)
STACK_TOP       EQU     $0200           ; user stack $0100-$01FF

                ORG     $2000
START           LDS     #STACK_TOP
                CLRA
                TFR     A,DP
                SETDP   $00

                JSR     TGL_INIT        ; resets 6845 start address
                LDX     #DEMOBUF
                JSR     TGL_SETBUF
                JSR     TGL_CLS

; Light every other row: columns 1-39 = all six sixels on
                LDX     #DEMOBUF+1      ; row 0, column 1
                LDB     #12             ; 24 rows / 2
                LDA     #$7F
D_ROW           PSHS    B
                LDB     #39
D_COL           STA     ,X+
                DECB
                BNE     D_COL
                LEAX    41,X            ; skip next row's col 0 and the row
                PULS    B
                DECB
                BNE     D_ROW

                JSR     TGL_BLIT

; Replace with a return to the monitor, or JMP $CD03 (FLEX warm start)
DONE
                BRA     DONE            ; warm start flex
