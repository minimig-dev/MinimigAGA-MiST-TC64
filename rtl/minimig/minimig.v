// Copyright 2006, 2007 Dennis van Weeren
//
// This file is part of Minimig
//
// Minimig is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// (at your option) any later version.
//
// Minimig is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//
//
// This is the top module for the Minimig rev1.0 board
//
// 19-03-2005 	-started coding
// 10-04-2005	-added cia's 
//				-verified timers a/b and I/O ports
// 11-04-2005	-adapted top to cleaned up address decoder
//				-connected cia's to .clk(~qclk) and .tick(e) for testing
// 13-04-2005	-_foe and _loe are now made with clocks driving FF's
//				-sram_bridge now also gets .clk(clk)
// 18-04-2005	-added second synchronisation latch for mreset
// 19-04-2005	-bootrom is now 2Kbyte large
// 05-05-2005	-made preparations for dma (bus multiplexers between agnus and cpu)
// 15-05-2005	-added denise
// 				-connected vertb (vertical blank intterupt) to int3 input of paula
// 18-05-2005	-removed interlaced top input pin
// 28-06-2005	-done some experimentation to solve logic loop in Agnus
// 17-07-2005	-connected second ram bank to hold kickstart rom
// 				-added ovl (kickstart overlay) and boot (bootrom overlay) signals
//				-wired cia in/out ports more correctly
//				-wired vsync/hsync to cia's
// 18-07-2005	-experimented to get kickstart running
// 20-07-2005	-still experimenting..
// 07-08-2005	-Jahoeee!! kickstart doesn't guru anymore but 'clicks' the floppy drive !
//				-the guru's were caused by spurious writes to ram which is fixed now in the sram controller
//				-unfortunately still no insert workbench screen but that may be caused by the missing blitter
// 04-09-2005	-added blitter finished interrupt
// 11-09-2005	-added 2meg addressing for Agnus
// 13-09-2005	-added 4bit (per color) video output
// 16-10-2005	-added user IO module
// 23-10-2005	-added dmal signal wire
// 08-11-2005	-fixed typo in instantiation of Paula
// 21-11-2005	-added some signals to handle floppy
// 22-11-2005	-adapted to new add-on develop board
//				-added joystick 1 port
// 10-12-2005	-done some experimentation to find floppy bug
// 21-12-2005	-reworked code to use new style gary module
// 27-12-2005	-added dskindx interrupt
// 03-01-2006	-added dmas to avoid interference with copper cycles
// 11-01-2006	-added Amber
// 15-01-2006	-added syscontrol module to handle automatic boot sequence
// 22-01-2006	-removed _csync port from agnus
// 23-01-2006	-added fastblit input
// 24-01-2006	-cia's now count positive _hsync/_vsync transitions
// 14-02-2006	-code clean up
//				-added fastchip input
// 19-02-2006	-improved indx disk interrupt timing
//				-cia timers now connect to sol/sof
// 12-11-2006	-started porting code to Minimig rev1.0 board
// 17-11-2006	-added address decoding for Minimig rev1.0 ram
// 22-11-2006	-added keyboard reset
// 27-11-2006	-code adapted to new synchronous bootrom
// 03-12-2006	-added dimming powerled
// 11-12-2006	-updated code to new ciaa
// 27-12-2006	-updated code to new ciab
// 24-06-2007	-moved cpu/sram/clock and syscontrol to this file to reduce number of source files
//
// TODO: 		-fixs bug and implement things I forgot.....

//JB:
// 2008-07-17
//	- scan doubler with vertical and horizontal interpolation
//	- transparent osd window
//	- selected osd line highlight
//	- osd control by joystick (up and down pressed simultaneously invoke menu) 
//	- memory configuration from osd (512KB chip, 1MB chip, 512KB chip/512KB slow, 1MB chip/512KB slow)
//	- video interpolation filter configuration from osd (vertical and horizontal)
//	- user reset accessible from osd
//	- user reset to bootloader (kickstart reloading)
//	- new bootloader (text messages during kickstart loading)
//	- ECS blittter
//	- PAL/NTSC selection
//	- modified display dma engine (better compatibility)
//	- modified sprite dma engine (better compatibility)
//	- modified copper timing (better compatibility) 
//	- modified floppy interface (better read and write support)
//	- Action Replay III module for debugging (takes 512KB memory bank)
//
// Thanks to:
// Dennis for his great Minimig
// Loriano for impressive enclosure 
// Darrin and Oscar for their ideas, support and help
// Toni for his indispensable help and logic analyzer (and WinUAE :-)
//
// 2008-09-22 	- code clean-up
// 2008-09-23	- added c1 and c3 clock anable signals
//				- adapted sram bridge to use only clk28m clock
// 2008-09-24	- added support for floppy _sel[3:1] signals
// 2008-11-14	- ram interface synchronous with clk28m, 70ns access cycle
// 2009-04-21	- code clean up
//
// Thanks to Loriano, Darrin, Richard, Edwin, Sascha, Peter and others for their help, support, ideas, testing, bug reports and feature requests.
//
// 2009-05-17	- hires OSD
// 2009-05-23	- more cycle exact CPU bus timing during CIA access
// 2009-05-24	- clean-up & renaming
// 2009-05-29	- changed blitter timing to be more cycle exact
// 2009-06-09	- fixed disk index pulses to 5 Hz (300 RPM)
// 2009-06-10	- fixed non-interlaced frames to be long
// 2009-06-11	- fixed serial port divider
// 2009-06-12	- CIA's SDR register returns written value
// 2009-07-01	- enabling of ddfstrt/ddfstop ECS extension bits is configurable
// 2009-08-11	- support for second hardfile
// 2009-08-16	- Action Replay problem fixed (thanks Sascha)
// 2009-12-15 - improved blitter data flow
// 2009-12-16 - improved bitplane dma timing
//        - Denise id is selectable
// 2010-05-30 - htotal changed
// 2010-07-27 - fixed isue with external reset
// 2010-07-28 - added vsync for the MCU
// 2010-08-05 - added cache for the CPU
// 2010-08-15 - added joystick emulation
//
// SB:
// 2010-12-22 - better drive step sound at 31KHz mode
// 2011-03-06 - changed autofire function to handless mode
// 2011-03-08 - added dip and fat agnus DIWSTRT handling (fix RoboCop2)
// 2011-04-02 - added functional ciaa port b (parallel) register to let Unreal game work and some trainer store data
// 2011-04-04 - added pwm controlled power-led at "off" state and active Turbo mode (thanks Herzi for the idea)
// 2011-04-10 - added readable VPOSW and VHPOSW register (fix for RSI slideshow)
// 11-04-2011 - autofire function toggle able via capslock / led status
// 2011-04-24 - fixed CIA TOD read
// 2011-07-21 - changed '#' key scan code, thanks Chris
//
// TobiFlex(TF):
// 2012-02-12  - change sigma/delta module
//
// SB:
// 2012-03-23 - fixed sprite enable signal (coppermaster demo)

