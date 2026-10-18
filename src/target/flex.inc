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

; Monitor RAM vectors and keyboard buffer pointers (monitor RAM at $E300)
MON_COPADR      EQU     $E365           ; console output routine address
MON_CINADR      EQU     $E367           ; console input routine address
MON_HEADST      EQU     $E387           ; keyboard buffer: static head
MON_TAIL        EQU     $E38B           ; keyboard buffer: tail
FLEX_WARMS      EQU     $CD03           ; FLEX warm start
