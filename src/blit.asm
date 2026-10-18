; ---------------------------------------------------------------------------
; T_BLIT - copy the off-screen buffer to screen rows 0-23 (960 bytes)
;   Stack-blast copy: PULU six bytes from the buffer, PSHS them to the
;   screen. S is borrowed, so IRQ and FIRQ are masked for the duration
;   (roughly 5ms at 1MHz).
;   Entry: DP = $00            Exit: all registers preserved
; ---------------------------------------------------------------------------
BLAST6          MACRO
                PULU    D,X,Y
                PSHS    D,X,Y
                LEAS    12,S
                ENDM

T_BLIT          PSHS    CC,D,DP,X,Y,U
                ORCC    #$50            ; mask IRQ and FIRQ
                STS     <W_SAVSP
                LDA     #BUFSIZE/24     ; 40 iterations x 24 bytes
                STA     <W_COUNT
                LDU     <W_BUF
                LDS     #VDU_BASE+6     ; PSHS writes downwards from here
BLIT_LOOP       BLAST6
                BLAST6
                BLAST6
                BLAST6
                DEC     <W_COUNT
                BNE     BLIT_LOOP
                LDS     <W_SAVSP
                PULS    CC,D,DP,X,Y,U,PC