module minimig
(
	//m68k pins
	input	[23:1] cpu_address,	// m68k address bus
	output 	[15:0] cpu_data,	// m68k data bus
	output 	[15:0] cpu_data2,	// m68k data bus 2nd word
	input	[15:0] cpudata_in,	// m68k data in
	output	[2:0] _cpu_ipl,		// m68k interrupt request
	input	_cpu_as,			// m68k address strobe
	input	_cpu_uds,			// m68k upper data strobe
	input	_cpu_lds,			// m68k lower data strobe
	input	_cpu_uds2,		// m68k upper data strobe 2nd word
	input	_cpu_lds2,		// m68k lower data strobe 2nd word
	input	cpu_r_w,			// m68k read / write
	output	_cpu_dtack,			// m68k data acknowledge
	output	_cpu_reset,			// m68k reset
  input _cpu_reset_in,    // m68k reset in
  input [31:0] cpu_vbr, // m68k VBR
  output wire ovr,      // NMI address decoding override
	//sram pins
	output	[15:0] ram_data,	//sram data bus
	input	[15:0] ramdata_in,		//sram data bus in
	output	[22:1] ram_address,	//sram address bus
	output	_ram_bhe,			//sram upper byte select
	output	_ram_ble,			//sram lower byte select
	output	_ram_bhe2,		//sram upper byte select 2nd word
	output	_ram_ble2,		//sram lower byte select 2nd word
	output	_ram_we,			//sram write enable
	output	_ram_oe,			//sram output enable
  input [48-1:0] chip48,         // big chipram read
	//system	pins
  input rst_ext,      // reset from ctrl block
  output rst_out,     // minimig reset status
	input	clk,				// 28.37516 MHz clock
  input clk7_en,      // 7MHz clock enable
  input clk7n_en, // 7MHz negedge clock enable
	input c1,			// clock enable signal
	input c3,			// clock enable signal
	input cck,			// colour clock enable
	input [9:0] eclk,			// ECLK enable (1/10th of CLK)
	//rs232 pins
	input	rxd,				//rs232 receive
	output	txd,				//rs232 send
	input	cts,				//rs232 clear to send
	output	rts,				//rs232 request to send
	//I/O
	input	[15:0]_joy1,		//joystick 1 [fire7:fire,up,down,left,right] (default mouse port)
	input	[15:0]_joy2,		//joystick 2 [fire7:fire,up,down,left,right] (default joystick port)
	input	[15:0]_joy3,		//joystick 3 [fire7:fire,up,down,left,right]
	input	[15:0]_joy4,		//joystick 4 [fire7:fire,up,down,left,right]
	input	[15:0] joy_ana,
  input [2:0] mouse0_btn, // mouse buttons
  input [2:0] mouse1_btn, // mouse buttons
  input mouse_idx,       // mouse buttons
  input kbd_reset_n,
  input kbd_mouse_strobe,
  input kms_level,
  input [1:0] kbd_mouse_type,
  input [7:0] kbd_mouse_data,
	input	_15khz,				//scandoubler disable
	input [63:0] rtc,
	output pwr_led,				//power led
	output disk_led,				//fdd led
	input		msdat_i,				//PS2 mouse data
	input		msclk_i,				//PS2 mouse clk
	input		kbddat_i,				//PS2 keyboard data
	input		kbdclk_i,				//PS2 keyboard clk
   output	msdat_o,				//PS2 mouse data
	output	msclk_o,				//PS2 mouse clk
	output	kbddat_o,				//PS2 keyboard data
	output	kbdclk_o,				//PS2 keyboard clk
	//host controller interface (SPI)
	input	[2:0]_scs,			//SPI chip select
	input	direct_sdi,			//SD Card direct in
	input	sdi,				//SPI data input
	inout	sdo,				//SPI data output
	input	sck,				//SPI clock

	input qcs,            //QSPI cs
	input qsck,           //QSPI clock
	input [3:0] qdat,     //QSPI data input
 // // host
 // output wire           host_cs,
 // output wire [ 24-1:0] host_adr,
 // output wire           host_we,
 // output wire [  2-1:0] host_bs,
 // output wire [ 16-1:0] host_wdat,
 // input  wire [ 16-1:0] host_rdat,
 // input  wire           host_ack,
	//video
	output	_hsync,				//horizontal sync
	output	hsyncpol,
	output	_vsync,				//vertical sync
	output	vsyncpol,
	output	_csync,				//composite sync (for _15khz mode)
	output   selcsync,
	output	[7:0] red,			//red
	output	[7:0] green,		//green
	output	[7:0] blue,			//blue
	//audio
	output	left,				//audio bitstream left
	output	right,				//audio bitstream right
	output	[15:0]ldata,			//left DAC data
	output	[15:0]rdata, 			//right DAC data
	output	[15:0]cdda_l,
	output	[15:0]cdda_r,
	//user i/o
  output  [3:0] cpu_config,
  output  [4:0] board_configured,
  output  turbochipram,
  output  turbokick,
  output  [1:0] slow_config,
  output  aga,
  output  init_b,       // vertical sync for MCU (sync OSD update)
  output wire fifo_full,
  // fifo / track display
	output  [7:0]trackdisp,
	output  [13:0]secdisp,
  output  floppy_fwr,
  output  floppy_frd,
  output  hd_fwr,
  output  hd_frd,
  output  hblank_out,
  output  vblank_out,
  output  osd_blank_out,	// Let the toplevel dither module handle drawing the OSD.
  output  osd_pixel_out,
  output  rtg_ena,
  output  rtg_linecompare,
  output reg ntsc = NTSC, //PAL/NTSC video mode selection
  input   ext_int2,	// External interrupt for Akiko
  input   ext_int6,	// External interrupt for AHI audio
  input   ram_64meg,
  output  insert_sound,
  output  eject_sound,
  output  motor_sound,
  output  step_sound,
  output  hdd_sound
);

