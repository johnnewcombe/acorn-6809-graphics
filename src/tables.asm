; ---------------------------------------------------------------------------
; Lookup tables - always referenced with ,PCR
;
; PTAB: one 4-byte entry per pixel row y (0-71):
;   +0,+1  offset of the first pixel column (COL1: 1, or 2 in a separated
;          build) of the cell row within the buffer: (y/3)*40+COL1
;   +2     sixel mask for an even x (left pixel)
;   +3     sixel mask for an odd x (right pixel)
; Sixel bits: top row 0/1, middle row 2/3, bottom row 4/6 (bit 5 always set)
; ---------------------------------------------------------------------------
PTAB
                FDB     0*COLS+COL1
                FCB     $01,$02           ; y=0
                FDB     0*COLS+COL1
                FCB     $04,$08           ; y=1
                FDB     0*COLS+COL1
                FCB     $10,$40           ; y=2
                FDB     1*COLS+COL1
                FCB     $01,$02           ; y=3
                FDB     1*COLS+COL1
                FCB     $04,$08           ; y=4
                FDB     1*COLS+COL1
                FCB     $10,$40           ; y=5
                FDB     2*COLS+COL1
                FCB     $01,$02           ; y=6
                FDB     2*COLS+COL1
                FCB     $04,$08           ; y=7
                FDB     2*COLS+COL1
                FCB     $10,$40           ; y=8
                FDB     3*COLS+COL1
                FCB     $01,$02           ; y=9
                FDB     3*COLS+COL1
                FCB     $04,$08           ; y=10
                FDB     3*COLS+COL1
                FCB     $10,$40           ; y=11
                FDB     4*COLS+COL1
                FCB     $01,$02           ; y=12
                FDB     4*COLS+COL1
                FCB     $04,$08           ; y=13
                FDB     4*COLS+COL1
                FCB     $10,$40           ; y=14
                FDB     5*COLS+COL1
                FCB     $01,$02           ; y=15
                FDB     5*COLS+COL1
                FCB     $04,$08           ; y=16
                FDB     5*COLS+COL1
                FCB     $10,$40           ; y=17
                FDB     6*COLS+COL1
                FCB     $01,$02           ; y=18
                FDB     6*COLS+COL1
                FCB     $04,$08           ; y=19
                FDB     6*COLS+COL1
                FCB     $10,$40           ; y=20
                FDB     7*COLS+COL1
                FCB     $01,$02           ; y=21
                FDB     7*COLS+COL1
                FCB     $04,$08           ; y=22
                FDB     7*COLS+COL1
                FCB     $10,$40           ; y=23
                FDB     8*COLS+COL1
                FCB     $01,$02           ; y=24
                FDB     8*COLS+COL1
                FCB     $04,$08           ; y=25
                FDB     8*COLS+COL1
                FCB     $10,$40           ; y=26
                FDB     9*COLS+COL1
                FCB     $01,$02           ; y=27
                FDB     9*COLS+COL1
                FCB     $04,$08           ; y=28
                FDB     9*COLS+COL1
                FCB     $10,$40           ; y=29
                FDB     10*COLS+COL1
                FCB     $01,$02           ; y=30
                FDB     10*COLS+COL1
                FCB     $04,$08           ; y=31
                FDB     10*COLS+COL1
                FCB     $10,$40           ; y=32
                FDB     11*COLS+COL1
                FCB     $01,$02           ; y=33
                FDB     11*COLS+COL1
                FCB     $04,$08           ; y=34
                FDB     11*COLS+COL1
                FCB     $10,$40           ; y=35
                FDB     12*COLS+COL1
                FCB     $01,$02           ; y=36
                FDB     12*COLS+COL1
                FCB     $04,$08           ; y=37
                FDB     12*COLS+COL1
                FCB     $10,$40           ; y=38
                FDB     13*COLS+COL1
                FCB     $01,$02           ; y=39
                FDB     13*COLS+COL1
                FCB     $04,$08           ; y=40
                FDB     13*COLS+COL1
                FCB     $10,$40           ; y=41
                FDB     14*COLS+COL1
                FCB     $01,$02           ; y=42
                FDB     14*COLS+COL1
                FCB     $04,$08           ; y=43
                FDB     14*COLS+COL1
                FCB     $10,$40           ; y=44
                FDB     15*COLS+COL1
                FCB     $01,$02           ; y=45
                FDB     15*COLS+COL1
                FCB     $04,$08           ; y=46
                FDB     15*COLS+COL1
                FCB     $10,$40           ; y=47
                FDB     16*COLS+COL1
                FCB     $01,$02           ; y=48
                FDB     16*COLS+COL1
                FCB     $04,$08           ; y=49
                FDB     16*COLS+COL1
                FCB     $10,$40           ; y=50
                FDB     17*COLS+COL1
                FCB     $01,$02           ; y=51
                FDB     17*COLS+COL1
                FCB     $04,$08           ; y=52
                FDB     17*COLS+COL1
                FCB     $10,$40           ; y=53
                FDB     18*COLS+COL1
                FCB     $01,$02           ; y=54
                FDB     18*COLS+COL1
                FCB     $04,$08           ; y=55
                FDB     18*COLS+COL1
                FCB     $10,$40           ; y=56
                FDB     19*COLS+COL1
                FCB     $01,$02           ; y=57
                FDB     19*COLS+COL1
                FCB     $04,$08           ; y=58
                FDB     19*COLS+COL1
                FCB     $10,$40           ; y=59
                FDB     20*COLS+COL1
                FCB     $01,$02           ; y=60
                FDB     20*COLS+COL1
                FCB     $04,$08           ; y=61
                FDB     20*COLS+COL1
                FCB     $10,$40           ; y=62
                FDB     21*COLS+COL1
                FCB     $01,$02           ; y=63
                FDB     21*COLS+COL1
                FCB     $04,$08           ; y=64
                FDB     21*COLS+COL1
                FCB     $10,$40           ; y=65
                FDB     22*COLS+COL1
                FCB     $01,$02           ; y=66
                FDB     22*COLS+COL1
                FCB     $04,$08           ; y=67
                FDB     22*COLS+COL1
                FCB     $10,$40           ; y=68
                FDB     23*COLS+COL1
                FCB     $01,$02           ; y=69
                FDB     23*COLS+COL1
                FCB     $04,$08           ; y=70
                FDB     23*COLS+COL1
                FCB     $10,$40           ; y=71

; T_SETMODE patch values: pre-op byte, operation opcode (indexed ,X)
MODETAB         FCB     $12,$AA         ; MODE_SET:   NOP,  ORA  ,X
                FCB     $43,$A4         ; MODE_CLEAR: COMA, ANDA ,X
                FCB     $12,$A8         ; MODE_XOR:   NOP,  EORA ,X

; MASKREAL: internal line mask (1,2,4,8,16,32) -> screen sixel mask
MASKREAL        FCB     0,$01,$02,0,$04,0,0,0,$08,0,0,0,0,0,0,0
                FCB     $10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                FCB     $40

; LTAB / RTAB: sixel masks covering sixel rows top..bottom of a cell, for
; the left / right pixel column. Index = top*3 + bottom (only top <= bottom
; is used).
LTAB            FCB     $01,$05,$15,$00,$04,$14,$00,$00,$10
RTAB            FCB     $02,$0A,$4A,$00,$08,$48,$00,$00,$40
