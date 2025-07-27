module pixel_integrate #(
	parameter signalwidth=8,
	parameter fracwidth = 8,
	parameter scale = 3,	// Output scaling to normalize the range
	parameter shift = 3		// If we're integrating over 8/3 (i.e. ~2.6) pixe
	                        // ls then the normalization will be (sum * 3) /8 (i.e. >> 3)
) (
	input clk,
	input inpixel,
	input [signalwidth-1:0] in,
	input [fracwidth-1:0] frac,	// Range 0 to 111...111
	input [fracwidth:0] frac_inv, // One extra bit to accommodate 1000...000 as the inverse of 0

	output reg outpixel,
	output [signalwidth-1:0] out
);

localparam headroom = shift;

reg [signalwidth+fracwidth:0] in_scaled;
reg [signalwidth+fracwidth:0] in_scaled_inv;

reg [headroom+signalwidth+fracwidth:0] sum;
reg [headroom+signalwidth+fracwidth:0] result;

reg inpixel_d;

always @(posedge clk) begin
	inpixel_d<=inpixel;

	in_scaled<=frac*in;
	in_scaled_inv<=frac_inv*in;

	outpixel <= 1'b0;

	if(inpixel_d) begin
		result <= scale * (sum + in_scaled);
		sum <= in_scaled_inv;
		outpixel <= 1'b1;
	end else begin
		sum <= sum + in_scaled_inv;
	end
end

assign out=result[signalwidth+fracwidth+shift-1:fracwidth+shift];

endmodule