//--------------------------------------------------------------------------------------

	parameter [0:0] NTSC = 1'b0;	//Agnus type (PAL/NTSC)

//--------------------------------------------------------------------------------------

//local signals for data bus
wire		[15:0] cpu_data_in;		//cpu data bus in
wire		[15:0] cpu_data_in2;	//cpu data bus in 2nd word
wire		[15:0] cpu_data_out;	//cpu data bus out
wire		[15:0] ram_data_in;		//ram data bus in
wire		[15:0] ram_data_out;	//ram data bus out
wire		[15:0] custom_data_in;	//custom chips data bus in
wire		[15:0] custom_data_out;	//custom chips data bus out
wire		[15:0] agnus_data_out;	//agnus data out
wire		[15:0] paula_data_out;	//paula data bus out
wire		[15:0] denise_data_out;	//denise data bus out
wire		[15:0] user_data_out;	//user IO data out
wire		[15:0] gary_data_out;	//data out from memory bus multiplexer
wire		[15:0] gayle_data_out;	//Gayle data out
wire		[15:0] cia_data_out;	//cia A+B data bus out
wire		[15:0] toc_data_out; //Toccata sound card data out
wire		[15:0] rtc_data_out;  //RTC data out
wire		[15:0] ar3_data_out;	//Action Replay data out

//local signals for spi bus
wire		paula_sdo; 				//paula spi data out
wire		user_sdo;				//userio spi data out

//local signals for address bus
wire		[23:1] cpu_address_out;	//cpu address out
wire		[20:1] dma_address_out;	//agnus address out
wire		[23:1] ram_address_out;	//ram address out

//local signals for control bus
wire		ram_rd;					//ram read enable
wire		ram_hwr;				//ram high byte write enable 
wire		ram_lwr;				//ram low byte write enable 
wire		ram_hwr2;				//ram high byte write enable
wire		ram_lwr2;				//ram low byte write enable
wire		cpu_rd; 				//cpu read enable
wire		cpu_hwr;				//cpu high byte write enable
wire		cpu_lwr;				//cpu low byte write enable
wire		cpu_hwr2;				//cpu high byte write enable 2nd word
wire		cpu_lwr2;				//cpu low byte write enable 2nd word

//register address bus
wire		[8:1] reg_address; 		//main register address bus

//rest of local signals
wire		kbdrst;					//keyboard reset
wire		reset;					//global reset
wire		aflock;
wire		cpu_custom;
wire		autoconfig_done;
wire		[7:0] toccata_base_addr; // IO base address for Toccata card
wire		[4:0] autoconfig_shutup; // IO shutup register, when bit 1 board needs to shut up
wire		dbr;					//data bus request, Agnus tells CPU that she is using the bus
wire		dbwe;					//data bus write enable, Agnus tells the RAM it's writing data
wire		dbs;					//data bus slow down, used for slowing down CPU access to chip, slow and custor register address space
wire		xbs;					//cross bridge access (memory and custom registers)
wire		ovl;					//kickstart overlay enable
wire		_led;					//power led
wire		[3:0] sel_chip;			//chip ram select
wire		[2:0] sel_slow;			//slow ram select
wire		sel_kick;				//rom select
wire		sel_kickext;		// extended rom select
wire    sel_kick1mb;     // 1MB upper rom select
wire		sel_cia;				//CIA address space
wire		sel_reg;				//chip register select
wire		sel_cia_a;				//cia A select
wire		sel_cia_b;				//cia B select
wire		sel_rtc;      // RTC select
wire		sel_toccata; // Toccata sound card select
wire		sel_autoconfig;
wire		int2;					//intterrupt 2
wire		int3;					//intterrupt 3 
wire		int6;					//intterrupt 6
wire		int6_toc;			//intterrupt 6
wire		[7:0] osd_ctrl;			//OSD control
wire    kb_lmb;
wire    kb_rmb;
wire    [5:0] kb_joy2;
wire		freeze;					//Action Replay freeze button
wire		_fire0;					//joystick 1 fire signal to cia A
wire		_fire1;					//joystick 2 fire signal to cia A
wire    _fire0_dat;
wire    _fire1_dat;
wire		[3:0] audio_dmal;		//audio dma data transfer request from Paula to Agnus
wire		[3:0] audio_dmas;		//audio dma location pointer restart from Paula to Agnus
wire		disk_dmal;				//disk dma data transfer request from Paula to Agnus
wire		disk_dmas;				//disk dma special request from Paula to Agnus
wire		index;					//disk index interrupt

wire		[15:0] ldata_toc;  // Toccata left audio channel
wire		[15:0] rdata_toc;  // Toccata right audio channel
wire		[15:0] ldata_paula;  // Toccata left audio channel
wire		[15:0] rdata_paula;  // Toccata right audio channel

//local video signals
wire		blank;					//blanking signal
wire		sol;						//start of video line
wire		sof;						//start of video frame
wire     vbl_int;					// vertical blanking interrupt
wire		strhor_denise;			//horizontal strobe for Denise
wire		strhor_paula;			//horizontal strobe for Paula
wire		[7:0]red_i;				//denise red (internal)
wire		[7:0]green_i;			//denise green (internal)
wire		[7:0]blue_i;			//denise blue (internal)
wire		osd_blank;				//osd blanking 
wire		osd_pixel;				//osd pixel(video) data
wire		_hsync_i;				//horizontal sync (internal)
wire		_vsync_i;				//vertical sync (internal)
wire		_csync_i;				//composite sync (internal)
wire		[8:0] htotal;			//video line length (140ns units)
wire    harddis;
wire    varbeamen;

