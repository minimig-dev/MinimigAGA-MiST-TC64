/*
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

// 2009-11-22 - read/write multiple implemented

// 2020-11-14 - AMR: Simplified and combined read / readm + write / writem.  AROS IDE now works.

//#include "AT91SAM7S256.h"
//#include "stdio.h"
//#include "string.h"
#include "errors.h"
#include "hardware.h"
#include "fat.h"
#include "hdd.h"
#include "hdd_internal.h"
#include "mmc.h"
#include "menu.h"
#include "fpga.h"
#include "config.h"
#include "drivesounds.h"

#include <stdio.h>
#include <string.h>

// hardfile structure
hdfTYPE hdf[HDF_COUNT];

char debugmsg[40];
char debugmsg2[40];

#define DIRECTMODE

#undef SERIALDEBUG

#define DEBUG1(x) {if(DebugMode) DebugMessage(x);}
#define DEBUG2(x,y) {if(DebugMode) { sprintf(debugmsg2,x,y); DebugMessage(debugmsg2); }}
#define DEBUG3(x,y,z) {if(DebugMode) { sprintf(debugmsg2,x,y,z); DebugMessage(debugmsg2); }}

static int lastcyl;

static char filename[12];


static void RDBChecksum(unsigned long *p)
{
	unsigned long count=p[1];
	unsigned long c2;
	long result=0;
	DEBUG1("Generating checksum");
	p[2]=0;
	for(c2=0;c2<count;++c2)
		result+=p[c2];
	p[2]=(unsigned long)-result;
}


// If the hardfile doesn't have a RigidDiskBlock,
// we synthesize one.
static void FakeRDB(int unit,int block)
{
	int i;
	DEBUG1("Clearing sector buffer");
	// Start by clearing the sector buffer
	for(i=0;i<512;++i)
		sector_buffer[i]=0;

	// If we're asked for LBA 0 we create an RDSK block, and if LBA 1, a PART block.
	switch(block)
	{
		case 0: // RDB
			{
				struct RigidDiskBlock *rdb=(struct RigidDiskBlock *)sector_buffer;
				DEBUG1("Creating RDB...");
				rdb->rdb_ID = 'R'<<24 | 'D' << 16 | 'S' << 8 | 'K';
				
				rdb->rdb_Summedlongs=0x40;
				rdb->rdb_HostID=0x07;
				rdb->rdb_BlockBytes=0x200;
				rdb->rdb_Flags=0x12; // (Disk ID valid, no LUNs after this one)
				rdb->rdb_BadBlockList=0xffffffff; // We don't provide a bad block list
				rdb->rdb_PartitionList=1;
				rdb->rdb_FileSysHeaderList=0xffffffff;
				rdb->rdb_DriveInit=0xffffffff;
				rdb->rdb_Reserved1[0]=0xffffffff;
				rdb->rdb_Reserved1[1]=0xffffffff;
				rdb->rdb_Reserved1[2]=0xffffffff;
				rdb->rdb_Reserved1[3]=0xffffffff;
				rdb->rdb_Reserved1[4]=0xffffffff;
				rdb->rdb_Reserved1[5]=0xffffffff;
				rdb->rdb_Cylinders=hdf[unit].cylinders;
				rdb->rdb_Sectors=hdf[unit].sectors;
				rdb->rdb_Heads=hdf[unit].heads;
				rdb->rdb_Interleave=1;
				rdb->rdb_Park=rdb->rdb_Cylinders;
				rdb->rdb_WritePreComp=rdb->rdb_Cylinders;
				rdb->rdb_ReducedWrite=rdb->rdb_Cylinders;
				rdb->rdb_StepRate=3;
				rdb->rdb_RDBBlocksLo=0;
				rdb->rdb_RDBBlocksHi=1;
				rdb->rdb_LoCylinder=1;
				rdb->rdb_HiCylinder=rdb->rdb_Cylinders-1;
				rdb->rdb_CylBlocks=rdb->rdb_Heads * rdb->rdb_Sectors;
				rdb->rdb_AutoParkSeconds=0;
				rdb->rdb_HighRDSKBlock=1;
				strcpy(rdb->rdb_DiskVendor,"Do not ");
				strcpy(rdb->rdb_DiskProduct, "repartition!");

				RDBChecksum((unsigned long *)rdb);
			}
			break;
		case 1: // Partition
			{
				struct PartitionBlock *pb=(struct PartitionBlock *)sector_buffer;
				DEBUG1("Creating RDB...");
				pb->pb_ID = 'P'<<24 | 'A' << 16 | 'R' << 8 | 'T';
			
				pb->pb_Summedlongs=0x40;
				pb->pb_HostID=0x07;
				pb->pb_Next=0xffffffff;
				pb->pb_Flags=0x1; // Bootable
				pb->pb_DevFlags=0;
				strcpy(pb->pb_DriveName," DH0");
				pb->pb_DriveName[0]=3;	// BCPL string

				pb->pb_Environment.de_TableSize=0x10;
				pb->pb_Environment.de_SizeBlock=0x80;
				pb->pb_Environment.de_Surfaces=hdf[unit].heads;
				pb->pb_Environment.de_SectorPerBlock=1;
				pb->pb_Environment.de_BlocksPerTrack=hdf[unit].sectors;
				pb->pb_Environment.de_Reserved=2;
				pb->pb_Environment.de_LowCyl=1;
				pb->pb_Environment.de_HighCyl=hdf[unit].cylinders-1;
				pb->pb_Environment.de_NumBuffers=30;
				pb->pb_Environment.de_MaxTransfer=0x1fffe;
				pb->pb_Environment.de_Mask=0x7ffffffe;
				pb->pb_Environment.de_DosType=0x444f5301;

				RDBChecksum((unsigned long *)pb);
			}
			break;
			break;
		default:
			break;
	}
}


void IdentifyDevice(unsigned short *pBuffer, int unit)
{ // builds Identify Device struct
    char *p;
	int i, x;
    unsigned long total_sectors = hdf[unit].cylinders * hdf[unit].heads * hdf[unit].sectors;

	hardfileTYPE *hf;
	if(unit<2)
		hf=&config.hardfile[unit];
	else if(unit<4)
		hf=&config.secondaryhardfile[unit-2];
	else
		return;

    memset(pBuffer, 0, 512);

	switch(hdf[unit].type)
	{
		case HDF_FILE | HDF_SYNTHRDB:
		case HDF_FILE:
			DEBUG1("Identify - Type: HDF_FILE");
			pBuffer[0] = 1 << 6; // hard disk
			pBuffer[1] = hdf[unit].cylinders; // cyl count
			pBuffer[3] = hdf[unit].heads; // head count
			pBuffer[6] = hdf[unit].sectors; // sectors per track
			// FIXME - can get serial no from card itself.
			memcpy((char*)&pBuffer[10], "1234567890ABCDEFGHIJ", 20); // serial number - byte swapped
			memcpy((char*)&pBuffer[23], ".100    ", 8); // firmware version - byte swapped
			p = (char*)&pBuffer[27];
			// FIXME - likewise the model name can be fetched from the card.
			if(hdf[unit].type & HDF_SYNTHRDB)
			{
				memcpy(p, "DON'T                                   ", 40);
				p += 8;
				memcpy(p, "REPARTITION!    ", 16);
			}
			else
			{
				memcpy(p, "YAQUBE                                  ", 40); // model name - byte swapped
				p += 8;
				if (hf->long_name[0])
				{
					for (i = 0; (x = hf->long_name[i]) && i < 16; i++) // copy file name as model name
						p[i] = x;
				}
				else
				{
					memcpy(p, hf->name, 8); // copy file name as model name
				}
			}
		//    SwapBytes((char*)&pBuffer[27], 40); //not for 68000
			break;
		case HDF_CARD:
		case HDF_CARDPART0:
		case HDF_CARDPART1:
		case HDF_CARDPART2:
		case HDF_CARDPART3:
			DEBUG1("Identify - Type: HDF_CARD");
			pBuffer[0] = 1 << 6; // hard disk
			pBuffer[1] = hdf[unit].cylinders; // cyl count
			pBuffer[3] = hdf[unit].heads; // head count
			pBuffer[6] = hdf[unit].sectors; // sectors per track
			// FIXME - can get serial no from card itself.
			memcpy((char*)&pBuffer[10], "TC64MiniMigSD0      ", 20); // serial number - byte swapped
			pBuffer[23]+=hdf[unit].type-HDF_CARD;
			memcpy((char*)&pBuffer[23], ".100    ", 8); // firmware version - byte swapped
			p = (char*)&pBuffer[27];
			// FIXME - likewise the model name can be fetched from the card.
			memcpy(p, "YAQUBE                                  ", 40); // model name - byte swapped
			p += 8;
			if(hdf[unit].type==HDF_CARD)
				memcpy(p, "SD/MMC Card", 11); // copy file name as model name
			else
			{
				memcpy(p, "Card Part 1", 11); // copy file name as model name
				p[10]+=hdf[unit].partition;
			}
			//    SwapBytes((char*)&pBuffer[27], 40); //not for 68000
			break;
	}

    pBuffer[47] = 0x8010; //maximum sectors per block in Read/Write Multiple command
    pBuffer[53] = 1;
    pBuffer[54] = hdf[unit].cylinders;
    pBuffer[55] = hdf[unit].heads;
    pBuffer[56] = hdf[unit].sectors;
    pBuffer[57] = (unsigned short)total_sectors;
    pBuffer[58] = (unsigned short)(total_sectors >> 16);
}

unsigned long chs2lba(int cylinder, int head, int sector, int unit)
{
    return(cylinder * hdf[unit].heads + head) * hdf[unit].sectors + sector - 1;
}

void WriteTaskFile(int error,int sector_count,int sector_number,int cylinder_low,int cylinder_high,int drive_head)
{
    EnableFpga();

    SPI(CMD_IDE_REGS_WR); // write task file registers command
    SPI(0x00);
    SPI(0x00); // dummy
    SPI(0x00);
    SPI(0x00); // dummy
    SPI(0x00);



    SPI(0x00); // dummy

    SPI(0x00);
    SPI(0x00);
    SPI(error); // error
    SPI(0x00);
    SPI(sector_count); // sector count
    SPI(0x00);
    SPI(sector_number); //sector number
    SPI(0x00);
    SPI(cylinder_low); // cylinder low
    SPI(0x00);
    SPI(cylinder_high); // cylinder high
    SPI(0x00);
    SPI(drive_head); // drive/head

    DisableFpga();
}

void WriteStatus(unsigned int status)
{
    EnableFpga();

    SPI(CMD_IDE_STATUS_WR);
    SPI(status);
    SPI(0x00);
    SPI(0x00);
    SPI(0x00);
    SPI(0x00);

    DisableFpga();
}

static unsigned short id[256];
static unsigned char  tfr[8];


// ATA_Recalibrate()
static inline void ATA_Recalibrate(unsigned char* tfr, int unit)
{
  // Recalibrate 0x10-0x1F (class 3 command: no data)
	DEBUG1("Recalibrate");
	WriteTaskFile(0, 0, 1, 0, 0, tfr[6] & 0xF0);
	WriteStatus(IDE_STATUS_END | IDE_STATUS_IRQ);
}


// ATA_Diagnostic()
static inline void ATA_Diagnostic(unsigned char* tfr)
{
	// Execute Drive Diagnostic (0x90)
	DEBUG1("IDE: Drive Diagnostic");
	WriteTaskFile(1, 0, 0, 0, 0, 0);
	WriteStatus(IDE_STATUS_END | IDE_STATUS_IRQ);
}


// ATA_IdentifyDevice()
void ATA_IdentifyDevice(unsigned char* tfr, int unit, unsigned short* id)
{
  int i;
  // Identify Device (0xec)
  DEBUG2("IDE%d: Identify Device", unit);
  IdentifyDevice(id, unit);
  WriteTaskFile(0, tfr[2], tfr[3], tfr[4], tfr[5], tfr[6]);
  WriteStatus(IDE_STATUS_RDY); // pio in (class 1) command type
  EnableFpga();
  SPI(CMD_IDE_DATA_WR); // write data command
  SPI(0x00);
  SPI(0x00);
  SPI(0x00);
  SPI(0x00);
  SPI(0x00);
  for (i = 0; i < 256; i++) {
    SPI((unsigned char)id[i]);
    SPI((unsigned char)(id[i] >> 8));
  }
  DisableFpga();
  WriteStatus(IDE_STATUS_END | IDE_STATUS_IRQ);
}


// ATA_Initialize()
void ATA_Initialize(unsigned char* tfr, int unit)
{
	// Initialize Device Parameters (0x91)
	printf("Initialize Device Parameters\r");
	WriteTaskFile(0, tfr[2], tfr[3], tfr[4], tfr[5], tfr[6]);
	WriteStatus(IDE_STATUS_END | IDE_STATUS_IRQ);
}


// ATA_SetMultipleMode()
void ATA_SetMultipleMode(unsigned char* tfr, int unit)
{
    hdf[unit].sectors_per_block = tfr[2];
    printf("Set Multiple Mode %d\r",tfr[2]);
    WriteStatus(IDE_STATUS_END | IDE_STATUS_IRQ);
}


// ATA_ReadSectors()
void ATA_ReadSectors(unsigned char* tfr, int sector, int cylinder, int head, int unit, int sector_count, int multiple)
{
	long lba;
	int i;
	int block_count;
	int blk;

	lba=chs2lba(cylinder, head, sector, unit);
	DEBUG3(multiple ? "ReadM %ld, %d" : "Read  %ld, %d",lba,sector_count);

	while (sector_count)
	{
		block_count = multiple ? sector_count : 1;
		if (multiple && block_count > hdf[unit].sectors_per_block)
			block_count = hdf[unit].sectors_per_block;

		WriteStatus(IDE_STATUS_RDY); // pio in (class 1) command type
		while (!(GetFPGAStatus() & CMD_IDECMD)); // wait for empty sector buffer

		/* Advance CHS values */
		blk=block_count;
		while(--blk)
		{
			if (sector == hdf[unit].sectors)
			{
				sector = 1;
				head++;
				if (head == hdf[unit].heads)
				{
					head = 0;
					cylinder++;
				}
			}
			else
				sector++;
		}

	    /* Update task file with CHS address */
	    WriteTaskFile(0, tfr[2], sector, cylinder, (cylinder >> 8), (tfr[6] & 0xF0) | head);

	    WriteStatus(IDE_STATUS_IRQ);

		switch(hdf[unit].type)
		{
			case HDF_FILE | HDF_SYNTHRDB:
			case HDF_FILE:
				if (hdf[unit].file.size)
				{
					blk=block_count;
					// Deal with FakeRDB and the potential for a read_multiple to cross the boundary into actual data.
					while(blk && ((lba+hdf[unit].offset)<0) || (unit==0 && hdf[unit].type==HDF_FILE && lba==0))
					{
						if(hdf[unit].type==HDF_FILE)
						{
							HardFileSeek(&hdf[unit], lba + hdf[unit].offset); // Patch flags and checksum of RDB.  Actually necessary?
							FileReadEx(&hdf[unit].file, sector_buffer, 1);
							struct RigidDiskBlock *rdb = (struct RigidDiskBlock *)sector_buffer;
							rdb->rdb_ChkSum = rdb->rdb_ChkSum + rdb->rdb_Flags - 0x12;
							rdb->rdb_Flags=0x12;
						}
						else
							FakeRDB(unit,lba);
						EnableFpga();
						SPI(CMD_IDE_DATA_WR); // write data command
						SPI(0x00); SPI(0x00); SPI(0x00); SPI(0x00); SPI(0x00);
						for (i = 0; i < 512; i++)
						{
							SPI(sector_buffer[i]);
						}
						DisableFpga();
						++lba;
						--blk;
					}
					if(blk) // Any blocks left?
					{
						int j;
#ifdef DIRECTMODE
						HardFileSeek(&hdf[unit], lba + hdf[unit].offset);
						FileReadEx(&hdf[unit].file, 0, blk); // NULL enables direct transfer to the FPGA
						lba+=blk;
#else
						while(blk)
						{
							HardFileSeek(&hdf[unit], lba + hdf[unit].offset);
							FileReadEx(&hdf[unit].file, sector_buffer, 1);
							EnableFpga();
							SPI(CMD_IDE_DATA_WR); // write data command
							SPI(0x00); SPI(0x00); SPI(0x00); SPI(0x00); SPI(0x00);
							for (i = 0; i < 512; i++)
							{
								SPI(sector_buffer[i]);
							}
							DisableFpga();
							++lba;
							--blk;
						}
#endif
					}
				}
				else
			        WriteStatus(IDE_STATUS_END|IDE_STATUS_RDY|IDE_STATUS_ERR);
				break;

			case HDF_CARD:
			case HDF_CARDPART0:
			case HDF_CARDPART1:
			case HDF_CARDPART2:
			case HDF_CARDPART3:
#ifdef DIRECTMODE
				MMC_ReadMultiple(lba+hdf[unit].offset,0,block_count);
				lba+=block_count;
#else
				blk=block_count;
				while(blk)
				{
					MMC_Read(lba+hdf[unit].offset,sector_buffer);
					EnableFpga();
					SPI(CMD_IDE_DATA_WR); // write data command
					SPI(0x00); SPI(0x00); SPI(0x00); SPI(0x00); SPI(0x00);
					for (i = 0; i < 512; i++)
					{
						SPI(sector_buffer[i]);
					}
					DisableFpga();
					++lba;
					--blk;
				}
#endif;
				break;
		}

		sector_count-=block_count;

	}
	if(cylinder!=lastcyl)
		drivesounds_queueevent(DRIVESOUND_HDDSTEP);
	lastcyl=cylinder;
	if(multiple)
	    WriteStatus(IDE_STATUS_END);
}


