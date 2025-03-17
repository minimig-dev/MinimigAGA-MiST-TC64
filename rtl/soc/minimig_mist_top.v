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
`ifdef MINIMIG_USE_MIDI_PINS
  output wire           MIDI_OUT,
  input wire            MIDI_IN,
`endif
`ifdef MINIMIG_SIDI128_EXPANSION
  input                 UART_CTS,
  output                UART_RTS,
  inout                 EXP7,
  inout                 MOTOR_CTRL,
`endif
  // VGA
  output reg            VGA_HS,     // VGA H_SYNC
  output reg            VGA_VS,     // VGA V_SYNC
  output reg  [ VGA_WIDTH-1:0] VGA_R,      // VGA Red
  output reg  [ VGA_WIDTH-1:0] VGA_G,      // VGA Green
  output reg  [ VGA_WIDTH-1:0] VGA_B,      // VGA Blue
`ifdef MINIMIG_USE_HDMI
  output                HDMI_RST,
  output reg      [7:0] HDMI_R,
  output reg      [7:0] HDMI_G,
  output reg      [7:0] HDMI_B,
  output reg            HDMI_HS,
  output reg            HDMI_VS,
  output                HDMI_PCLK,
  output reg            HDMI_DE,
  inout                 HDMI_SDA,
  inout                 HDMI_SCL,
  input                 HDMI_INT,
`endif
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
`ifdef MINIMIG_DUAL_SDRAM
  inout  wire [ 16-1:0] SDRAM2_DQ,  // SDRAM Data bus 16 Bits
  output wire [ 13-1:0] SDRAM2_A,   // SDRAM Address bus 13 Bits
  output wire           SDRAM2_DQML,// SDRAM Low-byte Data Mask
  output wire           SDRAM2_DQMH,// SDRAM High-byte Data Mask
  output wire           SDRAM2_nWE, // SDRAM Write Enable
  output wire           SDRAM2_nCAS,// SDRAM Column Address Strobe
  output wire           SDRAM2_nRAS,// SDRAM Row Address Strobe
  output wire           SDRAM2_nCS, // SDRAM Chip Select
  output wire [  2-1:0] SDRAM2_BA,  // SDRAM Bank Address
  output wire           SDRAM2_CLK, // SDRAM Clock
  output wire           SDRAM2_CKE, // SDRAM Clock Enable
`endif
  // MINIMIG specific
  output wire           AUDIO_L,    // sigma-delta DAC output left
  output wire           AUDIO_R,    // sigma-delta DAC output right
`ifdef MINIMIG_I2S_AUDIO
  output                I2S_BCK,
  output                I2S_LRCK,
  output                I2S_DATA,
`endif
`ifdef MINIMIG_I2S_AUDIO_HDMI
  output                HDMI_MCLK,
  output                HDMI_BCK,
  output                HDMI_LRCK,
  output                HDMI_SDATA,
`endif
`ifdef MINIMIG_SPDIF_AUDIO
  output                SPDIF,
`endif
  // SPI
  inout wire            SPI_DO,     // inout
  input wire            SPI_DI,
  input wire            SPI_SCK,
  input wire            SPI_SS2,    // fpga
  input wire            SPI_SS3,    // OSD
`ifndef MINIMIG_NO_DIRECT_UPLOAD
  input wire            SPI_SS4,    // "sniff" mode
`endif
`ifdef MINIMIG_QSPI
  input wire            QCSn,
  input wire            QSCK,
  input wire    [4-1:0] QDAT,
`endif
  input wire            CONF_DATA0  // SPI_SS for user_io
);


////////////////////////////////////////
// internal signals                   //
////////////////////////////////////////
`ifdef MINIMIG_NO_DIRECT_UPLOAD
wire           SPI_SS4 = 1;
`endif