//local floppy signals (CIA<-->Paula)
wire		_step;					//step heads of disk
wire		direc;					//step heads direction
wire		_sel0;					//disk0 select 	
wire		_sel1;					//disk1 select 	
wire		_sel2;					//disk2 select 	
wire		_sel3;					//disk3 select 	
wire		side;					//upper/lower disk head
wire		_motor;					//disk motor control
wire		_track0;				//track zero detect
wire		_change;				//disk has been removed from drive
wire		_ready;					//disk is ready
wire		_wprot;					//disk is write-protected

//--------------------------------------------------------------------------------------

wire	bls;					//blitter slowdown - required for sharing bus cycles between Blitter and CPU

wire cpurst;
wire cpuhlt;

wire	int7;					//int7 interrupt request from Action Replay
wire	[2:0] _iplx;			//interrupt request lines from Paula
wire	sel_cart;				//Action Replay RAM select
//wire	ovr;					//overide chip memmory decoding
wire  [16-1:0] cart_data_out;

wire	usrrst;					//user reset from osd interface
wire	[1:0] lr_filter;		//lowres interpolation filter mode: bit 0 - horizontal, bit 1 - vertical
wire	[1:0] hr_filter;		//hires interpolation filter mode: bit 0 - horizontal, bit 1 - vertical
wire	[1:0] scanline;			//scanline effect configuration
wire  [1:0] dither;   // video output dither
wire	hires;					//hires signal from Denise for interpolation filter enable in Amber
//wire	aron;					//Action Replay is enabled
wire	cpu_speed;				//requests CPU to switch speed mode
wire	turbo;					//CPU is working in turbo mode
reg		[6:0] memory_config;	//memory configuration
reg		[3:0] floppy_config;	//floppy drives configuration (drive number and speed)
reg		[4:0] chipset_config;	//chipset features selection
reg		[2:0] ide_config0;		//HDD & HDC config: bit #0 enables Gayle primary channel, bit #1 enables Master drive, bit #2 enables Slave drive
reg		[2:0] ide_config1;		//HDD & HDC config: bit #0 enables Gayle secondary chnnl, bit #1 enables Master drive, bit #2 enables Slave drive
wire	[1:0] audio_filter_mode;	//audio filter mode
wire	pwr_led_dim_n;			//power LED dim at off-state

//gayle stuff
wire	sel_ide;				//select IDE drive registers
wire	sel_gayle;				//select GAYLE control registers
wire	gayle_irq;				//interrupt request
wire  gayle_nrdy;       // HDD fifo is not ready for reading
//emulated hard disk drive signals
wire	hdd_cmd_req;			//hard disk controller has written command register and requests processing
wire	hdd_dat_req;			//hard disk controller requests data from emulated hard disk drive
wire	[2:0] hdd_addr;			//emulated hard disk drive register address bus
wire	[15:0] hdd_data_out;	//data output port of emulated hard disk drive
wire	[15:0] hdd_data_in;		//data input port of emulated hard disk drive
wire	hdd_wr;					//register write strobe
wire	hdd_status_wr;			//status register write strobe
wire	hdd_data_wr;			//data port write strobe
wire	hdd_data_rd;			//data port read strobe
wire	hdd_cdda_req;
wire	hdd_cdda_wr;

wire	[7:0] bank;				//memory bank select

wire	keyboard_disabled;		//disables Amiga keyboard while OSD is active
//wire	disk_led;				//floppy disk activity LED

wire  [5:0] mou_emu;

wire  dtr;

// host interface
wire           host_cs;
wire [ 24-1:0] host_adr;
wire           host_we;
wire [  2-1:0] host_bs;
wire [ 16-1:0] host_wdat;
wire [ 16-1:0] host_rdat;
wire           host_ack;

wire           sys_reset;    //reset output from minimig_syscontrol.v

assign reset = sys_reset | ~_cpu_reset_in; // both tg68k and minimig_syscontrol hold the reset signal for some clicks

assign vblank_out = vbl_int;

//--------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------

// power led control
//reg [3:0] led_cnt;
//reg led_dim;

//always @ (posedge clk) begin
//  if (_hsync) begin
//    led_cnt <= led_cnt + 1;
//    led_dim <= |led_cnt;
//  end
//end

//assign pwrled = (_led & (led_dim | ~turbo)) ? 1'b0 : 1'b1; // led dim at off-state and active turbo mode
//assign pwr_led = (_led & led_dim) ? 1'b0 : 1'b1; // led dim at off-state and active turbo mode
assign pwr_led = pwr_led_dim_n ? !_led : ((_led & !hblank_out) ? 1'b0 : 1'b1); // selectable led dim at off-state

//assign memcfg = memory_config[5:0];

// turbo chipram only when no overlay is active, cpu_config[2] (fast chip) is enabled and Agnus allows CPU on the bus and chipRAM=2MB
assign turbochipram = !ovl && cpu_config[2] && (&memory_config[1:0]);

// turbo kickstart only when no overlay is active and cpu_config[3] (fast kick) enabled
assign turbokick = !ovl && cpu_config[3];

assign aga = chipset_config[4];

assign slow_config = memory_config[3:2];

// NTSC/PAL switching is controlled by OSD menu, change requires reset to take effect
always @(posedge clk)
  if (clk7_en) begin
  	if (reset)
  		ntsc <= chipset_config[1];
  end

// vertical sync for the MCU
reg vsync_del = 1'b0;   // delayed vsync signal for edge detection
reg vsync_t = 1'b0;   // toggled vsync output

always @(posedge clk)
  if (clk7_en) begin
    vsync_del <= _vsync_i;
  end
  
always @(posedge clk)
  if (clk7_en) begin
    if (~_vsync_i && vsync_del)
      vsync_t <= ~vsync_t;
  end

assign init_b = vsync_t;


//--------------------------------------------------------------------------------------

