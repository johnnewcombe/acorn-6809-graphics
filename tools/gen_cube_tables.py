"""Regenerate demo/cube_tables.asm (sine and projection tables for the cube demo)."""
import math
SIN = [round(127 * math.sin(2 * math.pi * i / 256)) for i in range(256)]
RX = [min(255, round(57 * 128 / (100 + i - 64))) for i in range(128)]
RY = [min(255, round(70 * 128 / (100 + i - 64))) for i in range(128)]

def tab(name, vals):
    out = []
    for i in range(0, len(vals), 16):
        s = ",".join(f"${(v & 255):02X}" for v in vals[i:i + 16])
        out.append(f"{name if i == 0 else '':16}FCB     {s}")
    return "\n".join(out)

t = "; Generated tables (see tools/gen_cube_tables.py)\n\n; SINTAB: 127*sin(2*pi*i/256), signed\n" + tab("SINTAB", SIN)
t += ("\n\n; RXTAB/RYTAB: projection scale for depth z, indexed by z+64\n"
      ";   RX = 57*128/(100+z)  (x scale includes ~0.8 aspect correction)\n"
      ";   RY = 70*128/(100+z)\n" + tab("RXTAB", RX) + "\n" + tab("RYTAB", RY) + "\n")
open("demo/cube_tables.asm", "w").write(t)
