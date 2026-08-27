////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Copyright 2006, 2007 Dennis van Weeren                                     //
//                                                                            //
// This file is part of Minimig                                               //
//                                                                            //
// Minimig is free software; you can redistribute it and/or modify            //
// it under the terms of the GNU General Public License as published by       //
// the Free Software Foundation; either version 3 of the License, or          //
// (at your option) any later version.                                        //
//                                                                            //
// Minimig is distributed in the hope that it will be useful,                 //
// but WITHOUT ANY WARRANTY; without even the implied warranty of             //
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              //
// GNU General Public License for more details.                               //
//                                                                            //
// You should have received a copy of the GNU General Public License          //
// along with this program.  If not, see <http://www.gnu.org/licenses/>.      //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// This is Amber                                                              //
// Amber is a scandoubler to allow connection to a VGA monitor.               //
// In addition, it can overlay an OSD (on-screen-display) menu.               //
// Amber also has a pass-through mode in which                                //
// the video output can be connected to an RGB SCART input.                   //
// The meaning of _hsync_out and _vsync_out is then:                          //
// _vsync_out is fixed high (for use as RGB enable on SCART input).           //
// _hsync_out is composite sync output.                                       //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Changelog                                                                  //
// DW:                                                                        //
// 2006-01-10  - first serious version                                        //
// 2006-01-11  - done lot's of work, Amber is now finished                    //
// 2006-12-29  - added support for OSD overlay                                //
//                                                                            //
// JB:                                                                        //
// 2008-02-26  - synchronous 28 MHz version                                   //
// 2008-02-28  - horizontal and vertical interpolation                        //
// 2008-02-02  - hfilter/vfilter inputs added, unused inputs removed          //
// 2008-12-12  - useless scanline effect implemented                          //
// 2008-12-27  - clean-up                                                     //
// 2009-05-24  - clean-up & renaming                                          //
// 2009-08-31  - scanlines synthesis option                                   //
// 2010-05-30  - htotal changed                                               //
//                                                                            //
// RK:                                                                        //
// 2013-03-03  - cleanup                                                      //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////


module amber
(
  input  wire           clk,            // 28MHz clock
  // config
  input  wire           dblscan,        // enable VGA output (enable scandoubler)
  input  wire           varbeamen,      // variable beam enabled
  input  wire [  2-1:0] lr_filter,      // interpolation filter settings for low resolution
  input  wire [  2-1:0] hr_filter,      // interpolation filter settings for high resolution
  input  wire [  2-1:0] scanline,       // scanline effect enable
  input  wire [  2-1:0] dither,         // dither enable (00 = off, 01 = temporal, 10 = random, 11 = temporal + random)
  // control
  input  wire [  9-1:0] htotal,         // video line length
  input  wire     [1:0] hires,          // display is in hires or superhires mode (from bplcon0)
  input  wire           long_frame,     // for interlaced mode
  input  wire           track_vsync,    // for interlaced mode
  // osd
  input  wire           osd_blank,      // OSD overlay enable (blank normal video)
  input  wire           osd_pixel,      // OSD pixel(video) data
  // input
  input  wire [  8-1:0] red_in,         // red componenent video in
  input  wire [  8-1:0] green_in,       // green component video in
  input  wire [  8-1:0] blue_in,        // blue component video in
  input  wire           _csync_in,      // composite sync in
  input  wire           _hsync_in,      // horizontal synchronisation in
  input  wire           _vsync_in,      // vertical synchronisation in
  input  wire           blank_in,
  // output
  output reg  [  8-1:0] red_out=0,      // red componenent video out
  output reg  [  8-1:0] green_out=0,    // green component video out
  output reg  [  8-1:0] blue_out=0,     // blue component video out
  output reg            _hsync_out=0,   // horizontal synchronisation out
  output reg            _vsync_out=0,   // vertical synchronisation out
  output reg            _csync_out=0,
  output reg            blank_out=0,
  output wire           selcsync,
  output wire           osd_blank_out,
  output wire           osd_pixel_out
);


//// params ////
localparam [  8-1:0] OSD_R = 8'b11110000;
localparam [  8-1:0] OSD_G = 8'b11110000;
localparam [  8-1:0] OSD_B = 8'b11110000;