//instantiate agnus
agnus AGNUS1
(
	.clk(clk),
	.clk7_en(clk7_en),
	.cck(cck),
	.reset(reset),
	.aen(sel_reg),
	.rd(cpu_rd),
	.hwr(cpu_hwr),
	.lwr(cpu_lwr),
	.data_in(custom_data_in),
	.data_out(agnus_data_out),
	.address_in(cpu_address_out[8:1]),
	.address_out(dma_address_out),
	.reg_address_out(reg_address),
  .cpu_custom(cpu_custom),
	.dbr(dbr),
	.dbwe(dbwe),
	._hsync(_hsync_i),
	.hsyncpol(hsyncpol),
	._vsync(_vsync_i),
	.vsyncpol(vsyncpol),
	._csync(_csync_i),
	.blank(blank),
	.sol(sol),
	.sof(sof),
  .vbl_int(vbl_int),
	.strhor_denise(strhor_denise),
	.strhor_paula(strhor_paula),
	.htotal(htotal),
  .harddis(harddis),
  .varbeamen(varbeamen),
	.int3(int3),
	.audio_dmal(audio_dmal),
	.audio_dmas(audio_dmas),
	.disk_dmal(disk_dmal),
	.disk_dmas(disk_dmas),
	.bls(bls),
	.ntsc(ntsc),
  .a1k(chipset_config[2]),
	.ecs(|chipset_config[4:3]),
  .aga(chipset_config[4]),
	.floppy_speed(floppy_config[0]),
	.turbo(turbo),
	.rtg_ena(rtg_ena),
	.rtg_linecompare(rtg_linecompare),
	.hblank_out(hblank_out)
//	.vblank_out(vblank_out)
);

//instantiate paula
paula PAULA1
(
  .clk(clk),
  .clk7_en (clk7_en),
	.cck(cck),
	.reset(reset),
	.reg_address_in(reg_address),
	.data_in(custom_data_in),
	.data_out(paula_data_out),
	.txd(txd),
	.rxd(rxd),
  .ntsc(ntsc),
	.sof(sof),
  .strhor(strhor_paula),
  .vblint(vbl_int),
	.int2(int2|gayle_irq|ext_int2),
	.int3(int3),
	.int6(int6|ext_int6|int6_toc),
	._ipl(_iplx),
	.audio_dmal(audio_dmal),
	.audio_dmas(audio_dmas),
	.disk_dmal(disk_dmal),
	.disk_dmas(disk_dmas),
	._step(_step),
	.direc(direc),
	._sel({_sel3,_sel2,_sel1,_sel0}),
	.side(side),
	._motor(_motor),
	._track0(_track0),
	._change(_change),
	._ready(_ready),
	._wprot(_wprot),
  .index(index),
	.disk_led(disk_led),
	._scs(_scs[0]),
	.sdi(sdi),
	.sdo(paula_sdo),
	.sck(sck),
	.qcs(qcs),
	.qsck(qsck),
	.qdat(qdat),
	.left(left),
	.right(right),
	.ldata(ldata_paula),
	.rdata(rdata_paula),

	.floppy_drives(floppy_config[3:2]),
	//ide stuff
	.direct_scs(~_scs[2]),
	.direct_sdi(direct_sdi),
	.hdd_cmd_req(hdd_cmd_req),
	.hdd_dat_req(hdd_dat_req),
	.hdd_cdda_req(hdd_cdda_req),
	.hdd_addr(hdd_addr),
	.hdd_data_out(hdd_data_out),
	.hdd_data_in(hdd_data_in),
	.hdd_wr(hdd_wr),
	.hdd_status_wr(hdd_status_wr),
	.hdd_data_wr(hdd_data_wr),
	.hdd_data_rd(hdd_data_rd),
	.hdd_cdda_wr(hdd_cdda_wr),
  // fifo / track display
	.trackdisp(trackdisp),
	.secdisp(secdisp),
  .floppy_fwr (floppy_fwr),
  .floppy_frd (floppy_frd),
  .filter(~|audio_filter_mode ? !_led : audio_filter_mode[1]),
  .insert_sound(insert_sound),
  .eject_sound(eject_sound),
  .motor_sound(motor_sound),
  .step_sound(step_sound)
);

wire	[6:0] userio_memory_config;	//memory configuration
wire	[3:0] userio_floppy_config;	//floppy drives configuration (drive number and speed)
wire	[4:0] userio_chipset_config;	//chipset features selection
wire	[2:0] userio_ide_config0;		//HDD & HDC config: bit #0 enables Gayle, bit #1 enables Master drive, bit #2 enables Slave drive
wire	[2:0] userio_ide_config1;		//HDD & HDC config: bit #0 enables Gayle, bit #1 enables Master drive, bit #2 enables Slave drive
wire    [3:0] userio_cpu_config;
reg     [3:0] cpu_config_reg;

assign cpu_config = cpu_config_reg;

always @(posedge clk) begin
	memory_config <= userio_memory_config;
	floppy_config <= userio_floppy_config;
	chipset_config <= userio_chipset_config;
	ide_config0 <= userio_ide_config0;
	ide_config1 <= userio_ide_config1;
	cpu_config_reg <= userio_cpu_config;
end

