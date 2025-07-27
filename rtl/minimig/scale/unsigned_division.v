module unsigned_division #(
	parameter bitwidth = 32
) (
	input clk,
	input reset_n,
	input [bitwidth-1:0] dividend,
	input [bitwidth-1:0] divisor,
	output reg [bitwidth-1:0] quotient,
	output reg [bitwidth-1:0] remainder,
	input req,
	output reg ack
);

reg ack_int;
reg [bitwidth-1:0] bitcounter;
reg [bitwidth-1:0] quot;
reg [bitwidth-1:0] div;
reg [bitwidth-1:0] remain;

localparam IDLE=0;
localparam RUN=1;
localparam FINALISE=2;

reg [1:0] state=IDLE;

always @(posedge clk) begin
	ack <= 1'b0;

	if(!reset_n) begin
		state <= IDLE;
	end else begin

		case (state)
			IDLE : begin
				if(req) begin
					remain=0;
					quot<=dividend;
					div<=divisor;
					/* verilator lint_off WIDTH */
					bitcounter<=(bitwidth-1);
					/* verilator lint_on WIDTH */
					state <= RUN;
				end			
			end
			
			RUN : begin
				if (remain[bitwidth-1])
					remain={remain[bitwidth-1-1:0],quot[bitwidth-1]} + div;
				else
					remain={remain[bitwidth-1-1:0],quot[bitwidth-1]} - div;

				quot[bitwidth-1:1]<=quot[bitwidth-1-1:0];
				quot[0]<=~remain[bitwidth-1];

				if(|bitcounter)
					bitcounter<=bitcounter-1'b1;
				else
					state <= FINALISE;
			end
			
			FINALISE : begin
				if (remain[bitwidth-1])
					remainder<=remain+div;
				else
					remainder<=remain;

				quotient<=quot;
				ack<=1'b1;
				state<=IDLE;
			
			end

		endcase
	end
end

endmodule

