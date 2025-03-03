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

// 2009-11-14   - OSD labels changed
// 2009-12-15   - added display of directory name extensions
// 2010-01-09   - support for variable number of tracks

//#include "AT91SAM7S256.h"
//#include "stdbool.h"
#include "stdio.h"
#include "string.h"
#include "errors.h"
#include "mmc.h"
#include "fat.h"
#include "osd.h"
#include "fpga.h"
#include "fdd.h"
#include "hdd.h"
#include "hardware.h"
#include "firmware.h"
#include "config.h"
#include "menu.h"
#include "hexdump.h"
#include "drivesounds.h"

#define OSDCOLOR_TOPLEVEL 0x01
#define OSDCOLOR_SUBMENU 0x03
#define OSDCOLOR_WARNING 0x10

// other constants
#define DIRSIZE 8 // number of items in directory display window

signed char errorpage;
unsigned char menustate = MENU_NONE1;
unsigned char parentstate;
unsigned char parentsub;
unsigned char menusub = 0;
unsigned int menumask = 0; // Used to determine which rows are selectable...
unsigned long menu_timer;

extern unsigned char drives;
extern adfTYPE df[4];

extern configTYPE config;
extern fileTYPE file;
extern char s[40];

extern unsigned char fat32;

extern DIRENTRY DirEntry[MAXDIRENTRIES];
extern unsigned char sort_table[MAXDIRENTRIES];
extern unsigned char nDirEntries;
extern unsigned char iSelectedEntry;
extern unsigned long iCurrentDirectory;
extern char DirEntryLFN[MAXDIRENTRIES][261];
char DirEntryInfo[MAXDIRENTRIES][5]; // disk number info of dir entries
char DiskInfo[5]; // disk number info of selected entry

extern const char version[];

const char *config_filter_msg[] =  {"none", "HORIZONTAL", "VERTICAL", "H+V"};
const char *config_memory_chip_msg[] = {"0.5 MB", "1.0 MB", "1.5 MB", "2.0 MB"};
const char *config_memory_slow_msg[] = {"none  ", "0.5 MB", "1.0 MB", "1.5 MB"};
const char *config_on_off_msg[] = {"off", "on "};
const char *config_scanlines_msg[] = {"off", "dim", "black"};
const char *config_memory_fast_msg[] = {"none  ", "2.0 MB", "4.0 MB", "Maximum"};
const char *config_cpu_msg[] = {"68000 ", "68010", "-","68020"};
const char *config_hdf_msg[] = {"Disabled", "Hardfile (disk img)", "MMC/SD card", "MMC/SD partition 1", "MMC/SD partition 2", "MMC/SD partition 3", "MMC/SD partition 4"};
const char *config_chipset_msg[] = {"OCS-A500", "OCS-A1000", "ECS", "---", "---", "---", "AGA", "---"};
const char *config_turbo_msg[] = {"\004\005\005\005\005\006", "\007\007\005\005\005\006", "\007\007\007\007\005\006", "\007\007\007\007\007\007"};
const char *config_cd32pad_msg[] =  {"OFF", "ON"};

char *config_autofire_msg[] = {"        AUTOFIRE OFF", "        AUTOFIRE FAST", "        AUTOFIRE MEDIUM", "        AUTOFIRE SLOW"};

enum HelpText_Message {HELPTEXT_NONE,HELPTEXT_MAIN,HELPTEXT_HARDFILE,HELPTEXT_CHIPSET,HELPTEXT_MEMORY,HELPTEXT_VIDEO};
const char *helptexts[]={
	0,
	"                                Welcome to Minimig!  Use the cursor keys to navigate the menus.  Use space bar or enter to select an item.  Press Esc or F12 to exit the menus.  Joystick emulation on the numeric keypad can be toggled with the numlock key, while pressing Ctrl-Alt-0 (numeric keypad) toggles autofire mode.",
	"                                Minimig can emulate an A600 IDE harddisk interface.  The emulation can make use of Minimig-style hardfiles (complete disk images) or UAE-style hardfiles (filesystem images with no partition table).  It is also possible to use either the entire SD card or an individual partition as an emulated harddisk.",
	"                                Minimig's processor core can emulate a 68000 or 68020 processor.  Access to both Chip RAM and Kickstart ROM can be sped up with the Turbo function.  The emulated chipset can be either A500 or A1000 OCS, ECS or AGA.",
#ifdef ACTIONREPLAY_BROKEN
	"                                Minimig can make use of up to 2 megabytes of Chip RAM, up to 1.5 megabytes of Slow RAM (A500 Trapdoor RAM), and up to 28 megabytes of true Fast RAM.",
#else
	"                                Minimig can make use of up to 2 megabytes of Chip RAM, up to 1.5 megabytes of Slow RAM (A500 Trapdoor RAM), and up to 28 megabytes of true Fast RAM.  To use the HRTMon feature you will need an appropriate ROM file on the SD card.  To activate the monitor hold Ctrl and press the Pause key.",
#endif
	"                                Minimig's video features include a blur filter, to simulate the poorer picture quality on older monitors, and also scanline generation to simulate the appearance of a screen with low vertical resolution.",
	0
};

void SanityCheck();

void ColdBoot();
void (*confirmfunc)();

extern unsigned char DEBUG;

unsigned char config_autofire = 0;

// file selection menu variables
char *fs_pFileExt = NULL;
unsigned char fs_Options;
unsigned char fs_MenuSelect;
unsigned char fs_MenuCancel;

static char debuglines[8*32+1];
static char debugptr=0;

void _showdebugmessages()
{
	int i;
	for(i=0;i<8;++i)
	{
		int j=(debugptr+i)&7;
		debuglines[j*32+31]=0;
		OsdWrite(i,&debuglines[j*32],i==7,0);
	}
}

void SelectFile(char* pFileExt, unsigned char Options, unsigned char MenuSelect, unsigned char MenuCancel)
{
    // this function displays file selection menu

    if (strncmp(pFileExt, fs_pFileExt, 3) != 0) // check desired file extension
    { // if different from the current one go to the root directory and init entry buffer
        ChangeDirectory(DIRECTORY_ROOT);
        ScanDirectory(SCAN_INIT, pFileExt, Options);
    }

    fs_pFileExt = pFileExt;
    fs_Options = Options;
    fs_MenuSelect = MenuSelect;
    fs_MenuCancel = MenuCancel;

    menustate = MENU_FILE_SELECT1;
}

#define STD_EXIT "            exit"
#define STD_BACK "            back"
#define HELPTEXT_DELAY 2500
#define FRAME_DELAY 50


void ShowSplash()
{
	OsdSetTitle("Welcome",0);
    OsdWrite(0, "", 0,0);
	OsdDrawLogo(1,0,0);
	OsdDrawLogo(2,1,0);
	OsdDrawLogo(3,2,0);
	OsdDrawLogo(4,3,0);
	OsdDrawLogo(5,4,0);
    OsdWrite(6, "", 0,0);
    OsdWrite(7, "", 0,0);
	OsdShow(0);
	OsdColor(OSDCOLOR_TOPLEVEL);
}


void HideSplash()
{
	OsdHide();
}


