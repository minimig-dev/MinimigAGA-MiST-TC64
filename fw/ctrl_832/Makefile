# MINIMIG-DE1
# ctrl boot firmware
# 2012, rok.krajnc@gmail.com
# Ported to EightThirtyTwo by AMR

### tools ###

BASE	= 
832DIR = ../../EightThirtyTwo
CC      = $(832DIR)/vbcc/bin/vbcc832
GCC		= gcc
LD      = $(832DIR)/832a/832l
AS      = $(832DIR)/832a/832a
CP      = objcopy
DUMP    = objdump

LIBDIR = $(832DIR)/lib832
BUILD_DIR = 832obj
INCLUDE_DIR = $(832DIR)/include

PROJECT=832OSDAD

### flags ###

CFLAGS  = -+ -c99 -O=1343 -unsigned-char -D__geta4= -DNULL=0 -I. -I$(INCLUDE_DIR)/ -I$(LIBDIR)/
ASFLAGS = -eb
LDFLAGS  = -eb -s_STACKSIZE=0x0 -s_STACKTOP=0x2000 -b 0x2000

### variables ###

# headers
HEADERS=spr_defs.h or32_defs.h hardware.h string.h swap.h errors.h mmc.h fat.h

### variables ###
BUILD_USER=\"$(USER)\"
BUILD_T=$$(date +%Y-%m-%d)
BUILD_TIME=\"$(BUILD_T)\"
BUILD_N=$$(cat build_num.txt)
BUILD_NUM=\"$(BUILD_N)\"
BUILD_R=$$(git rev-parse --verify HEAD)
BUILD_REV=\"$(BUILD_R)\"
BUILD_TG=$$(git describe --tags --abbrev=0)
BUILD_TAG=\"$(BUILD_TG)\"

BINDIR=bin
OBJDIR=obj

CFLAGS += -D__BUILD_USER=$(BUILD_USER) -D__BUILD_TAG=$(BUILD_TAG)


ALL_SOURCES=$(BUILD_DIR)/hardware.o $(BUILD_DIR)/config.o $(BUILD_DIR)/fat.o $(BUILD_DIR)/fdd.o $(BUILD_DIR)/fpga.o \
	$(BUILD_DIR)/boot.o $(BUILD_DIR)/hdd.o $(BUILD_DIR)/main.o $(BUILD_DIR)/menu.o $(BUILD_DIR)/mmc.o $(BUILD_DIR)/spi.o \
	$(BUILD_DIR)/osd.o $(BUILD_DIR)/rafile.o $(BUILD_DIR)/swap.o $(BUILD_DIR)/hexdump.o $(BUILD_DIR)/uart.o $(BUILD_DIR)/errors.o \
	$(BUILD_DIR)/audiotrack.o $(BUILD_DIR)/bincue.o $(BUILD_DIR)/interrupts.o $(BUILD_DIR)/c64keys.o $(BUILD_DIR)/akiko.o \
	$(BUILD_DIR)/audio.o $(BUILD_DIR)/drivesounds.o $(BUILD_DIR)/rtc.o


### build rules ###

# all
all: bootcustominit.h version.h $(PROJECT).bin

force:

version.h: force
	echo >version.h \#define MM_FIRMWARE_VERSION \"`date +%Y-%-m-%-d`\"
	echo >>version.h \#define MM_VERSTRING \"\$$VER:AMR`date +%y%-m%-d`-832\"
	echo >>version.h \#define MM_YEAR `date +%Y`
	echo >>version.h \#define MM_MONTH `date +%m`
	echo >>version.h \#define MM_DAY `date +%d`
	echo >>version.h \#define MM_WEEKDAY `date +%w`
	touch fpga.c main.c

bootcustominit.h: bootcustominit.s
	vasmm68k_mot -Fbin bootcustominit.s -o bootcustominit.bin
	xxd -i bootcustominit.bin > bootcustominit.h

$(PROJECT).bin: Makefile $(BUILD_DIR) $(ALL_SOURCES)
	$(LD) $(LDFLAGS) -M $(PROJECT).map -o $@ $(LIBDIR)/crt0.a $(LIBDIR)/lib832.a $(ALL_SOURCES)
	@echo 
	@echo "Firmware build complete - copy $@ to SD card."

clean:
	@echo clean
	@-rm $(BUILD_DIR)/*.o
	@-rm *.asm	
	@-rm $(PROJECT).bin
	@-rm $(PROJECT).map

%.asm: %.c
	$(CC) $(CFLAGS) -o=$@ $<

$(BUILD_DIR)/%.o: %.asm
	$(AS) $(ASFLAGS) -o $@ $<

$(BUILD_DIR)/%.o: %.c
	$(CC) $(CFLAGS) $<
	$(AS) $(ASFLAGS) -o $(BUILD_DIR)/$*.o $*.asm

$(BUILD_DIR):
	mkdir $(BUILD_DIR)

