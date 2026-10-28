# Acorn System 3 Teletext Graphics Library - build
#
#   make            build library for both targets, plus the demos
#   make sys3       standard Acorn System 3 (VDU at $0400)
#   make flex       FLEX machine (VDU at $E400)
#   make SAFE=1     range-checked TGL_PLOT/TGL_LINE (use make -B or clean first
#                   when switching between normal and safe builds)
#   make test       build, put the FLEX build and demos on TGL.dsk, run MAME
#   make clean

LWASM   ?= lwasm
LWFLAGS  = --format=raw -I src
SRC      = $(wildcard src/*.asm src/*.inc src/target/*.inc)

ifdef SAFE
LWFLAGS += -D TGL_SAFE
BUILDTYPE = , SAFE build
endif
MAME 	 = /home/john/Dropbox/Repositories/mame-acorn-flex/mame
DEMO     = ./build/demo.bin
CUBE	 = ./build/cube.bin
SHIP	 = ./build/ship.bin
BOXES	 = ./build/boxes.bin
CIRCLES	 = ./build/circles.bin
TGL 	 = ./build/flex/tgl.bin
DESTDISK = ./mame/disks/TGL.dsk
TOOLS	 = ./tools

# Position-independence check: assemble at two origins, binaries must match
PIC_A    = 0x1000
PIC_B    = 0x2345

.PHONY: all sys3 flex demo cube ship boxes circles test clean

all: sys3 flex demo cube ship boxes circles

sys3: build/sys3/tgl.bin
flex: build/flex/tgl.bin
demo: build/demo.bin
cube: build/cube.bin
ship: build/ship.bin
boxes: build/boxes.bin
circles: build/circles.bin

build/sys3/tgl.bin: $(SRC)
	@mkdir -p $(@D)
	$(LWASM) $(LWFLAGS) --output=$@ --list=$(@D)/tgl.lst --symbols src/tgl.asm
	@$(LWASM) $(LWFLAGS) -D TGL_ORG=$(PIC_A) --output=$(@D)/pic_a.bin src/tgl.asm
	@$(LWASM) $(LWFLAGS) -D TGL_ORG=$(PIC_B) --output=$(@D)/pic_b.bin src/tgl.asm
	@cmp -s $(@D)/pic_a.bin $(@D)/pic_b.bin || \
	  { echo "ERROR: sys3 build is not position-independent"; rm -f $@; exit 1; }
	@rm -f $(@D)/pic_a.bin $(@D)/pic_b.bin
	@echo "sys3: $$(stat -c %s $@) bytes, position-independent$(BUILDTYPE)"

build/flex/tgl.bin: $(SRC)
	@mkdir -p $(@D)
	$(LWASM) $(LWFLAGS) -D TARGET_FLEX --output=$@ --list=$(@D)/tgl.lst --symbols src/tgl.asm
	@$(LWASM) $(LWFLAGS) -D TARGET_FLEX -D TGL_ORG=$(PIC_A) --output=$(@D)/pic_a.bin src/tgl.asm
	@$(LWASM) $(LWFLAGS) -D TARGET_FLEX -D TGL_ORG=$(PIC_B) --output=$(@D)/pic_b.bin src/tgl.asm
	@cmp -s $(@D)/pic_a.bin $(@D)/pic_b.bin || \
	  { echo "ERROR: flex build is not position-independent"; rm -f $@; exit 1; }
	@rm -f $(@D)/pic_a.bin $(@D)/pic_b.bin
	@echo "flex: $$(stat -c %s $@) bytes, position-independent$(BUILDTYPE)"

build/demo.bin: demo/demo.asm src/tgl_api.inc
	@mkdir -p $(@D)
	$(LWASM) $(LWFLAGS) --output=$@ --list=build/demo.lst --symbols demo/demo.asm

build/cube.bin: demo/cube.asm demo/cube_tables.asm src/tgl_api.inc
	@mkdir -p $(@D)
	$(LWASM) $(LWFLAGS) -I demo --output=$@ --list=build/cube.lst --symbols demo/cube.asm

build/circles.bin: demo/circles.asm src/tgl_api.inc
	@mkdir -p $(@D)
	$(LWASM) $(LWFLAGS) -I demo --output=$@ --list=build/circles.lst --symbols demo/circles.asm

build/boxes.bin: demo/boxes.asm src/tgl_api.inc
	@mkdir -p $(@D)
	$(LWASM) $(LWFLAGS) -I demo --output=$@ --list=build/boxes.lst --symbols demo/boxes.asm

build/ship.bin: demo/ship.asm demo/ship_model.asm demo/cube_tables.asm src/tgl_api.inc
	@mkdir -p $(@D)
	$(LWASM) $(LWFLAGS) -I demo --output=$@ --list=build/ship.lst --symbols demo/ship.asm


test: flex demo cube ship boxes circles
	# create a FLEX .dsk image
	# delete any previous file
	-$(TOOLS)/aflex-du delete-file -d $(DESTDISK) -f $(DEMO)
	-$(TOOLS)/aflex-du delete-file -d $(DESTDISK) -f $(CUBE)
	-$(TOOLS)/aflex-du delete-file -d $(DESTDISK) -f $(SHIP)
	-$(TOOLS)/aflex-du delete-file -d $(DESTDISK) -f $(BOXES)
	-$(TOOLS)/aflex-du delete-file -d $(DESTDISK) -f $(CIRCLES)
	-$(TOOLS)/aflex-du delete-file -d $(DESTDISK) -f $(TGL)

	# add the newly built file, this will be in raw binary format
	$(TOOLS)/aflex-du add-binary-file -d $(DESTDISK) -f $(DEMO) -l 0x2000 -t 0x2000
	$(TOOLS)/aflex-du add-binary-file -d $(DESTDISK) -f $(CUBE) -l 0x2000 -t 0x2000
	$(TOOLS)/aflex-du add-binary-file -d $(DESTDISK) -f $(SHIP) -l 0x2000 -t 0x2000
	$(TOOLS)/aflex-du add-binary-file -d $(DESTDISK) -f $(BOXES) -l 0x2000 -t 0x2000
	$(TOOLS)/aflex-du add-binary-file -d $(DESTDISK) -f $(CIRCLES) -l 0x2000 -t 0x2000
	$(TOOLS)/aflex-du add-binary-file -d $(DESTDISK) -f $(TGL) -l 0x1000 -t 0x1000

	# validate the disk
	$(TOOLS)/aflex-du validate -d $(DESTDISK)

	# To build the mame command line, use the following URL
	# https://arcade.vastheman.com/minimaws/machine/acrnsys3_6809
	# Note that VIB for use with flex needs to be at EC00 not the default of 0C00
	$(MAME) acrnsys_flex -noreadconfig -rompath ./mame/roms -keymap -verbose -uimodekey CAPSLOCK -window -flop1 ./mame/disks/ACORN_ORIGINAL.FLEX.hfe -flop2 $(DESTDISK) -bus6 vib

clean:
	rm -rf build
