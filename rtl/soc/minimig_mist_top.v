/********************************************/
/* minimig_mist_top.v                       */
/* MiST Board Top File                      */
/*                                          */
/* 2012-2015, rok.krajnc@gmail.com          */
/********************************************/


// board type define
`define MINIMIG_MIST

// simulation define
//`define SOC_SIM

`include "minimig_defines.vh"


module minimig_mist_top (
  // clock inputs
  input  wire [  2-1:0] CLOCK_32,   // 32 MHz
  input  wire [  2-1:0] CLOCK_27,   // 27 MHz
  input  wire [  2-1:0] CLOCK_50,   // 50 MHz
  // LED outputs
  output wire           LED,        // LED Yellow
  // UART
  output wire           UART_TX,    // UART Transmitter
  input wire            UART_RX,    // UART Receiver
  // VGA
  output reg            VGA_HS,     // VGA H_SYNC
  output reg            VGA_VS,     // VGA V_SYNC
  output reg  [  6-1:0] VGA_R,      // VGA Red[5:0]
  output reg  [  6-1:0] VGA_G,      // VGA Green[5:0]
  output reg  [  6-1:0] VGA_B,      // VGA Blue[5:0]
  // SDRAM
  inout  wire [ 16-1:0] SDRAM_DQ,   // SDRAM Data bus 16 Bits
  output wire [ 13-1:0] SDRAM_A,    // SDRAM Address bus 13 Bits
  output wire           SDRAM_DQML, // SDRAM Low-byte Data Mask
  output wire           SDRAM_DQMH, // SDRAM High-byte Data Mask
  output wire           SDRAM_nWE,  // SDRAM Write Enable
  output wire           SDRAM_nCAS, // SDRAM Column Address Strobe
  output wire           SDRAM_nRAS, // SDRAM Row Address Strobe
  output wire           SDRAM_nCS,  // SDRAM Chip Select
  output wire [  2-1:0] SDRAM_BA,   // SDRAM Bank Address
  output wire           SDRAM_CLK,  // SDRAM Clock
  output wire           SDRAM_CKE,  // SDRAM Clock Enable
  // MINIMIG specific
  output wire           AUDIO_L,    // sigma-delta DAC output left
  output wire           AUDIO_R,    // sigma-delta DAC output right
  // SPI
  inout wire            SPI_DO,     // inout
  input wire            SPI_DI,
  input wire            SPI_SCK,
  input wire            SPI_SS2,    // fpga
  input wire            SPI_SS3,    // OSD
  input wire            SPI_SS4,    // "sniff" mode
  input wire            CONF_DATA0  // SPI_SS for user_io
);


////////////////////////////////////////
// internal signals                   //
////////////////////////////////////////

// clock
wire           pll_in_clk;
wire           clk_114;
wire           clk_28;
wire           clk_sdram;
wire           clk_vid;
wire           pll_locked;
wire           clk7_en;
wire           clk7n_en;
wire           c1;
wire           c3;
wire           cck;
wire [ 10-1:0] eclk;

// reset
wire           pll_rst;
wire           sdctl_rst;
wire           rst_50;
wire           rst_minimig;

// ctrl
wire           rom_status;
wire           ram_status;
wire           reg_status;

// tg68
wire           tg68_rst;
wire [ 16-1:0] tg68_dat_in;
wire [ 16-1:0] tg68_dat_in2;
wire [ 16-1:0] tg68_dat_out;
wire [ 16-1:0] tg68_dat_out2;
wire [ 32-1:0] tg68_adr;
wire [  3-1:0] tg68_IPL;
wire           tg68_dtack;
wire           tg68_as;
wire           tg68_uds;
wire           tg68_lds;
wire           tg68_uds2;
wire           tg68_lds2;
wire           tg68_rw;
wire           tg68_ena7RD;
wire           tg68_ena7WR;
wire           tg68_ena28;
wire [ 16-1:0] tg68_cout;
wire [ 16-1:0] tg68_cin;
wire           tg68_cpuena;
wire [  4-1:0] cpu_config;
wire     [4:0] board_configured;
wire           turbochipram;
wire           turbokick;
wire     [1:0] slow_config;
wire           aga;
wire           cache_inhibit;
wire           cacheline_clr;
wire [ 32-1:0] tg68_cad;
wire [  7-1:0] tg68_cpustate;
wire           tg68_nrst_out;
wire           tg68_clds;
wire           tg68_cuds;
wire [  4-1:0] tg68_CACR_out;
wire [ 32-1:0] tg68_VBR_out;
wire           tg68_ovr;

wire tg68_host_req;
wire tg68_host_ack;

// minimig
wire           led;
wire [ 16-1:0] ram_data;      // sram data bus
wire [ 16-1:0] ram_data2;     // sram data bus
wire [ 16-1:0] ramdata_in;    // sram data bus in
wire [ 48-1:0] chip48;        // big chip read
wire [ 23-1:1] ram_address;   // sram address bus
wire           _ram_bhe;      // sram upper byte select
wire           _ram_ble;      // sram lower byte select
wire           _ram_bhe2;     // sram upper byte select 2nd word
wire           _ram_ble2;     // sram lower byte select 2nd word
wire           _ram_we;       // sram write enable
wire           _ram_oe;       // sram output enable
wire           _15khz;        // scandoubler disable
wire           sdo;           // SPI data output

wire           ntsc;
wire           hsyncpol;
wire           vsyncpol;
wire           cs;
wire           vs;
wire           hs;
wire [  8-1:0] red;
wire [  8-1:0] green;
wire [  8-1:0] blue;

reg            vs_reg;
reg            hs_reg;
reg            cs_reg;
reg  [  8-1:0] red_reg;
reg  [  8-1:0] green_reg;
reg  [  8-1:0] blue_reg;

wire           vga_window;
wire           vga_selcsync;
wire           vga_pixel;

// sdram
wire           reset_out;
wire [  4-1:0] sdram_cs;
wire [  2-1:0] sdram_dqm;
wire [  2-1:0] sdram_ba;

// mist
wire           user_io_sdo;
wire           minimig_sdo;
wire [ 16-1:0] joya;
wire [ 16-1:0] joyb;
wire [ 16-1:0] joyc;
wire [ 16-1:0] joyd;
wire [ 16-1:0] joy_ana;
wire [  8-1:0] kbd_mouse_data;
wire           kbd_mouse_strobe;
wire           kms_level;
wire           mouse_idx;
wire [  2-1:0] kbd_mouse_type;
wire [  3-1:0] mouse0_buttons;
wire [  3-1:0] mouse1_buttons;
wire [  4-1:0] core_config;
wire [  8-1:0] core_status;
wire [ 64-1:0] rtc;
wire           ypbpr;
wire           no_csync;
wire           force_csync;
wire     [1:0] clock_override;
wire           clock_ntsc;

////////////////////////////////////////
// toplevel assignments               //
////////////////////////////////////////

// SDRAM
assign SDRAM_CKE        = 1'b1;
assign SDRAM_CLK        = clk_sdram;
assign SDRAM_nCS        = sdram_cs[0];
assign SDRAM_DQML       = sdram_dqm[0];
assign SDRAM_DQMH       = sdram_dqm[1];
assign SDRAM_BA         = sdram_ba;

// clock
assign pll_in_clk       = CLOCK_27[0];

// reset
assign pll_rst          = 1'b0;
assign sdctl_rst        = pll_locked;

// minimig
assign _15khz           = ~core_config[0];

assign LED              = ~led;

assign ypbpr            = core_config[1];
assign no_csync         = core_config[2];
assign force_csync      = ypbpr | (!no_csync & vga_selcsync);
assign clock_override   = core_status[2:1];
assign clock_ntsc       = |clock_override ? clock_override[1] : ntsc;
wire aud_int;

//// amiga clocks ////
amiga_clk amiga_clk (
  .rst          (pll_rst          ), // async reset input
  .ntsc         (clock_ntsc       ), // pal/ntsc clock select
  .clk_in       (pll_in_clk       ), // input clock     ( 27.000000MHz)
  .clk_114      (clk_114          ), // output clock c0 (114.750000MHz)
  .clk_sdram    (clk_sdram        ), // output clock c2 (114.750000MHz, -146.25 deg)
  .clk_28       (clk_28           ), // output clock c1 ( 28.687500MHz)
  .clk7_en      (clk7_en          ), // output clock 7 enable (on 28MHz clock domain)
  .clk7n_en     (clk7n_en         ), // 7MHz negedge output clock enable (on 28MHz clock domain)
  .c1           (c1               ), // clk28m clock domain signal synchronous with clk signal
  .c3           (c3               ), // clk28m clock domain signal synchronous with clk signal delayed by 90 degrees
  .cck          (cck              ), // colour clock output (3.54 MHz)
  .eclk         (eclk             ), // 0.709379 MHz clock enable output (clk domain pulse)
  .locked       (pll_locked       )  // pll locked output
);


//// TG68K main CPU ////

TG68K tg68k (
  .clk          (clk_114          ),
  .reset        (tg68_rst         ),
  .clkena_in    (tg68_ena28       ),
  .IPL          (tg68_IPL         ),
  .dtack        (tg68_dtack       ),
  .vpa          (1'b1             ),
  .ein          (1'b1             ),
  .addr         (tg68_adr         ),
  .data_read    (tg68_dat_in      ),
  .data_read2   (tg68_dat_in2     ),
  .data_write   (tg68_dat_out     ),
  .data_write2  (tg68_dat_out2    ),
  .as           (tg68_as          ),
  .uds          (tg68_uds         ),
  .lds          (tg68_lds         ),
  .uds2         (tg68_uds2        ),
  .lds2         (tg68_lds2        ),
  .rw           (tg68_rw          ),
  .vma          (                 ),
  .wrd          (                 ),
  .ena7RDreg    (tg68_ena7RD      ),
  .ena7WRreg    (tg68_ena7WR      ),
  .fromram      (tg68_cout        ),
  .toram        (tg68_cin         ),
  .ramready     (tg68_cpuena      ),
  .cpu          (cpu_config[1:0]  ),
  .turbochipram (turbochipram     ),
  .turbokick    (turbokick        ),
  .slow_config  (slow_config      ),
  .aga          (aga              ),
  .cache_inhibit(cache_inhibit    ),
  .cacheline_clr(cacheline_clr    ),
  .ziiram_active(board_configured[0]),
  .ziiiram_active(board_configured[1]),
  .ziiiram2_active(board_configured[2]),
  .ziiiram3_active(board_configured[3]),
//  .fastramcfg   ({&memcfg[5:4],memcfg[5:4]}),
  .eth_en       (1'b1), // TODO
  .sel_eth      (),
  .frometh      (16'd0),
  .ethready     (1'b0),
//.ovr          (tg68_ovr         ),
  .ramaddr      (tg68_cad         ),
  .cpustate     (tg68_cpustate    ),
  .nResetOut    (tg68_nrst_out    ),
  .skipFetch    (                 ),
  .ramlds       (tg68_clds        ),
  .ramuds       (tg68_cuds        ),
  .CACR_out     (tg68_CACR_out    ),
  .VBR_out      (tg68_VBR_out     ),
  // RTG signals
  .rtg_addr(rtg_baseaddr),
  .rtg_base(rtg_baseaddr2),
  .rtg_vbend(rtg_vbend),
  .rtg_ext(rtg_ext),
  .rtg_pixelclock(rtg_pixelwidth),
  .rtg_16bit(rtg_16bit),
  .rtg_clut(rtg_clut),
  .rtg_clut_idx(rtg_clut_idx),
  .rtg_clut_r(rtg_clut_r),
  .rtg_clut_g(rtg_clut_g),
  .rtg_clut_b(rtg_clut_b),
  .audio_ena(aud_ena_cpu),
  .audio_buf(aud_addr[15]),
  .audio_int(aud_int),
  .host_req(tg68_host_req),
  .host_ack(tg68_host_ack)
);

assign tg68_host_ack=tg68_host_req; // Prevent lockups on reads to not-yet-implemented Akiko registers.

wire [23:0] host_addr;
wire [15:0] host_data;
wire host_req;
wire host_ack;

sdram_ctrl sdram (
  .sysclk       (clk_114          ),
  .reset_in     (sdctl_rst        ),
  .cache_rst    (tg68_rst         ),
  .cache_inhibit(cache_inhibit    ),
  .cacheline_clr(cacheline_clr    ),
  .cpu_cache_ctrl (tg68_CACR_out    ),
  //SDRAM chip
  .sdata        (SDRAM_DQ         ),
  .sdaddr       (SDRAM_A[12:0]    ),
  .dqm          (sdram_dqm        ),
  .sd_cs        (sdram_cs         ),
  .ba           (sdram_ba         ),
  .sd_we        (SDRAM_nWE        ),
  .sd_ras       (SDRAM_nRAS       ),
  .sd_cas       (SDRAM_nCAS       ),
  // Control CPU (not used in MiST)
  .hostWR       (16'h0000),
  .hostAddr     (host_addr[23:2]),
  .hostce       (host_req),
  .hostwe       (1'b0),
  .hostbytesel  (4'b1111),
  .hostRD       (host_data),
  .hostena      (host_ack),
  // Fast RAM
  .cpuena       (tg68_cpuena      ),
  .cpuRD        (tg68_cout        ),
  .cpuWR        (tg68_cin         ),
  .cpuAddr      (tg68_cad[25:1]   ),
  .cpuU         (tg68_cuds        ),
  .cpuL         (tg68_clds        ),
  .cpustate     (tg68_cpustate    ),
  // Chip RAM
  .chipWR       (ram_data         ),
  .chipWR2      (tg68_dat_out2    ),
  .chipAddr     ({1'b0, ram_address[22:1]}),
  .chipU        (_ram_bhe         ),
  .chipL        (_ram_ble         ),
  .chipU2       (_ram_bhe2        ),
  .chipL2       (_ram_ble2        ),
  .chipRW       (_ram_we          ),
  .chip_dma     (_ram_oe          ),
  .clk7_en      (clk7_en          ),
  .chipRD       (ramdata_in       ),
  .chip48       (chip48           ),
  // RTG
  .rtgAddr      (rtg_addr_mangled ),
  .rtgce        (rtg_ramreq       ),
  .rtgfill      (rtg_fill         ),
  .rtgRd        (rtg_fromram      ), 
  // Audio buffer
  .audAddr      (aud_ramaddr      ),
  .audce        (aud_ramreq       ),
  .audfill      (aud_fill         ),
  .audRd        (aud_fromram      ),
  // Misc signals
  .reset_out    (reset_out        ),
  .hostRD       (                 ),
  .hostena      (                 ),
  .enaWRreg     (tg68_ena28       ),
  .ena7RDreg    (tg68_ena7RD      ),
  .ena7WRreg    (tg68_ena7WR      )
);


// multiplex spi_do, drive it from user_io if that's selected, drive
// it from minimig if it's selected and leave it open else (also
// to be able to monitor sd card data directly)
assign SPI_DO = (CONF_DATA0 == 1'b0)?user_io_sdo:
    (((SPI_SS2 == 1'b0)|| (SPI_SS3 == 1'b0))?minimig_sdo:1'bZ);

//// user io has an extra spi channel outside minimig core ////
user_io user_io(
     .clk_sys(clk_28),
     .SPI_CLK(SPI_SCK),
     .SPI_SS_IO(CONF_DATA0),
     .SPI_MISO(user_io_sdo),
     .SPI_MOSI(SPI_DI),
     .JOY0(joya),
     .JOY1(joyb),
     .JOY2(joyc),
     .JOY3(joyd),
     .JOY_ANA1(joy_ana),
     .RTC(rtc),
     .MOUSE0_BUTTONS(mouse0_buttons),
     .MOUSE1_BUTTONS(mouse1_buttons),
     .MOUSE_IDX(mouse_idx),
     .KBD_MOUSE_DATA(kbd_mouse_data),
     .KBD_MOUSE_TYPE(kbd_mouse_type),
     .KBD_MOUSE_STROBE(kbd_mouse_strobe),
     .KMS_LEVEL(kms_level),
     .CORE_TYPE(8'ha5),    // minimig core id (a1 - old minimig id, a5 - new aga minimig id)
     .CONF(core_config),
     .STATUS(core_status)
  );
  
  
wire           VGA_CS_INT;     // VGA C_SYNC
wire           VGA_HS_INT;     // VGA H_SYNC
wire           VGA_VS_INT;     // VGA V_SYNC
wire [  8-1:0] VGA_R_INT;      // VGA Red[5:0]
wire [  8-1:0] VGA_G_INT;      // VGA Green[5:0]
wire [  8-1:0] VGA_B_INT;      // VGA Blue[5:0]

wire fd_step;
wire fd_insert;
wire fd_eject;
wire fd_motor;
wire hd_step;

//// minimig top ////
minimig minimig (
  //m68k pins
  .cpu_address  (tg68_adr[23:1]   ), // M68K address bus
  .cpu_data     (tg68_dat_in      ), // M68K data bus word1
  .cpu_data2    (tg68_dat_in2     ), // M68K data bus word2
  .cpudata_in   (tg68_dat_out     ), // M68K data in
  ._cpu_ipl     (tg68_IPL         ), // M68K interrupt request
  ._cpu_as      (tg68_as          ), // M68K address strobe
  ._cpu_uds     (tg68_uds         ), // M68K upper data strobe
  ._cpu_lds     (tg68_lds         ), // M68K lower data strobe
  ._cpu_uds2    (tg68_uds2        ), // M68K upper data strobe 2nd word
  ._cpu_lds2    (tg68_lds2        ), // M68K lower data strobe 2nd word
  .cpu_r_w      (tg68_rw          ), // M68K read / write
  ._cpu_dtack   (tg68_dtack       ), // M68K data acknowledge
  ._cpu_reset   (tg68_rst         ), // M68K reset
  ._cpu_reset_in(tg68_nrst_out    ), // M68K reset out
  .cpu_vbr      (tg68_VBR_out     ), // M68K VBR
  .ovr          (tg68_ovr         ), // NMI override address decoding
  //sram pins
  .ram_data     (ram_data         ), // SRAM data bus
  .ramdata_in   (ramdata_in       ), // SRAM data bus in
  .ram_address  (ram_address[22:1]), // SRAM address bus
  ._ram_bhe     (_ram_bhe         ), // SRAM upper byte select
  ._ram_ble     (_ram_ble         ), // SRAM lower byte select
  ._ram_bhe2    (_ram_bhe2        ), // SRAM upper byte select 2nd word
  ._ram_ble2    (_ram_ble2        ), // SRAM lower byte select 2nd word
  ._ram_we      (_ram_we          ), // SRAM write enable
  ._ram_oe      (_ram_oe          ), // SRAM output enable
  .chip48       (chip48           ), // big chipram read
  //system  pins
  .rst_ext      (rst_minimig      ), // reset from ctrl block
  .rst_out      (                 ), // minimig reset status
  .clk          (clk_28           ), // output clock c1 ( 28.687500MHz)
  .clk7_en      (clk7_en          ), // 7MHz clock enable
  .clk7n_en     (clk7n_en         ), // 7MHz negedge clock enable
  .c1           (c1               ), // clk28m clock domain signal synchronous with clk signal
  .c3           (c3               ), // clk28m clock domain signal synchronous with clk signal delayed by 90 degrees
  .cck          (cck              ), // colour clock output (3.54 MHz)
  .eclk         (eclk             ), // 0.709379 MHz clock enable output (clk domain pulse)
  //rs232 pins
  .rxd          (UART_RX          ),  // RS232 receive
  .txd          (UART_TX          ),  // RS232 send
  .cts          (1'b0             ),  // RS232 clear to send
  .rts          (                 ),  // RS232 request to send
  //I/O
  ._joy1        (~joya            ),  // joystick 1 [fire7:fire,up,down,left,right] (default mouse port)
  ._joy2        (~joyb            ),  // joystick 2 [fire7:fire,up,down,left,right] (default joystick port)
  ._joy3        (~joyc            ),  // joystick 3 [fire7:fire,up,down,left,right]
  ._joy4        (~joyd            ),  // joystick 4 [fire7:fire,up,down,left,right]
  .joy_ana      (joy_ana          ),  // analogue joystick (on the default joystick port)
  .mouse0_btn   (mouse0_buttons   ),  // mouse buttons for first mouse
  .mouse1_btn   (mouse1_buttons   ),  // mouse buttons for second mouse
  .mouse_idx    (mouse_idx        ),  // mouse index
  .kbd_reset_n  (1'b1             ),  // Aux keyboard reset (not used with MiST)
  .kbd_mouse_data (kbd_mouse_data ),  // mouse direction data, keycodes
  .kbd_mouse_type (kbd_mouse_type ),  // type of data
  .kbd_mouse_strobe (kbd_mouse_strobe), // kbd/mouse data strobe
  .kms_level    (kms_level        ),
  ._15khz       (_15khz           ),  // scandoubler disable
  .pwr_led      (led              ),  // power led
  .disk_led     (                 ),  // fdd active
  .rtc          (rtc              ),
  //host controller interface (SPI)
  ._scs         ( {SPI_SS4,SPI_SS3,SPI_SS2}  ),  // SPI chip select
  .direct_sdi   (SPI_DO           ),  // SD Card direct in  SPI_SDO
  .sdi          (SPI_DI           ),  // SPI data input
  .sdo          (minimig_sdo      ),  // SPI data output
  .sck          (SPI_SCK          ),  // SPI clock
  //video
  .selcsync     (vga_selcsync     ),
  ._csync       (cs               ),  // horizontal sync
  ._hsync       (hs               ),  // horizontal sync
  .hsyncpol     (hsyncpol         ),
  ._vsync       (vs               ),  // vertical sync
  .vsyncpol     (vsyncpol         ),
  .red          (red              ),  // red
  .green        (green            ),  // green
  .blue         (blue             ),  // blue
  //audio
  .left         (                 ),  // audio bitstream left
  .right        (                 ),  // audio bitstream right
  .ldata        (aud_amiga_left   ),  // left DAC data
  .rdata        (aud_amiga_right  ),  // right DAC data
  .cdda_l       (aud_cdda_left    ),
  .cdda_r       (aud_cdda_right   ),
  //user i/o
  .cpu_config   (cpu_config       ), // CPU config
  .board_configured(board_configured),
//  .memcfg       (memcfg           ), // memory config
  .turbochipram (turbochipram     ), // turbo chipRAM
  .turbokick    (turbokick        ), // turbo kickstart
  .slow_config  (slow_config      ),
  .aga          (aga              ),
  .init_b       (                 ), // vertical sync for MCU (sync OSD update)
  .fifo_full    (                 ),
  // fifo / track display
  .trackdisp    (                 ),  // floppy track number
  .secdisp      (                 ),  // sector
  .floppy_fwr   (                 ),  // floppy fifo writing
  .floppy_frd   (                 ),  // floppy fifo reading
  .hd_fwr       (                 ),  // hd fifo writing
  .hd_frd       (                 ),   // hd fifo  ading
  .hblank_out   (hblank_out       ),
  .vblank_out   (vblank_out       ),
  .osd_blank_out(osd_window       ),  // Let the toplevel dither module handle drawing the OSD.
  .osd_pixel_out(osd_pixel        ),
  .rtg_ena      (rtg_ena          ),
  .rtg_linecompare(rtg_linecompare),
  .ntsc         (ntsc             ),
  .ext_int2     (1'b0             ),
  .ext_int6     (aud_int          ),
  .ram_64meg    (core_config[3]   ),
  .insert_sound (fd_insert),
  .eject_sound  (fd_eject),
  .motor_sound  (fd_motor),
  .step_sound   (fd_step),
  .hdd_sound    (hd_step),
);


// RTG support...
vidclkcntrl vidclkcntrl (
	.clkselect ( rtg_ena ),
	.inclk0x   ( clk_28  ),
	.inclk1x   ( clk_114 ),
	.outclk    ( clk_vid )
);

wire rtg_ena;	// RTG screen on/off
wire rtg_clut;	// Are we in high-colour or 8-bit CLUT mode?
wire rtg_16bit; // Is high-colour mode 15 or 16 bit?

reg [3:0] rtg_pixelctr;	// Counter, compared against rtg_pixelwidth
wire [3:0] rtg_pixelwidth; // Number of clocks per fetch - 1
wire [7:0] rtg_clut_idx;	// The currently selected colour in indexed mode
wire rtg_pixel;	// Strobe the next pixel from the FIFO
wire rtg_linecompare;

wire hblank_out;
wire vblank_out;
reg rtg_vblank;
wire rtg_blank;
reg rtg_blank_d;
reg rtg_blank_d2;
reg [6:0] rtg_vbcounter;	// Vvbco counter
wire [6:0] rtg_vbend; // Size of VBlank area


wire [7:0] rtg_r;	// 16-bit mode RGB data
wire [7:0] rtg_g;
wire [7:0] rtg_b;
reg rtg_clut_in_sel;	// Select first or second byte of 16-bit word as CLUT index
reg rtg_clut_in_sel_d;
wire rtg_ext;	// Extend the active area by one clock.
wire [7:0] rtg_clut_r;	// RGB data from CLUT
wire [7:0] rtg_clut_g;
wire [7:0] rtg_clut_b;


// RTG data fetch strobe
assign rtg_pixel=(rtg_ena && (!rtg_blank || (!rtg_blank_d && rtg_ext)) && rtg_pixelctr==rtg_pixelwidth) ? 1'b1 : 1'b0;

wire rtg_clut_pixel;
assign rtg_clut_pixel = rtg_clut_in_sel & !rtg_clut_in_sel_d; // Detect rising edge;
reg rtg_pixel_d;
// Export a VGA pixel strobe for the dither module.
assign vga_pixel=rtg_ena ? (rtg_pixel_d | (rtg_clut_pixel & rtg_clut)) : 1'b1;

always @(posedge clk_114) begin
	rtg_pixel_d<=rtg_pixel;

	// Delayed copies of signals
	rtg_blank_d<=rtg_blank;
	rtg_blank_d2<=rtg_blank_d;
	rtg_clut_in_sel_d<=rtg_clut_in_sel;

	// Alternate colour index at twice the fetch clock.
	if(rtg_pixelctr=={1'b0,rtg_pixelwidth[3:1]})
		rtg_clut_in_sel<=1'b1;
	
	// Increment the fetch clock, reset during blank.
	if(rtg_blank || rtg_pixel) begin
		rtg_pixelctr<=3'b0;
		rtg_clut_in_sel<=1'b0;
	end else begin
		rtg_pixelctr<=rtg_pixelctr+1'd1;
	end
end

reg linecompare_d;
wire linecompare_trigger = rtg_linecompare & !linecompare_d;
reg [3:0] linecompare_fillmask_ctr;
wire linecompare_fillmask=|linecompare_fillmask_ctr;

always @(posedge clk_28)
begin
	// Handle vblank manually, since the OS makes it awkward to use the chipset for this.
	cs_reg    <= #1 cs;
	vs_reg    <= #1 vs;
	hs_reg    <= #1 hs;
	linecompare_d<=rtg_linecompare;

	// When we change the RTG address we must ensure any existing transaction has finished
	if(|linecompare_fillmask_ctr)
		linecompare_fillmask_ctr=linecompare_fillmask_ctr-1'd1;
	if(linecompare_trigger)
		linecompare_fillmask_ctr=4'hf;

	if(vblank_out) begin
		rtg_vblank<=1'b1;
		rtg_vbcounter<=5'b0;
	end else if(rtg_vbcounter==rtg_vbend) begin
		rtg_vblank<=1'b0;
	end else if(hs & !hs_reg) begin
		rtg_vbcounter<=rtg_vbcounter+1'd1;
	end
end

assign rtg_blank = rtg_vblank | hblank_out;

assign rtg_clut_idx = rtg_clut_in_sel_d ? rtg_dat[7:0] : rtg_dat[15:8];
assign rtg_r=rtg_16bit ? {rtg_dat[15:11],rtg_dat[15:13]} : {rtg_dat[14:10],rtg_dat[14:12]};
assign rtg_g=rtg_16bit ? {rtg_dat[10:5],rtg_dat[10:9]} : {rtg_dat[9:5],rtg_dat[9:7]};
assign rtg_b={rtg_dat[4:0],rtg_dat[4:2]};

wire [25:4] rtg_baseaddr;
wire [25:4] rtg_baseaddr2;
wire [25:0] rtg_addr;
wire [15:0] rtg_dat;

wire rtg_ramreq;
wire [15:0] rtg_fromram;
wire rtg_fill;

// Replicate the CPU's address mangling.
wire [25:0] rtg_addr_mangled;
assign rtg_addr_mangled[25:24]=rtg_addr[25:24];
assign rtg_addr_mangled[23]=rtg_addr[23]^(rtg_addr[22]|rtg_addr[21]);
assign rtg_addr_mangled[22:0]=rtg_addr[22:0];

VideoStream myvs
(
	.clk(clk_114),
	.reset_n(rtg_ena & !vblank_out & !linecompare_fillmask),
	.enable(rtg_ena),
	.baseaddr({rtg_linecompare ? rtg_baseaddr2[24:4] : rtg_baseaddr[24:4],4'b0}),
	// SDRAM interface
	.a(rtg_addr),
	.req(rtg_ramreq),
	.d(rtg_fromram),
	.fill(rtg_fill),
	// Display interface
	.rdreq(rtg_pixel & !rtg_linecompare), // Allow one blank line for fetch to get ahead of display
	.q(rtg_dat)
);


// Select between RTG hi-colour, RTG CLUT and native video

always @ (posedge clk_vid) begin
  red_reg   <= #1 rtg_ena && !rtg_blank_d2 ? rtg_clut ? rtg_clut_r : rtg_r : red;
  green_reg <= #1 rtg_ena && !rtg_blank_d2 ? rtg_clut ? rtg_clut_g : rtg_g : green;
  blue_reg  <= #1 rtg_ena && !rtg_blank_d2 ? rtg_clut ? rtg_clut_b : rtg_b : blue;
end


// Overlaying of OSD graphics


wire osd_window;
wire osd_pixel;
wire [1:0] osd_r;
wire [1:0] osd_g;
wire [1:0] osd_b;
assign osd_r = osd_pixel ? 2'b11 : 2'b00;
assign osd_g = osd_pixel ? 2'b11 : 2'b00;
assign osd_b = osd_pixel ? 2'b11 : 2'b10;
assign VGA_CS_INT           = cs_reg;
assign VGA_VS_INT           = vs_reg;
assign VGA_HS_INT           = hs_reg;
assign VGA_R_INT[7:0]       = osd_window ? {osd_r,red_reg[7:2]} : red_reg[7:0];
assign VGA_G_INT[7:0]       = osd_window ? {osd_g,green_reg[7:2]} : green_reg[7:0];
assign VGA_B_INT[7:0]       = osd_window ? {osd_b,blue_reg[7:2]} : blue_reg[7:0];


// Conversion to YPbPr

wire [  8-1:0] mixer_red;
wire [  8-1:0] mixer_green;
wire [  8-1:0] mixer_blue;
wire           mixer_vs;
wire           mixer_hs;
wire				mixer_cs;
wire				mixer_pixel;

RGBtoYPbPr videoconvert
(
	.clk(clk_vid),
	.ena(ypbpr),

	.red_in(VGA_R_INT),
	.green_in(VGA_G_INT),
	.blue_in(VGA_B_INT),
	
	.hs_in(VGA_HS_INT),
	.vs_in(VGA_VS_INT),
	.cs_in(VGA_CS_INT),
	.pixel_in(vga_pixel),
	
	.red_out(mixer_red),
	.green_out(mixer_green),
	.blue_out(mixer_blue),
	.hs_out(mixer_hs),
	.vs_out(mixer_vs),
	.cs_out(mixer_cs),
	.pixel_out(mixer_pixel)
);


// Video dithering

wire [  8-1:0] dithered_red;
wire [  8-1:0] dithered_green;
wire [  8-1:0] dithered_blue;
wire           dithered_vs;
wire           dithered_hs;

assign vga_window = 1'b1;
video_vga_dither #(.outbits(6), .flickerreduce("false")) dither
(
	.clk(clk_vid),
	.ena(rtg_ena),
	.pixel(mixer_pixel),
	.vidEna(vga_window),
	.iSelcsync(force_csync),
	.iCsync(mixer_cs),
	.iHsync(mixer_hs),
	.iVsync(mixer_vs),
	.iRed(mixer_red),
	.iGreen(mixer_green),
	.iBlue(mixer_blue),
	.oHsync(dithered_hs),
	.oVsync(dithered_vs),
	.oRed(dithered_red),
	.oGreen(dithered_green),
	.oBlue(dithered_blue)
	);

always @(posedge clk_vid) begin
	VGA_VS <= dithered_vs ^ (vsyncpol & !force_csync);
	VGA_HS <= dithered_hs ^ (hsyncpol & !force_csync);

	VGA_R[5:0] <= dithered_red[7:2];
	VGA_G[5:0] <= dithered_green[7:2];
	VGA_B[5:0] <= dithered_blue[7:2];
end

// Auxiliary audio

wire [15:0] aud_amiga_left;
wire [15:0] aud_amiga_right;    // sigma-delta DAC output right
wire [15:0] aud_cdda_left;
wire [15:0] aud_cdda_right;
reg [15:0] aud_aux_left;
reg [15:0] aud_aux_right;    // sigma-delta DAC output right

reg aud_tick;
reg aud_tick_d;
reg aud_next;

wire [25:0] aud_addr;
wire [15:0] aud_sample;

wire aud_ramreq;
wire [15:0] aud_fromram;
wire aud_fill;
wire aud_ena_cpu;
wire aud_clear;

wire [22:0] aud_ramaddr;
assign aud_ramaddr[15:0]=aud_addr[15:0];
assign aud_ramaddr[22:16]=7'b1101111;  // 0x6f0000 in SDRAM, 0x070000 to host, 0xef0000 to Amiga

reg [9:0] aud_ctr;
always @(posedge clk_28) begin
	aud_ctr<=aud_ctr+1'd1;
	if (aud_ctr==10'd642) begin
		aud_tick<=1'b1;
		aud_ctr<=10'b0;
	end
	else
		aud_tick<=1'b0;
end

//  tick:   0 0 1 1 1 1 0 0
//  tick_d: 0 0 0 1 1 1 1 0
// tick^tick_d  1 0 0 0 1 0 
always @(posedge clk_114) begin
	aud_tick_d<=aud_tick;
	aud_next<=aud_tick ^ aud_tick_d;
	if (aud_tick_d==1)
		aud_aux_left<={aud_sample[7:0],aud_sample[15:8]};
	else
		aud_aux_right<={aud_sample[7:0],aud_sample[15:8]};
end	

// We can use the same type of FIFO as we use for video.
VideoStream myaudiostream
(
	.clk(clk_114),
	.reset_n(aud_ena_cpu), // !aud_clear),
	.enable(aud_ena_cpu),
	.baseaddr(26'b0),
	// SDRAM interface
	.a(aud_addr),
	.req(aud_ramreq),
	.d(aud_fromram),
	.fill(aud_fill),
	// Display interface
	.rdreq(aud_next),
	.q(aud_sample)
);


// Drive sounds

wire [15:0] ds_aud;
`ifdef MINIMIG_DRIVESOUNDS
drivesounds ds_inst
(
	.clk(clk_114),
	.reset_n(tg68_rst),
	.mem_addr(host_addr),
	.mem_d(host_data),
	.mem_req(host_req),
	.mem_ack(host_ack),
	.fd_step(fd_step),
	.fd_motor(fd_motor),
	.fd_insert(fd_insert),
	.fd_eject(fd_eject),
	.hd_step(hd_step),
	.aud_q(ds_aud)
);
`else
assign ds_aud = 16'h0000;
`endif

// Audio mixing

wire [15:0] ldata;
wire [15:0] rdata;

AudioMix myaudiomix
(
	.clk(clk_28),
	.reset_n(~reset_out),
	.audio_in_l1(aud_amiga_left),
	.audio_in_l2(aud_aux_left),
	.audio_in_l3(aud_cdda_left),
	.audio_in_l4(ds_aud),
	.audio_in_r1(aud_amiga_right),
	.audio_in_r2(aud_aux_right),
	.audio_in_r3(aud_cdda_right),
	.audio_in_r4(ds_aud),
	.audio_l(ldata),
	.audio_r(rdata)
);

// Audio DAC

wire [15:0] lunsigned;
assign lunsigned[15]=!ldata[15];
assign lunsigned[14:0]=ldata[14:0];

wire [15:0] runsigned;
assign runsigned[15]=!rdata[15];
assign runsigned[14:0]=rdata[14:0];

hybrid_pwm_sd sd(
	.clk(clk_114),
	.d_l(lunsigned),
	.q_l(AUDIO_L),
	.d_r(runsigned),
	.q_r(AUDIO_R)
);

endmodule