// ATA_WriteSectors()
void ATA_WriteSectors(unsigned char* tfr, int sector, int cylinder, int head, int unit, int sector_count, int multiple)
{
	long lba;
	int block_count;
	int i;
	int blk;

	lba=chs2lba(cylinder, head, sector, unit);
	DEBUG3(multiple ? "WriteM %ld, %d" : "Write  %ld, %d",lba,sector_count);
	lba+=hdf[unit].offset;

	/* Advance CHS values */
	blk=sector_count;
	while(--blk)
	{
		if (sector == hdf[unit].sectors)
		{
			sector = 1;
			head++;
			if (head == hdf[unit].heads)
			{
				head = 0;
				cylinder++;
			}
		}
		else
			sector++;
	}

	/* Update task file with CHS address */
	WriteTaskFile(0, tfr[2], sector, cylinder, (cylinder >> 8), (tfr[6] & 0xF0) | head);

	WriteStatus(IDE_STATUS_REQ); // pio out (class 2) command type

	if(lba<0)
		SetError(ERROR_HDD,"Write to auto-generated RDB!",lba,0);

	if (hdf[unit].file.size)	// File size will be 0 in direct card modes
		HardFileSeek(&hdf[unit], (lba>-1) ? lba : 0);

	while (sector_count)
	{
		block_count = multiple ? sector_count : 1;
		if (multiple && block_count > hdf[unit].sectors_per_block)
		block_count = hdf[unit].sectors_per_block;

		while(block_count--)
		{
			while (!(GetFPGAStatus() & CMD_IDEDAT)); // wait for full write buffer
			EnableFpga();
			SPI(CMD_IDE_DATA_RD); // read data command
			SPI(0x00); SPI(0x00); SPI(0x00); SPI(0x00); SPI(0x00);
			for (i = 0; i < 512; i++)
			sector_buffer[i] = SPI(0xFF);
			DisableFpga();

			switch(hdf[unit].type)
			{
				case HDF_FILE | HDF_SYNTHRDB:
				case HDF_FILE:
					if (hdf[unit].file.size && (lba>-1))	// Don't attempt to write to fake RDB
					{
						FileWrite(&hdf[unit].file, sector_buffer);
						FileSeek(&hdf[unit].file, 1, SEEK_CUR);
					}
					++lba;
					break;
				case HDF_CARD:
				case HDF_CARDPART0:
				case HDF_CARDPART1:
				case HDF_CARDPART2:
				case HDF_CARDPART3:
					DEBUG1("Write HDF_Card");
					MMC_Write(lba,sector_buffer);
					++lba;
					break;
			}
			--sector_count;
		}

		if (sector_count)
			WriteStatus(IDE_STATUS_IRQ);
		else
			WriteStatus(IDE_STATUS_END | IDE_STATUS_IRQ);
	}
	if(cylinder!=lastcyl)
	drivesounds_queueevent(DRIVESOUND_HDDSTEP);
	lastcyl=cylinder;
}