`ifdef MINIMIG_VGA_8BIT
localparam VGA_WIDTH = 8;
`else
localparam VGA_WIDTH = 6;
`endif

`ifdef MINIMIG_SIDI128_EXPANSION
assign EXP7 = 1'bZ;
assign MOTOR_CTRL = 1'bZ;
`endif

// clock
wire           pll_in_clk;
wire           clk_114;
wire           clk_28;
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
wire           tg68_fast_rd;
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
wire   [  3:0] tg68_cpustate;
//wire           tg68_chipset_ramsel;
wire           tg68_nrst_out;
wire           tg68_clds;
wire           tg68_cuds;
wire [  4-1:0] tg68_CACR_out;
wire [ 32-1:0] tg68_VBR_out;
wire           tg68_ovr;

wire tg68_host_req;
wire tg68_host_ack;

// rtg
wire    [10:0] rtg_reg_addr;
wire    [15:0] rtg_reg_d;
wire           rtg_reg_wr;
wire           rtg_linecompare;

// aux audio
wire           aud_ena_cpu;
wire    [22:0] aud_ramaddr;
wire           aud_ack;
wire           aud_fill;
wire    [15:0] aud_fromram;
wire           aud_int;

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

wire           vga_window;
wire           vga_selcsync;
wire           vga_pixel;

// sdram
wire           reset_out;
wire [  4-1:0] sdram_cs;
wire [  2-1:0] sdram_dqm;
wire [  2-1:0] sdram_ba;

`ifdef MINIMIG_DUAL_SDRAM
wire [  4-1:0] sdram2_cs;
wire [  2-1:0] sdram2_dqm;
wire [  2-1:0] sdram2_ba;
`endif

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
wire     [1:0] switches;
wire           uart_in;
wire           uart_out;
wire           midi_in;
wire           midi_out;

`ifdef MINIMIG_USE_HDMI
wire        i2c_start;
wire        i2c_read;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr;
wire  [7:0] i2c_dout;
wire  [7:0] i2c_din;
wire        i2c_ack;
wire        i2c_end;
`endif

////////////////////////////////////////
// toplevel assignments               //
////////////////////////////////////////

// SDRAM
assign SDRAM_CKE        = 1'b1;
assign SDRAM_nCS        = sdram_cs[0];
assign SDRAM_DQML       = sdram_dqm[0];
assign SDRAM_DQMH       = sdram_dqm[1];
assign SDRAM_BA         = sdram_ba;

`ifdef MINIMIG_DUAL_SDRAM
assign SDRAM2_CKE       = 1'b1;
assign SDRAM2_nCS       = sdram2_cs[0];
assign SDRAM2_DQML      = sdram2_dqm[0];
assign SDRAM2_DQMH      = sdram2_dqm[1];
assign SDRAM2_BA        = sdram2_ba;
`endif

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

//// amiga clocks ////
amiga_clk amiga_clk (
  .rst          (pll_rst          ), // async reset input
  .ntsc         (clock_ntsc       ), // pal/ntsc clock select
  .clk_in       (pll_in_clk       ), // input clock     ( 27.000000MHz)
  .clk_114      (clk_114          ), // output clock c0 (114.750000MHz)
  .clk_sdram    (SDRAM_CLK        ), // output clock c2 (114.750000MHz, -146.25 deg)
  .clk_28       (clk_28           ), // output clock c1 ( 28.687500MHz)
  .clk7_en      (clk7_en          ), // output clock 7 enable (on 28MHz clock domain)
  .clk7n_en     (clk7n_en         ), // 7MHz negedge output clock enable (on 28MHz clock domain)
  .c1           (c1               ), // clk28m clock domain signal synchronous with clk signal
  .c3           (c3               ), // clk28m clock domain signal synchronous with clk signal delayed by 90 degrees
  .cck          (cck              ), // colour clock output (3.54 MHz)
  .eclk         (eclk             ), // 0.709379 MHz clock enable output (clk domain pulse)
  .locked       (pll_locked       )  // pll locked output
);

`ifdef MINIMIG_DUAL_SDRAM
amiga_clk amiga_clk2 (
  .rst          (pll_rst          ), // async reset input
  .ntsc         (clock_ntsc       ), // pal/ntsc clock select
  .clk_in       (pll_in_clk       ), // input clock     ( 27.000000MHz)
  .clk_114      (                 ), // output clock c0 (114.750000MHz)
  .clk_sdram    (SDRAM2_CLK       ), // output clock c2 (114.750000MHz, -146.25 deg)
  .clk_28       (                 ), // output clock c1 ( 28.687500MHz)
  .clk7_en      (                 ), // output clock 7 enable (on 28MHz clock domain)
  .clk7n_en     (                 ), // 7MHz negedge output clock enable (on 28MHz clock domain)
  .c1           (                 ), // clk28m clock domain signal synchronous with clk signal
  .c3           (                 ), // clk28m clock domain signal synchronous with clk signal delayed by 90 degrees
  .cck          (                 ), // colour clock output (3.54 MHz)
  .eclk         (                 ), // 0.709379 MHz clock enable output (clk domain pulse)
  .locked       (                 )  // pll locked output
);
`endif

//// TG68K main CPU ////

`ifdef MINIMIG_AUX_AUDIO
localparam auxaudio="true";
`else
localparam auxaudio="false";
`endif