void HandleUI(void)
{
    unsigned char i, c, up, down, select, menu, right, left, plus, minus;
    unsigned long len;
	static char hardfile_firstunit;
    static hardfileTYPE t_hardfile[4]; // temporary copy of former hardfile configuration
	static int t_hdfdir[4];
    static char t_enable_ide; // temporary copy of former enable_ide flag.
    static unsigned char ctrl = false;
    static unsigned char lalt = false;
	char enable;
	static long helptext_timer;
	static const char *helptext;
	static char helpstate=0;

    // get user control codes
    c = OsdGetCtrl();

    // decode and set events
    menu = false;
    select = false;
    up = false;
    down = false;
    left = false;
    right = false;
	plus=false;
	minus=false;

    switch (c)
    {
    case KEY_CTRL :
        ctrl = true;
        break;
    case KEY_CTRL | KEY_UPSTROKE :
        ctrl = false;
        break;
    case KEY_LALT :
        lalt = true;
        break;
    case KEY_LALT | KEY_UPSTROKE :
        lalt = false;
        break;
    case KEY_KPPLUS :
        if (ctrl && lalt)
        {
            config.chipset |= CONFIG_TURBO;
            ConfigChipset(config.chipset);
            if (menustate == MENU_SETTINGS_CHIPSET2)
                menustate = MENU_SETTINGS_CHIPSET1;
            else if (menustate == MENU_NONE2 || menustate == MENU_INFO)
                InfoMessage("             TURBO");
        }
		else
			plus=true;
        break;
    case KEY_KPMINUS :
        if (ctrl && lalt)
        {
            config.chipset &= ~CONFIG_TURBO;
            ConfigChipset(config.chipset);
            if (menustate == MENU_SETTINGS_CHIPSET2)
                menustate = MENU_SETTINGS_CHIPSET1;
            else if (menustate == MENU_NONE2 || menustate == MENU_INFO)
                InfoMessage("             NORMAL");
        }
		else
			minus=true;
        break;
    case KEY_KP0 :
        if (ctrl && lalt)
        {
            if (menustate == MENU_NONE2 || menustate == MENU_INFO)
            {
                config_autofire++;
                config_autofire &= 3;
                ConfigAutofire(config_autofire);
                if (menustate == MENU_NONE2 || menustate == MENU_INFO)
                    InfoMessage(config_autofire_msg[config_autofire]);
            }
        }
        break;
    case KEY_MENU :
        if (ctrl && lalt)
		{
			OsdSetTitle("Debug",0);
			DebugMode=DebugMode^1;
			if(DebugMode)
				SanityCheck();
	        menustate = MENU_NONE1;
		}
		else
	        menu = true;
        break;
    case KEY_ESC :
        if (menustate != MENU_NONE2)
            menu = true;
        break;
    case KEY_ENTER :
    case KEY_SPACE :
        select = true;
        break;
    case KEY_UP :
        up = true;
        break;
    case KEY_DOWN :
        down = true;
        break;
    case KEY_LEFT :
        left = true;
        break;
    case KEY_RIGHT :
        right = true;
        break;
    }

	if(menu || select || up || down || left || right )
	{
		if(helpstate)
			OsdWrite(7,STD_EXIT,(menumask-((1<<(menusub+1))-1))<=0,0); // Redraw the Exit line...
		helpstate=0;
		helptext_timer=GetTimer(HELPTEXT_DELAY);
	}

	if(helptext)
	{
		if(helpstate<9)
		{
			if(CheckTimer(helptext_timer))
			{
				helptext_timer=GetTimer(FRAME_DELAY);
				OsdWriteOffset(7,STD_EXIT,0,0,helpstate);
				++helpstate;
			}
		}
		else if(helpstate==9)
		{
			ScrollReset();
			++helpstate;
		}
		else
			ScrollText(7,helptext,0,0,0);
	}

	// Standardised menu up/down.
	// The screen should set menumask, bit 0 to make the top line selectable, bit 1 for the 2nd line, etc.
	// (Lines in this context don't have to correspond to rows on the OSD.)
	// Also set parentstate to the appropriate menustate.
	if(menumask)
	{
        if (down && (menumask>=(1<<(menusub+1))))	// Any active entries left?
		{
			do
				menusub++;
			while((menumask & (1<<menusub)) == 0);
            menustate = parentstate;
        }

		// ...mmmm.
		// ......X.

        if (up && (menusub > 0) && (menumask&(0xff>>(8-menusub))))
        {
			do
				--menusub;
			while((menumask & (1<<menusub)) == 0);
            menustate = parentstate;
        }
	}


    switch (menustate)
    {
        /******************************************************************/
        /* no menu selected                                               */
        /******************************************************************/
    case MENU_NONE1 :
		helptext=helptexts[HELPTEXT_NONE];
		menumask=0;
		if(DebugMode)
		{
			helptext=helptexts[HELPTEXT_NONE];
			OsdShow(0);
		}
		else
	        OsdHide();
        menustate = MENU_NONE2;
        break;

    case MENU_NONE2 :
		if(DebugMode)
			_showdebugmessages();
        if (menu)
        {
            menustate = MENU_MAIN1;
            menusub = 0;
            OsdClear();
            OsdShow(DISABLE_KEYBOARD);
        }
        break;

        /******************************************************************/
        /* main menu                                                      */
        /******************************************************************/
    case MENU_MAIN1 :
        OsdColor(OSDCOLOR_TOPLEVEL);
		menumask=0xf0;	// b01110000 Floppy turbo, Harddisk options & Exit.
		OsdSetTitle("Minimig",OSD_ARROW_RIGHT);
		helptext=helptexts[HELPTEXT_MAIN];

        // floppy drive info
		// We display a line for each drive that's active
		// in the config file, but grey out any that the FPGA doesn't think are active.
		// We also print a help text in place of the last drive if it's inactive.
        for (i = 0; i < 4; i++)
        {
			if(i==config.floppy.drives+1)
				OsdWrite(i," KP +/- to add/remove drives",0,1);
			else
			{
		        strcpy(s, " dfx: ");
		        s[3] = i + '0';
				if(i<=drives)
				{
					menumask|=(1<<i);	// Make enabled drives selectable

				    if (df[i].status & DSK_INSERTED) // floppy disk is inserted
				    {
				        strncpy(&s[6], df[i].name, sizeof(df[0].name));
						if(!(df[i].status & DSK_WRITABLE))
					        strcpy(&s[6 + sizeof(df[i].name)-1], " \x17"); // padlock icon for write-protected disks
						else
					        strcpy(&s[6 + sizeof(df[i].name)-1], "  "); // clear padlock icon for write-enabled disks
				    }
				    else // no floppy disk
					{
				        strcat(s, "* no disk *");
					}
				}
				else if(i<=config.floppy.drives)
				{
					strcat(s,"* active after reset *");
				}
				else
					strcpy(s,"");
		        OsdWrite(i, s, menusub == i,(i>drives)||(i>config.floppy.drives));
			}
        }
        OsdWrite(4, " Floppy disk settings \x16", menusub == 4,0);
        OsdWrite(5, " Primary hard disk \x16", menusub == 5,0);
        OsdWrite(6, " Secondary hard disk \x16", menusub == 6,0);
        OsdWrite(7, STD_EXIT, menusub == 7,0);

        menustate = MENU_MAIN2;
		parentstate=MENU_MAIN1;
        break;

    case MENU_MAIN2 :
        if (menu)
            menustate = MENU_NONE1;
		else if(plus && (config.floppy.drives<3))
		{
			config.floppy.drives++;
			ConfigFloppy(config.floppy.drives,config.floppy.speed);
	        menustate = MENU_MAIN1;
		}
		else if(minus && (config.floppy.drives>0))
		{
			config.floppy.drives--;
			ConfigFloppy(config.floppy.drives,config.floppy.speed);
	        menustate = MENU_MAIN1;
		}
        else if (select)
        {
            if (menusub < 4)
            {
                if (df[menusub].status & DSK_INSERTED) // eject selected floppy
                {
                    df[menusub].status = 0;
                    menustate = MENU_MAIN1;
					drivesounds_queueevent(DRIVESOUND_EJECT);
                }
                else
                {
                    df[menusub].status = 0;
                    SelectFile("ADF", SCAN_DIR | SCAN_LFN, MENU_FILE_SELECTED, MENU_MAIN1);
                }
            }
            else if (menusub == 4)	// Floppy disk options.
			{
                menustate = MENU_FLOPPY1;
				parentsub=4;
				menusub=0;
			}
            else if (menusub == 5 || menusub == 6)	// Go to harddrives page.
			{
				hardfile_firstunit=2*(menusub-5);
                t_hardfile[0] = config.hardfile[0];
                t_hardfile[1] = config.hardfile[1];
                t_hardfile[2] = config.secondaryhardfile[0];
                t_hardfile[3] = config.secondaryhardfile[1];
				t_enable_ide=config.enable_ide;
				t_hdfdir[0]=config.hdfdir[0];
				t_hdfdir[1]=config.hdfdir[1];
				t_hdfdir[2]=config.hdfdir[2];
				t_hdfdir[3]=config.hdfdir[3];
                menustate = MENU_SETTINGS_HARDFILE1;
				menusub=0;
			}
            else if (menusub == 7)
                menustate = MENU_NONE1;
        }
        else if (c == KEY_BACK) // eject all floppies
        {
            for (i = 0; i <= drives; i++)
                df[i].status = 0;

            menustate = MENU_MAIN1;
        }
        else if (right)
        {
            menustate = MENU_MAIN2_1;
            menusub = 0;
        }
        break;

	case MENU_FLOPPY1 : // Floppy drive options
        OsdColor(OSDCOLOR_TOPLEVEL);
		helptext=helptexts[HELPTEXT_MAIN];
		menumask=0x0f;
 		OsdSetTitle("Floppy",0);
        OsdWrite(0, "", 0,0);
		sprintf(s," Floppy drives : %d",config.floppy.drives+1);
        OsdWrite(1, s, menusub==0,0);
		sprintf(s," Floppy disk turbo : %s",config.floppy.speed ? "on" : "off");
        OsdWrite(2, s, menusub==1,0);
		sprintf(s," Floppy disk sounds : %s",config.drivesounds&DRIVESOUNDS_FLOPPY ? "on" : "off");
        OsdWrite(3, s, menusub==2,!drivesounds_loaded());
		if(!drivesounds_loaded())
			menumask&=0xb;
        OsdWrite(4, "", 0,0);
        OsdWrite(5, "", 0,0);
        OsdWrite(6, "", 0,0);
        OsdWrite(7, STD_EXIT, menusub == 3,0);

		parentstate = menustate;
        menustate = MENU_FLOPPY2;
        break;

	case MENU_FLOPPY2 :
        if (menu)
            menustate = MENU_NONE1;
        else if (select)
        {
			switch(menusub)
			{
				case 0:	/* Number of drives */
					config.floppy.drives=(config.floppy.drives+1)&3;
					ConfigFloppy(config.floppy.drives,config.floppy.speed);
					menustate = MENU_FLOPPY1;
					break;
				case 1:
		            config.floppy.speed^=1;
					ConfigFloppy(config.floppy.drives,config.floppy.speed);
		            menustate = MENU_FLOPPY1;
					break;
				case 2:
		            config.drivesounds^=DRIVESOUNDS_FLOPPY;
					if(config.drivesounds&DRIVESOUNDS_FLOPPY)
						drivesounds_enable(DRIVESOUNDS_FLOPPY);
					else
						drivesounds_disable(DRIVESOUNDS_FLOPPY);
		            menustate = MENU_FLOPPY1;
					break;
				case 3:
	                menustate = MENU_MAIN1;
					menusub=parentsub;
					break;
			}
        }
		break;

    case MENU_FILE_SELECTED : // file successfully selected

         InsertFloppy(&df[menusub]);
         menustate = MENU_MAIN1;
         menusub++;
         if (menusub > drives)
             menusub = 6;

         break;

        /******************************************************************/
        /* second part of the main menu                                   */
        /******************************************************************/
    case MENU_MAIN2_1 :
        OsdColor(OSDCOLOR_TOPLEVEL);
		helptext=helptexts[HELPTEXT_MAIN];
		menumask=0x3f;
 		OsdSetTitle("Settings",OSD_ARROW_LEFT|OSD_ARROW_RIGHT);
        OsdWrite(0, "    load configuration", menusub == 0,0);
        OsdWrite(1, "    save configuration", menusub == 1,0);
        OsdWrite(2, "", 0,0);
        OsdWrite(3, "    chipset settings \x16", menusub == 2,0);
        OsdWrite(4, "     memory settings \x16", menusub == 3,0);
        OsdWrite(5, "      video settings \x16", menusub == 4,0);
        OsdWrite(6, "", 0,0);
        OsdWrite(7, STD_EXIT, menusub == 5,0);

		parentstate = menustate;
        menustate = MENU_MAIN2_2;
        break;

    case MENU_MAIN2_2 :
        if (menu)
            menustate = MENU_NONE1;
        else if (select)
        {
            if (menusub == 0)
            {
                menusub = 0;
                menustate = MENU_LOADCONFIG_1;
            }
            else if (menusub == 1)
            {
                menusub = 0;
                menustate = MENU_SAVECONFIG_1;
            }
            else if (menusub == 2)
            {
                menustate = MENU_SETTINGS_CHIPSET1;
                menusub = 0;
            }
            else if (menusub == 3)
            {
                menustate = MENU_SETTINGS_MEMORY1;
                menusub = 0;
            }
            else if (menusub == 4)
            {
                menustate = MENU_SETTINGS_VIDEO1;
                menusub = 0;
            }
            else if (menusub == 5)
                menustate = MENU_NONE1;
        }
        else if (left)
        {
            menustate = MENU_MAIN1;
            menusub = 0;
        }
        else if (right)
        {
            menustate = MENU_MISC1;
            menusub = 0;
        }
        break;

    case MENU_MISC1 :
        OsdColor(OSDCOLOR_TOPLEVEL);
		helptext=helptexts[HELPTEXT_MAIN];
		menumask=0x7f;	// Reset, about and exit.
 		OsdSetTitle("Misc",OSD_ARROW_LEFT);
        OsdWrite(0, "  Reset", menusub == 0,0);
        OsdWrite(1, "  Reboot", menusub == 1,0);
        OsdWrite(2, "", 0,0);
		if(PLATFORM&(1<<PLATFORM_RECONFIG))
	        OsdWrite(2, "  Return to Chameleon", menusub == 2,0);
		else
		{
	        OsdWrite(2, "", 0,0);
			menumask&=~0x04;	// Remove the Reconfigure option from the menu
		}

		if(PLATFORM&(1<<PLATFORM_IECSERIAL))
		{
			if(config.misc & (1<<PLATFORM_IECSERIAL))
			    OsdWrite(3, "  Serial over IEC : On", menusub==3,0);
			else
			    OsdWrite(3, "  Serial over IEC : Off", menusub==3,0);
		}
		else
		{
	        OsdWrite(3, "", 0,0);
			menumask&=~0x08;	// Remove the IEC option from the menu
		}

        OsdWrite(4, "  About", menusub == 4,0);
        OsdWrite(5, "  Supporters", menusub == 5,0);
        OsdWrite(6, "", 0,0);
        OsdWrite(7, STD_EXIT, menusub == 6,0);

		parentstate = menustate;
        menustate = MENU_MISC2;
        break;

    case MENU_MISC2 :

        if (menu)
            menusub=0, menustate = MENU_NONE1;
		if (left)
			menusub=0, menustate = MENU_MAIN2_1;
        else if (select)
        {
			parentsub=menusub;
            if (menusub == 0)	// Reset
            {
                menusub = 0;
				strcpy(s,"         Reset Minimig?");
				confirmfunc=OsdReset;
				menustate=MENU_CONFIRM1;
			}
            if (menusub == 1)	// Reboot
            {
                menusub = 0;
				strcpy(s,"         Reboot Minimig?");
				confirmfunc=ColdBoot;
				menustate=MENU_CONFIRM1;
			}
            if (menusub == 2)	// Reconfig
            {
				menusub=0;
				strcpy(s,"     Return to Chameleon?");
				confirmfunc=Reconfigure;
				menustate=MENU_CONFIRM1;
			}
            if (menusub == 3)	// IEC over serial
            {
				if(config.misc & (1<<PLATFORM_IECSERIAL))
				{
					DisableIECSerial();
					menustate=MENU_MISC1;
				}
				else
				{
					strcpy(s,"  Experimental - proceed?");
					confirmfunc=EnableIECSerial;
					menusub=0;
					menustate=MENU_CONFIRM1;
				}
			}
            if (menusub == 4)	// About
            {
				menusub=0;
				menustate=MENU_ABOUT1;
			}
            if (menusub == 5)	// About
            {
				menusub=0;
				menustate=MENU_SUPPORTERS1;
			}
            if (menusub == 6)	// Exit
            {
				menustate=MENU_NONE1;
			}
		}
		break;

	case MENU_ABOUT1 :
        OsdColor(OSDCOLOR_SUBMENU);
		helptext=helptexts[HELPTEXT_NONE];
		menumask=0x01;	// Just Exit
 		OsdSetTitle("About",0);
		OsdDrawLogo(0,0,1);
		OsdDrawLogo(1,1,1);
		OsdDrawLogo(2,2,1);
		OsdDrawLogo(3,3,1);
		OsdDrawLogo(4,4,1);
		OsdDrawLogo(6,6,1);
//        OsdWrite(1, "", 0,0);
//        OsdWriteDoubleSize(2,"   Minimig",0);
//        OsdWriteDoubleSize(3,"   Minimig",1);
//        OsdWrite(4, "", 0,0);
        OsdWrite(5, "", 0,0);
        OsdWrite(6, "", 0,0);
        OsdWrite(7, STD_BACK, menusub == 0,0);

		StarsInit();
		ScrollReset();

		parentstate = menustate;
        menustate = MENU_ABOUT2;
        break;

	case MENU_ABOUT2 :
		StarsUpdate();
		OsdDrawLogo(0,0,1);
		OsdDrawLogo(1,1,1);
		OsdDrawLogo(2,2,1);
		OsdDrawLogo(3,3,1);
		OsdDrawLogo(4,4,1);
		OsdDrawLogo(6,6,1);
		ScrollText(5,"                                 Minimig AGA by Rok Krajnc, ported to Turbo Chameleon 64 by Alastair M. Robinson.  Original Minimig by Dennis van Weeren with chipset improvements by Jakub Bednarski and Sascha Boing.  TG68K softcore by Tobias Gubener.  Menu / disk code by Dennis van Weeren, Jakub Bednarski, Alastair M. Robinson and Christian Vogelgsang.  Minimig logo based on a design by Loriano Pagni.  Minimig is distributed under the terms of the GNU General Public License version 3.",0,0,0);
        if (select || menu)
        {
			menusub = parentsub;
			menustate=MENU_MISC1;
		}
		break;

	case MENU_SUPPORTERS1 :
        OsdColor(OSDCOLOR_SUBMENU);
		helptext=helptexts[HELPTEXT_NONE];
		menumask=0x01;	// Just Exit
 		OsdSetTitle("Thanks to",0);
		OsdDrawLogo(0,0,1);
		OsdDrawLogo(1,1,1);
		OsdDrawLogo(2,2,1);
		OsdDrawLogo(3,3,1);
		OsdDrawLogo(4,4,1);
		OsdDrawLogo(6,6,1);
//        OsdWrite(1, "", 0,0);
//        OsdWriteDoubleSize(2,"   Minimig",0);
//        OsdWriteDoubleSize(3,"   Minimig",1);
//        OsdWrite(4, "", 0,0);
        OsdWrite(5, "", 0,0);
        OsdWrite(6, "", 0,0);
        OsdWrite(7, STD_BACK, menusub == 0,0);

		FireworksInit();
		ScrollReset();

		parentstate = menustate;
        menustate = MENU_SUPPORTERS2;
        break;

	case MENU_SUPPORTERS2 :
		FireworksUpdate();
		OsdDrawLogo(0,8,1);
		OsdDrawLogo(1,8,1);
		OsdDrawLogo(2,8,1);
		OsdDrawLogo(3,8,1);
		OsdDrawLogo(4,8,1);
		OsdDrawLogo(6,8,1);
		ScrollText(5,"                                 I'm very grateful to these people for their support, which will give me the means and motivation to continue working on this core and others.  If you would like to contribute then one-off donations at paypal.me/robinsonb5 are very welcome, or if you wish you can contribute regularly at patreon.com/coresforchameleon - if you donate 20UKP or more, or join the second tier at Patreon your name will be included on this screen, or the equivalent screen of future projects.",0,0,0);
        if (select || menu)
        {
			menusub = parentsub;
			menustate=MENU_MISC1;
		}
		break;

    case MENU_LOADCONFIG_1 :
        OsdColor(OSDCOLOR_SUBMENU);
		helptext=helptexts[HELPTEXT_NONE];
		if(parentstate!=menustate)	// First run?
		{
			menumask=0x60;
			SetConfigurationFilename(0); if(ConfigurationExists(0)) menumask|=0x01;
			SetConfigurationFilename(1); if(ConfigurationExists(0)) menumask|=0x02;
			SetConfigurationFilename(2); if(ConfigurationExists(0)) menumask|=0x04;
			SetConfigurationFilename(3); if(ConfigurationExists(0)) menumask|=0x08;
			SetConfigurationFilename(4); if(ConfigurationExists(0)) menumask|=0x10;
			if(!(menumask&0x1f))
				menusub=5;
		}
		parentstate=menustate;
 		OsdSetTitle("Load",0);

        OsdWrite(0, "    Default", menusub == 0,(menumask & 1)==0);
        OsdWrite(1, "          1", menusub == 1,(menumask & 2)==0);
        OsdWrite(2, "          2", menusub == 2,(menumask & 4)==0);
        OsdWrite(3, "          3", menusub == 3,(menumask & 8)==0);
        OsdWrite(4, "          4", menusub == 4,(menumask & 0x10)==0);
        OsdWrite(5, "      Other \x16", menusub==5,0);
        OsdWrite(6, "", 0,0);
        OsdWrite(7, STD_EXIT, menusub == 6,0);

        menustate = MENU_LOADCONFIG_2;
        break;

    case MENU_LOADCONFIG_2 :

		if(select)
        {
			if(menusub<5)
			{
		        OsdWrite(7, "      Loading config...", 0,0);
				SetConfigurationFilename(menusub);
				LoadConfiguration(NULL);
				ApplyConfiguration(1,1);
				OsdHide();
				OsdDoReset(SPI_RST_USR | SPI_RST_CPU,0);
	   	        menustate = MENU_NONE1;
			}
			else if(menusub==5)
			{
                SelectFile("CFG", SCAN_DIR | SCAN_LFN, MENU_LOADCONFIG_3, MENU_MAIN2_1);				
			}
			else
			{
				menustate = MENU_MAIN2_1;
				menusub = 0;
			}
        }
        if (menu) // exit menu
        {
            menustate = MENU_MAIN2_1;
            menusub = 0;
        }

        break;

	case MENU_LOADCONFIG_3 :
        OsdWrite(7, "      Loading config...", 0,0);
		if(CheckConfiguration(&file))
		{
			LoadConfiguration(&file);
			ApplyConfiguration(1,1);
			OsdHide();
			OsdDoReset(SPI_RST_USR | SPI_RST_CPU,0);
	        menustate = MENU_NONE1;
		}
		else
			InfoMessage(" Not a valid config file!");
		break;

        /******************************************************************/
        /* file selection menu                                            */
        /******************************************************************/
    case MENU_FILE_SELECT1 :
        OsdColor(OSDCOLOR_SUBMENU);
		helptext=helptexts[HELPTEXT_NONE];
 		OsdSetTitle("Select",0);
        PrintDirectory();
        menustate = MENU_FILE_SELECT2;
        break;

    case MENU_FILE_SELECT2 :
		menumask=0;
 
        ScrollLongName(); // scrolls file name if longer than display line

        if (c == KEY_HOME)
        {
            ScanDirectory(SCAN_INIT, fs_pFileExt, fs_Options);
            menustate = MENU_FILE_SELECT1;
        }

        if (c == KEY_BACK)
        {
            if (iCurrentDirectory) // if not root directory
            {
                ScanDirectory(SCAN_INIT, fs_pFileExt, fs_Options);
                ChangeDirectory(DirEntry[sort_table[iSelectedEntry]].StartCluster +
						(fat32 ? (DirEntry[sort_table[iSelectedEntry]].HighCluster & 0x0FFF) << 16 : 0));
                if (ScanDirectory(SCAN_INIT_FIRST, fs_pFileExt, fs_Options))
                    ScanDirectory(SCAN_INIT_NEXT, fs_pFileExt, fs_Options);

                menustate = MENU_FILE_SELECT1;
            }
        }

        if (c == KEY_PGUP)
        {
            ScanDirectory(SCAN_PREV_PAGE, fs_pFileExt, fs_Options);
            menustate = MENU_FILE_SELECT1;        }

        if (c == KEY_PGDN)
        {
            ScanDirectory(SCAN_NEXT_PAGE, fs_pFileExt, fs_Options);
            menustate = MENU_FILE_SELECT1;
        }

        if (down) // scroll down one entry
        {
            ScanDirectory(SCAN_NEXT, fs_pFileExt, fs_Options);
            menustate = MENU_FILE_SELECT1;
        }

        if (up) // scroll up one entry
        {
            ScanDirectory(SCAN_PREV, fs_pFileExt, fs_Options);
            menustate = MENU_FILE_SELECT1;
        }

        if ((i = GetASCIIKey(c)))
        { // find an entry beginning with given character
            if (nDirEntries)
            {
                if (DirEntry[sort_table[iSelectedEntry]].Attributes & ATTR_DIRECTORY)
                { // it's a directory
                    if (i < DirEntry[sort_table[iSelectedEntry]].Name[0])
                    {
                        if (!ScanDirectory(i, fs_pFileExt, fs_Options | FIND_FILE))
                            ScanDirectory(i, fs_pFileExt, fs_Options | FIND_DIR);
                    }
                    else if (i > DirEntry[sort_table[iSelectedEntry]].Name[0])
                    {
                        if (!ScanDirectory(i, fs_pFileExt, fs_Options | FIND_DIR))
                            ScanDirectory(i, fs_pFileExt, fs_Options | FIND_FILE);
                    }
                    else
                    {
                        if (!ScanDirectory(i, fs_pFileExt, fs_Options)) // find nexr
                            if (!ScanDirectory(i, fs_pFileExt, fs_Options | FIND_FILE))
                                ScanDirectory(i, fs_pFileExt, fs_Options | FIND_DIR);
                    }
                }
                else
                { // it's a file
                    if (i < DirEntry[sort_table[iSelectedEntry]].Name[0])
                    {
                        if (!ScanDirectory(i, fs_pFileExt, fs_Options | FIND_DIR))
                            ScanDirectory(i, fs_pFileExt, fs_Options | FIND_FILE);
                    }
                    else if (i > DirEntry[sort_table[iSelectedEntry]].Name[0])
                    {
                        if (!ScanDirectory(i, fs_pFileExt, fs_Options | FIND_FILE))
                            ScanDirectory(i, fs_pFileExt, fs_Options | FIND_DIR);
                    }
                    else
                    {
                        if (!ScanDirectory(i, fs_pFileExt, fs_Options)) // find next
                            if (!ScanDirectory(i, fs_pFileExt, fs_Options | FIND_DIR))
                                ScanDirectory(i, fs_pFileExt, fs_Options | FIND_FILE);
                    }
                }
            }
            menustate = MENU_FILE_SELECT1;
        }

        if (select)
        {
            if (DirEntry[sort_table[iSelectedEntry]].Attributes & ATTR_DIRECTORY)
            {
                ChangeDirectory(DirEntry[sort_table[iSelectedEntry]].StartCluster +
					(fat32 ? (DirEntry[sort_table[iSelectedEntry]].HighCluster & 0x0FFF) << 16 : 0));
                {
                    if (strncmp((char*)DirEntry[sort_table[iSelectedEntry]].Name, "..", 2) == 0)
                    { // parent dir selected
                         if (ScanDirectory(SCAN_INIT_FIRST, fs_pFileExt, fs_Options))
                             ScanDirectory(SCAN_INIT_NEXT, fs_pFileExt, fs_Options);
                         else
                             ScanDirectory(SCAN_INIT, fs_pFileExt, fs_Options);
                    }
                    else
                        ScanDirectory(SCAN_INIT, fs_pFileExt, fs_Options);

                    menustate = MENU_FILE_SELECT1;
                }
            }
            else
            {
                if (nDirEntries)
                {
                    file.long_name[0] = 0;
                    len = strlen(DirEntryLFN[sort_table[iSelectedEntry]]);
                    if (len > 4)
                        if (DirEntryLFN[sort_table[iSelectedEntry]][len-4] == '.')
                            len -= 4; // remove extension

                    if (len > sizeof(file.long_name))
                        len = sizeof(file.long_name);

                    strncpy(file.name, (const char*)DirEntry[sort_table[iSelectedEntry]].Name, sizeof(file.name));
                    memset(file.long_name, 0, sizeof(file.long_name));
                    strncpy(file.long_name, DirEntryLFN[sort_table[iSelectedEntry]], len);
                    strncpy(DiskInfo, DirEntryInfo[iSelectedEntry], sizeof(DiskInfo));

                    file.size = DirEntry[sort_table[iSelectedEntry]].FileSize;
                    file.attributes = DirEntry[sort_table[iSelectedEntry]].Attributes;
                    file.start_cluster = DirEntry[sort_table[iSelectedEntry]].StartCluster +
						(fat32 ? (DirEntry[sort_table[iSelectedEntry]].HighCluster & 0x0FFF) << 16 : 0);
                    file.cluster = file.start_cluster;
                    file.sector = 0;

                    menustate = fs_MenuSelect;
                }
				else
					menustate = MENU_MAIN1;	// Return to main menu if user selects the "No files!" line
            }
        }

        if (menu)
        {
            menustate = fs_MenuCancel;
        }

        break;

        /******************************************************************/
        /* reset menu                                                     */
        /******************************************************************/
    case MENU_CONFIRM1 :
        OsdColor(OSDCOLOR_WARNING);
		helptext=helptexts[HELPTEXT_NONE];
		OsdSetTitle("Confirm",0);
		menumask=0x03;	// Yes / No
		parentstate=menustate;

        OsdWrite(0, "", 0,0);
        OsdWrite(1, s, 0,0);
        OsdWrite(2, "", 0,0);
        OsdWrite(3, "               yes", menusub == 0,0);
        OsdWrite(4, "               no", menusub == 1,0);
        OsdWrite(5, "", 0,0);
        OsdWrite(6, "", 0,0);
        OsdWrite(7, "", 0,0);

        menustate = MENU_CONFIRM2;
        break;

    case MENU_CONFIRM2 :

        if (select && menusub == 0)
        {
            menustate = MENU_NONE1;
			OsdHide();
            confirmfunc();
        }

        if (menu || (select && (menusub == 1))) // exit menu
        {
            menustate = MENU_MISC1;
            menusub = parentsub;
        }
        break;

        /******************************************************************/
        /* settings menu                                                  */
        /******************************************************************/

    case MENU_SAVECONFIG_1 :
        OsdColor(OSDCOLOR_SUBMENU);
		helptext=helptexts[HELPTEXT_NONE];
		menumask=0x7f;
		parentstate=menustate;
 		OsdSetTitle("Save",0);

		SetConfigurationFilename(0);
		sprintf(s,"    Default %s",ConfigurationExists(0) ? "(overwrite)" : "");
        OsdWrite(0, s, menusub == 0,0);
		SetConfigurationFilename(1);
		sprintf(s,"          1 %s",ConfigurationExists(0) ? "(overwrite)" : "");
        OsdWrite(1, s, menusub == 1,0);
		SetConfigurationFilename(2);
		sprintf(s,"          2 %s",ConfigurationExists(0) ? "(overwrite)" : "");
        OsdWrite(2, s, menusub == 2,0);
		SetConfigurationFilename(3);
		sprintf(s,"          3 %s",ConfigurationExists(0) ? "(overwrite)" : "");
        OsdWrite(3, s, menusub == 3,0);
		SetConfigurationFilename(4);
		sprintf(s,"          4 %s",ConfigurationExists(0) ? "(overwrite)" : "");
        OsdWrite(4, s, menusub == 4,0);
        OsdWrite(5, "     Other \x16", menusub==5, 0);
        OsdWrite(6, "", 0,0);
        OsdWrite(7, STD_EXIT, menusub == 6,0);

        menustate = MENU_SAVECONFIG_2;
        break;

    case MENU_SAVECONFIG_2 :

        if (menu)
		{
            menustate = MENU_MAIN2_1;
            menusub = 5;
		}

        else if (up)
        {
            if (menusub > 0)
                menusub--;
            menustate = MENU_SAVECONFIG_1;
        }
        else if (down)
        {
//            if (menusub < 3)
            if (menusub < 5)
                menusub++;
            menustate = MENU_SAVECONFIG_1;
        }
        else if (select)
        {
			if(menusub<5)
			{
				SetConfigurationFilename(menusub);
				SaveConfiguration(NULL);
		        menustate = MENU_NONE1;
			}
			else if(menusub==5)
			{
                SelectFile("CFG", SCAN_DIR | SCAN_LFN, MENU_SAVECONFIG_3, MENU_MAIN2_1);
			}
			else
			{
				menustate = MENU_MAIN2_1;
				menusub = 1;
			}
        }
        if (menu) // exit menu
        {
            menustate = MENU_MAIN2_1;
            menusub = 1;
        }
        break;

	case MENU_SAVECONFIG_3:
        OsdWrite(7, "      Saving config...", 0,0);
		if(CheckConfiguration(&file))
		{
			SaveConfiguration(&file);
			menustate = MENU_MAIN2_1;
		}
		else
			InfoMessage(" Not a valid config file!");
		break;

        /******************************************************************/
        /* chipset settings menu                                          */
        /******************************************************************/
    case MENU_SETTINGS_CHIPSET1 :
        OsdColor(OSDCOLOR_SUBMENU);
		helptext=helptexts[HELPTEXT_CHIPSET];
		parentstate = menustate;
		menumask=0x3f;
 		OsdSetTitle("Chipset",OSD_ARROW_LEFT|OSD_ARROW_RIGHT);

#if 0
        OsdWrite(0, "", 0,0);
        strcpy(s, "         CPU : ");
//        strcat(s, config.chipset & CONFIG_TURBO ? "turbo" : "normal");
        strcat(s, config_cpu_msg[config.cpu & 0x03]);
        OsdWrite(1, s, menusub == 0,0);
        strcpy(s, "       Video : ");
        strcat(s, config.chipset & CONFIG_NTSC ? "NTSC" : "PAL");
        OsdWrite(2, s, menusub == 1,0);
        strcpy(s, "     Chipset : ");
        strcat(s, config_chipset_msg[config.chipset >> 2 & 3]);
        OsdWrite(3, s, menusub == 2,0);
        OsdWrite(4, "", 0,0);
        OsdWrite(5, "", 0,0);
        OsdWrite(6, "", 0,0);
#endif
		OsdWrite(0, "", 0,0);
		strcpy(s, "         CPU : ");
		strcat(s, config_cpu_msg[config.cpu & 0x03]);
		OsdWrite(1, s, menusub == 0,0);
		strcpy(s, "       Turbo : ");
		strcat(s, config_turbo_msg[(config.cpu >> 2) & 0x03]);
		OsdWrite(2, s, menusub == 1,0);
		strcpy(s, "       Video : ");
		strcat(s, config.chipset & CONFIG_NTSC ? "NTSC" : "PAL");
		OsdWrite(3, s, menusub == 2,0);
		strcpy(s, "     Chipset : ");
		strcat(s, config_chipset_msg[(config.chipset >> 2) & 7]);
		OsdWrite(4, s, menusub == 3,0);
		strcpy(s, "     CD32Pad : ");
		strcat(s, config_cd32pad_msg[(config.autofire >> 2) & 1]);
		OsdWrite(5, s, menusub == 4,0);
		OsdWrite(6, "", 0,0);

        OsdWrite(7, STD_BACK, menusub == 5,0);

        menustate = MENU_SETTINGS_CHIPSET2;
        break;

    case MENU_SETTINGS_CHIPSET2 :

        if (down && menusub < 5)
        {
            menusub++;
            menustate = MENU_SETTINGS_CHIPSET1;
        }

        if (up && menusub > 0)
        {
            menusub--;
            menustate = MENU_SETTINGS_CHIPSET1;
        }

        if (select)
        {
            if (menusub == 0)
            {
				int cpu=(config.cpu+1)&3;
                menustate = MENU_SETTINGS_CHIPSET1;
				
                if(cpu==2)
					++cpu;
				config.cpu&=~3;
				config.cpu|=cpu;
                ConfigCPU(config.cpu);

            }
			else if (menusub == 1)
			{
				int _config_turbo = (config.cpu >> 2) & 0x3;
				menustate = MENU_SETTINGS_CHIPSET1;
				_config_turbo += 1;
				config.cpu = (config.cpu & 0x3) | ((_config_turbo & 0x3) << 2);
				ConfigCPU(config.cpu);
			}
            else if (menusub == 2)
            {
                config.chipset ^= CONFIG_NTSC;
                menustate = MENU_SETTINGS_CHIPSET1;
                ConfigChipset(config.chipset);
            }
            else if (menusub == 3)
            {
				switch(config.chipset&0x1c) {
					case 0:
						config.chipset = (config.chipset&3) | CONFIG_A1000;
						break;
					case CONFIG_A1000:
						config.chipset = (config.chipset&3) | CONFIG_ECS;
						break;
					case CONFIG_ECS:
						config.chipset = (config.chipset&3) | CONFIG_AGA | CONFIG_ECS;
						break;
					case (CONFIG_AGA|CONFIG_ECS):
						config.chipset = (config.chipset&3) | 0;
						break;
				}

                menustate = MENU_SETTINGS_CHIPSET1;
                ConfigChipset(config.chipset);
            }
            else if (menusub == 4)
            {
				/* CD32 pad */
				config.autofire  = (config.autofire + 4) & 0x7;
				menustate = MENU_SETTINGS_CHIPSET1;
				ConfigAutofire(config.autofire);
            }
            else if (menusub == 5)
            {
                menustate = MENU_MAIN2_1;
                menusub = 2;
            }
        }

        if (menu)
        {
            menustate = MENU_MAIN2_1;
            menusub = 2;
        }
        else if (right)
        {
            menustate = MENU_SETTINGS_MEMORY1;
            menusub = 0;
        }
        else if (left)
        {
            menustate = MENU_SETTINGS_VIDEO1;
            menusub = 0;
        }
        break;

        /******************************************************************/
        /* memory settings menu                                           */
        /******************************************************************/
    case MENU_SETTINGS_MEMORY1 :
        OsdColor(OSDCOLOR_SUBMENU);
		helptext=helptexts[HELPTEXT_MEMORY];
		menumask=0x3f;
		parentstate=menustate;

 		OsdSetTitle("Memory",OSD_ARROW_LEFT|OSD_ARROW_RIGHT);

		strcpy(s, "      CHIP  : ");
		strcat(s, config_memory_chip_msg[config.memory & 0x03]);
		OsdWrite(0, s, menusub == 0,0);
		strcpy(s, "      SLOW  : ");
		strcat(s, config_memory_slow_msg[config.memory >> 2 & 0x03]);
		OsdWrite(1, s, menusub == 1,0);
		strcpy(s, "      FAST  : ");
		strcat(s, config_memory_fast_msg[config.memory >> 4 & 0x03]);
		OsdWrite(2, s, menusub == 2,0);

		OsdWrite(3, "", 0,0);

        strcpy(s, "        ROM  : ");
        if (config.kickstart.long_name[0])
            strncat(s, config.kickstart.long_name, sizeof(config.kickstart.long_name));
        else
            strncat(s, config.kickstart.name, sizeof(config.kickstart.name));
        OsdWrite(4, s, menusub == 3,0);

		if(PLATFORM&(1<<PLATFORM_HRTMONCART)) {
			strcpy(s, "      HRTmon: ");
			strcat(s, (config.memory&0x40) ? "enabled " : "disabled");
			OsdWrite(5, s, menusub == 4,0);
		}
		else
			OsdWrite(5, "", 0,0);
		OsdWrite(6, "", 0,0);

        OsdWrite(7, STD_BACK, menusub == 5,0);

        menustate = MENU_SETTINGS_MEMORY2;
        break;

    case MENU_SETTINGS_MEMORY2 :
        if (select)
        {
			if (menusub == 0) /* Chip RAM */
			{
				config.memory = ((config.memory + 1) & 0x03) | (config.memory & ~0x03);
				menustate = MENU_SETTINGS_MEMORY1;
				ConfigMemory(config.memory);
			}
			else if (menusub == 1) /* Slow RAM */
			{
				config.memory = ((config.memory + 4) & 0x0C) | (config.memory & ~0x0C);
				menustate = MENU_SETTINGS_MEMORY1;
				ConfigMemory(config.memory);
			}
			else if (menusub == 2) /* Fast RAM */
			{
				config.memory = ((config.memory + 0x10) & 0x30) | (config.memory & ~0x30);
				menustate = MENU_SETTINGS_MEMORY1;
				ConfigMemory(config.memory);
			}
            else if (menusub == 3) /* Kickstart ROM */
            {
                SelectFile("ROM", SCAN_DIR | SCAN_LFN, MENU_ROMFILE_SELECTED, MENU_SETTINGS_MEMORY1);
            }
            else if (menusub == 4) /* HRTMon */
            {
				config.memory ^= 0x40;
				ConfigMemory(config.memory);
				//if (!(config.disable_ar3 & 0x01)||(config.memory & 0x20))
				//  config.disable_ar3 |= 0x01;
				//else
				//  config.disable_ar3 &= 0xFE;
				menustate = MENU_SETTINGS_MEMORY1;
            }
            else if (menusub == 5)
            {
                menustate = MENU_MAIN2_1;
                menusub = 3;
            }
        }

        if (menu)
        {
            menustate = MENU_MAIN2_1;
            menusub = 3;
        }
        else if (right)
        {
            menustate = MENU_SETTINGS_VIDEO1;
            menusub = 0;
        }
        else if (left)
        {
            menustate = MENU_SETTINGS_CHIPSET1;
            menusub = 0;
        }
        break;

        /******************************************************************/
        /* drive settings menu                                            */
        /******************************************************************/

        /******************************************************************/
        /* hardfile settings menu                                         */
        /******************************************************************/

    case MENU_SETTINGS_HARDFILE1 :
        OsdColor(OSDCOLOR_SUBMENU);
		helptext=helptexts[HELPTEXT_HARDFILE];
		OsdSetTitle("Harddisks",0);

		enable=t_enable_ide & (1<<(hardfile_firstunit>>1));
		parentstate = menustate;

		menumask=0x41;	// b01000001 - On/off & exit enabled by default...
		if(enable)
			menumask|=hardfile_firstunit ? 0x0a : 0x2a;  // b00101010 - HD0 and HD1 type + sounds (for first page)
        strcpy(s, hardfile_firstunit ? "    IDE : (secondary) " : "    IDE : (primary) ");
        strcat(s, enable ? "on " : "off");
        OsdWrite(0, s, menusub == 0,0);

        strcpy(s, " Master : ");
		if(t_hardfile[hardfile_firstunit].enabled==(HDF_FILE|HDF_SYNTHRDB))
			strcat(s,"Hardfile (filesys)");
		else
	        strcat(s, config_hdf_msg[t_hardfile[hardfile_firstunit].enabled & HDF_TYPEMASK]);
        OsdWrite(1, s, enable ? (menusub == 1) : 0 ,enable==0);

        if (t_hardfile[hardfile_firstunit].present)
        {
            strcpy(s, "                                ");
            if (t_hardfile[hardfile_firstunit].long_name[hardfile_firstunit])
                strncpy(&s[14], t_hardfile[hardfile_firstunit].long_name, sizeof(t_hardfile[hardfile_firstunit].long_name));
            else
                strncpy(&s[14], t_hardfile[hardfile_firstunit].name, sizeof(t_hardfile[hardfile_firstunit].name));
        }
        else
            strcpy(s, "       ** file not found **");

		enable=(t_enable_ide & (1<<(hardfile_firstunit>>1))) && ((t_hardfile[hardfile_firstunit].enabled&HDF_TYPEMASK)==HDF_FILE);
		if(enable)
			menumask|=0x04;	// Make hardfile selectable
	    OsdWrite(2, s, enable ? (menusub == 2) : 0 , enable==0);

		enable=t_enable_ide & (1<<(hardfile_firstunit>>1));

        strcpy(s, "  Slave : ");
		if(t_hardfile[hardfile_firstunit+1].enabled==(HDF_FILE|HDF_SYNTHRDB))
			strcat(s,"Hardfile (filesys)");
		else
	        strcat(s, config_hdf_msg[t_hardfile[hardfile_firstunit+1].enabled & HDF_TYPEMASK]);
        OsdWrite(3, s, enable ? (menusub == 3) : 0 ,enable==0);
        if (t_hardfile[hardfile_firstunit+1].present)
        {
            strcpy(s, "                                ");
            if (t_hardfile[hardfile_firstunit+1].long_name[0])
                strncpy(&s[14], t_hardfile[hardfile_firstunit+1].long_name, sizeof(t_hardfile[hardfile_firstunit+1].long_name));
            else
                strncpy(&s[14], t_hardfile[hardfile_firstunit+1].name, sizeof(t_hardfile[hardfile_firstunit+1].name));
        }
        else
            strcpy(s, "       ** file not found **");

		enable=(t_enable_ide & (1<<(hardfile_firstunit>>1))) && ((t_hardfile[hardfile_firstunit+1].enabled&HDF_TYPEMASK)==HDF_FILE);
		if(enable)
			menumask|=0x10;	// Make hardfile selectable
        OsdWrite(4, s, enable ? (menusub == 4) : 0 ,enable==0);

		if(hardfile_firstunit)
			OsdWrite(5,"",0,0);
		else
		{
			strcpy(s, " Sounds : ");
			strcat(s, config.drivesounds&DRIVESOUNDS_HDD ? "on " : "off");
			OsdWrite(5, s, menusub==5,t_enable_ide==0);
		}
        OsdWrite(6, "", 0,0);
        OsdWrite(7, STD_BACK, menusub == 6,0);

        menustate = MENU_SETTINGS_HARDFILE2;

        break;

    case MENU_SETTINGS_HARDFILE2 :
        if (select)
        {
            if (menusub == 0)
            {
				t_enable_ide^=hardfile_firstunit ? ENABLE_IDE_SECONDARY : ENABLE_IDE_PRIMARY;
				menustate = MENU_SETTINGS_HARDFILE1;
            }
            if (menusub == 1)
            {
				if(t_hardfile[hardfile_firstunit].enabled==HDF_FILE)
				{
					t_hardfile[hardfile_firstunit].enabled|=HDF_SYNTHRDB;
				}
				else if(t_hardfile[hardfile_firstunit].enabled==(HDF_FILE|HDF_SYNTHRDB))
				{
					t_hardfile[hardfile_firstunit].enabled&=~HDF_SYNTHRDB;
					t_hardfile[hardfile_firstunit].enabled +=1;
				}
				else
				{
					t_hardfile[hardfile_firstunit].enabled +=1;
					t_hardfile[hardfile_firstunit].enabled %=HDF_CARDPART0+partitioncount;
				}
                menustate = MENU_SETTINGS_HARDFILE1;
            }
            else if (menusub == 2)
            {
                SelectFile("HDF", SCAN_DIR | SCAN_LFN, MENU_HARDFILE_SELECTED, MENU_SETTINGS_HARDFILE1);
            }
            else if (menusub == 3)
            {
				if(t_hardfile[hardfile_firstunit+1].enabled==HDF_FILE)
				{
					t_hardfile[hardfile_firstunit+1].enabled|=HDF_SYNTHRDB;
				}
				else if(t_hardfile[hardfile_firstunit+1].enabled==(HDF_FILE|HDF_SYNTHRDB))
				{
					t_hardfile[hardfile_firstunit+1].enabled&=~HDF_SYNTHRDB;
					t_hardfile[hardfile_firstunit+1].enabled +=1;
				}
				else
				{
					t_hardfile[hardfile_firstunit+1].enabled +=1;
					t_hardfile[hardfile_firstunit+1].enabled %=HDF_CARDPART0+partitioncount;
				}
				menustate = MENU_SETTINGS_HARDFILE1;
            }
            else if (menusub == 4)
            {
                SelectFile("HDF", SCAN_DIR | SCAN_LFN, MENU_HARDFILE_SELECTED, MENU_SETTINGS_HARDFILE1);
            }
            else if (menusub == 5)
            {
                config.drivesounds^=DRIVESOUNDS_HDD;
				if(config.drivesounds&DRIVESOUNDS_HDD)
					drivesounds_enable(DRIVESOUNDS_HDD);
				else
					drivesounds_disable(DRIVESOUNDS_HDD);
				menustate = MENU_SETTINGS_HARDFILE1;
            }
            else if (menusub == 6) // return to previous menu
            {
                menustate = MENU_HARDFILE_EXIT;
            }
        }

        if (menu) // return to previous menu
        {
            menustate = MENU_HARDFILE_EXIT;
        }
        break;

        /******************************************************************/
        /* hardfile selected menu                                         */
        /******************************************************************/
    case MENU_HARDFILE_SELECTED :
        if (menusub == 2) // master drive selected
        {
			// Read RDB from selected drive and determine type...
            memcpy((void*)t_hardfile[hardfile_firstunit].name, (void*)file.name, sizeof(t_hardfile[hardfile_firstunit].name));
            memcpy((void*)t_hardfile[hardfile_firstunit].long_name, (void*)file.long_name, sizeof(t_hardfile[hardfile_firstunit].long_name));
			t_hdfdir[hardfile_firstunit]=CurrentDirectory();
			switch(GetHDFFileType(file.name))
			{
				case HDF_FILETYPE_RDB:
					t_hardfile[hardfile_firstunit].enabled=HDF_FILE;
		            t_hardfile[hardfile_firstunit].present = 1;
			        menustate = MENU_SETTINGS_HARDFILE1;
					break;
				case HDF_FILETYPE_DOS:
					t_hardfile[hardfile_firstunit].enabled=HDF_FILE|HDF_SYNTHRDB;
		            t_hardfile[hardfile_firstunit].present = 1;
			        menustate = MENU_SETTINGS_HARDFILE1;
					break;
				case HDF_FILETYPE_UNKNOWN:
		            t_hardfile[hardfile_firstunit].present = 1;
					if(t_hardfile[hardfile_firstunit].enabled==HDF_FILE)	// Warn if we can't detect the type
						menustate=MENU_SYNTHRDB1;
					else
						menustate=MENU_SYNTHRDB2_1;
					menusub=0;
					break;
				case HDF_FILETYPE_NOTFOUND:
				default:
		            t_hardfile[hardfile_firstunit].present = 0;
			        menustate = MENU_SETTINGS_HARDFILE1;
					break;
			}
			
        }

        if (menusub == 4) // slave drive selected
        {
            memcpy((void*)t_hardfile[hardfile_firstunit+1].name, (void*)file.name, sizeof(t_hardfile[hardfile_firstunit+1].name));
            memcpy((void*)t_hardfile[hardfile_firstunit+1].long_name, (void*)file.long_name, sizeof(t_hardfile[hardfile_firstunit+1].long_name));
			t_hdfdir[hardfile_firstunit+1]=CurrentDirectory();
			switch(GetHDFFileType(file.name))
			{
				case HDF_FILETYPE_RDB:
					t_hardfile[hardfile_firstunit+1].enabled=HDF_FILE;
		            t_hardfile[hardfile_firstunit+1].present = 1;
			        menustate = MENU_SETTINGS_HARDFILE1;
					break;
				case HDF_FILETYPE_DOS:
					t_hardfile[hardfile_firstunit+1].enabled=HDF_FILE|HDF_SYNTHRDB;
		            t_hardfile[hardfile_firstunit+1].present = 1;
			        menustate = MENU_SETTINGS_HARDFILE1;
					break;
				case HDF_FILETYPE_UNKNOWN:
		            t_hardfile[hardfile_firstunit+1].present = 1;
					if(t_hardfile[hardfile_firstunit+1].enabled==HDF_FILE)	// Warn if we can't detect the type...
						menustate=MENU_SYNTHRDB1;
					else
						menustate=MENU_SYNTHRDB2_1;
					menusub=0;
					break;
				case HDF_FILETYPE_NOTFOUND:
				default:
		            t_hardfile[hardfile_firstunit+1].present = 0;
			        menustate = MENU_SETTINGS_HARDFILE1;
					break;
			}
        }
        break;

     // check if hardfile configuration has changed
    case MENU_HARDFILE_EXIT :
         if ((memcmp(config.hardfile, t_hardfile, sizeof(config.hardfile)) != 0)
			|| (memcmp(config.secondaryhardfile, &t_hardfile[2], sizeof(config.secondaryhardfile)) != 0)
				|| (t_enable_ide!=config.enable_ide))
         {
             menustate = MENU_HARDFILE_CHANGED1;
             menusub = 1;
         }
         else 
         {
             menustate = MENU_MAIN1;
             menusub = 5;
         }

         break;

    // hardfile configuration has changed, ask user if he wants to use the new settings
    case MENU_HARDFILE_CHANGED1 :
		helptext=helptexts[HELPTEXT_NONE];
        OsdColor(OSDCOLOR_WARNING);
		menumask=0x03;
		parentstate=menustate;
 		OsdSetTitle("Confirm",0);

        OsdWrite(0, "", 0,0);
        OsdWrite(1, "    Changing configuration", 0,0);
        OsdWrite(2, "      requires reset.", 0,0);
        OsdWrite(3, "", 0,0);
        OsdWrite(4, "       Reset Minimig?", 0,0);
        OsdWrite(5, "", 0,0);
        OsdWrite(6, "             yes", menusub == 0,0);
        OsdWrite(7, "             no", menusub == 1,0);

        menustate = MENU_HARDFILE_CHANGED2;
        break;

    case MENU_HARDFILE_CHANGED2 :
        if (select)
        {
            if (menusub == 0) // yes
            {
				int upd0=0,upd1=0,upd2=0,upd3=0;
				if(config.enable_ide!=t_enable_ide)
				{
					upd0=t_hardfile[0].enabled;
					upd1=t_hardfile[1].enabled;
					upd2=t_hardfile[2].enabled;
					upd3=t_hardfile[3].enabled;
				}
                if ((config.hardfile[0].enabled != t_hardfile[0].enabled)
					|| (strncmp(config.hardfile[0].name, t_hardfile[0].name, sizeof(t_hardfile[0].name)) != 0))
					upd0=1;
                if ((config.hardfile[1].enabled != t_hardfile[1].enabled)
					|| (strncmp(config.hardfile[1].name, t_hardfile[1].name, sizeof(t_hardfile[1].name)) != 0))
					upd1=1;
                if ((config.secondaryhardfile[0].enabled != t_hardfile[2].enabled)
					|| (strncmp(config.secondaryhardfile[0].name, t_hardfile[2].name, sizeof(t_hardfile[2].name)) != 0))
					upd2=1;
                if ((config.secondaryhardfile[1].enabled != t_hardfile[3].enabled)
					|| (strncmp(config.secondaryhardfile[1].name, t_hardfile[3].name, sizeof(t_hardfile[3].name)) != 0))
					upd3=1;

				// Apply new configuration
				config.hardfile[0]=t_hardfile[0];
				config.hardfile[1]=t_hardfile[1];
				config.secondaryhardfile[0]=t_hardfile[2];
				config.secondaryhardfile[1]=t_hardfile[3];
				config.enable_ide=t_enable_ide; // Apply new IDE on/off
				config.hdfdir[0]=t_hdfdir[0];
				config.hdfdir[1]=t_hdfdir[1];
				config.hdfdir[2]=t_hdfdir[2];
				config.hdfdir[3]=t_hdfdir[3];

				// FIXME - waiting for user-confirmation increases the window of opportunity for file corruption!

                if (upd0)
                    OpenHardfile(0);

                if (upd1)
                    OpenHardfile(1);

                if (upd2)
                    OpenHardfile(2);

                if (upd3)
                    OpenHardfile(3);

                ConfigIDE(config.enable_ide&1, config.hardfile[0].present && config.hardfile[0].enabled,
						 config.hardfile[1].present && config.hardfile[1].enabled);
                ConfigIDE(2|(config.enable_ide>>1), config.secondaryhardfile[0].present && config.secondaryhardfile[0].enabled,
						 config.secondaryhardfile[1].present && config.secondaryhardfile[1].enabled);
   	            OsdReset();
				
                menustate = MENU_NONE1;
            }
            else if (menusub == 1) // no
            {
                menustate = MENU_MAIN1;
                menusub = 5;
            }
        }

        if (menu)
        {
            menustate = MENU_MAIN1;
            menusub = 5;
        }
        break;

    case MENU_SYNTHRDB1 :
		helptext=helptexts[HELPTEXT_NONE];
		menumask=0x01;
		parentstate=menustate;
 		OsdSetTitle("Warning",0);
        OsdWrite(0, "", 0,0);
        OsdWrite(1, " No partition table found -", 0,0);
        OsdWrite(2, " Hardfile image may need", 0,0);
        OsdWrite(3, " to be prepped with HDToolbox,", 0,0);
        OsdWrite(4, " then formatted.", 0,0);
        OsdWrite(5, "", 0,0);
        OsdWrite(6, "", 0,0);
        OsdWrite(7, "             OK", menusub == 0,0);

        menustate = MENU_SYNTHRDB2;
        break;


    case MENU_SYNTHRDB2_1 :
		helptext=helptexts[HELPTEXT_NONE];
		menumask=0x01;
		parentstate=menustate;
 		OsdSetTitle("Warning",0);
        OsdWrite(0, "", 0,0);
        OsdWrite(1, " No filesystem recognised.", 0,0);
        OsdWrite(2, " Hardfile may need formatting", 0,0);
        OsdWrite(3, " (or may simply be an", 0,0);
        OsdWrite(4, " unrecognised filesystem)", 0,0);
        OsdWrite(5, "", 0,0);
        OsdWrite(6, "", 0,0);
        OsdWrite(7, "             OK", menusub == 0,0);

        menustate = MENU_SYNTHRDB2;
        break;


    case MENU_SYNTHRDB2 :
        if (select || menu)
        {
            if (menusub == 0) // OK
		        menustate = MENU_SETTINGS_HARDFILE1;
        }
        break;


        /******************************************************************/
        /* video settings menu                                            */
        /******************************************************************/
    case MENU_SETTINGS_VIDEO1 :
        OsdColor(OSDCOLOR_SUBMENU);
		menumask=0x1f;
		parentstate=menustate;
		helptext=helptexts[HELPTEXT_VIDEO];
 
		OsdSetTitle("Video",OSD_ARROW_LEFT|OSD_ARROW_RIGHT);
        OsdWrite(0, "", 0,0);
        strcpy(s, "   Lores Filter : ");
        strcat(s, config_filter_msg[config.filter.lores & 0x03]);
        OsdWrite(1, s, menusub == 0,0);
        strcpy(s, "   Hires Filter : ");
        strcat(s, config_filter_msg[config.filter.hires & 0x03]);
        OsdWrite(2, s, menusub == 1,0);
        OsdWrite(3, "   Scanlines",0,0);
        strcpy(s, "     Normal     : ");
        strcat(s, config_scanlines_msg[config.scanlines & 3]);
        OsdWrite(4, s, menusub == 2,0);
        strcpy(s, "     Interlaced : ");
        strcat(s, config_scanlines_msg[(config.scanlines & 0xc)>>2]);
        OsdWrite(5, s, menusub == 3,0);
        OsdWrite(6, "", 0,0);
        OsdWrite(7, STD_BACK, menusub == 4,0);

        menustate = MENU_SETTINGS_VIDEO2;
        break;

    case MENU_SETTINGS_VIDEO2 :
        if (select)
        {
            if (menusub == 0)
            {
                config.filter.lores++;
                config.filter.lores &= 0x03;
                menustate = MENU_SETTINGS_VIDEO1;
                ConfigVideo(config.filter.hires, config.filter.lores,config.scanlines);
            }
            else if (menusub == 1)
            {
                config.filter.hires++;
                config.filter.hires &= 0x03;
                menustate = MENU_SETTINGS_VIDEO1;
                ConfigVideo(config.filter.hires, config.filter.lores,config.scanlines);
//                ConfigFilter(config.filter.lores, config.filter.hires);
            }
            else if (menusub == 2)
            {
				short tmp=config.scanlines+1;
				if((tmp&3)==3)
					tmp=0;
                config.scanlines=(config.scanlines&0xfc)|(tmp&3);
                menustate = MENU_SETTINGS_VIDEO1;
                ConfigVideo(config.filter.hires, config.filter.lores,config.scanlines);
//                ConfigScanlines(config.scanlines);
            }
            else if (menusub == 3)
            {
 				short tmp=config.scanlines+4;
				if((tmp&0xc)==0xc)
					tmp=0;
                config.scanlines=(config.scanlines&0xf3)|(tmp&0xc);
                menustate = MENU_SETTINGS_VIDEO1;
                ConfigVideo(config.filter.hires, config.filter.lores,config.scanlines);
//                ConfigScanlines(config.scanlines);
            }

            else if (menusub == 4)
            {
                menustate = MENU_MAIN2_1;
                menusub = 4;
            }
        }

        if (menu)
        {
            menustate = MENU_MAIN2_1;
            menusub = 4;
        }
        else if (right)
        {
            menustate = MENU_SETTINGS_CHIPSET1;
            menusub = 0;
        }
        else if (left)
        {
            menustate = MENU_SETTINGS_MEMORY1;
            menusub = 0;
        }
        break;

        /******************************************************************/
        /* rom file selected menu                                         */
        /******************************************************************/
    case MENU_ROMFILE_SELECTED :

         menusub = 1;
		 menustate=MENU_ROMFILE_SELECTED1;
         // no break intended

    case MENU_ROMFILE_SELECTED1 :
		helptext=helptexts[HELPTEXT_NONE];
        OsdColor(OSDCOLOR_WARNING);
		menumask=0x03;
		parentstate=menustate;
 		OsdSetTitle("Confirm",0);
        OsdWrite(0, "", 0,0);
        OsdWrite(1, "       Reload Kickstart?", 0,0);
        OsdWrite(2, "", 0,0);
        OsdWrite(3, "              yes", menusub == 0,0);
        OsdWrite(4, "              no", menusub == 1,0);
        OsdWrite(5, "", 0,0);
        OsdWrite(6, "", 0,0);
        OsdWrite(7, "", 0,0);

        menustate = MENU_ROMFILE_SELECTED2;
        break;

    case MENU_ROMFILE_SELECTED2 :

        if (select)
        {
            if (menusub == 0)
            {
                memcpy((void*)config.kickstart.name, (void*)file.name, sizeof(config.kickstart.name));
                memcpy((void*)config.kickstart.long_name, (void*)file.long_name, sizeof(config.kickstart.long_name));
				config.kickdir=CurrentDirectory();

		        OsdWrite(7, "           Loading...", 0,0);

				OsdDoReset(0,SPI_RST_CPU | SPI_CPU_HLT);

				ApplyConfiguration(1,0);
//				UploadKickstart(config.kickstart.name);
                OsdHide();
				OsdDoReset(SPI_RST_USR | SPI_RST_CPU,0);

                menustate = MENU_NONE1;
            }
            else if (menusub == 1)
            {
                menustate = MENU_SETTINGS_MEMORY1;
                menusub = 4;
            }
        }

        if (menu)
        {
            menustate = MENU_SETTINGS_MEMORY1;
            menusub = 4;
        }
        break;


        /******************************************************************/
        /* error message menu                                             */
        /******************************************************************/
    case MENU_ERROR :
		menumask=0x01;
		parentstate=MENU_MAIN1;

 		OsdSetTitle("Error",OSD_ARROW_LEFT|OSD_ARROW_RIGHT);
        OsdWrite(0, ErrorFatal ? "      *** FATAL ERROR ***" : "         *** ERROR ***", 1,0);
	    OsdWrite(1, "", 0,!(ErrorMask&(1<<errorpage)));
		snprintf(s,32," %s",ErrorMessages[errorpage]);
        OsdWrite(2, s, 0,!(ErrorMask&(1<<errorpage)));
		snprintf(s,32," %s",Errors[errorpage].string);
        OsdWrite(3, s, 0,!(ErrorMask&(1<<errorpage)));
		snprintf(s,32," %x",Errors[errorpage].a);
        OsdWrite(4, s, 0,!(ErrorMask&(1<<errorpage)));
		snprintf(s,32," %x",Errors[errorpage].b);
        OsdWrite(5, s, 0,!(ErrorMask&(1<<errorpage)));
	    OsdWrite(6, "", 0,0);
	    OsdWrite(7, ErrorFatal ? "           Reboot" : "             OK", 1,0);

        ClearError(ERROR_ALL);

		menustate = MENU_ERROR2;
		break;

	case MENU_ERROR2 :
		if(left)
		{
			--errorpage;
			if(errorpage<0)
				errorpage=ERROR_MAX;
		}
		if(right)
		{
			++errorpage;
			if(errorpage>ERROR_MAX)
				errorpage=0;
		}
        if (select)
		{
			OsdHide();
			if(ErrorFatal)
	            ColdBoot();
			menustate = MENU_NONE1;
		}
        break;

        /******************************************************************/
        /* popup info menu                                                */
        /******************************************************************/
    case MENU_INFO :

        if (menu)
            menustate = MENU_MAIN1;
        else if (CheckTimer(menu_timer))
            menustate = MENU_NONE1;

        break;

        /******************************************************************/
        /* we should never come here                                      */
        /******************************************************************/
    default :

        break;
    }
}


