
# time information
set_time_format -unit ns -decimal_places 3


#create clocks
create_clock -name pll_in_clk -period 20 [get_ports {clk50m}]

# pll clocks
derive_pll_clocks

# name PLL clocks
set pll_sdram "virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[0]"
set clk_114   "virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[1]"
set clk_28    "virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[2]"

# generated clocks
create_generated_clock -name clk_sdram -source [get_pins {virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[0]}] [get_ports {ram_clk}]
create_generated_clock -name clk_spi -source [get_pins $clk_114] -divide_by 4 [get_nets {minimig_virtual_top:virtual_top|cfide:mycfide|sck}]

# name SDRAM ports
set sdram_outputs [get_ports {ram_d[*] ram_a[*] ram_ldqm ram_udqm ram_we ram_cas ram_ras ram_ba[*] }]
set sdram_inputs  [get_ports {ram_d[*]}]


# clock groups



# clock uncertainty
derive_clock_uncertainty


# input delay
set_input_delay -clock clk_sdram -max 3.0 $sdram_inputs
set_input_delay -clock clk_sdram -min 2.0 $sdram_inputs

set_input_delay -clock $clk_114 0.5 [get_ports low_d[*]]
set_input_delay -clock $clk_114 0.5 [get_ports ps2iec[*]]
set_input_delay -clock $clk_114 0.5 [get_ports {ba_in dotclk_n ioef ir_data phi2_n reset_btn romlh spi_miso usart_cts}]


#output delay
#set_output_delay -clock $clk_sdram -max  1.5 [get_ports sm_clk]
#set_output_delay -clock $clk_sdram -min -0.8 [get_ports sm_clk]
set_output_delay -clock clk_sdram -max  1.5 $sdram_outputs
set_output_delay -clock clk_sdram -min -0.8 $sdram_outputs

set_output_delay -clock $clk_114 0.5 [get_ports low_d[*]]
set_output_delay -clock $clk_114 0.5 [get_ports low_a[*]]
set_output_delay -clock $clk_114 0.5 [get_ports ser_out*]
set_output_delay -clock $clk_114 0.5 [get_ports {game_out irq_out mmc_cs ps2iec_sel rw_out sa15_out}]
set_output_delay -clock $clk_114 0.5 [get_ports {sa_oe sd_dir sd_oe spi_clk spi_mosi}]

# false paths

set_false_path -from [get_clocks {virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[1]}] -to [get_clocks {clk_spi}]
set_false_path -from [get_clocks {virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[2]}] -to [get_clocks {clk_spi}]
set_false_path -from [get_clocks {clk_spi}] -to [get_clocks {virtual_top|amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[1]}]

set_false_path -to {sigma_*}
set_false_path -to {red[*]}
set_false_path -to {grn[*]}
set_false_path -to {blu[*]}
set_false_path -to {*sync_n}
set_false_path -from {usart_clk usart_rts usart_tx}
set_false_path -to {usart_rx iec_dat_out rtc_cs}


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

#set_multicycle_path -from {virtual_top|sdram|cpu_cache|itram|*} -to {virtual_top|sdram|cpu_cache|cpu_cacheline_*[*][*]} -setup 2
#set_multicycle_path -from {virtual_top|sdram|cpu_cache|itram|*} -to {virtual_top|sdram|cpu_cache|cpu_cacheline_*[*][*]} -hold 1
#set_multicycle_path -from {virtual_top|sdram|cpu_cache|dtram|*} -to {virtual_top|sdram|cpu_cache|cpu_cacheline_*[*][*]} -setup 2
#set_multicycle_path -from {virtual_top|sdram|cpu_cache|dtram|*} -to {virtual_top|sdram|cpu_cache|cpu_cacheline_*[*][*]} -hold 1

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

# C64 IO signals are stable long before the IO entity writes them to the bus...
set_multicycle_path -to {low_a[*]} -setup -end 4
set_multicycle_path -to {low_a[*]} -hold -end 3