void trap()
{
	putchar('t');
}

void trap2()
{
	putchar('T');
}

void HandleHDD(unsigned int c1, unsigned int c2)
{
	int i;
	int sector;
	int cylinder;
	int head;
    int unit;
	int sector_count;
	int block_count;

    if (c1 & CMD_IDECMD)
    {
        DISKLED_ON;
        EnableFpga();
        SPI(CMD_IDE_REGS_RD); // read task file registers
        SPI(0x00);
        SPI(0x00);
        SPI(0x00);
        SPI(0x00);
        SPI(0x00);
        for (i = 0; i < 8; i++)
        {
			int t=SPI(0);
            tfr[i] = SPI(0);
			if(i==6)
				unit=((tfr[i]>>4)&1)|((t&1)<<1);
        }
        DisableFpga();

//        unit = ((tfr[6]<<1)&2)|((tfr[6]>>4)&1); // master/slave selection

		if (hdf[unit].type==HDF_DISABLED) {
		  WriteStatus(IDE_STATUS_END | IDE_STATUS_IRQ | IDE_STATUS_ERR);
          DISKLED_OFF;
		  return;
		}
		sector = tfr[3];
		cylinder = tfr[4] | (tfr[5] << 8);
		head = tfr[6] & 0x0F;
		sector_count = tfr[2];
		if (sector_count == 0) sector_count = 0x100;

//		if (cylinder==444 && head==2 && sector==51)
//			trap();

#ifdef SERIALDEBUG
    printf("IDE:");
    for (i = 1; i<=7; i++)
        printf("%02X.",tfr[i]);
    printf(", C: %d, H: %d, S: %d, count: %d\r", cylinder,head,sector,sector_count);
#endif
		if ((tfr[7] & 0xF0) == ACMD_RECALIBRATE) {
		  ATA_Recalibrate(tfr,  unit);
		} else if (tfr[7] == ACMD_DIAGNOSTIC) {
		  ATA_Diagnostic(tfr);
		} else if (tfr[7] == ACMD_IDENTIFY_DEVICE) {
		  ATA_IdentifyDevice(tfr, unit, id);
		} else if (tfr[7] == ACMD_INITIALIZE_DEVICE_PARAMETERS) {
		  ATA_Initialize(tfr, unit);
		} else if (tfr[7] == ACMD_SET_MULTIPLE_MODE) {
		  ATA_SetMultipleMode(tfr, unit);
		} else if (tfr[7] == ACMD_READ_SECTORS) {
		  ATA_ReadSectors(tfr, sector, cylinder, head, unit, sector_count,0);
		} else if (tfr[7] == ACMD_READ_MULTIPLE) {
		  ATA_ReadSectors(tfr, sector, cylinder, head, unit, sector_count,1);
		} else if (tfr[7] == ACMD_WRITE_SECTORS) {
		  ATA_WriteSectors(tfr, sector, cylinder, head, unit, sector_count,0);
		} else if (tfr[7] == ACMD_WRITE_MULTIPLE) {
		  ATA_WriteSectors(tfr, sector, cylinder, head, unit, sector_count,1);
		} else {
            printf("Unknown ATA command\r");

            printf("IDE:");
            for (i = 1; i < 7; i++)
                printf("%02X.", tfr[i]);
            printf("%02X\r", tfr[7]);
            WriteTaskFile(0x04, tfr[2], tfr[3], tfr[4], tfr[5], tfr[6]);
            WriteStatus(IDE_STATUS_END | IDE_STATUS_IRQ | IDE_STATUS_ERR);
        }
        DISKLED_OFF;
		if(cylinder==444 && head==2 && sector==61)
			trap2();
    }
}

