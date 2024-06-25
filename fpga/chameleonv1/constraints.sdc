
# time information
set_time_format -unit ns -decimal_places 3


#create clocks
create_clock -name pll_in_clk -period 125 [get_ports {clk8}]

# pll clocks
derive_pll_clocks

# name PLL clocks
set pll_sdram "virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[0]"
set clk_114   "virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[1]"
set clk_28    "virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[2]"

# generated clocks
create_generated_clock -name clk_sdram -source [get_pins {virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[0]}] [get_ports {sd_clk}]
create_generated_clock -name clk_spi -source [get_pins $clk_114] -divide_by 4 [get_nets {minimig_virtual_top:virtual_top|cfide:mycfide|sck}]


# name SDRAM ports
set sdram_outputs [get_ports {sd_addr[*] sd_ldqm sd_udqm sd_we_n sd_cas_n sd_ras_n sd_ba_* }]
set sdram_dqoutputs [get_ports {sd_data[*]}]
set sdram_inputs  [get_ports {sd_data[*]}]


# clock groups



# clock uncertainty
derive_clock_uncertainty


# MUX constraints
# Really shouldn't need to worry about these since the clock edge will
# be 8.8ns away from the data.  Provided the signals all stay reasonably
# together there shouldn't be a problem.

# mux[0] seems to be on a tortuous path compared with the others
# Since it has a whole clock cycle to propagate before mux_clk triggers
# we multicycle it, but give it tight timing requirements on the second
# cycle, giving the router freedom use about 1.2 cycles, since 1 cycle
# seems to be unattainable.

set_input_delay -clock [get_clocks $clk_114] -min 4.0 [get_ports {mux_q[*]}]
set_input_delay -clock [get_clocks $clk_114] -max 4.5 [get_ports {mux_q[*]}]
set_output_delay -clock [get_clocks $clk_114] -min 6.0 [get_ports {mux[*]}]
set_output_delay -clock [get_clocks $clk_114] -max 6.5 [get_ports {mux[*]}]
set_output_delay -clock [get_clocks $clk_114] -min 0.0 [get_ports {mux_clk}]
set_output_delay -clock [get_clocks $clk_114] -max 0.5 [get_ports {mux_clk}]

# SDRAM constraints
# input delay
set_input_delay -clock clk_sdram -max 3.0 $sdram_inputs
set_input_delay -clock clk_sdram -min 2.0 $sdram_inputs
# output delay
#set_output_delay -clock clk_sdram -max  1.5 [get_ports {sd_clk}]
#set_output_delay -clock clk_sdram -min  0.5 [get_ports {sd_clk}]

set_output_delay -clock clk_sdram -max  1.5 $sdram_outputs
set_output_delay -clock clk_sdram -max  1.5 $sdram_dqoutputs
#set_output_delay -clock clk_sdram -min -0.8 $sdram_outputs
set_output_delay -clock clk_sdram -min -0.8 $sdram_outputs
set_output_delay -clock clk_sdram -min -0.8 $sdram_dqoutputs

set_input_delay -clock $clk_114 0.5 [get_ports {dotclock_n ioef_n phi2_n romlh_n spi_miso usart_cts}]
set_output_delay -clock $clk_114 0.5 [get_ports {mux_d[*]}]


# false paths

set_false_path -from [get_clocks {virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[1]}] -to [get_clocks {pll_in_clk}]
set_false_path -from {gen_reset:myReset|nreset*} -to {reset_28}
set_false_path -from [get_clocks {virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[1]}] -to [get_clocks {clk_spi}]
set_false_path -from [get_clocks {virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[2]}] -to [get_clocks {clk_spi}]
set_false_path -from [get_clocks {clk_spi}] -to [get_clocks {virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[1]}]
set_false_path -from {virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[0]} -to {sd_clk}

set_false_path -to {sigma*}
set_false_path -to {red[*]}
set_false_path -to {grn[*]}
set_false_path -to {blu[*]}
set_false_path -to {n*Sync}
set_false_path -from {usart_clk usart_rts usart_tx}

# multicycle paths

set_multicycle_path -from {minimig_virtual_top:virtual_top|EightThirtyTwo_Bridge:hostcpu|eightthirtytwo_cpu:my832|*} -to {minimig_virtual_top:virtual_top|EightThirtyTwo_Bridge:hostcpu|eightthirtytwo_cpu:my832|eightthirtytwo_alu:alu|mulresult[*]} -setup -end 2
set_multicycle_path -from {minimig_virtual_top:virtual_top|EightThirtyTwo_Bridge:hostcpu|eightthirtytwo_cpu:my832|*} -to {minimig_virtual_top:virtual_top|EightThirtyTwo_Bridge:hostcpu|eightthirtytwo_cpu:my832|eightthirtytwo_alu:alu|mulresult[*]} -hold -end 2

