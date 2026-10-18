; ---------------------------------------------------------------------------
; Target: Acorn System FLEX machine (6809, FLEX memory map)
; ---------------------------------------------------------------------------
VDU_BASE        EQU     $E400           ; teletext VDU screen RAM
CRTC_ADDR       EQU     $E800           ; 6845 address register
CRTC_DATA       EQU     $E801           ; 6845 data register

; Default load address. Override with: lwasm -D TGL_ORG=0x2000
                IFNDEF  TGL_ORG
TGL_ORG         EQU     $1000
                ENDC