//instantiate user IO
userio USERIO1 
(	
	.clk(clk),
  .clk7_en(clk7_en),
  .clk7n_en(clk7n_en),
	.reset(reset),
	.c1(c1),
	.c3(c3),
	.sol(sol),
	.sof(sof),
	.varbeamen(varbeamen),
	.rtg_ena(rtg_ena),
	.reg_address_in(reg_address),
	.data_in(custom_data_in),
	.data_out(user_data_out),
	.ps2mdat_i(msdat_i),
	.ps2mclk_i(msclk_i),
	.ps2mdat_o(msdat_o),
	.ps2mclk_o(msclk_o),
	._fire0(_fire0),
	._fire1(_fire1),
	._fire0_dat(_fire0_dat),
	._fire1_dat(_fire1_dat),
	.aflock(aflock),
	._joy1(_joy1),
	._joy2(_joy2 & {10'b1111111111,kb_joy2}),
	.joy_ana(joy_ana),
	.mouse0_btn(mouse0_btn),
	.mouse1_btn(mouse1_btn),
	.mouse_idx(mouse_idx),
	._lmb(kb_lmb),
	._rmb(kb_rmb),
	.mou_emu (mou_emu),
	.kbd_mouse_type(kbd_mouse_type),
	.kbd_mouse_strobe(kbd_mouse_strobe),
	.kms_level(kms_level),
	.kbd_mouse_data(kbd_mouse_data), 
	.osd_ctrl(osd_ctrl),
	.keyboard_disabled(keyboard_disabled),
	._scs(_scs[1]),
	.sdi(sdi),
	.sdo(user_sdo),
	.sck(sck),
	.osd_blank(osd_blank),
	.osd_pixel(osd_pixel),
	.lr_filter(lr_filter),
	.hr_filter(hr_filter),
	.memory_config(userio_memory_config),
	.chipset_config(userio_chipset_config),
	.floppy_config(userio_floppy_config),
	.scanline(scanline),
  .dither(dither),
	.ide_config0(userio_ide_config0),
	.ide_config1(userio_ide_config1),
	.cpu_config(userio_cpu_config),
	.audio_filter_mode(audio_filter_mode),
	.pwr_led_dim_n(pwr_led_dim_n),
	.usrrst(usrrst),
  .cpurst(cpurst),
  .cpuhlt(cpuhlt),
  .fifo_full(fifo_full),
  .host_cs      (host_cs          ),
  .host_adr     (host_adr         ),
  .host_we      (host_we          ),
  .host_bs      (host_bs          ),
  .host_wdat    (host_wdat        ),
  .host_rdat    (host_rdat        ),
  .host_ack     (host_ack         )
);

//assign cpu_speed = (chipset_config[0] & ~int7 & ~freeze & ~ovr);
assign cpu_speed = 1'b0;

/*
// debug module
debug DEBUG1 (
  .clk        (clk),
  .clk7_en    (clk7_en),
  .adr        (reg_address),
  .dat        (custom_data_in)
);
*/

//instantiate Denise
denise DENISE1
(		
  .clk(clk),
  .clk7_en(clk7_en),
  .c1(c1),
  .c3(c3),
  .cck(cck),
	.reset(reset),
	.strhor(strhor_denise),
	.reg_address_in(reg_address),
	.data_in(custom_data_in),
  .chip48(chip48),
	.data_out(denise_data_out),
	.blank(blank),
	.red(red_i),
	.green(green_i),
	.blue(blue_i),
  .a1k(chipset_config[2]),
  .ecs(|chipset_config[4:3]),
  .aga(chipset_config[4]),
	.hires(hires)
);

//instantiate Amber
amber AMBER1
(		
	.clk(clk),
	.dblscan(_15khz && !varbeamen),
  .varbeamen(varbeamen),
	.lr_filter(lr_filter),
	.hr_filter(hr_filter),
	.scanline(scanline),
  .dither(dither),
	.htotal(htotal),
	.hires(hires),
	.osd_blank(osd_blank),
	.osd_pixel(osd_pixel),
	.red_in(red_i),
	.blue_in(blue_i),
	.green_in(green_i),
	._hsync_in(_hsync_i),
	._vsync_in(_vsync_i),
	._csync_in(_csync_i),
	.red_out(red),
	.blue_out(blue),
	.green_out(green),
	._hsync_out(_hsync),
	._vsync_out(_vsync),
	._csync_out(_csync),
	.selcsync(selcsync),
	.osd_blank_out(osd_blank_out),
	.osd_pixel_out(osd_pixel_out)
);

// Amiga keyboard
wire       key_strobe;
wire [7:0] key_data;
wire       keyack;

amiga_keyboard kbd
(
	.clk       ( clk ),
	.clk7_en   ( clk7_en ),
	.clk7n_en  ( clk7n_en ),
	.reset     ( reset ),
	.kbdrst    ( kbdrst ),
	.kbddat_i  ( kbddat_i ),
	.kbdclk_i  ( kbdclk_i ),
	.kbddat_o  ( kbddat_o ),
	.kbdclk_o  ( kbdclk_o ),
	.kbd_mouse_type( kbd_mouse_type ),
	.kbd_mouse_strobe( kbd_mouse_strobe ),
	.kms_level ( kms_level ),
	.kbd_mouse_data( kbd_mouse_data ), 
	.keyboard_disabled( keyboard_disabled ),
	.osd_ctrl  ( osd_ctrl ),
	._lmb      ( kb_lmb ),
	._rmb      ( kb_rmb ),
	._joy2     ( kb_joy2 ),
	.aflock    ( aflock ),
	.freeze    ( freeze ),
	.disk_led  ( disk_led ),
	._f_led    ( _led ),
	.mou_emu   ( mou_emu ),
	.hrtmon_en ( memory_config[6] ),

	.key_strobe( key_strobe ),
	.key_data  ( key_data ),
	.keyack    ( keyack )
);

//instantiate cia A
ciaa CIAA1
(
	.clk(clk),
	.clk7_en(clk7_en),
	.clk7n_en(clk7n_en),
	.aen(sel_cia_a),
	.rd(cpu_rd),
	.wr(cpu_lwr|cpu_hwr),
	.reset(reset),
	.rs(cpu_address_out[11:8]),
	.data_in(cpu_data_out[7:0]),
	.data_out(cia_data_out[7:0]),
	.tick(_vsync_i),
	.eclk(eclk[8]),
	.irq(int2),
	.porta_in({_fire1,_fire0,_ready,_track0,_wprot,_change}),
	.porta_out({_fire1_dat,_fire0_dat,_led,ovl}),
	.portb_in({_joy4[0],_joy4[1],_joy4[2],_joy4[3],_joy3[0],_joy3[1],_joy3[2],_joy3[3]}),
	.key_strobe( key_strobe ),
	.key_data  ( key_data ),
	.keyack    ( keyack )
);

//instantiate cia B
ciab CIAB1 
(
	.clk(clk),
  .clk7_en(clk7_en),
	.aen(sel_cia_b),
	.rd(cpu_rd),
	.wr(cpu_hwr|cpu_lwr),
	.reset(reset),
	.rs(cpu_address_out[11:8]),
	.data_in(cpu_data_out[15:8]),
	.data_out(cia_data_out[15:8]),
	.tick(_hsync_i),
	.eclk(eclk[8]),
	.irq(int6),
	.flag(index),
	.porta_in({1'b0,cts,1'b0,_joy3[4],1'b1,_joy4[4]}),
	.porta_out({dtr,rts}),
	.portb_out({_motor,_sel3,_sel2,_sel1,_sel0,side,direc,_step})
);

//instantiate cpu bridge
minimig_m68k_bridge CPU1 
(
	.clk(clk),
  .clk7_en(clk7_en),
  .clk7n_en(clk7n_en),
  .blk(scanline[1]),
	.c1(c1),
	.c3(c3),
	.cck(cck),
	.eclk(eclk),
	.vpa(sel_cia),
	.dbr(dbr),
	.dbs(dbs),
	.xbs(xbs),
  .nrdy(gayle_nrdy),
	.bls(bls),
	.cpu_speed(cpu_speed & ~int7 & ~ovr & ~usrrst),
  .memory_config(memory_config[3:0]),
	.turbo(turbo),
	._as(_cpu_as),
	._lds(_cpu_lds),
	._uds(_cpu_uds),
	._lds2(_cpu_lds2),
	._uds2(_cpu_uds2),
	.r_w(cpu_r_w),
	._dtack(_cpu_dtack),
	.rd(cpu_rd),
	.hwr(cpu_hwr),
	.lwr(cpu_lwr),
	.hwr2(cpu_hwr2),
	.lwr2(cpu_lwr2),
	.address(cpu_address),
	.address_out(cpu_address_out),
	.cpudatain(cpudata_in),
	.data(cpu_data),
	.data2(cpu_data2),
	.data_out(cpu_data_out),
	.data_in(cpu_data_in),
	.data_in2(cpu_data_in2),
  ._cpu_reset (_cpu_reset),
  .cpu_halt (cpuhlt),
  .host_cs (host_cs),
  .host_adr (host_adr[23:1]),
  .host_we (host_we),
  .host_bs (host_bs),
  .host_wdat (host_wdat),
  .host_rdat (host_rdat),
  .host_ack (host_ack)
);

//instantiate RAM banks mapper
minimig_bankmapper BMAP1
(
	.chip0((~ovr|~cpu_rd|dbr) & sel_chip[0]),
	.chip1(sel_chip[1]),
	.chip2(sel_chip[2]),
	.chip3(sel_chip[3]),	
	.slow0(sel_slow[0]),
	.slow1(sel_slow[1]),
	.slow2(sel_slow[2]),
	.kick(sel_kick),
	.kickext(sel_kickext),
  .kick1mb(sel_kick1mb),
	.cart(sel_cart),
	.drivesounds(sel_drivesounds),
//	.aron(1'b0),
  .ecs(|chipset_config[4:3]),
	.memory_config(memory_config[3:0]),
	.bank(bank)
);

//instantiate sram bridge
minimig_sram_bridge RAM1 
(
	.clk(clk),
	.c1(c1),
	.c3(c3),	
	.bank(bank),
	.address_in(ram_address_out),
	.data_in(ram_data_in),
	.data_out(ram_data_out),
	.rd(ram_rd),
	.hwr(ram_hwr),
	.lwr(ram_lwr),
	.hwr2(ram_hwr2),
	.lwr2(ram_lwr2),
	._bhe(_ram_bhe),
	._ble(_ram_ble),
	._bhe2(_ram_bhe2),
	._ble2(_ram_ble2),
	._we(_ram_we),
	._oe(_ram_oe),
	.address(ram_address),
	.data(ram_data),	
	.ramdata_in(ramdata_in)	
);

cart CART1
(
  .clk            (clk            ),
  .clk7_en        (clk7_en        ),
  .clk7n_en       (clk7n_en       ),
  .cpu_rst        (!_cpu_reset    ),
  .cpu_address    (cpu_address    ),
  .cpu_address_in (cpu_address_out),
  ._cpu_as        (_cpu_as        ),
  .cpu_rd         (cpu_rd         ),
  .cpu_hwr        (cpu_hwr        ),
  .cpu_lwr        (cpu_lwr        ),
  .cpu_vbr        (cpu_vbr        ),
  .reg_address_in (reg_address    ),
  .reg_data_in    (custom_data_in ),
  .dbr            (dbr            ),
  .ovl            (ovl            ),
  .freeze         (freeze         ),
  .cart_data_out  (cart_data_out  ),
  .int7           (int7           ),
  .sel_cart       (sel_cart       ),
  .ovr            (ovr            ),
//  .aron           (aron           ),
  .cpuhlt         (cpuhlt         )
);

//level 7 interrupt for CPU
assign _cpu_ipl = int7 ? 3'b000 : _iplx;	//m68k interrupt request

assign cpu_data_in2 = chip48[47:32];

wire sel_drivesounds;
//instantiate gary
gary GARY1 
(
	.cpu_address_in(cpu_address_out),
	.dma_address_in(dma_address_out),
	.ram_address_out(ram_address_out),
	.cpu_data_out(cpu_data_out),
	.cpu_data_in(gary_data_out),
	.custom_data_out(custom_data_out),
	.custom_data_in(custom_data_in),
	.ram_data_out(ram_data_out),
	.ram_data_in(ram_data_in),
	.cpu_rd(cpu_rd),
	.cpu_hwr(cpu_hwr),
	.cpu_lwr(cpu_lwr),
	.cpu_hwr2(cpu_hwr2),
	.cpu_lwr2(cpu_lwr2),
  .cpu_hlt(cpuhlt),
	.ovl(ovl),
	.dbr(dbr),
	.dbwe(dbwe),
	.dbs(dbs),
	.xbs(xbs),
	.memory_config(memory_config[3:0]),
	.hdc_ena({ide_config1[0], ide_config0[0]}), // Gayle decoding enable	
	.ram_rd(ram_rd),
	.ram_hwr(ram_hwr),
	.ram_lwr(ram_lwr),
	.ram_hwr2(ram_hwr2),
	.ram_lwr2(ram_lwr2),
  .ecs(|chipset_config[4:3]),
  .a1k(chipset_config[2]),
	.sel_chip(sel_chip),
	.sel_slow(sel_slow),
	.sel_kick(sel_kick),
	.sel_kickext(sel_kickext),
	.sel_kick1mb(sel_kick1mb),
	.sel_cia(sel_cia),
	.sel_reg(sel_reg),
	.sel_cia_a(sel_cia_a),
	.sel_cia_b(sel_cia_b),
	.sel_rtc(sel_rtc),
	.sel_toccata(sel_toccata),
	.sel_ide(sel_ide),
	.sel_gayle(sel_gayle),
	.sel_autoconfig(sel_autoconfig),
	.sel_drivesounds(sel_drivesounds),
	// Auto config IO BASE
	.autoconfig_done(autoconfig_done),
	.autoconfig_shutup(autoconfig_shutup),
	.toccata_base_addr(toccata_base_addr)
);

gayle GAYLE1
(
	.clk(clk),
	.clk7_en(clk7_en),
	.reset(reset),
	.address_in(cpu_address_out),
	.data_in(cpu_data_out),
	.data_out(gayle_data_out),
	.rd(cpu_rd),
	.hwr(cpu_hwr),
	.lwr(cpu_lwr),
	.sel_ide(sel_ide),
	.sel_gayle(sel_gayle),
	.irq(gayle_irq),
	.nrdy(gayle_nrdy),
	.hdd0_ena({2{ide_config0[0]}} & ide_config0[2:1]),
	.hdd1_ena({2{ide_config1[0]}} & ide_config1[2:1]),

	.hdd_cmd_req(hdd_cmd_req),
	.hdd_dat_req(hdd_dat_req),
	.hdd_data_in(hdd_data_in),
	.hdd_addr(hdd_addr),
	.hdd_data_out(hdd_data_out),
	.hdd_wr(hdd_wr),
	.hdd_status_wr(hdd_status_wr),
	.hdd_data_wr(hdd_data_wr),
	.hdd_data_rd(hdd_data_rd),
	.hd_fwr(hd_fwr),
	.hd_frd(hd_frd),
	.hdd_step(hdd_sound)
);

reg         cen_44100;
reg  [31:0] cen_44100_cnt;
wire [31:0] cen_44100_cnt_next = cen_44100_cnt + 16'd44100;
always @(posedge clk) begin
	cen_44100 <= 0;
	cen_44100_cnt <= cen_44100_cnt_next;
	if (cen_44100_cnt_next >= (28*1000000)) begin
		cen_44100 <= 1;
		cen_44100_cnt <= cen_44100_cnt_next - (28*1000000);
	end
end

cdda_fifo cdda_fifo (
	.clk_sys       ( clk          ),
	.clk_en        ( clk7_en      ),
	.cen_44100     ( cen_44100    ),
	.reset         ( reset        ),

	.hdd_cdda_req  ( hdd_cdda_req ),
	.hdd_cdda_wr   ( hdd_cdda_wr  ),
	.hdd_data_out  ( hdd_data_out ),

	.cdda_l        ( cdda_l       ),
	.cdda_r        ( cdda_r       )
);

//instantiate system control
minimig_syscontrol CONTROL1 
(	
	.clk(clk),
  .clk7_en (clk7_en),
	.cnt(sof),
	.mrst(kbdrst | usrrst | rst_ext | !kbd_reset_n),// | ~_cpu_reset_in),
	.reset(sys_reset)
);

wire [15:0] autoconfig_data_out;

`ifdef MINIMIG_TOCCATA
minimig_autoconfig#(.TOCCATA_SND(1'b1)) autoconfig
`else
minimig_autoconfig#(.TOCCATA_SND(1'b0)) autoconfig
`endif
(
	.clk(clk),
	.clk7_en(clk7_en),
	.reset(reset),
	.address_in(cpu_address_out),
	.data_in(cpu_data_out),
	.data_out(autoconfig_data_out),
	.rd(cpu_rd),
	.hwr(cpu_hwr),
	.lwr(cpu_lwr),
	.sel(sel_autoconfig),
	.fastram_config(memory_config[5:4]),
	.m68020(cpu_config[1]),
	.ram_64meg(ram_64meg),
	.slowram_config(memory_config[3:2]),
	.board_configured(board_configured),
	.autoconfig_done(autoconfig_done),
	.toccata_base_addr(toccata_base_addr),
	.board_shutup(autoconfig_shutup),
);

//-------------------------------------------------------------------------------------
assign rtc_data_out = (sel_rtc && cpu_rd) ? {12'h000, rtc[{cpu_address_out[5:2], 2'b00} +:4]} : 16'h0000;

`ifdef MINIMIG_TOCCATA

toccata #(
  .CLK_FREQUENCY(28_359_380)
) mytoccata (
  .clk(clk),
  .rst(reset),
  .hsync(_hsync),
  .data_in(cpu_data_out),
  .data_out(toc_data_out),
  .addr(cpu_address_out[15:1]),
  .rd(cpu_rd),
  .hwr(cpu_hwr),
  .lwr(cpu_lwr),
  .sel(sel_toccata),
  .toc_int(int6_toc),
  .out_left(ldata_toc),
  .out_right(rdata_toc)
);

// Mix the Paula and the Toccata data
AudioMix tocAudioMix
(
  .clk(clk),
  .reset_n(!reset),
  .audio_in_l1(ldata_paula),
  .audio_in_l2(ldata_toc),
  .audio_in_r1(rdata_paula),
  .audio_in_r2(rdata_toc),
  .audio_l(ldata),
  .audio_r(rdata)
);

`else
	assign int6_toc = 1'b0;
	assign toc_data_out = 16'h0000;
	assign ldata = ldata_paula;
	assign rdata = rdata_paula;	
`endif

//data multiplexer
assign cpu_data_in[15:0] = gary_data_out[15:0]
						 | cia_data_out[15:0]
						 | gayle_data_out[15:0]
             | cart_data_out[15:0]
             | rtc_data_out
				 | toc_data_out[15:0]
				 | autoconfig_data_out;

assign custom_data_out[15:0] = agnus_data_out[15:0]
							 | paula_data_out[15:0]
							 | denise_data_out[15:0]
							 | user_data_out[15:0];


//--------------------------------------------------------------------------------------

//spi multiplexer
//assign sdo = _scs[1] ? paula_sdo : user_sdo;
assign sdo = paula_sdo | user_sdo;
//assign sdo = (!_scs[0] || !_scs[1]) ? (paula_sdo | user_sdo) : 1'bz;

//--------------------------------------------------------------------------------------

//cpu reset and clock
assign _cpu_reset = ~(cpurst || sys_reset); //~(reset || cpurst);

//--------------------------------------------------------------------------------------

// minimig reset status
assign rst_out = reset;


endmodule

