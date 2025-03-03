/*
Copyright 2005, 2006, 2007 Dennis van Weeren
Copyright 2008, 2009 Jakub Bednarski

This file is part of Minimig

Minimig is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

Minimig is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

// 2008-10-04   - porting to ARM
// 2008-10-06   - support for 4 floppy drives
// 2008-10-30   - hdd write support
// 2009-05-01   - subdirectory support
// 2009-06-26   - SDHC and FAT32 support
// 2009-08-10   - hardfile selection
// 2009-09-11   - minor changes to hardware initialization routine
// 2009-10-10   - any length fpga core file support
// 2009-11-14   - adapted floppy gap size
//              - changes to OSD labels
// 2009-12-24   - updated version number
// 2010-01-09   - changes to floppy handling
// 2010-07-28   - improved menu button handling
//              - improved FPGA configuration routines
//              - added support for OSD vsync
// 2010-08-15   - support for joystick emulation
// 2010-08-18   - clean-up

// FIXME - detect number of partitions on the SD card, and allow that many to be selected as hard files.

//#include "AT91SAM7S256.h"
//#include "stdio.h"
//#include "string.h"
#include "errors.h"
#include "boot.h"
#include "hardware.h"
#include "mmc.h"
#include "fat.h"
#include "osd.h"
#include "fpga.h"
#include "fdd.h"
#include "hdd.h"
#include "firmware.h"
#include "menu.h"
#include "config.h"
#include "bincue.h"
#include "c64keys.h"
#include "akiko.h"
#include "interrupts.h"
#include "drivesounds.h"
#include "audio.h"
#include "rtc.h"
#include "version.h"

#include <stdio.h>

const char version[] = MM_VERSTRING;

extern adfTYPE df[4];

char s[40];

extern int _bss_start__;
int CheckSum(char *adr,int size)
{
	int *end=(int *)(adr+size);
	int *ptr=(int *)adr;
	int sum=0;
	while(ptr<end)
	{
		sum+=*ptr++;
	}
	return(sum);
}


void HandleFpga(void)
{
    unsigned char  c1, c2,c3,c4;

    EnableFpga();
    c1 = SPI(0); // cmd request and drive number
    c2 = SPI(0); // track number
    SPI(0);
    SPI(0);
    c3 = SPI(0);
    c4 = SPI(0);
    DisableFpga();

    HandleFDD(c1, c2, c3 ,c4);
    HandleHDD(c1, c2);

    UpdateDriveStatus();
}


void inthandler()
{
	int ints=GetInterrupts();
	DisableInterrupts();
	akiko_inthandler();
	c64keys_inthandler();
	EnableInterrupts();
}


int Init() {
	int result=0;
	/* Reset the chipset briefly to cancel AGA display modes, then Put the CPU in reset while we initialise */
	OsdDoReset(SPI_RST_USR | SPI_RST_CPU | SPI_CPU_HLT,SPI_RST_CPU | SPI_CPU_HLT);

	DisableInterrupts();

    if (MMC_Init())
	{
	    if (FindDrive())
		{
			int key;
			int override=0;
		    ChangeDirectory(DIRECTORY_ROOT);

			config.kickstart.name[0]=0;
			SetConfigurationFilename(0); // Use default config
		    LoadConfiguration(0);	// Use slot-based config filename
			ApplyConfiguration(0,0);  // Setup screenmodes, etc before loading KickStart.
			result=1;
		}
	}
	return(result);
}

void ColdBoot() {
	int result=0;
	int key;
	int override;

	fpga_init();	// Display splashscreen

	key = OsdGetCtrl();
	sprintf(s,"Got key: %x\n",key);
	BootPrint(s);
	if ((key == KEY_F1) || (key == KEY_F3) || (key == KEY_F5))
	{
		override=1;
		config.chipset |= CONFIG_NTSC; // force NTSC mode if F1 or F3 pressed
	}

	if ((key == KEY_F2) || (key == KEY_F4) || (key == KEY_F6))
	{
		override=1;
		config.chipset &= ~CONFIG_NTSC; // force PAL mode if F2 or F4 pressed
	}

	// FIXME - new interface for scandoubler?
	if ((key == KEY_F3) || (key == KEY_F4))
	{
		override=1;
		config.misc &= ~(1<<(PLATFORM_SCANDOUBLER));	// High byte of platform register
	}

	if ((key == KEY_F1) || (key == KEY_F2))
	{
		override=1;
		config.misc |= 1<<(PLATFORM_SCANDOUBLER);  // High byte of platform register
	}

	if ((key == KEY_F5) || (key == KEY_F6))
	{
		override=1;
		config.misc |= 1<<(PLATFORM_INVERTSYNC);  // High byte of platform register
	}

	if(override)
	{
		BootPrintEx("Overriding screenmode.");
		ApplyConfiguration(0,0);
	}

	drivesounds_init("DRIVESNDBIN");
	ClearError(ERROR_FILESYSTEM); /* Don't report a missing drivesnd.bin */			

	BootPrintEx("Loading kickstart ROM...");
	result=ApplyConfiguration(1,1);

	OsdDoReset(SPI_RST_USR | SPI_RST_CPU,0);

	SetIntHandler(inthandler);
	EnableInterrupts();

	audio_clear();
	if(drivesounds_loaded())
		drivesounds_enable(config.drivesounds);
}

struct cdimage cd;

void setstack();

int main(void) {
	int c=0;
	int rtc=PLATFORM & (1<<PLATFORM_SPIRTC);
	int clockport=PLATFORM & (1<<PLATFORM_CLOCKPORT);
	int cartridge=PLATFORM & (1<<PLATFORM_C64CARTRIDGE);
	setstack();
	debugmsg[0]=0;
	debugmsg2[0]=0;

	ClearError(ERROR_ALL);

	if(!Init())
		FatalError(ERROR_SDCARD,"SD initialisation failed",0,0);
	
	if(clockport && cartridge)
		FatalError(ERROR_GENERAL,"C64: use non-clockport core",0,0);

	if(ErrorFatal) {
		ShowError();		
		HandleUI();
		while(1)
			;	
	}

    DISKLED_ON;

	ColdBoot()

//	cd_setcuefile(&cd,"EXODUS_THELASTWAR.CUE");
//	cd_playaudio(&cd,4);

    while(1)
    {
		drivesounds_fill();
		if(c64keyboard_checkreset())
			OsdDoReset(SPI_RST_USR | SPI_RST_CPU,0);

		if(rtc)
			HandleRTC();

//		cd_continueaudio(&cd);
		if(ErrorMask)
			ShowError();

		if(!ErrorFatal)
			HandleFpga(); /* Stop talking to the disk subsystems if a fatal error occurs */

        HandleUI();
    }
}