void ScrollLongName(void)
{
// this function is called periodically when file selection window is displayed
// it checks if predefined period of time has elapsed and scrolls the name if necessary

    char k = sort_table[iSelectedEntry];
	static int len;
	int max_len;

    if (DirEntryLFN[k][0]) // && CheckTimer(scroll_timer)) // scroll if long name and timer delay elapsed
    {
		// FIXME - yuk, we don't want to do this every frame!
        len = strlen(DirEntryLFN[k]); // get name length

        if (len > 4)
            if (DirEntryLFN[k][len - 4] == '.')
                len -= 4; // remove extension

        max_len = 30; // number of file name characters to display (one more required for scrolling)
        if (DirEntry[k].Attributes & ATTR_DIRECTORY)
            max_len = 25; // number of directory name characters to display

		ScrollText(iSelectedEntry,DirEntryLFN[k],len,max_len,1);
    }
}


char* GetDiskInfo(char* lfn, long len)
{
// extracts disk number substring form file name
// if file name contains "X of Y" substring where X and Y are one or two digit number
// then the number substrings are extracted and put into the temporary buffer for further processing
// comparision is case sensitive

    short i, k;
    static char info[] = "XX/XX"; // temporary buffer
    static char template[4] = " of "; // template substring to search for
    char *ptr1, *ptr2, c;
    unsigned char cmp;

    if (len > 20) // scan only names which can't be fully displayed
    {
        for (i = (unsigned short)len - 1 - sizeof(template); i > 0; i--) // scan through the file name starting from its end
        {
            ptr1 = &lfn[i]; // current start position
            ptr2 = template;
            cmp = 0;
            for (k = 0; k < sizeof(template); k++) // scan through template
            {
                cmp |= *ptr1++ ^ *ptr2++; // compare substrings' characters one by one
                if (cmp)
                   break; // stop further comparing if difference already found
            }

            if (!cmp) // match found
            {
                k = i - 1; // no need to check if k is valid since i is greater than zero

                c = lfn[k]; // get the first character to the left of the matched template substring
                if (c >= '0' && c <= '9') // check if a digit
                {
                    info[1] = c; // copy to buffer
                    info[0] = ' '; // clear previous character
                    k--; // go to the preceding character
                    if (k >= 0) // check if index is valid
                    {
                        c = lfn[k];
                        if (c >= '0' && c <= '9') // check if a digit
                            info[0] = c; // copy to buffer
                    }

                    k = i + sizeof(template); // get first character to the right of the mached template substring
                    c = lfn[k]; // no need to check if index is valid
                    if (c >= '0' && c <= '9') // check if a digit
                    {
                        info[3] = c; // copy to buffer
                        info[4] = ' '; // clear next char
                        k++; // go to the followwing character
                        if (k < len) // check if index is valid
                        {
                            c = lfn[k];
                            if (c >= '0' && c <= '9') // check if a digit
                                info[4] = c; // copy to buffer
                        }
                        return info;
                    }
                }
            }
        }
    }
    return NULL;
}

