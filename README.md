# Acorn System 3 Teletext Graphics Library (working name)

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

## Routines

| Entry       | Offset | Function |
|-------------|--------|----------|
| TGL_INIT    | +0     | Reset 6845 start address, hide cursor, buffer after library, SET mode |
| TGL_SETBUF  | +3     | X = off-screen buffer address |
| TGL_CLS     | +6     | Clear buffer to blank graphics |
| TGL_SETMODE | +9     | A = mode: 0 set, 1 clear, 2 XOR |
| TGL_PLOT    | +12    | A = x (0-77), B = y (0-71) |
| TGL_LINE    | +15    | A,B = x0,y0; X = x1:y1 (high:low) |
| TGL_BLIT    | +18    | Copy buffer to screen rows 0-23 |

Coordinates are not range-checked.

## Testing

`tools/run_demo.py` runs the System 3 build and the demo in a Python 6809
emulator (`pip install MC6809`) and prints screen memory as a pixel grid:

    python3 tools/run_demo.py build/sys3/tgl.bin build/demo.bin 0400 <DONE address from build/demo.lst>

## Credits

The approach follows the Bitshifters' teletextr routines (Kieran Connell and
Simon Morris, adapted from Bresenham routines by Rich Talbot-Watkins):
https://github.com/bitshifters/teletextr (MIT licence). The 6809 code here
is written for this library rather than translated; if any of their code is
ported directly in future, their copyright notice and licence text must be
included with it.
