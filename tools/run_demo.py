"""Run the library + demo in a 6809 emulator and render screen memory.

Usage: python3 tools/run_demo.py <tgl.bin> <demo.bin> <vdu_base_hex> <done_addr_hex>
Needs: pip install MC6809
"""
import sys
from MC6809.components.cpu6809 import CPU
from MC6809.components.memory import Memory
from MC6809.core.configs import BaseConfig
from MC6809.components import mc6809_base


# The MC6809 package's SEX instruction never sets A to $FF for a negative B
# (as of version 0.9.0), which breaks the polygon fill. Replace it with a
# correct version.
def _fixed_sex(self, opcode):
    self.accu_a.set(0xFF if self.accu_b.value & 0x80 else 0x00)
    self.clear_NZ()
    self.update_NZ_16(self.accu_d.value)


for _cls in vars(mc6809_base).values():
    if isinstance(_cls, type) and hasattr(_cls, "instruction_SEX"):
        _orig = _cls.instruction_SEX
        _fixed_sex._is_opcode = True        # what the package's @opcode
        _fixed_sex._opcodes = _orig._opcodes  # decorator attaches
        _cls.instruction_SEX = _fixed_sex


class Cfg(BaseConfig):
    RAM_START, RAM_END, ROM_START, ROM_END = 0x0000, 0x7FFF, 0x8000, 0xFFFF

tgl, demo, vdu, done = sys.argv[1], sys.argv[2], int(sys.argv[3], 16), int(sys.argv[4], 16)
mem = Memory(Cfg({"verbosity": None, "trace": None}))
cpu = CPU(mem, Cfg({"verbosity": None, "trace": None}))
mem.load(0x1000, bytearray(open(tgl, "rb").read()))
mem.load(0x2800, bytearray(open(demo, "rb").read()))
# There is no VIA here: hold Timer 2's "timed out" flag set so TGL_PACE
# never waits (it would otherwise wait for ever)
mem.load(0x0980 + 0xD, bytearray([0x20]))
cpu.test_run(0x2800, done)

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