//// control ////
reg            _hsync_in_del=0;         // delayed horizontal synchronisation input
reg            hss=0;                   // horizontal sync start
reg            _vsync_in_del=0;         // delayed vertical synchronisation input
reg            vss=0;                   // vertical sync start
reg            vse=0;                   // vertical sync end

// horizontal sync start  (falling edge detection)
always @ (posedge clk) begin
  _hsync_in_del <= #1 _hsync_in;
  hss           <= #1 ~_hsync_in & _hsync_in_del;
  _vsync_in_del <= #1 _vsync_in;
  vss           <= #1 ~_vsync_in & _vsync_in_del;
  vse           <= #1 _vsync_in & ~_vsync_in_del;
end

// Interlace long frame detection
// reg long_frame;

// always @(posedge clk) begin
//	if(vss)
//		long_frame <= ~_hsync_in;
// end


//// horizontal interpolation ////
reg            hi_en=0;                 // horizontal interpolation enable
reg  [  8-1:0] r_in_d=0;                // pixel data delayed by 70ns for horizontal interpolation
reg  [  8-1:0] g_in_d=0;                // pixel data delayed by 70ns for horizontal interpolation
reg  [  8-1:0] b_in_d=0;                // pixel data delayed by 70ns for horizontal interpolation
wire [  9-1:0] hi_r;                    // horizontal interpolation output
wire [  9-1:0] hi_g;                    // horizontal interpolation output
wire [  9-1:0] hi_b;                    // horizontal interpolation output
reg  [ 11-1:0] sd_lbuf_wr=0;            // line buffer write pointer

// horizontal interpolation enable
// AMR - since the scandoubler only has hires resolution, force the filter to on
// for super-hires mode.  Not ideal, but at least all pixels are then represented in the output,
// instead of 50% of them being ignored entirely.
always @ (posedge clk) begin
`ifdef MINIMIG_VIDEO_FILTER
  if (hss) hi_en <= #1 hires[1] | (hires[0] ? hr_filter[0] : lr_filter[0]);
`else
  hi_en <= #1 1'b0;