`ifdef MINIMIG_DUAL_SDRAM
localparam dualsdram="true";
`else
localparam dualsdram="false";
`endif

`ifdef MINIMIG_USE_PROFILER
localparam useprofiler="true";
`else
localparam useprofiler="false";
`endif

`ifdef MINIMIG_HRTMON_CART
localparam havecart="true";
`else
localparam havecart="false";
`endif

TG68K #(
  .dualsdram(dualsdram),
  .useprofiler(useprofiler),
  .haveaudio(auxaudio),
  .havecart(havecart)
) tg68k (
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
  .fast_rd      (tg68_fast_rd     ),
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
//  .chipset_ramsel(tg68_chipset_ramsel),
  .nResetOut    (tg68_nrst_out    ),
  .skipFetch    (                 ),
  .ramlds       (tg68_clds        ),
  .ramuds       (tg68_cuds        ),
  .CACR_out     (tg68_CACR_out    ),
  .VBR_out      (tg68_VBR_out     ),
  // RTG signals
  .rtg_reg_addr(rtg_reg_addr),
  .rtg_reg_d(rtg_reg_d),
  .rtg_reg_wr(rtg_reg_wr),
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

// RTG to RAM interface
wire [25:0] rtg_fetch_addr;
wire rtg_ramreq;
wire [15:0] rtg_fromram;
wire rtg_fill;
wire rtg_rampri;
wire rtg_ack;

// SDRAM controller(s)

`ifndef MINIMIG_DUAL_SDRAM

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
  .clk28_en     (tg68_ena28       ),
  .chipRD       (ramdata_in       ),
  .chip48       (chip48           ),
  // RTG
  .rtgAddr      (rtg_fetch_addr   ),
  .rtgce        (rtg_ramreq       ),
  .rtgack       (rtg_ack          ),
  .rtgpri       (rtg_rampri       ),
  .rtgfill      (rtg_fill         ),
  .rtgRd        (rtg_fromram      ), 
  // Audio buffer
  .audAddr      (aud_ramaddr      ),
  .audce        (aud_ramreq       ),
  .audack       (aud_ack          ),
  .audfill      (aud_fill         ),
  .audRd        (aud_fromram      ),
  // Misc signals
  .reset_out    (reset_out        ),
  .enaWRreg     (tg68_ena28       ),
  .ena7RDreg    (tg68_ena7RD      ),
  .ena7WRreg    (tg68_ena7WR      )
);

