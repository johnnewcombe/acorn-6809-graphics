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