void GetHardfileGeometry(hdfTYPE *pHDF)
{ // this function comes from WinUAE, should return the same CHS as WinUAE

    unsigned long total=0;
    unsigned long i, head, cyl, spt;
    long sptt[] = { 63, 127, 255, -1 };
	unsigned long cyllimit=65535;

	switch(pHDF->type)
	{
		case (HDF_FILE | HDF_SYNTHRDB):
		    if (pHDF->file.size == 0)
    		    return;
			// For WinUAE generated hardfiles we have a fixed sectorspertrack of 32, number of heads and cylinders are variable.
			// Make a first guess based on 1 head, then refine that guess until the geometry gives a plausible number of
			// cylinders and also has the correct number of blocks.
		    total = pHDF->file.size / 512;
			pHDF->sectors = 32;
			head=1;
			cyl = total/32;
			cyllimit-=1;
			while(head<16 && (cyl>cyllimit || (head*cyl*32)!=total))
			{
				++head;
				cyl=total/(32*head);
			}
			pHDF->heads = head;
			pHDF->cylinders = cyl+1;	// Add a cylinder for the fake RDB.
		
			if ((head*cyl*32)==total)	// Does the geometry match the size of the underlying hard file?
				return;
			// If not, fall back to regular hardfile geometry aproximations...
			break;
		case HDF_FILE:
		    if (pHDF->file.size == 0)
    		    return;
		    total = pHDF->file.size / 512;
			break;
		case HDF_CARD:
		    total = MMC_GetCapacity();	// GetCapacity returns number of blocks, not bytes.
			break;
		case HDF_CARDPART0:
		case HDF_CARDPART1:
		case HDF_CARDPART2:
		case HDF_CARDPART3:
		    total = partitions[pHDF->partition].sectors;
			break;
		default:
			break;
	}

    for (i = 0; sptt[i] >= 0; i++)
    {
        spt = sptt[i];
        for (head = 4; head <= 16; head++)
        {
            cyl = total / (head * spt);
            if (total <= 1024 * 1024)
            {
                if (cyl <= 1023)
                    break;
            }
            else
            {
                if (cyl < 16383)
                    break;
                if (cyl < 32767 && head >= 5)
                    break;
                if (cyl <= cyllimit)
                    break;
            }
        }
        if (head <= 16)
            break;
    }
	if(pHDF->type == (HDF_FILE | HDF_SYNTHRDB))
		++cyl;	// Add an extra cylinder for the fake RDB
    pHDF->cylinders = (unsigned short)cyl;
    pHDF->heads = (unsigned short)head;
    pHDF->sectors = (unsigned short)spt;
	printf("Total sectors: %d, cyl: %d, heads: %d, sectors: %d\n",total, cyl, head,spt);
}