`else

//assign         tg68_cout = !chipram_cpustate[2] ? chipram_cout : fastram_cout;
//assign         tg68_cpuena = !chipram_cpustate[2] ? chipram_ready : !fastram_cpustate[2] ? fastram_ready : 1'b0;

reg sel_2ndram;
always @(posedge clk_114)
  sel_2ndram <= tg68_cad[26];

assign         tg68_cpuena = chipram_ready | fastram_ready;
assign         tg68_cout = sel_2ndram? fastram_cout : chipram_cout;

//chipram
//wire     [3:0] chipram_cpustate = tg68_cpustate | {1'b0, ~tg68_chipset_ramsel, 2'b00};
wire [ 16-1:0] chipram_cout;
wire           chipram_ready;

sdram_ctrl #(.addr_prefix_bits(1), .addr_prefix(0), .fast_write(1)) sdram (
  .sysclk       (clk_114          ),
  .reset_in     (sdctl_rst        ),
  .cache_rst    (tg68_rst         ),
  .cache_inhibit(cache_inhibit    ),
  .cacheline_clr(cacheline_clr    ),
  .cpu_cache_ctrl (tg68_CACR_out  ),
  //SDRAM chip
  .sdata        (SDRAM_DQ         ),
  .sdaddr       (SDRAM_A[12:0]    ),
  .dqm          (sdram_dqm        ),
  .sd_cs        (sdram_cs         ),
  .ba           (sdram_ba         ),
  .sd_we        (SDRAM_nWE        ),
  .sd_ras       (SDRAM_nRAS       ),
  .sd_cas       (SDRAM_nCAS       ),
  // Control CPU (used for drivesounds on MiST)
  .hostWR       (16'h0000),
  .hostAddr     (host_addr[23:2]),
  .hostce       (host_req),
  .hostwe       (1'b0),
  .hostbytesel  (4'b1111),
  .hostRD       (host_data),
  .hostena      (host_ack),
  // Fast RAM
  .cpuena       (chipram_ready    ),
  .cpuRD        (chipram_cout     ),
  .cpuWR        (tg68_cin         ),
  .cpuAddr      (tg68_cad[26:1]   ),
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
  .clk28_en     (tg68_ena28       ),
  .chipRD       (ramdata_in       ),
  .chip48       (chip48           ),
  // RTG
  .rtgAddr      (rtg_fetch_addr   ),
  .rtgce        (rtg_ramreq       ),
  .rtgack       (rtg_ack          ),
  .rtgpri       (rtg_rampri       ),
  .rtgfill      (rtg_fill         ),
  .rtgRd        (rtg_fromram      ), 
  // Audio buffer
  .audAddr      (aud_ramaddr      ),
  .audce        (aud_ramreq       ),
  .audack       (aud_ack          ),
  .audfill      (aud_fill         ),
  .audRd        (aud_fromram      ),
  // Misc signals
  .reset_out    (reset_out        ),
  .enaWRreg     (tg68_ena28       ),
  .ena7RDreg    (tg68_ena7RD      ),
  .ena7WRreg    (tg68_ena7WR      )
);

//fastram
//wire     [3:0] fastram_cpustate = tg68_cpustate | {1'b0, tg68_chipset_ramsel, 2'b00};
wire [ 16-1:0] fastram_cout;
wire           fastram_ready;

sdram_ctrl #(.shortcut(1'b1), .addr_prefix_bits(1), .addr_prefix(1), .fast_write(1) ) sdram2 (
  .sysclk       (clk_114          ),
  .reset_in     (sdctl_rst        ),
  .cache_rst    (tg68_rst         ),
  .cache_inhibit(1'b0             ),
  .cacheline_clr(1'b0             ),
  .cpu_cache_ctrl (tg68_CACR_out  ),
  //SDRAM chip
  .sdata        (SDRAM2_DQ        ),
  .sdaddr       (SDRAM2_A[12:0]   ),
  .dqm          (sdram2_dqm       ),
  .sd_cs        (sdram2_cs        ),
  .ba           (sdram2_ba        ),
  .sd_we        (SDRAM2_nWE       ),
  .sd_ras       (SDRAM2_nRAS      ),
  .sd_cas       (SDRAM2_nCAS      ),
  // Control CPU (not used in MiST)
  .hostce       (1'b0             ),
  .hostwe       (1'b0             ),
  // Fast RAM
  .cpuena       (fastram_ready    ),
  .cpuRD        (fastram_cout     ),
  .cpuWR        (tg68_cin         ),
  .cpuAddr      (tg68_cad[26:1]   ),
  .cpuU         (tg68_cuds        ),
  .cpuL         (tg68_clds        ),
  .cpustate     (tg68_cpustate    ),
  // Chip RAM
  .chipWR       (                 ),
  .chipWR2      (                 ),
  .chipAddr     (                 ),
  .chipU        (                 ),
  .chipL        (                 ),
  .chipU2       (                 ),
  .chipL2       (                 ),
  .chipRW       (1'b1             ),
  .chip_dma     (1'b1             ),
  .clk7_en      (clk7_en          ),
  .clk28_en     (tg68_ena28       ),
  .chipRD       (                 ),
  .chip48       (                 ),
  // RTG
  .rtgAddr      (                 ),
  .rtgce        (                 ),
  .rtgfill      (                 ),
  .rtgRd        (                 ), 
  // Audio buffer
  .audAddr      (                 ),
  .audce        (                 ),
  .audfill      (                 ),
  .audRd        (                 ),
  // Misc signals
  .reset_out    (                 ),
  .hostRD       (                 ),
  .hostena      (                 ),
  .enaWRreg     (                 ),
  .ena7RDreg    (                 ),
  .ena7WRreg    (                 )
);

`endif

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
     .SWITCHES(switches),
     .KBD_MOUSE_DATA(kbd_mouse_data),
     .KBD_MOUSE_TYPE(kbd_mouse_type),
     .KBD_MOUSE_STROBE(kbd_mouse_strobe),
     .KMS_LEVEL(kms_level),
     .CORE_TYPE(8'ha5),    // minimig core id (a1 - old minimig id, a5 - new aga minimig id)
     .CONF(core_config),
`ifdef MINIMIG_USE_HDMI
     .i2c_start      (i2c_start      ),
     .i2c_read       (i2c_read       ),
     .i2c_addr       (i2c_addr       ),
     .i2c_subaddr    (i2c_subaddr    ),
     .i2c_dout       (i2c_dout       ),
     .i2c_din        (i2c_din        ),
     .i2c_ack        (i2c_ack        ),
     .i2c_end        (i2c_end        ),
     .hdmi_hiclk     (rtg_ena        ), // HDMI Pixel Clock > 80MHz
`endif
     .STATUS(core_status)
);

