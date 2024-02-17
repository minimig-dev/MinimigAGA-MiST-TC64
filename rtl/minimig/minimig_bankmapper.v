//This module maps physical 512KB blocks of every memory chip to different memory ranges in Amiga


module minimig_bankmapper
(
	input	chip0,					// chip ram select: 1st 512 KB block
	input	chip1,					// chip ram select: 2nd 512 KB block
	input	chip2,					// chip ram select: 3rd 512 KB block
	input	chip3,					// chip ram select: 4th 512 KB block
	input	slow0,					// slow ram select: 1st 512 KB block
	input	slow1,					// slow ram select: 2nd 512 KB block
	input	slow2,					// slow ram select: 3rd 512 KB block
	input	kick,					// Kickstart ROM address range select
	input	kickext,				// Kickstart extended ROM select
	input	kick1mb,				// 1MB Kickstart 'upper' half
	input	cart,					// Action Replay memory range select
	input drivesounds,      // RAM buffer for uploading drive sounds
//	input	aron,					// Action Replay enable
	input	ecs,					// ECS chipset enable
	input	[3:0] memory_config,	// memory configuration
	output	reg [7:0] bank		// bank select
);

always @(*)
  begin
    bank[7:4] = { kick , kickext, chip3 | chip2 | chip1 | chip0, kick1mb | slow0 | slow1 | slow2 | cart | drivesounds};
    case (memory_config[1:0])
      2'b00 : bank[3:0] = {  1'b0,  1'b0,          1'b0, chip3 | chip2 | chip1 | chip0 }; // 0.5M CHIP
      2'b01 : bank[3:0] = {  1'b0,  1'b0, chip3 | chip1,                 chip2 | chip0 }; // 1.0M CHIP
      2'b10 : bank[3:0] = {  1'b0, chip2,         chip1,                         chip0 }; // 1.5M CHIP
      2'b11 : bank[3:0] = { chip3, chip2,         chip1,                         chip0 }; // 2.0M CHIP
    endcase
end


endmodule

