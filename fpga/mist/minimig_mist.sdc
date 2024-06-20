
# time information
set_time_format -unit ns -decimal_places 3


#create clocks
create_clock -name pll_in_clk -period 37.037 [get_ports {CLOCK_27[0]}]
create_clock -name spi_clk -period 41.666 -waveform { 20.8 41.666 } [get_ports {SPI_SCK}]

# pll clocks
derive_pll_clocks


# generated clocks


# name PLL clocks
set clk_sdram "amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[0]"
set clk_114   "amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[1]"
set clk_28    "amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[2]"


# name SDRAM ports
set sdram_outputs [get_ports {SDRAM_DQ[*] SDRAM_A[*] SDRAM_DQML SDRAM_DQMH SDRAM_nWE SDRAM_nCAS SDRAM_nRAS SDRAM_nCS SDRAM_BA[*] SDRAM_CKE}]
set sdram_inputs  [get_ports {SDRAM_DQ[*]}]


# clock groups
set_clock_groups -exclusive -group [get_clocks {amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[*]}] -group [get_clocks {spi_clk}]
set_clock_groups -exclusive -group [get_clocks {amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[*]}] -group [get_clocks {pll_in_clk}]


# clock uncertainty
derive_clock_uncertainty


# input delay
set_input_delay -clock $clk_sdram -reference_pin [get_ports SDRAM_CLK] -max 6.4 $sdram_inputs
set_input_delay -clock $clk_sdram -reference_pin [get_ports SDRAM_CLK] -min 3.2 $sdram_inputs

#output delay
set_output_delay -clock $clk_sdram -reference_pin [get_ports SDRAM_CLK] -max  1.5 $sdram_outputs
set_output_delay -clock $clk_sdram -reference_pin [get_ports SDRAM_CLK] -min -0.8 $sdram_outputs

# Simply setting these to fast output registers should be sufficient.
#set_output_delay -clock $clk_114 .5 [get_ports {VGA_R[*]}]
#set_output_delay -clock $clk_114 .5 [get_ports {VGA_G[*]}]
#set_output_delay -clock $clk_114 .5 [get_ports {VGA_B[*]}]

# input delay on SPI pins
set_input_delay -clock { spi_clk } .5 [get_ports SPI*]
set_input_delay -clock { spi_clk } .5 [get_ports CONF_DATA0]

# output delay on SPI pins
set_output_delay -clock { spi_clk } .5 [get_ports SPI_DO]


# false paths
set_false_path -from * -to [get_ports {SDRAM_CLK}]
set_false_path -from * -to [get_ports {LED}]
set_false_path -from * -to [get_ports {UART_TX}]
set_false_path -from [get_ports {UART_RX}] -to *
#set_false_path -from * -to [get_ports {VGA_*}]
set_false_path -from * -to [get_ports {VGA_VS}]
set_false_path -from * -to [get_ports {VGA_HS}]
set_false_path -from * -to [get_ports {AUDIO_L}]
set_false_path -from * -to [get_ports {AUDIO_R}]


# multicycle paths

set_multicycle_path -from {TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|*} -setup 4
set_multicycle_path -from {TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|*} -hold 3
set_multicycle_path -from {TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|memaddr*} -setup 3
set_multicycle_path -from {TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|memaddr*} -hold 2
set_multicycle_path -from {TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|memaddr*} -to {TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|*} -setup 4
set_multicycle_path -from {TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|memaddr*} -to {TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|*} -hold 3
set_multicycle_path -from {TG68K:tg68k|addr[*]} -setup 3
set_multicycle_path -from {TG68K:tg68k|addr[*]} -hold 2


