"""Run the library + demo in a 6809 emulator and render screen memory.

Usage: python3 tools/run_demo.py <tgl.bin> <demo.bin> <vdu_base_hex> <done_addr_hex>
Needs: pip install MC6809
"""
import sys
from MC6809.components.cpu6809 import CPU
from MC6809.components.memory import Memory
from MC6809.core.configs import BaseConfig

class Cfg(BaseConfig):
    RAM_START, RAM_END, ROM_START, ROM_END = 0x0000, 0x7FFF, 0x8000, 0xFFFF

tgl, demo, vdu, done = sys.argv[1], sys.argv[2], int(sys.argv[3], 16), int(sys.argv[4], 16)
mem = Memory(Cfg({"verbosity": None, "trace": None}))
cpu = CPU(mem, Cfg({"verbosity": None, "trace": None}))
mem.load(0x1000, bytearray(open(tgl, "rb").read()))
mem.load(0x2000, bytearray(open(demo, "rb").read()))
cpu.test_run(0x2000, done)

scr = [mem.read_byte(vdu + i) for i in range(960)]
bits = [(0, 0x01), (1, 0x02), (0, 0x04), (1, 0x08), (0, 0x10), (1, 0x40)]
bad = [r for r in range(24) if scr[r * 40] != 0x97]
print("rows without graphics code in col 0:", bad or "none")
for py in range(72):
    row, sub = divmod(py, 3)
    line = ""
    for px in range(78):
        c = scr[row * 40 + 1 + px // 2]
        mask = [0x01, 0x04, 0x10][sub] if px % 2 == 0 else [0x02, 0x08, 0x40][sub]
        line += "#" if c & mask else "."
    print(line)
