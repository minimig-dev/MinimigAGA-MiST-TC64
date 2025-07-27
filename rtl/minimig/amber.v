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


module amber #(parameter FRAMING_BITS=11)
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
reg  [ FRAMING_BITS-1:0] sd_lbuf_wr=0;            // line buffer write pointer

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

//// Horizontal scaling / interpolation ////

`ifdef MINIMIG_ASPECT_CORRECTION

// If we're doing aspect correction we need to generate sync and blank signals using counters rather than the buffer,
// since we won't be replaying the buffer at exactly double speed.
reg [FRAMING_BITS-1:0] hb_stop;
reg [FRAMING_BITS-1:0] hs_stop;
reg [FRAMING_BITS-1:0] hb_start;
reg [FRAMING_BITS-1:0] hs_start=0;
reg hb_del;

reg hb_gen;
reg hs_gen;
reg invb;

always @(posedge clk) begin
	hb_del <= blank_in;
	if (_hsync_in && !_hsync_in_del) begin
		if(invb)
			hb_stop<=-1;
		invb<=1'b1;
		hs_stop <= sd_lbuf_wr;
	end
	if(blank_in && !hb_del)
		hb_start <= sd_lbuf_wr;
	if(!blank_in && hb_del) begin
		hb_stop <= sd_lbuf_wr;
		invb<=1'b0;
	end
end

always @(posedge clk) begin
	if(sd_lbuf_rd_reset)
		hs_gen<=1'b0;
	if(sd_lbuf_rd=={1'b0,hs_stop[FRAMING_BITS-1:1]})
		hs_gen<=1'b1;
	if(sd_lbuf_rd=={1'b0,hb_start[FRAMING_BITS-1:1]})
		hb_gen<=1'b1;		
	if(sd_lbuf_rd=={1'b0,hb_stop[FRAMING_BITS-1:1]})
		hb_gen<=1'b0;
end

// When the output is scaled, the consume rate will be different from the fill rate,
// so we need to use different buffer regions. Maintain MSB for input and output.

reg sd_wr_msb;
reg sd_rd_msb;

always @(posedge clk) begin
	if(hss) begin
		sd_rd_msb <= sd_wr_msb;
		sd_wr_msb <= ~ sd_wr_msb;
	end
end

// Deal with horizontal filtering to improve the image quality.
// Rather than interpolate at the output, we integrate over multiple pixels before
// writing to the scandoubler buffer.

localparam hi_fracwidth=8; // Must be at least 8. No real advantage to increasing this.

wire [FRAMING_BITS-1:0] hi_whole; // Index into pixel buffer
wire [hi_fracwidth-1:0] hi_fraction; // Blend factor
wire [hi_fracwidth:0] hi_fraction_inv; // Blend factor
wire hi_step; // Move onto the next pixel

reg [FRAMING_BITS-1:0] centre_offset;
reg [ FRAMING_BITS-1:0] sd_wrptr;            // line buffer write pointer

reg hb_gen_d;
reg newfrac;

wire hfilter_en = |hires ? hr_filter[0] : lr_filter[0];
always @(posedge clk) begin
	centre_offset<= htotal[8:2]; 
	hb_gen_d <= hb_gen;

	newfrac<=1'b0;
	if(hb_gen && !hb_gen_d)
		newfrac <= 1'b1;		// Update the scale factor on the rising edge of HBlank	
end


// Apply OSD early so it can be scaled along with the Amiga video

wire [8:0] red_early_osd = osd_blank ? (osd_pixel ? {OSD_R,1'b0} : {2'b00, red_in[7:1]}) : {red_in,1'b0};
wire [8:0] green_early_osd = osd_blank ? (osd_pixel ? {OSD_G,1'b0} : {2'b00, green_in[7:1]}) : {green_in,1'b0};
wire [8:0] blue_early_osd = osd_blank ? (osd_pixel ? {OSD_B,1'b0} : {2'b10, blue_in[7:1]}) : {blue_in,1'b0};

wire osd_pixel_masked = hfilter_en ? 1'b0 : osd_pixel;
wire osd_blank_masked = hfilter_en ? 1'b0 : osd_blank;

// Blend multiple pixes, applying appropriate weights to the first and last pixel in a span. 

// We're mapping from 16:9 to 4:3, aka 16:9 to 12:9
// The scale factor is thus 16/12, or 4/3, doubled to 8/3
// because scandoubled lines are consumed at twice the rate they're recorded.

frac_interp #(.bitwidth(FRAMING_BITS),.fracwidth(hi_fracwidth)) interp_core_h (
	.clk(clk),
	.reset_n(1'b1),
	.num('h8),
	.den('h3),
	.limit(-1), // No limit
	.newfraction(hss),
	.step_reset(hss),
	.step_in(1'b1),
	.step_offset(16'h0),
	.pan_offset(0),
	.centre_offset(0),
	.step_out(hi_step),
	.fraction(hi_fraction),
	.fraction_inv(hi_fraction_inv)
);

reg [FRAMING_BITS-1:0] hi_whole_d;
wire [26:0] rgb_current;
wire [26:0] rgb_interp;

wire [7:0] hfilter_fraction = hi_fraction[hi_fracwidth-1:hi_fracwidth-8];
wire [8:0] hfilter_fraction_inv = hi_fraction_inv[hi_fracwidth:hi_fracwidth-8];


assign rgb_current = {red_early_osd,green_early_osd,blue_early_osd};
wire hi_step_out;
scandoubler_rgb_integrate rgbinterp_h1
(
	.clk_sys(clk),
	.inpixel(hi_step),
	.fraction(hfilter_fraction),
	.fraction_inv(hfilter_fraction_inv),
	.rgb_in(rgb_current),
	.rgb_out(rgb_interp),
	.outpixel(hi_step_out)
);

// Advance the output pointer 3 times every 8 clocks.
// Disable scaling during vblank just so the idle portion of the buffer gets
// backfilled with (near) black.
always @(posedge clk) begin
	if(hi_step_out)
		sd_wrptr <= sd_wrptr+1;
	if(hss)
		sd_wrptr<=centre_offset;	
	if((!hfilter_en) || (!_vsync_in))
		sd_wrptr <= sd_lbuf_wr[FRAMING_BITS-1:1];
end

wire sd_wr_en;
assign sd_wr_en = (hi_step_out) | (~_vsync_in) | (~hfilter_en);

reg [30-1:0] hi_rgb;

reg blank_d;
reg blank_d2;

always @(posedge clk) begin
	if(hi_step_out) begin
		hi_rgb <= {sd_lbuf_o[29:27],rgb_interp};
		blank_d2 <= blank_in;
		blank_d <= blank_in & blank_d2;
	end
end

// Backfill the buffer with RGB 080808 just so the inactive area isn't black, and doesn't get
// cropped-and-scaled away by overly-smart TVs / Monitors 
assign hi_r = hfilter_en ? (_vsync_in & ~blank_d ? hi_rgb[26:18] : 9'h08) : {red_in[7:0]  , 1'b0};
assign hi_g = hfilter_en ? (_vsync_in & ~blank_d ? hi_rgb[17:9] : 9'h08) : {green_in[7:0], 1'b0};
assign hi_b = hfilter_en ? (_vsync_in & ~blank_d ? hi_rgb[8:0] : 9'h08) : {blue_in[7:0] , 1'b0};

// Create linebuffer of twice the size so we can fill and ready from alternative lines.
// (necessary because in and out are no longer in lockstep when scaling.)
reg  [ 31-1:0] sd_lbuf [0:2048-1];      // line buffer for scan doubling (there are 908/910 hires pixels in every line)

`else
// The traditional path without Aspect ratio correction.