// print directory contents
void PrintDirectory(void)
{
    unsigned char i;
    unsigned char k;
    unsigned long len;
    char *lfn;
    char *info;
    char *p;
    unsigned char j;

    s[32] = 0; // set temporary string length to OSD line length

	ScrollReset();

    for (i = 0; i < 8; i++)
    {
        memset(s, ' ', 32); // clear line buffer
        if (i < nDirEntries)
        {
            k = sort_table[i]; // ordered index in storage buffer
            lfn = DirEntryLFN[k]; // long file name pointer
            DirEntryInfo[i][0] = 0; // clear disk number info buffer

            if (lfn[0]) // item has long name
            {
                len = strlen(lfn); // get name length
                info = NULL; // no disk info

                if (!(DirEntry[k].Attributes & ATTR_DIRECTORY)) // if a file
                {
                if (len > 4)
                    if (lfn[len-4] == '.')
                        len -= 4; // remove extension

                info = GetDiskInfo(lfn, len); // extract disk number info

                if (info != NULL)
                   memcpy(DirEntryInfo[i], info, 5); // copy disk number info if present
                }

                if (len > 30)
                    len = 30; // trim display length if longer than 30 characters

                if (i != iSelectedEntry && info != NULL)
                { // display disk number info for not selected items
                    strncpy(s + 1, lfn, 30-6); // trimmed name
                    strncpy(s + 1+30-5, info, 5); // disk number
                }
                else
                    strncpy(s + 1, lfn, len); // display only name
            }
            else  // no LFN
            {
                strncpy(s + 1, (const char*)DirEntry[k].Name, 8); // if no LFN then display base name (8 chars)
                if (DirEntry[k].Attributes & ATTR_DIRECTORY && DirEntry[k].Extension[0] != ' ')
                {
                    p = (char*)&DirEntry[k].Name[7];
                    j = 8;
                    do
                    {
                        if (*p-- != ' ')
                            break;
                    } while (--j);

                    s[1 + j++] = '.';
                    strncpy(s + 1 + j, (const char*)DirEntry[k].Extension, 3); // if no LFN then display base name (8 chars)
                }
            }

            if (DirEntry[k].Attributes & ATTR_DIRECTORY) // mark directory with suffix
                strcpy(&s[22], " <DIR>");
        }
        else
        {
            if (i == 0 && nDirEntries == 0) // selected directory is empty
                strcpy(s, "          No files!");
        }

        OsdWrite(i, s, i == iSelectedEntry,0); // display formatted line text
    }
}

