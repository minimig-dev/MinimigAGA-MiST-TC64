library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

package minimig_virtual_pkg is

	COMPONENT minimig_virtual_top
	generic
	( debug : integer := 0;
	  spimux : integer := 0;
	  havespirtc : integer := 0;
	  haveiec : integer := 0;
	  havereconfig : integer := 0;
	  havec2p : integer := 1;
	  havertg : integer := 1;
	  haveaudio : integer := 1;
	  havecart : integer := 1;
	  ram_64meg : integer := 0;
	  vga_width : integer := 5
	);
	PORT
	(
		CLK_114		:	 out STD_LOGIC;
		CLK_28		:	 out STD_LOGIC;
		CLK_IN 		:   in std_logic;
		PLL_LOCKED  :   out std_logic;
		RESET_N 		:   in STD_LOGIC;
		MENU_BUTTON :   IN STD_LOGIC;
		LED_POWER	:	 OUT STD_LOGIC;
		LED_DISK		:	 OUT STD_LOGIC;
		CTRL_TX		:	 OUT STD_LOGIC;
		CTRL_RX		:	 IN STD_LOGIC;
		AMIGA_TX		:	 OUT STD_LOGIC;
		AMIGA_RX		:	 IN STD_LOGIC;
		VGA_HS		:	 OUT STD_LOGIC;
		VGA_VS		:	 OUT STD_LOGIC;
		VGA_R		:	 OUT STD_LOGIC_VECTOR(vga_width-1 DOWNTO 0);
		VGA_G		:	 OUT STD_LOGIC_VECTOR(vga_width-1 DOWNTO 0);
		VGA_B		:	 OUT STD_LOGIC_VECTOR(vga_width-1 DOWNTO 0);
		SDRAM_DQ		:	 INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		SDRAM_A		:	 OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
		SDRAM_DQML		:	 OUT STD_LOGIC;
		SDRAM_DQMH		:	 OUT STD_LOGIC;
		SDRAM_nWE		:	 OUT STD_LOGIC;
		SDRAM_nCAS		:	 OUT STD_LOGIC;
		SDRAM_nRAS		:	 OUT STD_LOGIC;
		SDRAM_nCS		:	 OUT STD_LOGIC;
		SDRAM_BA		:	 OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		SDRAM_CLK		:	 OUT STD_LOGIC;
		SDRAM_CKE		:	 OUT STD_LOGIC;
		AUDIO_L		:	 OUT STD_LOGIC_VECTOR(23 downto 0);
		AUDIO_R		:	 OUT STD_LOGIC_VECTOR(23 downto 0);
		PS2_DAT_I		:	 IN STD_LOGIC;
		PS2_CLK_I		:	 IN STD_LOGIC;
		PS2_MDAT_I		:	 IN STD_LOGIC;
		PS2_MCLK_I		:	 IN STD_LOGIC;
		PS2_DAT_O	:	 OUT STD_LOGIC;
		PS2_CLK_O	:	 OUT STD_LOGIC;
		PS2_MDAT_O	:	 OUT STD_LOGIC;
		PS2_MCLK_O	:	 OUT STD_LOGIC;
		AMIGA_RESET_N : IN STD_LOGIC;
		AMIGA_KEY	: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		AMIGA_KEY_STB : IN STD_LOGIC;
		C64_KEYS	:	IN STD_LOGIC_VECTOR(63 DOWNTO 0);
		JOYA		:	 IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		JOYB		:	 IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		JOYC		:	 IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		JOYD		:	 IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		SD_MISO	:	 IN STD_LOGIC;
		SD_MOSI	:	 OUT STD_LOGIC;
		SD_CLK	:	 OUT STD_LOGIC;
		SD_CS		:	 OUT STD_LOGIC;
		SD_ACK	:	 IN STD_LOGIC;
		RTC_CS   :   OUT STD_LOGIC;
		RECONFIG	:	 OUT STD_LOGIC;
		IECSERIAL:	 OUT STD_LOGIC;
		FREEZE   :  in std_logic := '0'
	);
	END COMPONENT;
end package;