wire sd_wr_msb = 1'b0;
wire sd_rd_msb = 1'b0;

wire osd_pixel_masked = osd_pixel;
wire osd_blank_masked = osd_blank;

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

wire [ FRAMING_BITS:0] sd_wrptr;            // line buffer write pointer
assign sd_wrptr = sd_lbuf_wr[FRAMING_BITS-1:1];
wire sd_wr_en = 1'b1;

reg  [ 31-1:0] sd_lbuf [0:1024-1];      // line buffer for scan doubling (there are 908/910 hires pixels in every line)

wire hb_gen = sd_lbuf_o[30];

`endif

//// scandoubler ////
reg  [ 31-1:0] sd_lbuf_o=0;             // line buffer output register
reg  [ 31-1:0] sd_lbuf_o_d=0;           // compensation for one clock delay of the second line buffer
reg  [ FRAMING_BITS-1:0] sd_lbuf_rd=0;            // line buffer read pointer
reg  [ FRAMING_BITS-1:0] vsync_event;
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
	if(sd_wr_en)
		sd_lbuf[{sd_wr_msb,sd_wrptr[9:0]}] <= #1 {blank_in, _hsync_in, osd_blank_masked, osd_pixel_masked, hi_r, hi_g, hi_b};
    // read
    sd_lbuf_o <= #1 sd_lbuf[{sd_rd_msb,sd_lbuf_rd[9:0]}];
    // delayed data
    
    sd_bbuf[sd_lbuf_rd[FRAMING_BITS-1:0]] <= #1 hb_gen;
    sd_bbuf_o <= sd_bbuf[sd_lbuf_rd[FRAMING_BITS-1:0]];

    sd_lbuf_o_d <= #1 sd_lbuf_o;
  end
end


wire [30-1:0] vi_rgb = sd_lbuf_o;

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
  vi_lbuf[sd_lbuf_rd[9:0]] <= #1 vi_rgb[29:0];
  // read
  vi_lbuf_o <= #1 vi_lbuf[sd_lbuf_rd[9:0]];
end

// interpolate & mux
assign vi_r_tmp = vi_en ? ({1'b0, sd_lbuf_o_d[26:18]} + {1'b0, vi_rgb[26:18]}) : {sd_lbuf_o_d[26:18], 1'b0};
assign vi_g_tmp = vi_en ? ({1'b0, sd_lbuf_o_d[17:09]} + {1'b0, vi_rgb[17:09]}) : {sd_lbuf_o_d[17:09], 1'b0};
assign vi_b_tmp = vi_en ? ({1'b0, sd_lbuf_o_d[ 8: 0]} + {1'b0, vi_rgb[ 8: 0]}) : {sd_lbuf_o_d[ 8: 0], 1'b0};

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

// scanline enable
always @ (posedge clk) begin
  if (hss) // reset at horizontal sync start
    sl_en <= #1 1'b0;
  else if (sd_lbuf_rd == {1'b0,htotal[8:1],2'b11}) // set at end of scandoubled line
    sl_en <= #1 1'b1;
end

// scanlines for scandoubled lines
always @ (posedge clk) begin
  sl_r <= #1 ((sl_en && scanline[1]) ? 8'h00 : ((sl_en && scanline[0]) ? {1'b0, dither_r[7:1]} : dither_r));
  sl_g <= #1 ((sl_en && scanline[1]) ? 8'h00 : ((sl_en && scanline[0]) ? {1'b0, dither_g[7:1]} : dither_g));
  sl_b <= #1 ((sl_en && scanline[1]) ? 8'h00 : ((sl_en && scanline[0]) ? {1'b0, dither_b[7:1]} : dither_b));
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

assign bm_vsync     = (dblscan & track_vsync) ? _vsync_sd_d     : _vsync_in;
//assign bm_hsync     = dblscan ? sd_lbuf_o_d[29] : varbeamen ? _hsync_in : ns_csync;
//assign bm_vsync     = dblscan ? _vsync_in       : varbeamen ? _vsync_in : 1'b1;
assign bm_osd_blank = dblscan ? sd_lbuf_o_d[28] : varbeamen ? osd_blank : ns_osd_blank;
assign bm_osd_pixel = dblscan ? sd_lbuf_o_d[27] : varbeamen ? osd_pixel : ns_osd_pixel;
assign osd_blank_out = dblscan ? sd_lbuf_o_d[28] : osd_blank;
assign osd_pixel_out = dblscan ? sd_lbuf_o_d[27] : osd_pixel;

`ifdef MINIMIG_ASPECT_CORRECTION

assign bm_blank     = dblscan ? ( (long_frame & ~track_vsync) ? sd_bbuf_o : hb_gen_d ) : blank_in;
assign bm_hsync     = dblscan ? hs_gen : _hsync_in;

`else

assign bm_blank     = dblscan ? ( (long_frame & ~track_vsync) ? sd_bbuf_o : sd_lbuf_o_d[30] ) : blank_in;
assign bm_hsync     = dblscan ? sd_lbuf_o_d[29] : _hsync_in;

`endif

assign bm_r         = dblscan ? sl_r            : varbeamen ? red_in    : ns_r;
assign bm_g         = dblscan ? sl_g            : varbeamen ? green_in  : ns_g;
assign bm_b         = dblscan ? sl_b            : varbeamen ? blue_in   : ns_b;

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