`endif
end

// pixel data delayed by one hires pixel for horizontal interpolation
always @ (posedge clk) begin
  if (sd_lbuf_wr[0] | hires[1])  begin // sampled at 14MHz (hires clock rate) or 28MHz for super-hires mode
    r_in_d <= red_in;
    g_in_d <= green_in;
    b_in_d <= blue_in;
  end
end

// interpolate & mux
assign hi_r = hi_en ? ({1'b0, red_in}   + {1'b0, r_in_d}) : {red_in[7:0]  , 1'b0};
assign hi_g = hi_en ? ({1'b0, green_in} + {1'b0, g_in_d}) : {green_in[7:0], 1'b0};
assign hi_b = hi_en ? ({1'b0, blue_in}  + {1'b0, b_in_d}) : {blue_in[7:0] , 1'b0};


//// scandoubler ////
reg  [ 31-1:0] sd_lbuf [0:1024-1];      // line buffer for scan doubling (there are 908/910 hires pixels in every line)
reg  [ 31-1:0] sd_lbuf_o=0;             // line buffer output register
reg  [ 31-1:0] sd_lbuf_o_d=0;           // compensantion for one clock delay of the second line buffer
reg  [ 11-1:0] sd_lbuf_rd=0;            // line buffer read pointer
reg  [ 11-1:0] vsync_event;
reg            vsync_rise;
reg            vsync_rise_d;
reg            vsync_fall;
reg            vsync_fall_d;
reg            _vsync_sd;
reg            _vsync_sd_d;

reg sd_bbuf[0:1024-1]; // Buffer for delayed blank signal
reg sd_bbuf_o;

// scandoubler line buffer write pointer
always @ (posedge clk) begin
  if (hss || !dblscan)
    sd_lbuf_wr <= #1 11'd0;
  else
    sd_lbuf_wr <= #1 sd_lbuf_wr + 11'd1;
end

always @ (posedge clk) begin
  if (vse) begin
    vsync_fall <= 0;
    vsync_rise <= 1;
    vsync_event <= sd_lbuf_wr;
  end;
  if (vss) begin
    vsync_fall <= 1;
    vsync_rise <= 0;
    vsync_event <= sd_lbuf_wr;
  end;
end

wire sd_lbuf_rd_reset = hss || (sd_lbuf_rd == {1'b0,htotal[8:1],2'b11});
// scandoubler line buffer read pointer
always @ (posedge clk) begin
  if (!dblscan || sd_lbuf_rd_reset) // reset at horizontal sync start and end of scandoubled line
    sd_lbuf_rd <= #1 11'd0;
  else
    sd_lbuf_rd <= #1 sd_lbuf_rd + 11'd1;
end

always @ (posedge clk) begin
  if (sd_lbuf_rd_reset) begin
    vsync_rise_d <= vsync_rise;
    vsync_fall_d <= vsync_fall;
  end
  if (vsync_rise_d & vsync_event[10:1] == sd_lbuf_rd[9:0])
    _vsync_sd <= 1;
  if (vsync_fall_d & vsync_event[10:1] == sd_lbuf_rd[9:0])
    _vsync_sd <= 0;
  _vsync_sd_d <= _vsync_sd;
end

// scandoubler line buffer write/read
always @ (posedge clk) begin
  if (dblscan) begin
    // write
    sd_lbuf[sd_lbuf_wr[10:1]] <= #1 {blank_in, _hsync_in, osd_blank, osd_pixel, hi_r, hi_g, hi_b};
    // read
    sd_lbuf_o <= #1 sd_lbuf[sd_lbuf_rd[9:0]];
    // delayed data
    
    sd_bbuf[sd_lbuf_rd[9:0]] <= #1 sd_lbuf_o[30];
    sd_bbuf_o <= sd_bbuf[sd_lbuf_rd[9:0]];
    
    sd_lbuf_o_d <= #1 sd_lbuf_o;
  end
end


//// vertical interpolation ////
reg            vi_en=0;                 // vertical interpolation enable
reg  [ 30-1:0] vi_lbuf [0:1024-1];      // vertical interpolation line buffer
reg  [ 30-1:0] vi_lbuf_o=0;             // vertical interpolation line buffer output register
wire [ 10-1:0] vi_r_tmp;                // vertical interpolation temp data
wire [ 10-1:0] vi_g_tmp;                // vertical interpolation temp data
wire [ 10-1:0] vi_b_tmp;                // vertical interpolation temp data
wire [  8-1:0] vi_r;                    // vertical interpolation outputs
wire [  8-1:0] vi_g;                    // vertical interpolation outputs
wire [  8-1:0] vi_b;                    // vertical interpolation outputs

//vertical interpolation enable
always @ (posedge clk) begin
`ifdef MINIMIG_VIDEO_FILTER
  if (hss) vi_en <= #1 |hires ? hr_filter[1] : lr_filter[1];
`else
  vi_en <= #1 1'b0;
`endif
end

// vertical interpolation line buffer write/read
always @ (posedge clk) begin
  // write
  vi_lbuf[sd_lbuf_rd[9:0]] <= #1 sd_lbuf_o[29:0];
  // read
  vi_lbuf_o <= #1 vi_lbuf[sd_lbuf_rd[9:0]];
end