`ifdef MINIMIG_USE_MIDI_PINS

`ifdef MINIMIG_USE_JTAG_MIDI
	rs232_jtag jtag_midi (
		.clk(clk_28),
		.reset_n(pll_locked),
		.rxd(midi_out),
		.txd(midi_in)
	);
`else
  assign uart_in=UART_RX;
  assign UART_TX=uart_out;
  assign midi_in = MIDI_IN;
  assign MIDI_OUT = midi_out;
`endif

`else
   assign uart_in = UART_RX;
   assign midi_in = UART_RX;
   assign UART_TX = uart_out & midi_out;
`endif

wire fd_step;
wire fd_insert;
wire fd_eject;
wire fd_motor;
wire hd_step;

wire [23:0] aud_amiga_left;
wire [23:0] aud_amiga_right;    // sigma-delta DAC output right
reg [15:0] aud_aux_left;
reg [15:0] aud_aux_right;
wire [15:0] ds_aud;

wire [7:0] red_amiga;
wire [7:0] green_amiga;
wire [7:0] blue_amiga;
wire blank_amiga;
wire hblank_amiga;
wire vblank_amiga;

wire rtg_ena;

//// minimig top ////
minimig minimig (
  //m68k pins
  .cpu_address  (tg68_adr[23:1]   ), // M68K address bus
  .cpu_data     (tg68_dat_in      ), // M68K data bus word1
  .cpu_data2    (tg68_dat_in2     ), // M68K data bus word2
  .cpudata_in   (tg68_dat_out     ), // M68K data in
  ._cpu_ipl     (tg68_IPL         ), // M68K interrupt request
  .fast_rd      (tg68_fast_rd     ),
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
  .midi_rx      (midi_in          ),  // RS232 receive
  .midi_tx      (midi_out         ),  // RS232 send
  .rxd          (uart_in          ),  // RS232 receive
  .txd          (uart_out         ),  // RS232 send
`ifdef MINIMIG_SIDI128_EXPANSION
  .cts          (UART_CTS         ),  // RS232 clear to send
  .rts          (UART_RTS         ),  // RS232 request to send
`else
  .cts          (1'b0             ),  // RS232 clear to send
  .rts          (                 ),  // RS232 request to send
`endif
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
`ifdef MINIMIG_QSPI
  .qcs          (~QCSn            ),
  .qsck         (QSCK             ),
  .qdat         (QDAT             ),
`else
  .qcs          (1'b0             ),
  .qsck         (1'b0             ),
  .qdat         (3'd0             ),
`endif
  //video
  .selcsync     (vga_selcsync     ),
  ._csync       (cs               ),  // horizontal sync
  ._hsync       (hs               ),  // horizontal sync
  .hsyncpol     (hsyncpol         ),
  ._vsync       (vs               ),  // vertical sync
  .vsyncpol     (vsyncpol         ),
  .red          (red_amiga        ),  // red
  .green        (green_amiga      ),  // green
  .blue         (blue_amiga       ),  // blue
  //audio
  .ldata        (aud_amiga_left   ),  // left DAC data
  .rdata        (aud_amiga_right  ),  // right DAC data
  .aux_left_1   (aud_aux_left     ),  // Auxiliary audio
  .aux_right_1  (aud_aux_right    ),  // Auxiliary audio
  .aux_left_2   (ds_aud           ),  // Auxiliary audio
  .aux_right_2  (ds_aud           ),  // Auxiliary audio
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
  .hd_frd       (                 ),  // hd fifo  ading
  .hblank_out   (hblank_amiga     ),
  .vblank_out   (vblank_amiga     ),
  .blank_out    (blank_amiga      ),  // Composite blank
  .osd_blank_out(osd_window       ),  // Let the toplevel dither module handle drawing the OSD.
  .osd_pixel_out(osd_pixel        ),
  .rtg_ena      (rtg_ena          ),
  .rtg_linecompare(rtg_linecompare),
  .ntsc         (ntsc             ),
  .ext_int2     (1'b0             ),
  .ext_int6     (aud_int          ),
`ifndef MINIMIG_DUAL_SDRAM
  .ram_64meg    ({1'b0,core_config[3]}),
`else
  .ram_64meg    (2'b10            ),
`endif
  .insert_sound (fd_insert),
  .eject_sound  (fd_eject),
  .motor_sound  (fd_motor),
  .step_sound   (fd_step),
  .hdd_sound    (hd_step)
);


// RTG support...
vidclkcntrl vidclkcntrl (
	.clkselect ( rtg_ena ),
	.inclk0x   ( clk_28  ),
	.inclk1x   ( clk_114 ),
	.outclk    ( clk_vid )
);

wire [7:0] rtg_r;	// 16-bit mode RGB data
wire [7:0] rtg_g;
wire [7:0] rtg_b;

wire rtg_de;

rtg_video rtg (
	.clk_114(clk_114),
	.clk_28(clk_28),
	.clk_vid(clk_vid),
	.rtg_ena(rtg_ena),
	.rtg_linecompare(rtg_linecompare),
	.reg_addr(rtg_reg_addr),
	.reg_wr(rtg_reg_wr),
	.reg_d(rtg_reg_d),

	.fetch_addr(rtg_fetch_addr),
	.fetch_req(rtg_ramreq),
	.fetch_pri(rtg_rampri),
	.fetch_d(rtg_fromram),
	.fetch_ack(rtg_ack),
	.fetch_fill(rtg_fill),
		
	.amiga_r(red_amiga),
	.amiga_g(green_amiga),
	.amiga_b(blue_amiga),
	.amiga_hb(hblank_amiga),
	.amiga_vb(vblank_amiga),
	.amiga_hs(hs),
	.amiga_blank(blank_amiga),

	.red(rtg_r),
	.green(rtg_g),
	.blue(rtg_b),
	.de(rtg_de)
);


// Overlaying of OSD graphics

wire osd_window;
wire osd_pixel;
wire [1:0] osd_r;
wire [1:0] osd_g;
wire [1:0] osd_b;
assign osd_r = osd_pixel ? 2'b11 : 2'b00;
assign osd_g = osd_pixel ? 2'b11 : 2'b00;
assign osd_b = osd_pixel ? 2'b11 : 2'b10;
reg       VGA_CS_INT;
reg       VGA_VS_INT;
reg       VGA_HS_INT;
wire [7:0] VGA_R_INT = osd_window ? {osd_r,rtg_r[7:2]} : rtg_r;
wire [7:0] VGA_G_INT = osd_window ? {osd_g,rtg_g[7:2]} : rtg_g;
wire [7:0] VGA_B_INT = osd_window ? {osd_b,rtg_b[7:2]} : rtg_b;

always @(posedge clk_vid) begin
	VGA_CS_INT = cs;
	VGA_HS_INT = hs;
	VGA_VS_INT = vs;
end


// Conversion to YPbPr

wire [  8-1:0] mixer_red;
wire [  8-1:0] mixer_green;
wire [  8-1:0] mixer_blue;
wire           mixer_vs;
wire           mixer_hs;
wire           mixer_cs;
wire           mixer_de;
wire           mixer_pixel;

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
	.de_in(rtg_de),
	.pixel_in(vga_pixel),
	
	.red_out(mixer_red),
	.green_out(mixer_green),
	.blue_out(mixer_blue),
	.hs_out(mixer_hs),
	.vs_out(mixer_vs),
	.cs_out(mixer_cs),
	.de_out(mixer_de),
	.pixel_out(mixer_pixel)
);


// Video dithering

wire [  8-1:0] dithered_red;
wire [  8-1:0] dithered_green;
wire [  8-1:0] dithered_blue;
wire           dithered_vs;
wire           dithered_hs;
wire           dithered_de;

assign vga_window = 1'b1;
video_vga_dither #(.outbits(VGA_WIDTH), .flickerreduce("true")) dither
(
	.clk(clk_vid),
`ifdef MINIMIG_TOPLEVEL_DITHER
	.ena(1'b1),
`else
	.ena(rtg_ena),
`endif
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

	VGA_R[VGA_WIDTH-1:0] <= dithered_red[7:8-VGA_WIDTH];
	VGA_G[VGA_WIDTH-1:0] <= dithered_green[7:8-VGA_WIDTH];
	VGA_B[VGA_WIDTH-1:0] <= dithered_blue[7:8-VGA_WIDTH];
end

`ifdef MINIMIG_USE_HDMI

i2c_master #(28_000_000) i2c_master (
	.CLK         (clk_28),
	.I2C_START   (i2c_start),
	.I2C_READ    (i2c_read),
	.I2C_ADDR    (i2c_addr),
	.I2C_SUBADDR (i2c_subaddr),
	.I2C_WDATA   (i2c_dout),
	.I2C_RDATA   (i2c_din),
	.I2C_END     (i2c_end),
	.I2C_ACK     (i2c_ack),

	//I2C bus
	.I2C_SCL     (HDMI_SCL),
	.I2C_SDA     (HDMI_SDA)
);

assign HDMI_RST = 1'b1;
assign HDMI_PCLK = clk_vid;

always @(posedge clk_vid) begin
	HDMI_VS <= mixer_vs;
	HDMI_HS <= mixer_hs;
	HDMI_R <= mixer_red;
	HDMI_G <= mixer_green;
	HDMI_B <= mixer_blue;
	HDMI_DE <= mixer_de;
end

`endif

`ifdef MINIMIG_CAPTURE_SYNC
edge_capture #(.bits(3)) synccapture (
	.clk(clk_114),
	.reset(~tg68_rst),
	.d({mixer_de,mixer_vs,mixer_hs})
);
`endif

// Auxiliary audio
`ifdef MINIMIG_AUX_AUDIO
reg aud_tick;
reg aud_tick_d;
reg aud_next;

wire [25:0] aud_addr;
wire [15:0] aud_sample;

wire aud_ramreq;
wire aud_clear;

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
	.ack(aud_ack),
	.d(aud_fromram),
	.fill(aud_fill),
	// Display interface
	.rdreq(aud_next),
	.q(aud_sample)
);

`else

always @(*) begin
	aud_aux_left<=0;
   aud_aux_right<=0;
end

wire aud_ramreq=1'b0;
wire [25:0] aud_addr=0;

`endif

// Drive sounds

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

wire [23:0] ldata = aud_amiga_left;
wire [23:0] rdata = aud_amiga_right;

// Audio DAC

wire [15:0] lunsigned;
assign lunsigned[15]=!ldata[23];
assign lunsigned[14:0]=ldata[22:8];

wire [15:0] runsigned;
assign runsigned[15]=!rdata[23];
assign runsigned[14:0]=rdata[22:8];

hybrid_pwm_sd sd(
	.clk(clk_114),
	.d_l(lunsigned),
	.q_l(AUDIO_L),
	.d_r(runsigned),
	.q_r(AUDIO_R)
);

`ifdef MINIMIG_I2S_AUDIO
i2s #(.AUDIO_DW(24)) i2s (
	.reset(1'b0),
	.clk(clk_114),
	.clk_rate(clock_ntsc ? 32'd114_545_440 : 32'd113_500_640),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan(ldata),
	.right_chan(rdata)
);
`ifdef MINIMIG_I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
i2s i2s_hdmi (
	.reset(1'b0),
	.clk(clk_114),
	.clk_rate(clock_ntsc ? 32'd114_545_440 : 32'd113_500_640),

	.sclk(HDMI_BCK),
	.lrclk(HDMI_LRCK),
	.sdata(HDMI_SDATA),

	.left_chan(ldata[23:8]),
	.right_chan(rdata[23:8])
);
`endif
`endif

`ifdef MINIMIG_SPDIF_AUDIO
spdif spdif
(
	.clk_i(clk_114),
	.rst_i(1'b0),
	.clk_rate_i(clock_ntsc ? 32'd114_545_440 : 32'd113_500_640),
	.spdif_o(SPDIF),
	.sample_i({rdata[23:8], ldata[23:8]})
);
`endif

endmodule

