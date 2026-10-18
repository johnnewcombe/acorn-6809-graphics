; ---------------------------------------------------------------------------
; System services: restoring the display, reading the keyboard, exiting.
; These go through the monitor's RAM vectors (target/*.inc), so they work
; whichever monitor version is fitted.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; T_DONE - give the display back to the monitor / FLEX
;   Sends a form feed through the monitor's console output vector. The
;   monitor's form-feed handler (CRTCI) re-detects the 6845 type, reloads
;   all its registers (restoring the cursor and start address), resets the
;   driver's row, column and scroll position, homes the cursor and clears
;   the screen.
;   Entry: any DP              Exit: all registers preserved
; ---------------------------------------------------------------------------
T_DONE          PSHS    A
                LDA     #$0C            ; form feed
                JSR     [MON_COPADR]
                PULS    A,PC

; ---------------------------------------------------------------------------
; T_INKEY - check for a key without waiting
;   The monitor's IRQ handler buffers keypresses; a key is waiting when the
;   buffer's tail and static head differ. Needs IRQs enabled.
;   Entry: any DP
;   Exit:  Z set, A = 0 if no key; Z clear, A = key if there was one.
;          Other registers preserved.
; ---------------------------------------------------------------------------
T_INKEY         PSHS    X
                LDX     MON_TAIL
                CMPX    MON_HEADST
                BEQ     IK_NONE
                JSR     [MON_CINADR]    ; returns at once: a key is waiting
                ANDCC   #$FB            ; Z clear: key in A
                PULS    X,PC
IK_NONE         CLRA                    ; Z set (PULS leaves flags alone)
                PULS    X,PC

; ---------------------------------------------------------------------------
; T_EXIT - restore the display and return to the operating system
;   FLEX machine: FLEX warm start. Standard System 3: SWI into the monitor
;   (it shows the registers and stays in the monitor; proceeding just
;   re-executes the SWI).
;   Does not return.
; ---------------------------------------------------------------------------
T_EXIT          BSR     T_DONE
                IFDEF   TARGET_FLEX
                JMP     FLEX_WARMS
                ELSE
                SWI
                ENDC
