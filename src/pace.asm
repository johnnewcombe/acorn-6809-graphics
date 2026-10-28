; ---------------------------------------------------------------------------
; T_PACE - keep a steady frame rate
;   Entry: A = frame length in 50Hz ticks: 1 = 50 fps, 2 = 25 fps,
;          3 = about 17 fps (0 counts as 1, more than 3 counts as 3)
;          DP = $00
;   Exit:  all registers preserved
;
;   Call once per frame, just before TGL_BLIT. It waits until the frame
;   period started by the previous call has run out, then starts the next
;   one, so every frame takes the same time however much was drawn. If a
;   frame took longer than its period it carries straight on, so the frame
;   rate falls gracefully rather than stalling. The first call after
;   TGL_INIT starts timing without waiting.
;
;   The period is timed with Timer 2 of the main VIA, in one-shot mode:
;   writing its high byte loads the count and starts it, and IFR bit 5 sets
;   when it reaches zero. Only the flag is polled - the timer's interrupt is
;   never enabled - and nothing else in the library touches the VIA. A
;   program that needs Timer 2 for itself simply doesn't call TGL_PACE, or
;   builds the library with NOPACE=1, which reduces this routine to RTS.
;
;   Timer 2's longest count is 65535 clocks (65ms at 1MHz), which is why
;   periods stop at three ticks (60ms).
;
;   This keeps animation smooth and even, but cannot stop tearing: the
;   timer is not locked to the display, as the 6845's vertical sync is not
;   connected to anything the CPU can read.
; ---------------------------------------------------------------------------
                IFDEF   TGL_NOPACE
T_PACE          RTS                     ; NOPACE build: does nothing
                ELSE

T_PACE          PSHS    D,X
                TSTA                    ; ticks: 0 counts as 1 ...
                BNE     PA_1
                INCA
PA_1            CMPA    #3              ; ... more than 3 counts as 3
                BLS     PA_2
                LDA     #3
PA_2            LDX     #VIA_BASE
                TST     <P_RUN          ; a period running? wait for it to
                BEQ     PA_START        ;  finish (first call: no waiting)
PA_WAIT         LDB     VIA_IFR,X
                BITB    #T2_FLAG
                BEQ     PA_WAIT

PA_START        LDB     VIA_ACR,X       ; make sure Timer 2 is a one-shot
                ANDB    #~ACR_T2COUNT&$FF   ;  timer, leaving the rest of the
                STB     VIA_ACR,X       ;  ACR alone
                LEAX    PA_TAB-2,PCR    ; X -> period for A ticks (2 bytes
                ASLA                    ;  each, A = 1-3)
                LDD     A,X
                LDX     #VIA_BASE
                STB     VIA_T2L,X       ; low byte into the latch ...
                STA     VIA_T2H,X       ; ... high byte starts the count and
                                        ;  clears the timed-out flag
                LDA     #1
                STA     <P_RUN
                PULS    D,X,PC

PA_TAB          FDB     TICK,2*TICK,3*TICK
                ENDC