void _strncpy(char* pStr1, const char* pStr2, size_t nCount)
{
// customized strncpy() function to fill remaing destination string part with spaces

    while (*pStr2 && nCount)
    {
        *pStr1++ = *pStr2++; // copy strings
        nCount--;
    }

    while (nCount--)
        *pStr1++ = ' '; // fill remaining space with spaces
}

// insert floppy image pointed to to by global <file> into <drive>
void InsertFloppy(adfTYPE *drive)
{
    unsigned char i, j;
    unsigned long tracks;

    // calculate number of tracks in the ADF image file
    tracks = file.size / (512*11);
    if (tracks > MAX_TRACKS)
    {
        SetError(ERROR_FDD,"ADF has too many tracks!",tracks,0);
		printf("UNSUPPORTED ADF SIZE!!! Too many tracks: %lu\r", tracks);
        tracks = MAX_TRACKS;
    }
    drive->tracks = (unsigned char)tracks;

	drive->filesize = file.size;

    // fill index cache
    for (i = 0; i < tracks; i++) // for every track get its start position within image file
    {
        drive->cache[i] = file.cluster; // start of the track within image file
        for (j = 0; j < 11; j++)
            FileNextSector(&file); // advance by track length (11 sectors)
    }

    // copy image file name into drive struct
    if (file.long_name[0]) // file has long name
        _strncpy(drive->name, file.long_name, sizeof(drive->name)); // copy long name
    else
    {
        strncpy(drive->name, file.name, 8); // copy base name
        memset(&drive->name[8], ' ', sizeof(drive->name) - 8); // fill the rest of the name with spaces
    }

    if (DiskInfo[0]) // if selected file has valid disk number info then copy it to its name in drive struct
    {
        drive->name[16] = ' '; // precede disk number info with space character
        strncpy(&drive->name[17], DiskInfo, sizeof(DiskInfo)); // copy disk number info
    }

    // initialize the rest of drive struct
    drive->status = DSK_INSERTED;
    if (!(file.attributes & ATTR_READONLY)) // read-only attribute
        drive->status |= DSK_WRITABLE;

    drive->cluster_offset = drive->cache[0];
    drive->sector_offset = 0;
    drive->track = 0;
    drive->track_prev = -1;

    // some debug info
    if (file.long_name[0])
        printf("Inserting floppy: \"%s\"\r", file.long_name);
    else
        printf("Inserting floppy: \"%.11s\"\r", file.name);

    printf("file attributes: 0x%02X\r", file.attributes);
    printf("file size: %lu (%lu KB)\r", file.size, file.size >> 10);
    printf("drive tracks: %u\r", drive->tracks);
    printf("drive status: 0x%02X\r", drive->status);
	drivesounds_queueevent(DRIVESOUND_INSERT);
}