set_multicycle_path -from {sdram_ctrl:sdram|cpu_cache_new:cache|dpram_256x32:dtram|altsyncram:altsyncram_component|*|q_a[*]} -to {sdram_ctrl:sdram|cpu_cache_new:cache|cpu_cacheline*[*][*]} -setup 2
set_multicycle_path -from {sdram_ctrl:sdram|cpu_cache_new:cache|dpram_256x32:dtram|altsyncram:altsyncram_component|*|q_a[*]} -to {sdram_ctrl:sdram|cpu_cache_new:cache|cpu_cacheline*[*][*]} -hold 1
set_multicycle_path -from {sdram_ctrl:sdram|cpu_cache_new:cache|dpram_256x32:itram|altsyncram:altsyncram_component|*|q_a[*]} -to {sdram_ctrl:sdram|cpu_cache_new:cache|cpu_cacheline*[*][*]} -setup 2
set_multicycle_path -from {sdram_ctrl:sdram|cpu_cache_new:cache|dpram_256x32:itram|altsyncram:altsyncram_component|*|q_a[*]} -to {sdram_ctrl:sdram|cpu_cache_new:cache|cpu_cacheline*[*][*]} -hold 1

set_multicycle_path -from {sdram_ctrl:sdram2|cpu_cache_new:cache|dpram_256x32:dtram|altsyncram:altsyncram_component|*|q_a[*]} -to {sdram_ctrl:sdram2|cpu_cache_new:cache|cpu_cacheline*[*][*]} -setup 2
set_multicycle_path -from {sdram_ctrl:sdram2|cpu_cache_new:cache|dpram_256x32:dtram|altsyncram:altsyncram_component|*|q_a[*]} -to {sdram_ctrl:sdram2|cpu_cache_new:cache|cpu_cacheline*[*][*]} -hold 1
set_multicycle_path -from {sdram_ctrl:sdram2|cpu_cache_new:cache|dpram_256x32:itram|altsyncram:altsyncram_component|*|q_a[*]} -to {sdram_ctrl:sdram2|cpu_cache_new:cache|cpu_cacheline*[*][*]} -setup 2
set_multicycle_path -from {sdram_ctrl:sdram2|cpu_cache_new:cache|dpram_256x32:itram|altsyncram:altsyncram_component|*|q_a[*]} -to {sdram_ctrl:sdram2|cpu_cache_new:cache|cpu_cacheline*[*][*]} -hold 1

set_multicycle_path -from [get_clocks $clk_28] -to [get_clocks $clk_114] -setup 4
set_multicycle_path -from [get_clocks $clk_28] -to [get_clocks $clk_114] -hold 3

set_multicycle_path -from [get_clocks $clk_sdram] -to [get_clocks $clk_114] -setup 2

# Neither in nor out of the C2P requires single-cycle speed
set_multicycle_path -from {TG68K:tg68k|akiko:myakiko|cornerturn:\c2p:myc2p|rdptr[*]} -to {TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|*} -setup -end 2
set_multicycle_path -from {TG68K:tg68k|akiko:myakiko|cornerturn:\c2p:myc2p|rdptr[*]} -to {TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|*} -hold -end 1
set_multicycle_path -from {TG68K:tg68k|akiko:myakiko|cornerturn:\c2p:myc2p|buf[*][*]} -to {TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|*} -setup -end 2
set_multicycle_path -from {TG68K:tg68k|akiko:myakiko|cornerturn:\c2p:myc2p|buf[*][*]} -to {TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|*} -hold -end 1

# Likewise RTG and audio address have 8 cycles of downtime between bursts
set_multicycle_path -from {VideoStream:myvs|fetch_address[*]} -to {sdram_ctrl:sdram|*} -setup -end 2
set_multicycle_path -from {VideoStream:myvs|fetch_address[*]} -to {sdram_ctrl:sdram|*} -hold -end 1
set_multicycle_path -from {VideoStream:myvs|outptr[*]} -to {sdram_ctrl:sdram|*} -setup -end 2
set_multicycle_path -from {VideoStream:myvs|outptr[*]} -to {sdram_ctrl:sdram|*} -hold -end 1
set_multicycle_path -from {VideoStream:myaudiostream|*} -to {sdram_ctrl:sdram|*} -setup -end 2
set_multicycle_path -from {VideoStream:myaudiostream|*} -to {sdram_ctrl:sdram|*} -hold -end 1
