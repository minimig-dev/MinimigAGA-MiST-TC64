module frac_interp #(parameter bitwidth=10, parameter fracwidth=16) (
	input  clk,
	input  reset_n,
	input  [bitwidth-1:0] num, // Larger value
	input  [bitwidth-1:0] den, // Smaller value
	input  [bitwidth-1:0] limit, // Blank after this value is reached (in input pixels).
	output [bitwidth-1:0] limit_out, // Anticipated size, in output pixels.
	input  newfraction,
	output reg ready,
	input  step_reset,
	input  step_in,
	input  [fracwidth-1:0] step_offset,
	input  [bitwidth-1:0] pan_offset,
	input  [bitwidth-1:0] centre_offset,
	output reg step_out,
	output [bitwidth-1:0] whole,
	output reg [fracwidth-1:0] fraction,
	output reg [fracwidth:0] fraction_inv,
	output blank
);

wire div_done;
wire [bitwidth+fracwidth-1:0] step;
wire [bitwidth+fracwidth-1:0] remain; /* not used */
	
unsigned_division #(.bitwidth(bitwidth+fracwidth)) div (
	.clk(clk),
	.reset_n(reset_n),
	.dividend({num,{fracwidth{1'b0}}}),
	.divisor({{fracwidth{1'b0}},den}),
	.quotient(step),
	.remainder(remain),
	.req(newfraction),
	.ack(div_done)
);

reg [bitwidth+fracwidth-1:0] spos;
wire [bitwidth-1:0] spos_whole = spos[bitwidth+fracwidth-1:fracwidth];
wire [fracwidth-1:0] spos_frac = spos[fracwidth-1:0];

reg [bitwidth-1:0] dpos;

reg [bitwidth-1:0] whole_i;
reg [bitwidth-1:0] offset;

reg [bitwidth+fracwidth-1:0] limit_out_fp;

always @(posedge clk) begin
	step_out<=1'b0;
	if (step_in) begin
		if(dpos>spos_whole) begin
			spos<=spos+step;
			fraction<=spos_frac;
			fraction_inv <= {1'b1,{fracwidth{1'b0}}}-spos_frac;
			step_out<=1'b1;
			whole_i<=whole_i+(dpos-spos_whole);
		end else begin
			fraction<=0;
			fraction_inv <= {1'b1,{fracwidth{1'b0}}};
		end
			
		if(|offset)
			offset<=offset-1;
		else begin
//			if((dpos-spos_whole)<2) // Seems to fail in Verilator - not sure why
			if(dpos<(spos_whole+2))
				dpos<=dpos+1'b1;
		end
	end
	
	if (newfraction || reset_n)
		ready <= 1'b0;

	if (|centre_offset && whole_i>limit) // HACK: Extend the span by one pixel when processing rows.
		offset<={bitwidth{1'b1}}; // Ensure the rest of the span is blanked

	if (!(|centre_offset) && whole_i==limit)
		offset<={bitwidth{1'b1}}; // Ensure the rest of the span is blanked

	if (step_reset || newfraction || !reset_n) begin
		spos<={pan_offset,step_offset};
		dpos<=pan_offset;
		whole_i<=pan_offset;
		offset<=centre_offset;
	end
		
	if(div_done) begin
		limit_out_fp <= step * limit;
		ready<=1'b1;
	end

end

assign limit_out = limit_out_fp[bitwidth+fracwidth-1:fracwidth];

assign whole=whole_i;

assign blank=|offset;

endmodule

