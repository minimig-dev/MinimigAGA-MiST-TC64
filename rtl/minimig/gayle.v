// Copyright 2008, 2009 by Jakub Bednarski
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
// -- JB --
//
// 2008-10-06	- initial version
// 2008-10-08	- interrupt controller implemented, kickstart boots
// 2008-10-09	- working identify device command implemented (hdtoolbox detects our drive)
//				- read command reads data from hardfile (fixed size and name, only one sector read size supported, workbench sees hardfile partition)
// 2008-10-10	- multiple sector transfer supported: works ok, sequential transfers with direct spi read and 28MHz CPU from 400 to 520 KB/s
//				- arm firmare seekfile function very slow: seeking from start to 20MB takes 144 ms (some software improvements required)
// 2008-10-30	- write support added
// 2008-12-31	- added hdd enable
// 2009-05-24	- clean-up & renaming
// 2009-08-11	- hdd_ena enables Master & Slave drives
// 2009-11-18	- changed sector buffer size
// 2010-04-13	- changed sector buffer size
// 2010-08-10	- improved BSY signal handling

module gayle
(
	input	clk,
	input clk7_en,
	input	reset,
	input	[23:1] address_in,
	input	[15:0] data_in,
	output	[15:0] data_out,
	input	rd,
	input	hwr,
	input	lwr,
	input	sel_ide,			// $DAxxxx
	input	sel_gayle,			// $DExxxx
	output	irq,
	output	nrdy,				// fifo is not ready for reading 
	input	[1:0] hdd0_ena,		// enables Master & Slave drives on primary channel
	input	[1:0] hdd1_ena,		// enables Master & Slave drives on secondary channel

	output	hdd_cmd_req,
	output	hdd_dat_req,
	input	[2:0] hdd_addr,
	input	[15:0] hdd_data_out,
	output	[15:0] hdd_data_in,
	input	hdd_wr,
	input	hdd_status_wr,
	input	hdd_data_wr,
	input	hdd_data_rd,
	output hd_fwr,
	output hd_frd,
	output hdd_step
);

localparam VCC = 1'b1;
localparam GND = 1'b0;

//0xda2000 Data
//0xda2004 Error | Feature
//0xda2008 SectorCount
//0xda200c SectorNumber
//0xda2010 CylinderLow
//0xda2014 CylinderHigh
//0xda2018 Device/Head
//0xda201c Status | Command
//0xda3018 Control

/*
memory map:

$DA0000 - $DA0FFFF : CS1 16-bit speed
$DA1000 - $DA1FFFF : CS2 16-bit speed
$DA2000 - $DA2FFFF : CS1 8-bit speed
$DA3000 - $DA3FFFF : CS2 8-bit speed
$DA4000 - $DA7FFFF : reserved
$DA8000 - $DA8FFFF : IDE INTREQ state status register (not implemented as scsi.device doesn't use it)
$DA9000 - $DA9FFFF : IDE INTREQ change status register (writing zeros resets selected bits, writing ones doesn't change anything) 
$DAA000 - $DAAFFFF : IDE INTENA register (r/w, only MSB matters)
 

command class:
PI (PIO In)
PO (PIO Out)
ND (No Data)

Status:
#6 - DRDY	- Drive Ready
#7 - BSY	- Busy
#3 - DRQ	- Data Request
#0 - ERR	- Error
INTRQ	- Interrupt Request

*/
 

// address decoding signals
wire 	sel_gayleid;  // Gayle ID register select
wire 	sel_tfr;      // HDD task file registers select
wire  sel_cs;       // Gayle IDE CS
wire 	sel_intreq;	  // Gayle interrupt request status register select
wire 	sel_intena;	  // Gayle interrupt enable register select
wire  sel_cfg;      // Gayle CFG

// internal registers
reg         intena; // Gayle IDE interrupt enable bit
wire  [1:0] intreq; // Gayle IDE interrupt request bit
reg   [3:0] cfg;
reg   [1:0] cs;
reg   [5:0] cs_mask;

wire 	fifo_rd;
wire 	fifo_wr;

// gayle id reg
reg		[1:0] gayleid_cnt;	// sequence counter
wire	gayleid;			// output data (one bit wide)

// hd leds
assign hd_fwr = fifo_wr;
assign hd_frd = fifo_rd;

