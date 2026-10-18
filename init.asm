; ---------------------------------------------------------------------------
; T_INIT - initialise the library
;   Resets the 6845 display start address (R12/R13) to zero so the visible
;   screen begins at VDU_BASE. The monitor and FLEX VDU drivers scroll in
;   hardware, which can leave the start address anywhere in the 1K.
;   Hides the hardware cursor (R10 = $20, the "no cursor" mode bits).
;   Sets the off-screen buffer to the memory immediately after the library
;   (BUFSIZE bytes must be free there) and the plot mode to MODE_SET.
;   Entry: DP = $00            Exit: all registers preserved
; ---------------------------------------------------------------------------
T_INIT          PSHS    D,X
                CLRB
                LDA     #12             ; R12 - start address high
                STA     CRTC_ADDR
                STB     CRTC_DATA
                LDA     #13             ; R13 - start address low
                STA     CRTC_ADDR
                STB     CRTC_DATA
                LDA     #10             ; R10 - cursor start / blink mode
                STA     CRTC_ADDR
                LDA     #$20            ; bits 6-5 = 01: no cursor
                STA     CRTC_DATA
                LEAX    TGL_END,PCR
                STX     <W_BUF
                LDA     #MODE_SET
                LBSR    T_SETMODE       ; patches T_PLOT for MODE_SET
                PULS    D,X,PC

; ---------------------------------------------------------------------------
; T_SETBUF - use a caller-supplied off-screen buffer
;   Entry: X = buffer address (BUFSIZE bytes), DP = $00
;   Exit:  all registers preserved
; ---------------------------------------------------------------------------
T_SETBUF        STX     <W_BUF
                RTS
