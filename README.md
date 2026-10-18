# Acorn System 3 6809 Graphics Library

## Introduction

This is a graphics library for the Acorn System 3 6809 computer. The library was inspired by the __teletexr__ graphics
library created by [BitShifters](http://bitshifters.github.io/). The original code was written in 6502
Assembler [](https://github.com/bitshifters/teletextr/tree/master/lib), this library has converted many of the routines
to relocatable 6809 Assembler and is designed to be used in the standard Acorn System 3 6809 and the Acorn Syatem 3 6809
with Flex. 

Sixel graphics for the Acorn teletext VDU (6845 + SAA5050) on 6809-based
Acorn System machines. Assembler callers only; built with lwasm.

## Building

    make            # library for both targets, plus the demo
    make sys3       # standard Acorn System 3  (VDU $0400, CRTC $0800)
    make flex       # FLEX machine            (VDU $E400, CRTC $E800)

Output is raw binary: `build/sys3/tgl.bin`, `build/flex/tgl.bin`,
`build/demo.bin`, with listings alongside.

## Using the library

The binary is position-independent: load it anywhere. Define `TGL_BASE`
as the load address and `INCLUDE "tgl_api.inc"`; entry points are fixed
offsets from the load address.

Calling conventions:

- Enter every routine with **DP = $00**. The library's workspace is in
  page zero (`src/ws.inc`).
- Registers are preserved unless a routine says otherwise.
- The stack belongs to the caller. `TGL_BLIT` borrows S briefly with IRQ
  and FIRQ masked.
- The off-screen buffer is 960 bytes (24 rows x 40). `TGL_INIT` places it
  immediately after the library; `TGL_SETBUF` puts it anywhere else.

Every build assembles the library at two different origins and fails if
the binaries differ, so position independence can't silently break.

## Credits

The plotting and line routines will be based on the Bitshifters'
teletextr routines (Kieran Connell and Simon Morris, adapted from
Bresenham routines by Rich Talbot-Watkins), used under the MIT licence:
https://github.com/bitshifters/teletextr — their copyright notice and
licence text must be included once that code is ported.