# Adjust data window for SDRAM reads by 1 cycle
set_multicycle_path -from clk_sdram -to [get_clocks $clk_114] -setup 2

set_multicycle_path -from {virtual_top|tg68k|pf68K_Kernel_inst|*} -setup 4
set_multicycle_path -from {virtual_top|tg68k|pf68K_Kernel_inst|*} -hold 3
set_multicycle_path -from {virtual_top|tg68k|pf68K_Kernel_inst|memaddr*} -setup 3
set_multicycle_path -from {virtual_top|tg68k|pf68K_Kernel_inst|memaddr*} -hold 2
set_multicycle_path -from {virtual_top|tg68k|pf68K_Kernel_inst|memaddr*} -to {virtual_top|tg68k|pf68K_Kernel_inst|*} -setup 4
set_multicycle_path -from {virtual_top|tg68k|pf68K_Kernel_inst|memaddr*} -to {virtual_top|tg68k|pf68K_Kernel_inst|*} -hold 3
set_multicycle_path -from {virtual_top|tg68k|addr[*]} -setup 3
set_multicycle_path -from {virtual_top|tg68k|addr[*]} -hold 2

#set_multicycle_path -from {virtual_top|sdram|cache|itram|*} -to {virtual_top|sdram|cache|cpu_cacheline_*[*][*]} -setup 2
#set_multicycle_path -from {virtual_top|sdram|cache|itram|*} -to {virtual_top|sdram|cache|cpu_cacheline_*[*][*]} -hold 1
#set_multicycle_path -from {virtual_top|sdram|cache|dtram|*} -to {virtual_top|sdram|cache|cpu_cacheline_*[*][*]} -setup 2
#set_multicycle_path -from {virtual_top|sdram|cache|dtram|*} -to {virtual_top|sdram|cache|cpu_cacheline_*[*][*]} -hold 1

set_multicycle_path -from [get_clocks $clk_28] -to [get_clocks $clk_114] -setup 4
set_multicycle_path -from [get_clocks $clk_28] -to [get_clocks $clk_114] -hold 3


# Neither in nor out of the C2P requires single-cycle speed
set_multicycle_path -from {minimig_virtual_top:virtual_top|TG68K:tg68k|akiko:myakiko|cornerturn:myc2p|rdptr[*]} -to {minimig_virtual_top:virtual_top|TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|*} -setup -end 2
set_multicycle_path -from {minimig_virtual_top:virtual_top|TG68K:tg68k|akiko:myakiko|cornerturn:myc2p|rdptr[*]} -to {minimig_virtual_top:virtual_top|TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|*} -hold -end 2
set_multicycle_path -from {minimig_virtual_top:virtual_top|TG68K:tg68k|akiko:myakiko|cornerturn:myc2p|buf[*][*]} -to {minimig_virtual_top:virtual_top|TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|*} -setup -end 2
set_multicycle_path -from {minimig_virtual_top:virtual_top|TG68K:tg68k|akiko:myakiko|cornerturn:myc2p|buf[*][*]} -to {minimig_virtual_top:virtual_top|TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|*} -hold -end 2

# Likewise RTG and audio address have 8 cycles of downtime between bursts
set_multicycle_path -from {minimig_virtual_top:virtual_top|VideoStream:myvs|fetch_address[*]} -to {minimig_virtual_top:virtual_top|sdram_ctrl:sdram|*} -setup -end 2
set_multicycle_path -from {minimig_virtual_top:virtual_top|VideoStream:myvs|fetch_address[*]} -to {minimig_virtual_top:virtual_top|sdram_ctrl:sdram|*} -hold -end 2
set_multicycle_path -from {minimig_virtual_top:virtual_top|VideoStream:myvs|outptr[*]} -to {minimig_virtual_top:virtual_top|sdram_ctrl:sdram|*} -setup -end 2
set_multicycle_path -from {minimig_virtual_top:virtual_top|VideoStream:myvs|outptr[*]} -to {minimig_virtual_top:virtual_top|sdram_ctrl:sdram|*} -hold -end 2
set_multicycle_path -from {minimig_virtual_top:virtual_top|VideoStream:myaudiostream|*} -to {minimig_virtual_top:virtual_top|sdram_ctrl:sdram|*} -setup -end 2
set_multicycle_path -from {minimig_virtual_top:virtual_top|VideoStream:myaudiostream|*} -to {minimig_virtual_top:virtual_top|sdram_ctrl:sdram|*} -hold -end 2


set_multicycle_path -from {chameleon_io:myIO|mux_reg[*]} -to {mux[*]} -setup -end 2