// interpolate & mux
assign vi_r_tmp = vi_en ? ({1'b0, sd_lbuf_o_d[26:18]} + {1'b0, vi_lbuf_o[26:18]}) : {sd_lbuf_o_d[26:18], 1'b0};
assign vi_g_tmp = vi_en ? ({1'b0, sd_lbuf_o_d[17:09]} + {1'b0, vi_lbuf_o[17:09]}) : {sd_lbuf_o_d[17:09], 1'b0};
assign vi_b_tmp = vi_en ? ({1'b0, sd_lbuf_o_d[ 8: 0]} + {1'b0, vi_lbuf_o[ 8: 0]}) : {sd_lbuf_o_d[ 8: 0], 1'b0};

// cut unneeded bits
assign vi_r = vi_r_tmp[8+2-1:2];
assign vi_g = vi_g_tmp[8+2-1:2];
assign vi_b = vi_b_tmp[8+2-1:2];

`ifdef MINIMIG_TOPLEVEL_DITHER

wire [ 8-1:0] dither_r;
wire [ 8-1:0] dither_g;
wire [ 8-1:0] dither_b;
wire f_cnt;

assign dither_r = vi_r;
assign dither_g = vi_g;
assign dither_b = vi_b;
assign f_cnt=1'b0;

`else
//// dither ////
reg  [24-1:0] seed=0;
reg  [24-1:0] randval=0;
reg  [24-1:0] seed_old=0;
wire [26-1:0] hpf_sum;
reg           f_cnt=0;
reg           h_cnt=0;
reg           v_cnt=0;
wire [ 8-1:0] r_dither_err;
wire [ 8-1:0] g_dither_err;
wire [ 8-1:0] b_dither_err;
reg  [ 8-1:0] r_err=0;
reg  [ 8-1:0] g_err=0;
reg  [ 8-1:0] b_err=0;
wire [ 8-1:0] r_dither_tsp;
wire [ 8-1:0] g_dither_tsp;
wire [ 8-1:0] b_dither_tsp;
wire [ 8-1:0] r_dither_rnd;
wire [ 8-1:0] g_dither_rnd;
wire [ 8-1:0] b_dither_rnd;
wire [ 8-1:0] dither_r;
wire [ 8-1:0] dither_g;
wire [ 8-1:0] dither_b;

// pseudo random number generator
always @ (posedge clk) begin
  if (vss) begin
    seed <= #1 24'h654321;
    seed_old <= #1 24'd0;
    randval <= #1 24'd0;
  end else if (|dither) begin
    seed <= #1 {seed[22:0], ~(seed[23] ^ seed[22] ^ seed[21] ^ seed[16])};
    seed_old <= #1 seed;
    randval <= #1 hpf_sum[25:2];
  end
end

assign hpf_sum = {2'b00,randval} + {2'b00, seed} - {2'b00, seed_old};

// horizontal / vertical / frame marker
always @ (posedge clk) begin
  if (vss) begin
    f_cnt <= #1 ~f_cnt;
    v_cnt <= #1 1'b0;
    h_cnt <= #1 1'b0;
  end else if (|dither) begin
    if (sd_lbuf_rd == {1'b0,htotal[8:1],2'b11}) v_cnt <= #1 ~v_cnt;
    h_cnt <= #1 ~h_cnt;
  end
end

// dither add previous error / 2
assign r_dither_err = &vi_r[7:2] ? vi_r[7:0] : vi_r[7:0] + {6'b000000, r_err[1:0]};
assign g_dither_err = &vi_g[7:2] ? vi_g[7:0] : vi_g[7:0] + {6'b000000, g_err[1:0]};
assign b_dither_err = &vi_b[7:2] ? vi_b[7:0] : vi_b[7:0] + {6'b000000, b_err[1:0]};

// temporal/spatial dithering
assign r_dither_tsp = &r_dither_err[7:2] ? r_dither_err[7:0] : r_dither_err[7:0] + {6'b000000, (dither[0] & (f_cnt ^ v_cnt ^ h_cnt) & r_dither_err[1]), 1'b0};
assign g_dither_tsp = &g_dither_err[7:2] ? g_dither_err[7:0] : g_dither_err[7:0] + {6'b000000, (dither[0] & (f_cnt ^ v_cnt ^ h_cnt) & g_dither_err[1]), 1'b0};
assign b_dither_tsp = &b_dither_err[7:2] ? b_dither_err[7:0] : b_dither_err[7:0] + {6'b000000, (dither[0] & (f_cnt ^ v_cnt ^ h_cnt) & b_dither_err[1]), 1'b0};

// random dithering
assign r_dither_rnd = &r_dither_tsp[7:2] ? r_dither_tsp[7:0] : r_dither_tsp[7:0] + {7'b0000000, dither[1] & randval[0]};
assign g_dither_rnd = &g_dither_tsp[7:2] ? g_dither_tsp[7:0] : g_dither_tsp[7:0] + {7'b0000000, dither[1] & randval[0]};
assign b_dither_rnd = &b_dither_tsp[7:2] ? b_dither_tsp[7:0] : b_dither_tsp[7:0] + {7'b0000000, dither[1] & randval[0]};

// dither error
always @ (posedge clk) begin
  if (vss) begin
    r_err <= #1 8'd0;
    g_err <= #1 8'd0;
    b_err <= #1 8'd0;
  end else if (|dither) begin
    r_err <= #1 {6'b000000, r_dither_rnd[1:0]};
    g_err <= #1 {6'b000000, g_dither_rnd[1:0]};
    b_err <= #1 {6'b000000, b_dither_rnd[1:0]};
  end
end

assign dither_r = r_dither_rnd;
assign dither_g = g_dither_rnd;
assign dither_b = b_dither_rnd;

`endif

//// scanlines ////
reg            sl_en=0;                 // scanline enable
reg  [  8-1:0] sl_r=0;                  // scanline data output
reg  [  8-1:0] sl_g=0;                  // scanline data output
reg  [  8-1:0] sl_b=0;                  // scanline data output
reg  [  8-1:0] ns_r;
reg  [  8-1:0] ns_g;
reg  [  8-1:0] ns_b;
reg            ns_csync;
reg            ns_osd_blank;
reg            ns_osd_pixel;

// LUT-based scanlines - means we can calculate the light counterpart for dark pixels
// in linear rather than device space, and could potentially upload custom curves
// from the Amiga itself!

wire [7:0] sl_r_dk;
wire [7:0] sl_r_lt;
wire [7:0] sl_g_dk;
wire [7:0] sl_g_lt;
wire [7:0] sl_b_dk;
wire [7:0] sl_b_lt;

scanlines_rom redgreenrom (
	.clk(clk),
	.addr_a(dither_r),
	.q1_a(sl_r_dk),
	.q2_a(sl_r_lt),
	.addr_b(dither_g),
	.q1_b(sl_g_dk),
	.q2_b(sl_g_lt)
);

scanlines_rom bluerom (
	.clk(clk),
	.addr_a(dither_b),
	.q1_a(sl_b_dk),
	.q2_a(sl_b_lt),
	.addr_b(0),
	.q1_b(),
	.q2_b()
);


// "balanced" scanlines - see https://www.buffee.ca/scanlines/
// Done by averaging the bright/dark line back to the original
// value exactly (bright=min(2v,255), dark=max(0,2v-255)), but that also
// means bright and dark converge to the same value as v approaches 0 or
// 255 - full saturated colors end up with no visible scanline at all.
// m1nl (Mateusz Nalewajski) solved this by adding SL_GAP which floors
// the bright/dark difference at full brightness, at the cost of a slight
// (SL_GAP/2 at most) dimming of near-white highlights.

localparam [  8-1:0] SL_GAP = 8'd32;
function [  8-1:0] sl_bright;
  input [  8-1:0] v;
  begin
    sl_bright = {v[6:0], 1'b0} | {8{v[7]}};
  end
endfunction
function [  8-1:0] sl_dark;
  input [  8-1:0] v;
  reg  [  8-1:0] raw;
  begin
    raw = {v[6:0], 1'b1} & {8{v[7]}};
    sl_dark = (raw > (8'd255 - SL_GAP)) ? (8'd255 - SL_GAP) : raw;
  end
endfunction

wire [7:0] sl_r1_lt = sl_bright(dither_r[7:0]);
wire [7:0] sl_r1_dk = sl_dark(dither_r[7:0]);
wire [7:0] sl_g1_lt = sl_bright(dither_g[7:0]);
wire [7:0] sl_g1_dk = sl_dark(dither_g[7:0]);
wire [7:0] sl_b1_lt = sl_bright(dither_b[7:0]);
wire [7:0] sl_b1_dk = sl_dark(dither_b[7:0]);

// scanline enable
always @ (posedge clk) begin
  if (hss) // reset at horizontal sync start
    sl_en <= #1 1'b0;
  else if (sd_lbuf_rd == {1'b0,htotal[8:1],2'b11}) // set at end of scandoubled line
    sl_en <= #1 1'b1;
end

// scanlines for scandoubled lines
always @ (posedge clk) begin
	sl_r <= scanline[1] ? (sl_en ? sl_r_dk : sl_r_lt) : (scanline[0] ? (sl_en ? sl_r1_dk : sl_r1_lt) : dither_r);
	sl_g <= scanline[1] ? (sl_en ? sl_g_dk : sl_g_lt) : (scanline[0] ? (sl_en ? sl_g1_dk : sl_g1_lt) : dither_g);
	sl_b <= scanline[1] ? (sl_en ? sl_b_dk : sl_b_lt) : (scanline[0] ? (sl_en ? sl_b1_dk : sl_b1_lt) : dither_b);
end

// scanlines for non-scandoubled lines
always @ (posedge clk) begin
  ns_r          <= #1 ((!dblscan && f_cnt && scanline[1]) ? 8'h00 : ((!dblscan && f_cnt && scanline[0]) ? {1'b0, red_in[7:1]}   : red_in));
  ns_g          <= #1 ((!dblscan && f_cnt && scanline[1]) ? 8'h00 : ((!dblscan && f_cnt && scanline[0]) ? {1'b0, green_in[7:1]} : green_in));
  ns_b          <= #1 ((!dblscan && f_cnt && scanline[1]) ? 8'h00 : ((!dblscan && f_cnt && scanline[0]) ? {1'b0, blue_in[7:1]}  : blue_in));
  ns_csync      <= #1 _csync_in;
  ns_osd_blank  <= #1 osd_blank;
  ns_osd_pixel  <= #1 osd_pixel;
end


//// bypass mux ////
wire           bm_hsync;
wire           bm_vsync;
wire           bm_blank;
wire [  8-1:0] bm_r;
wire [  8-1:0] bm_g;
wire [  8-1:0] bm_b;
wire           bm_osd_blank;
wire           bm_osd_pixel;

assign selcsync     = dblscan ? 1'b0 : varbeamen ? 1'b0 : 1'b1;
assign bm_blank     = dblscan ? ( (long_frame & ~track_vsync) ? sd_bbuf_o : sd_lbuf_o_d[30] ) : blank_in;
assign bm_hsync     = dblscan ? sd_lbuf_o_d[29] : _hsync_in;
assign bm_vsync     = (dblscan & track_vsync) ? _vsync_sd_d     : _vsync_in;
//assign bm_hsync     = dblscan ? sd_lbuf_o_d[29] : varbeamen ? _hsync_in : ns_csync;
//assign bm_vsync     = dblscan ? _vsync_in       : varbeamen ? _vsync_in : 1'b1;
assign bm_r         = dblscan ? sl_r            : varbeamen ? red_in    : ns_r;
assign bm_g         = dblscan ? sl_g            : varbeamen ? green_in  : ns_g;
assign bm_b         = dblscan ? sl_b            : varbeamen ? blue_in   : ns_b;
assign bm_osd_blank = dblscan ? sd_lbuf_o_d[28] : varbeamen ? osd_blank : ns_osd_blank;
assign bm_osd_pixel = dblscan ? sd_lbuf_o_d[27] : varbeamen ? osd_pixel : ns_osd_pixel;
assign osd_blank_out = dblscan ? sd_lbuf_o_d[28] : osd_blank;
assign osd_pixel_out = dblscan ? sd_lbuf_o_d[27] : osd_pixel;


`ifdef MINIMIG_TOPLEVEL_DITHER
`define MINIMIG_TOPLEVEL_OSD
`endif

//// osd ////
wire [  8-1:0] osd_r;
wire [  8-1:0] osd_g;
wire [  8-1:0] osd_b;

`ifdef MINIMIG_TOPLEVEL_OSD

assign osd_r = bm_r;
assign osd_g = bm_g;
assign osd_b = bm_b;

`else

assign osd_r = (bm_osd_blank ? (bm_osd_pixel ? OSD_R : {2'b00, bm_r[7:2]}) : bm_r);
assign osd_g = (bm_osd_blank ? (bm_osd_pixel ? OSD_G : {2'b00, bm_g[7:2]}) : bm_g);
assign osd_b = (bm_osd_blank ? (bm_osd_pixel ? OSD_B : {2'b10, bm_b[7:2]}) : bm_b);

`endif

//// output registers ////
always @ (posedge clk) begin
  _hsync_out <= #1 bm_hsync;
  _vsync_out <= #1 bm_vsync;
  _csync_out <= #1 dblscan ? ~(~bm_hsync ^ ~bm_vsync) : _csync_in;
  blank_out  <= #1 bm_blank;
  red_out    <= #1 osd_r;
  green_out  <= #1 osd_g;
  blue_out   <= #1 osd_b;
end

endmodule

