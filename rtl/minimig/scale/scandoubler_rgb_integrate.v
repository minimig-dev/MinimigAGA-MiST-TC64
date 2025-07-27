// Perform three integrations in parallel to process an RGB triple

module scandoubler_rgb_integrate#(
	parameter signalwidth=9,
	parameter fracwidth = 8,
	parameter scale = 3,	// Output scaling to normalize the range
	parameter shift = 3		// If we're integrating over 8/3 (i.e. ~2.6) pixe
	                        // ls then the normalization will be (sum * 3) /8 (i.e. >> 3)
) (
	input clk_sys,
	input inpixel,	// input strobe
	input [fracwidth-1:0] fraction,	// Range 0 to 111...111
	input [fracwidth:0] fraction_inv, // One extra bit to accommodate 1000...000 as the inverse of 0
	input [signalwidth*3-1:0] rgb_in,
	output [signalwidth*3-1:0] rgb_out,
	output outpixel	// output strobe
);

pixel_integrate #(.signalwidth(signalwidth),.fracwidth(fracwidth), .scale(scale), .shift(shift)) interp_red
(
	.clk(clk_sys),
	.inpixel(inpixel),
	.frac(fraction),
	.frac_inv(fraction_inv),
	.in(rgb_in[signalwidth*3-1:signalwidth*2]),
	.out(rgb_out[signalwidth*3-1:signalwidth*2]),
	.outpixel(outpixel)
);

pixel_integrate #(.signalwidth(signalwidth),.fracwidth(fracwidth), .scale(scale), .shift(shift)) interp_green
(
	.clk(clk_sys),
	.inpixel(inpixel),
	.frac(fraction),
	.frac_inv(fraction_inv),
	.in(rgb_in[signalwidth*2-1:signalwidth]),
	.out(rgb_out[signalwidth*2-1:signalwidth])
);

pixel_integrate #(.signalwidth(signalwidth),.fracwidth(fracwidth), .scale(scale), .shift(shift)) interp_blue
(
	.clk(clk_sys),
	.inpixel(inpixel),
	.frac(fraction),
	.frac_inv(fraction_inv),
	.in(rgb_in[signalwidth-1:0]),
	.out(rgb_out[signalwidth-1:0])
);

endmodule