void BuildHardfileIndex(hdfTYPE *pHDF)
{
    // builds index to speed up hard file seek

    fileTYPE *file = &pHDF->file;
    unsigned long *index = pHDF->index;
    unsigned long i;
    unsigned long j;

    pHDF->index_size = 16; // indexing size
    j = 1 << pHDF->index_size;
    i = pHDF->file.size >> 10; // divided by index table size (1024)
    while (j < i) // find greater or equal power of two
    {
        j <<= 1;
        pHDF->index_size++;
    }

    for (i = 0; i < file->size; i += j)
    {
        FileSeek(file, i >> 9, SEEK_SET); // FileSeek seeks in 512-byte sectors
        *index++ = file->cluster;
    }
}

unsigned char HardFileSeek(hdfTYPE *pHDF, unsigned long lba)
{
    if ((pHDF->file.sector ^ lba) & cluster_mask)
    { // different clusters
        if ((pHDF->file.sector > lba) || ((pHDF->file.sector ^ lba) & (cluster_mask << (fat32 ? 7 : 8)))) // 7: 128 FAT32 links per sector, 8: 256 FAT16 links per sector
        { // requested cluster lies before current pointer position or in different FAT sector
            pHDF->file.cluster = pHDF->index[lba >> (pHDF->index_size - 9)];// minus 9 because lba is in 512-byte sectors
            pHDF->file.sector = lba & (-1 << (pHDF->index_size - 9));
        }
    }
    return FileSeek(&pHDF->file, lba, SEEK_SET);
}