/*  Error Message */

void ShowError()
{
	int t=ErrorMask>>1;
	errorpage=0;
	while(t)
	{
		t>>=1;
		++errorpage;
	}
    menustate = MENU_ERROR;
	OsdShow(DISABLE_KEYBOARD);
    OsdColor(OSDCOLOR_WARNING);
}


void InfoMessage(char *message)
{
//    OsdWaitVBL();
    if (menustate != MENU_INFO)
    {
//        OsdClear();
 		OsdSetTitle("Message",0);
        OsdShow(0); // do not disable keyboard
		OsdShow(OSDCOLOR_TOPLEVEL);
    }
    OsdWrite(0, "", 0,0);
    OsdWrite(1, message, 0,0);
    OsdWrite(2, "", 0,0);
    OsdWrite(3, "", 0,0);
    OsdWrite(4, "", 0,0);
    OsdWrite(5, "", 0,0);
    OsdWrite(6, "", 0,0);
    OsdWrite(7, "", 0,0);
    menu_timer = GetTimer(1000);
    menustate = MENU_INFO;
}

static int shiftcheck(int in)
{
	return(in>>1);
}

static int mulcheck(int in)
{
	return(in*0x88888888);
}

static int addcheck(int in)
{
	return(in+0xa5a5a5a5);
}

void SanityCheck()
{
	snprintf(s,32,"%x",shiftcheck(0xabcdef01));
	DebugMessage(s);
	snprintf(s,32,"%x",shiftcheck(0x23456789));
	DebugMessage(s);
	snprintf(s,32,"%x",mulcheck(0xabcdef01));
	DebugMessage(s);
	snprintf(s,32,"%x",mulcheck(0x23456789));
	DebugMessage(s);
	snprintf(s,32,"%x",addcheck(0xabcdef01));
	DebugMessage(s);
	snprintf(s,32,"%x",addcheck(0x23456789));
	DebugMessage(s);
	snprintf(s,32,"%x",checksum_pre);
	DebugMessage(s);
}

void DebugMessage(char *message)
{
	strncpy(&debuglines[debugptr*32],message,31);
	debuglines[debugptr*32+31]=0;
	debugptr=(debugptr+1)&7;
}

