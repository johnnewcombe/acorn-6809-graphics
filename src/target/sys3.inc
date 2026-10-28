; ---------------------------------------------------------------------------
; Target: standard Acorn System 3 with 6809 CPU card
; ---------------------------------------------------------------------------
VDU_BASE        EQU     $0400           ; teletext VDU screen RAM
CRTC_ADDR       EQU     $0800           ; 6845 address register
CRTC_DATA       EQU     $0801           ; 6845 data register

; Default load address. Override with: lwasm -D TGL_ORG=0x2000
; (The code is position-independent; this only sets where the
; listing and the default build place it.)
                IFNDEF  TGL_ORG
TGL_ORG         EQU     $1000
                ENDC

; Monitor RAM vectors and keyboard buffer pointers (monitor RAM at $0300)
; Checked against the standard ROM listing (monitor source with BASE=$0000).
MON_COPADR      EQU     $0365           ; console output routine address
MON_CINADR      EQU     $0367           ; console input routine address
MON_HEADST      EQU     $0387           ; keyboard buffer: static head
MON_TAIL        EQU     $038B           ; keyboard buffer: tail

; Main VIA (keyboard/printer/cassette). The library uses only Timer 2, and
; only inside TGL_PACE; the monitor uses Timer 1 and never touches Timer 2.
VIA_BASE        EQU     $0980
