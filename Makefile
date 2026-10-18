# Acorn System 3 Teletext Graphics Library - build
#
#   make            build library for both targets, plus the demo
#   make sys3       standard Acorn System 3 (VDU at $0400)
#   make flex       FLEX machine (VDU at $E400)
#   make clean

LWASM   ?= lwasm
LWFLAGS  = --format=raw -I src
SRC      = $(wildcard src/*.asm src/*.inc src/target/*.inc)
MAME 	 = /home/john/Dropbox/Repositories/mame-acorn-flex/mame
DEMO     = ./build/demo.bin
TGL 	 = ./build/flex/tgl.bin
DESTDISK = ./mame/disks/TGL.dsk
TOOLS	 = ./tools

# Position-independence check: assemble at two origins, binaries must match
PIC_A    = 0x1000
PIC_B    = 0x2345

.PHONY: all sys3 flex demo clean

all: sys3 flex demo

sys3: build/sys3/tgl.bin
flex: build/flex/tgl.bin
demo: build/demo.bin

build/sys3/tgl.bin: $(SRC)
	@mkdir -p $(@D)
	$(LWASM) $(LWFLAGS) --output=$@ --list=$(@D)/tgl.lst --symbols src/tgl.asm
	@$(LWASM) $(LWFLAGS) -D TGL_ORG=$(PIC_A) --output=$(@D)/pic_a.bin src/tgl.asm
	@$(LWASM) $(LWFLAGS) -D TGL_ORG=$(PIC_B) --output=$(@D)/pic_b.bin src/tgl.asm
	@cmp -s $(@D)/pic_a.bin $(@D)/pic_b.bin || \
	  { echo "ERROR: sys3 build is not position-independent"; rm -f $@; exit 1; }
	@rm -f $(@D)/pic_a.bin $(@D)/pic_b.bin
	@echo "sys3: $$(stat -c %s $@) bytes, position-independent"

build/flex/tgl.bin: $(SRC)
	@mkdir -p $(@D)
	$(LWASM) $(LWFLAGS) -D TARGET_FLEX --output=$@ --list=$(@D)/tgl.lst --symbols src/tgl.asm
	@$(LWASM) $(LWFLAGS) -D TARGET_FLEX -D TGL_ORG=$(PIC_A) --output=$(@D)/pic_a.bin src/tgl.asm
	@$(LWASM) $(LWFLAGS) -D TARGET_FLEX -D TGL_ORG=$(PIC_B) --output=$(@D)/pic_b.bin src/tgl.asm
	@cmp -s $(@D)/pic_a.bin $(@D)/pic_b.bin || \
	  { echo "ERROR: flex build is not position-independent"; rm -f $@; exit 1; }
	@rm -f $(@D)/pic_a.bin $(@D)/pic_b.bin
	@echo "flex: $$(stat -c %s $@) bytes, position-independent"

build/demo.bin: demo/demo.asm src/tgl_api.inc
	@mkdir -p $(@D)
	$(LWASM) $(LWFLAGS) --output=$@ --list=build/demo.lst --symbols demo/demo.asm

	# create a FLEX .dsk image
	# delete any previous file
	-$(TOOLS)/aflex-du delete-file -d $(DESTDISK) -f $(DEMO)
	-$(TOOLS)/aflex-du delete-file -d $(DESTDISK) -f $(TGL)

	# add the newly built file, this will be in raw bianry format
	$(TOOLS)/aflex-du add-binary-file -d $(DESTDISK) -f $(DEMO) -l 0x2000 -t 0x2000
	$(TOOLS)/aflex-du add-binary-file -d $(DESTDISK) -f $(TGL) -l 0x1000 -t 0x1000

	# validate the disk
	$(TOOLS)/aflex-du validate -d $(DESTDISK)

test:
	# To build the mame command line, use the following URL
	# https://arcade.vastheman.com/minimaws/machine/acrnsys3_6809
	# Note hat VIB for use with flex needs to be at EC00 not the default of 0C00
	$(MAME) acrnsys3_flex40 -noreadconfig -rompath ./mame/roms -keymap -verbose -uimodekey CAPSLOCK -window -flop1 ./mame/disks/ACORN_ORIGINAL.FLEX.hfe -flop2 $(DESTDISK) -bus6 vib

clean:
	rm -rf build