// address decoding
assign sel_gayleid = sel_gayle && address_in[15:12]==4'b0001 ? VCC : GND;	  // GAYLEID, $DE1xxx
assign sel_tfr = sel_ide && address_in[15:14]==2'b00 && (!address_in[12] || |hdd1_ena) ? VCC : GND; // $DA0xxx, $DA1xxx, $DA2xxx, $DA3xxx
assign sel_cs     = sel_ide && address_in[15:12]==4'b1000 ? VCC : GND;      // GAYLE_CS_1200,  $DA8xxx
assign sel_intreq = sel_ide && address_in[15:12]==4'b1001 ? VCC : GND;	    // GAYLE_IRQ_1200, $DA9xxx
assign sel_intena = sel_ide && address_in[15:12]==4'b1010 ? VCC : GND;	    // GAYLE_INT_1200, $DAAxxx
assign sel_cfg    = sel_ide && address_in[15:12]==4'b1011 ? VCC : GND;      // GAYLE_CFG_1200, $DABxxx

//===============================================================================================//

// gayle cs
always @ (posedge clk) begin
  if (clk7_en) begin
    if (reset) begin
      cs_mask <= #1 6'd0;
      cs      <= #1 2'd0;
    end else if (hwr && sel_cs) begin
      cs_mask <= #1 data_in[15:10];
      cs      <= #1 data_in[9:8];
    end
  end
end

// gayle cfg
always @ (posedge clk) begin
  if (clk7_en) begin
    if (reset)
      cfg <= #1 4'd0;
    if (hwr && sel_cfg) begin
      cfg <= #1 data_in[15:12];
    end
  end
end

// IDE interrupt enable register
always @(posedge clk)
	if (clk7_en) begin
		if (reset)
			intena <= GND;
		else if (sel_intena && hwr)
			intena <= data_in[15];
	end

// gayle id register: reads 1->1->0->1 on MSB
always @(posedge clk)
	if (clk7_en) begin
		if (sel_gayleid)
			if (hwr) // a write resets sequence counter
				gayleid_cnt <= 2'd0;
			else if (rd)
				gayleid_cnt <= gayleid_cnt + 2'd1;
	end

assign gayleid = ~gayleid_cnt[1] | gayleid_cnt[0]; // Gayle ID output data

assign irq = |intreq & intena; // interrupt request line (INT2)

wire [15:0] ide_out;

//data_out multiplexer
assign data_out = ide_out
         | (sel_cs      && rd  ? {(cs_mask[5] || |intreq), cs_mask[4:0], cs, 8'h0}: 16'h00_00)
         | (sel_intreq  && rd  ? {|intreq,     15'b000_0000_0000_0000}            : 16'h00_00)
         | (sel_intena  && rd  ? {intena,      15'b000_0000_0000_0000}            : 16'h00_00)
         | (sel_gayleid && rd  ? {gayleid,     15'b000_0000_0000_0000}            : 16'h00_00)
         | (sel_cfg     && rd  ? {cfg,         12'b0000_0000_0000}                : 16'h00_00);


//===============================================================================================//

wire intreq_ack = sel_intreq && hwr && !data_in[15];

ide ide (
	.clk(clk),
	.clk_en(1'b1/*clk7_en*/),
	.reset(reset),
	.sel_ide(sel_tfr),
	.sel_secondary(address_in[12]),
	.address_in(address_in[4:2]),
	.data_in(data_in),
	.data_out(ide_out),
	.rd(rd),
	.hwr(hwr),
	.lwr(lwr),
	.intreq(intreq),
	.intreq_ack({intreq_ack, intreq_ack}),
	.nrdy(nrdy),				// fifo is not ready for reading 
	.hdd0_ena(hdd0_ena),		// enables Master & Slave drives on primary channel
	.hdd1_ena(hdd1_ena),		// enables Master & Slave drives on secondary channel
	.fifo_rd(fifo_rd),
	.fifo_wr(fifo_wr),

	.hdd_cmd_req(hdd_cmd_req),
	.hdd_dat_req(hdd_dat_req),
	.hdd_addr(hdd_addr),
	.hdd_data_out(hdd_data_out),
	.hdd_data_in(hdd_data_in),
	.hdd_wr(hdd_wr),
	.hdd_status_wr(hdd_status_wr),
	.hdd_data_wr(hdd_data_wr),
	.hdd_data_rd(hdd_data_rd),
	.hdd_step(hdd_step)
);

endmodule