unsigned char OpenHardfile(unsigned int unit)
{
    unsigned long time;
	hardfileTYPE *hf;
	if(unit<2)
		hf=&config.hardfile[unit];
	else if(unit<4)
		hf=&config.secondaryhardfile[unit-2];
	else
		return(0);

	switch(hf->enabled)
	{
		case HDF_FILE | HDF_SYNTHRDB:
		case HDF_FILE:
			hdf[unit].type=hf->enabled;
			strncpy(filename, hf->name, 8);
			strcpy(&filename[8], "HDF");

			if (filename[0])
			{
				if(ValidateDirectory(config.hdfdir[unit]))
				{
					ChangeDirectory(config.hdfdir[unit]);
					if (FileOpen(&hdf[unit].file, filename))
					{
						GetHardfileGeometry(&hdf[unit]);

						printf("HARDFILE %d:\r", unit);
						printf("file: \"%.8s.%.3s\"\r", hdf[unit].file.name, &hdf[unit].file.name[8]);
						printf("size: %lu (%lu MB)\r", hdf[unit].file.size, hdf[unit].file.size >> 20);
						printf("CHS: %u.%u.%u", hdf[unit].cylinders, hdf[unit].heads, hdf[unit].sectors);
						printf(" (%lu MB)\r", ((((unsigned long) hdf[unit].cylinders) * hdf[unit].heads * hdf[unit].sectors) >> 11));

						time = GetTimer(0);
						BuildHardfileIndex(&hdf[unit]);
						time = GetTimer(0) - time;
						printf("Hardfile indexed in %lu ms\r", time >> 16);

						if(hf->enabled & HDF_SYNTHRDB)
							hdf[unit].offset=-(hdf[unit].heads*hdf[unit].sectors);
						else
							hdf[unit].offset=0;		

						hf->present = 1;
						return 1;
					}
				}
				else
				{
					hf->present = 0;
					SetError(ERROR_HDD,"Bad hardfile directory",config.hdfdir[unit],0);
				}
			}
			break;
		case HDF_CARD:
			hdf[unit].type=HDF_CARD;
		    hf->present = 1;
			hdf[unit].file.size=0;
			hdf[unit].offset=0;
		    GetHardfileGeometry(&hdf[unit]);
			return 1;
			break;
		case HDF_CARDPART0:
		case HDF_CARDPART1:
		case HDF_CARDPART2:
		case HDF_CARDPART3:
			hdf[unit].type=hf->enabled;
			hdf[unit].partition=hdf[unit].type-HDF_CARDPART0;
		    hf->present = 1;
			hdf[unit].file.size=0;
			hdf[unit].offset=partitions[hdf[unit].partition].startlba;
		    GetHardfileGeometry(&hdf[unit]);
			return 1;
			break;
	}
    hf->present = 0;
    return 0;
}


fileTYPE rdbfile;	// We scan for RDB without mounting the file as a unit, so need a file struct specifically for this task.

unsigned char GetHDFFileType(char *filename)
{
	if(FileOpen(&rdbfile,filename))
	{
		int i;
		DEBUG1("Hunting for RDB...");
		for(i=0;i<16;++i)
		{
			FileRead(&rdbfile,sector_buffer);
			FileSeek(&rdbfile,512,SEEK_CUR);
			if(sector_buffer[0]=='R' && sector_buffer[1]=='D' && sector_buffer[2]=='S' && sector_buffer[3]=='K')
				return(HDF_FILETYPE_RDB);
			if(sector_buffer[0]=='D' && sector_buffer[1]=='O' && sector_buffer[2]=='S')
				return(HDF_FILETYPE_DOS);
			if(sector_buffer[0]=='P' && sector_buffer[1]=='F' && sector_buffer[2]=='S')
				return(HDF_FILETYPE_DOS);
			if(sector_buffer[0]=='S' && sector_buffer[1]=='F' && sector_buffer[2]=='S')
				return(HDF_FILETYPE_DOS);
		}
		return(HDF_FILETYPE_UNKNOWN);
	}
	return(HDF_FILETYPE_NOTFOUND);
}


