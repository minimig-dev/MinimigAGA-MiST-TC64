------------------------------------------------------------------------------
------------------------------------------------------------------------------
--                                                                          --
-- Copyright (c) 2009-2011 Tobias Gubener                                   --
-- Subdesign fAMpIGA by TobiFlex                                            --
--                                                                          --
-- This is the TOP-Level for TG68KdotC_Kernel to generate 68K Bus signals   --
--                                                                          --
-- This source file is free software: you can redistribute it and/or modify --
-- it under the terms of the GNU General Public License as published        --
-- by the Free Software Foundation, either version 3 of the License, or     --
-- (at your option) any later version.                                      --
--                                                                          --
-- This source file is distributed in the hope that it will be useful,      --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of           --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            --
-- GNU General Public License for more details.                             --
--                                                                          --
-- You should have received a copy of the GNU General Public License        --
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.    --
--                                                                          --
------------------------------------------------------------------------------
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity TG68K is
generic
	(
		havertg : boolean := true;
		haveaudio : boolean := true;
		havec2p : boolean := true;
		dualsdram : boolean := false;
		useprofiler : boolean := false
	);
port(
	clk           : in      std_logic;
	reset         : in      std_logic;
	clkena_in     : in      std_logic:='1';
	IPL           : in      std_logic_vector(2 downto 0):="111";
	dtack         : in      std_logic;
	freeze        : in      std_logic;
	vpa           : in      std_logic:='1';
	ein           : in      std_logic:='1';
	addr          : out     std_logic_vector(31 downto 0);
	data_read     : in      std_logic_vector(15 downto 0);
	data_read2    : in      std_logic_vector(15 downto 0);
	data_write    : out     std_logic_vector(15 downto 0);
	data_write2   : out     std_logic_vector(15 downto 0);
    fast_rd       : buffer  std_logic;
	as            : out     std_logic;
	uds           : out     std_logic;
	lds           : out     std_logic;
	uds2          : out     std_logic;
	lds2          : out     std_logic;
	rw            : out     std_logic;
	vma           : buffer  std_logic:='1';
	wrd           : out     std_logic;
	ena7RDreg     : in      std_logic:='1';
	ena7WRreg     : in      std_logic:='1';
	fromram       : in      std_logic_vector(15 downto 0);
	toram         : out     std_logic_vector(15 downto 0);
	ramready      : in      std_logic:='0';
	cpu           : in      std_logic_vector(1 downto 0);
	ziiram_active : in      std_logic;
	ziiiram_active : in     std_logic;
	ziiiram2_active : in     std_logic;
	ziiiram3_active : in     std_logic;

	eth_en        : in      std_logic:='0';
	sel_eth       : buffer  std_logic;
	frometh       : in      std_logic_vector(15 downto 0);
	ethready      : in      std_logic;
	slow_config   : in      std_logic_vector(1 downto 0);
	aga           : in      std_logic;
	turbochipram  : in      std_logic;
	turbokick     : in      std_logic;
	cache_inhibit : out     std_logic;
	cacheline_clr : out     std_logic;
	--    ovr           : in      std_logic;
	ramaddr       : out     std_logic_vector(31 downto 0);
	cpustate      : out     std_logic_vector(3 downto 0);
--	chipset_ramsel: out     std_logic;
	nResetOut     : buffer  std_logic;
	skipFetch     : buffer  std_logic;
	--    cpuDMA        : buffer  std_logic;
	ramlds        : out     std_logic;
	ramuds        : out     std_logic;
	CACR_out      : buffer  std_logic_vector(3 downto 0);
	VBR_out       : buffer  std_logic_vector(31 downto 0);
	-- RTG interface
	rtg_base : out std_logic_vector(25 downto 4);
	rtg_addr : out std_logic_vector(25 downto 4);
	rtg_vbend : out std_logic_vector(6 downto 0);
	rtg_ext : out std_logic;
	rtg_pixelclock : out std_logic_vector(3 downto 0);
	rtg_clut : out std_logic;
	rtg_16bit : out std_logic;
	rtg_clut_idx : in std_logic_vector(7 downto 0) := X"00";
	rtg_clut_r : out std_logic_vector(7 downto 0);
	rtg_clut_g : out std_logic_vector(7 downto 0);
	rtg_clut_b : out std_logic_vector(7 downto 0);
	-- Audio interface
	audio_buf : in std_logic;
	audio_ena : out std_logic;
	audio_int : out std_logic;
	-- Host interface
	host_req : out std_logic;
	host_ack : in std_logic :='0';
	host_q : in std_logic_vector(15 downto 0) := "----------------"
);
end TG68K;


ARCHITECTURE logic OF TG68K IS
SIGNAL addrtg68         : std_logic_vector(31 downto 0);
SIGNAL cpuaddr          : std_logic_vector(31 downto 0);
SIGNAL r_data           : std_logic_vector(15 downto 0);
SIGNAL cpuIPL           : std_logic_vector(2 downto 0);
signal CACR             : std_logic_vector(3 downto 0);

SIGNAL clkena_e         : std_logic;
SIGNAL clkena_f         : std_logic;
SIGNAL wr               : std_logic;
SIGNAL uds_in           : std_logic;
SIGNAL lds_in           : std_logic;
SIGNAL state            : std_logic_vector(1 downto 0);
signal longword         : std_logic;
SIGNAL clkena           : std_logic;
SIGNAL sel_ram          : std_logic;
SIGNAL sel_chip         : std_logic;
SIGNAL sel_chipram      : std_logic;
SIGNAL turbochip_d      : std_logic := '0';
SIGNAL turbokick_d      : std_logic := '0';
SIGNAL turboslow_d      : std_logic := '0';
SIGNAL slower           : std_logic_vector(2 downto 0);

signal datatg68_selram  : std_logic;
SIGNAL datatg68_c       : std_logic_vector(15 downto 0);
SIGNAL datatg68         : std_logic_vector(15 downto 0);
SIGNAL w_datatg68       : std_logic_vector(15 downto 0);
SIGNAL ramcs            : std_logic;

SIGNAL z2ram_ena        : std_logic;
SIGNAL z3ram_ena        : std_logic;
SIGNAL z3ram2_ena        : std_logic;
SIGNAL z3ram3_ena        : std_logic;
SIGNAL eth_base         : std_logic_vector(7 downto 0);
SIGNAL eth_cfgd         : std_logic;
SIGNAL sel_z2ram        : std_logic;
SIGNAL sel_z3ram        : std_logic;
SIGNAL sel_z3ram2       : std_logic;
SIGNAL sel_z3ram3       : std_logic;
SIGNAL sel_kick         : std_logic;
SIGNAL sel_kickram      : std_logic;
--SIGNAL sel_eth          : std_logic;
SIGNAL sel_slow         : std_logic;
SIGNAL sel_slowram      : std_logic;
SIGNAL sel_cart         : std_logic;
SIGNAL sel_32           : std_logic;
signal sel_undecoded    : std_logic;
signal sel_undecoded_d  : std_logic;
signal sel_akiko        : std_logic;
signal sel_akiko_d      : std_logic;
signal sel_audio        : std_logic;
signal sel_gayle_ide    : std_logic;

SIGNAL cpu_internal     : std_logic;
SIGNAL cpu_fetch        : std_logic;
SIGNAL cpu_read         : std_logic;
SIGNAL cpu_write        : std_logic;
signal cpu_disablecache : std_logic;

-- Akiko registers
signal akiko_d : std_logic_vector(15 downto 0);
signal akiko_q : std_logic_vector(15 downto 0);
signal akiko_wr : std_logic;
signal akiko_req : std_logic;
signal akiko_ack : std_logic;
signal host_req_r : std_logic;

SIGNAL NMI_addr         : std_logic_vector(31 downto 0);
SIGNAL sel_nmi_vector_addr : std_logic;
SIGNAL sel_nmi_vector   : std_logic;

signal block_turbo : std_logic;
signal throttle_sel : std_logic_vector(1 downto 0);

component profile_cpu
port (
	clk : in std_logic;
	reset_n : in std_logic;
	clkena : in std_logic;
	cpustate : in std_logic_vector(1 downto 0);
	sel_chip : in std_logic;
	sel_kick : in std_logic;
	sel_fast24 : in std_logic;
	sel_fast32: in std_logic
);
end component;

BEGIN

sel_eth<='0';

	-- NMI
	PROCESS(reset, clk,VBR_out) BEGIN
		IF reset='0' THEN
			NMI_addr <= X"0000007c";
			sel_nmi_vector_addr <= '0';
		ELSIF rising_edge(clk) THEN
			NMI_addr <= VBR_out + X"0000007c";
			sel_nmi_vector_addr <= '0';
			IF (cpuaddr(31 downto 2) = NMI_addr(31 downto 2)) THEN
				sel_nmi_vector_addr <= '1';
			END IF;
		END IF;
	END PROCESS;

	-- AMR just for convenience / clarity
	cpu_fetch    <= '1' WHEN state = "00" else '0';
	cpu_internal <= '1' WHEN state = "01" else '0';
	cpu_read     <= '1' WHEN state = "10" else '0';
	cpu_write    <= '1' WHEN state = "11" else '0';
	cpu_disablecache <= not CACR(0);

	sel_nmi_vector <= '1' WHEN sel_nmi_vector_addr='1' AND cpu_read='1' ELSE '0';

	toram <= w_datatg68;
	wrd <= wr;

	PROCESS(clk) BEGIN
		IF rising_edge(clk) THEN
			z2ram_ena <= ziiram_active;
			z3ram_ena <= ziiiram_active;
			z3ram2_ena <= ziiiram2_active;
			z3ram3_ena <= ziiiram3_active;

			sel_akiko_d<=sel_akiko;
			sel_undecoded_d<=sel_32 and not sel_ram;
		END IF;
	END PROCESS;

	datatg68 <= fromram WHEN datatg68_selram='1' else datatg68_c;
--	chipset_ramsel <= sel_z2ram or sel_chipram or sel_kickram or sel_slowram;
--	chipset_ramsel <= not sel_z3ram;

	-- Register incoming data
	process(clk) begin
		if rising_edge(clk) then
			datatg68_selram <= sel_ram and (not cpu_internal) and (not block_turbo) and (not sel_nmi_vector); -- AMR - remove sel_nmi_vector's decoding from the mux path
			if sel_undecoded_d = '1' then
				datatg68_c <= X"FFFF";
			elsif sel_akiko_d = '1' then
				datatg68_c <= akiko_q;
			elsif sel_eth='1' then
				datatg68_c <= frometh;
			else
				datatg68_c <= r_data;
			end if;
		end if;
	end process;

DUALRAM_ZIII: if dualsdram=true generate
-- First block of ZIII RAM - 0x40000000 - 0x43ffffff
	sel_z3ram       <= '1' WHEN (cpuaddr(31 downto 30)="01") and cpuaddr(26)='0' else '0';
-- Second block of ZIII RAM - 32 meg from 0x44000000 - 0x45ffffff
-- Also matches third block, 16 meg from 0x46000000 - 0x46ffffff
	sel_z3ram2      <= '1' WHEN (cpuaddr(31 downto 30)="01") and cpuaddr(26)='1' else '0';
-- Third block of ZIII RAM - either 2 or 4 meg, starting at either 0x41000000 or 0x44000000
	sel_z3ram3      <= '0'; -- '1' WHEN (cpuaddr(31 downto 30)="01") and (cpuaddr(26)='1' or cpuaddr(24)='1') else '0'; 
end generate;

SINGLERAM_ZIII: if dualsdram=false generate
-- First block of ZIII RAM - 0x40000000 - 0x40ffffff
	sel_z3ram       <= '1' WHEN (cpuaddr(31 downto 30)="01") and cpuaddr(26 downto 24)="000" else '0'; -- AND z3ram_ena='1' ELSE '0';
-- Second block of ZIII RAM - 32 meg from 0x42000000 - 0x43ffffff
	sel_z3ram2      <= '1' WHEN (cpuaddr(31 downto 30)="01") and cpuaddr(25)='1' else '0'; -- AND z3ram2_ena='1' ELSE '0';
-- Third block of ZIII RAM - either 2 or 4 meg, starting at either 0x41000000 or 0x44000000
	sel_z3ram3      <= '1' WHEN (cpuaddr(31 downto 30)="01") and (cpuaddr(26)='1' or cpuaddr(24)='1') else '0'; -- and z3ram3_ena='1' ELSE '0';
end generate;

	sel_gayle_ide <= '1' when state(1 downto 0) = "10" and cpuaddr(31 downto 14)=X"00DA"&"00" else '0';

	sel_akiko <= '1' when cpuaddr(31 downto 16)=X"00B8" else '0';
	sel_32 <= '1' when cpu(1)='1' and cpuaddr(31 downto 24)/=X"00" and cpuaddr(31 downto 24)/=X"ff" else '0'; -- Decode 32-bit space, but exclude interrupt vectors
	sel_z2ram       <= '1' WHEN (cpuaddr(31 downto 24) = X"00")
	                         AND ((cpuaddr(23 downto 21) = "001")
	                           OR (cpuaddr(23 downto 21) = "010")
	                           OR (cpuaddr(23 downto 21) = "011")
	                           OR (cpuaddr(23 downto 21) = "100")) else '0'; --  AND z2ram_ena='1' ELSE '0';
	--sel_eth         <= '1' WHEN (cpuaddr(31 downto 24) = eth_base) AND eth_cfgd='1' ELSE '0';
	sel_chip        <= '1' WHEN (cpuaddr(31 downto 24) = X"00") AND (cpuaddr(23 downto 21)="000") ELSE '0'; --$000000 - $1FFFFF
	sel_chipram     <= '1' WHEN sel_chip = '1' AND turbochip_d='1' ELSE '0';
	sel_kick        <= '1' WHEN (cpuaddr(31 downto 24) = X"00") AND ((cpuaddr(23 downto 19)="11111") OR (cpuaddr(23 downto 19)="11100")) AND state/="11" ELSE '0'; -- $F8xxxx, $E0xxxx, read only
	sel_kickram     <= '1' WHEN sel_kick='1' AND (aga='1' OR (aga='0' AND turbokick_d='1')) ELSE '0'; -- menu option for OCS/ECS, always enable for AGA
	sel_slow        <= '1' WHEN (cpuaddr(31 downto 24) = X"00") AND ((cpuaddr(23 downto 20)=X"C" AND ((cpuaddr(19)='0' AND slow_config/="00") OR (cpuaddr(19)='1' AND slow_config(1)='1'))) OR (cpuaddr(23 downto 19)=X"D"&'0' AND slow_config="11")) ELSE '0'; -- $C00000 - $D7FFFF
	sel_slowram     <= '1' WHEN sel_slow='1' AND turboslow_d='1' ELSE '0';
	sel_cart        <= '1' WHEN (cpuaddr(31 downto 24) = X"00") AND (cpuaddr(23 downto 20)="1010") ELSE '0'; -- $A00000 - $A7FFFF (actually matches up to $AFFFFF)
	sel_audio       <= '1' WHEN (cpuaddr(31 downto 24) = X"00") AND (cpuaddr(23 downto 18)="111011") ELSE '0'; -- $EC0000 - $EFFFFF
--	sel_undecoded   <= '1' WHEN sel_32='1' and (sel_z3ram and z3ram_ena)='0' and (sel_z3ram2 and z3ram2_ena)='0' and (sel_z3ram3 and z3ram3_ena)='0' else '0';
	sel_ram         <= '1' WHEN (
         (sel_z2ram='1' and z2ram_ena='1')
      OR (sel_z3ram='1' and z3ram_ena='1')
      OR (sel_z3ram2='1' and z3ram2_ena='1')
      OR (sel_z3ram3='1' and z3ram3_ena='1')
      OR sel_chipram='1'
      OR sel_slowram='1'
      OR sel_kickram='1'
      OR sel_audio='1'
    ) ELSE '0';

  ramcs <= NOT datatg68_selram or slower(0); -- (NOT cpu_internal AND sel_ram_d AND NOT sel_nmi_vector) OR slower(0) or block_turbo;

  cpustate <= longword&ramcs&state(1 downto 0);
  ramlds <= lds_in;
  ramuds <= uds_in;

-- This is the mapping to the SDRAM
-- map $00-$1F to $00-$1F (chipram), $A0-$FF to $20-$7F. All non-fastram goes into the first
-- 8M block (i.e. SDRAM bank 0). This map should be the same as in minimig_sram_bridge.v
-- 8M Zorro II RAM $20-9F goes to $80-$FF (SDRAM bank 1)
  
-- Boolean logic can handle this mapping.  Furthermore, applying the same
-- mapping to the other three banks is harmless, so there's no point expending logic
-- to make it specific to the first bank.

-- ABCD  B|C  A^(B|C)
--
-- 0000  0    0       0 -> 0
--
-- 0010  1    1       2 -> A
-- 0100  1    1       4 -> C
-- 0110  1    1       6 -> E
-- 1000  0    1       8 -> 8
--
-- 1010  1    0       A -> 2
-- 1100  1    0       C -> 4
-- 1110  1    0       E -> 6 
 
-- On 64-meg platforms we need an extra 32 meg merged into the memory map.
-- If we configure that range second, it should end up in 42000000 - 43ffffff
-- so the extra 2 or 4 meg will end up at either 41000000 or 4400000, depending
-- on whether the extra 32 meg is configured.

-- addr(25) will be high only when 32-meg block is active
-- addr(24) will be high for the 16-meg block or the second half of the 32-meg block

-- The extra ZIII mapping maps 41000000 -> 200000, (or 44000000 -> 200000)
-- bits 23 downto 20 are mapped like so:
-- 0000->0010 (1st 2 meg), 0010->0100 (2nd 2 meg),
-- 0100->0010 (3rd 2 meg, aliases 1st), 0110->0100 (4th 2 meg, aliases 2nd), 
-- addr(23) <= addr(23) and not sel_ziii_3;
-- addr(22) <= (addr(22) and not sel_ziii_3) or (addr(21) and sel_ziii_3);
-- addr(21) <= addr(21) xor sel_ziii_3;
 
DUALRAM_ADDR: if dualsdram=true generate
-- FIXME - fold a 16 meg chunk from the first SDRAM into the memory map.
  ramaddr(31 downto 27) <= "00000";
  ramaddr(26) <= sel_z3ram;
  ramaddr(25) <= cpuaddr(25) or sel_z3ram2; -- Second block of 32 meg, in 1st SDRAM.
  ramaddr(24) <= cpuaddr(24);
  ramaddr(23)<=(cpuaddr(23) xor (cpuaddr(22) or cpuaddr(21))) and not sel_z3ram3; -- ZII address mangling (disabled for RAM overlaid with trapdoor RAM.)
  ramaddr(22)<=cpuaddr(21) when sel_z3ram3='1' else cpuaddr(22);
  ramaddr(21)<=cpuaddr(21) xor sel_z3ram3;
  ramaddr(20 downto 0) <= cpuaddr(20 downto 0);

end generate;

SINGLERAM_ADDR: if dualsdram=false generate
 
  ramaddr(31 downto 26) <= "000000";
  ramaddr(25) <= sel_z3ram2; -- Second block of 32 meg
  ramaddr(24) <= (cpuaddr(24) and sel_z3ram2) or sel_z3ram; -- Remap the first block of Zorro III RAM to 0x1000000
  ramaddr(23)<=(cpuaddr(23) xor (cpuaddr(22) or cpuaddr(21))) and not sel_z3ram3;
  ramaddr(22)<=cpuaddr(21) when sel_z3ram3='1' else cpuaddr(22);
  ramaddr(21)<=cpuaddr(21) xor sel_z3ram3;
  ramaddr(20 downto 0) <= cpuaddr(20 downto 0);

end generate;


  
  -- 32bit address space for 68020, limit address space to 24bit for 68000/68010
  cpuaddr <= addrtg68 WHEN cpu(1) = '1' ELSE X"00" & addrtg68(23 downto 0);

pf68K_Kernel_inst: entity work.TG68KdotC_Kernel
  generic map (
    SR_Read         => 2, -- 0=>user,   1=>privileged,    2=>switchable with CPU(0)
    VBR_Stackframe  => 2, -- 0=>no,     1=>yes/extended,  2=>switchable with CPU(0)
    extAddr_Mode    => 2, -- 0=>no,     1=>yes,           2=>switchable with CPU(1)
    MUL_Mode        => 2, -- 0=>16Bit,  1=>32Bit,         2=>switchable with CPU(1),  3=>no MUL,
    DIV_Mode        => 2, -- 0=>16Bit,  1=>32Bit,         2=>switchable with CPU(1),  3=>no DIV,
    BitField        => 2, -- 0=>no,     1=>yes,           2=>switchable with CPU(1)
	MUL_Hardware    => 1  -- 0=>no,     1=>yes
  )
  PORT MAP (
    clk             => clk,           -- : in std_logic;
    nReset          => reset,         -- : in std_logic:='1';      --low active
    clkena_in       => clkena,        -- : in std_logic:='1';
    data_in         => datatg68,      -- : in std_logic_vector(15 downto 0);
    IPL             => cpuIPL,        -- : in std_logic_vector(2 downto 0):="111";
    IPL_autovector  => '1',           -- : in std_logic:='0';
    CPU             => cpu,
    regin_out       => open,          -- : out std_logic_vector(31 downto 0);
    addr_out        => addrtg68,      -- : buffer std_logic_vector(31 downto 0);
    data_write      => w_datatg68,    -- : out std_logic_vector(15 downto 0);
    busstate        => state,         -- : buffer std_logic_vector(1 downto 0);
	 longword        => longword,
    nWr             => wr,            -- : out std_logic;
    nUDS            => uds_in,
    nLDS            => lds_in,        -- : out std_logic;
    nResetOut       => nResetOut,
    skipFetch       => skipFetch,     -- : out std_logic
    CACR_out        => CACR,
    VBR_out         => VBR_out
  );
  CACR_out <= CACR;

PROCESS (clk) BEGIN
  IF rising_edge(clk) THEN
    IF (reset='0' OR nResetOut='0') THEN
      turbochip_d <= '0';
      turbokick_d <= '0';
      turboslow_d <= '0';
      cacheline_clr <= '0';
    ELSIF cpu_internal='1' THEN -- No mem access, so safe to switch chipram access mode
      turbochip_d <= turbochipram OR (turbokick AND aga);
      turbokick_d <= turbokick;
      turboslow_d <= turbochipram OR (turbokick AND aga);
      cacheline_clr <= ((turbochipram OR (turbokick AND aga)) XOR turbochip_d) OR (turbokick XOR turbokick_d);
    END IF;
  END IF;
END PROCESS;

host_req<=host_req_r;
myakiko : entity work.akiko
generic map
(
	havertg => havertg,
	haveaudio => haveaudio,
	havec2p => havec2p
)
port map
(
	clk => clk,
	reset_n => reset,
	addr => cpuaddr(10 downto 0),
	d => akiko_d,
	q => akiko_q,
	wr => akiko_wr,
	req => akiko_req,
	ack => akiko_ack,
	host_req => host_req_r,
	host_ack => host_ack,
	host_q => host_q,
	rtg_addr => rtg_addr,
	rtg_base => rtg_base,
	rtg_vbend => rtg_vbend,
	rtg_ext => rtg_ext,
	rtg_pixelclock => rtg_pixelclock,
	rtg_16bit => rtg_16bit,
	rtg_clut => rtg_clut,
	rtg_clut_idx => rtg_clut_idx,
	rtg_clut_r => rtg_clut_r,
	rtg_clut_g => rtg_clut_g,
	rtg_clut_b => rtg_clut_b,
	audio_buf => audio_buf,
	audio_ena => audio_ena,
	audio_int => audio_int
);


akiko_d <= w_datatg68;
process(clk,cpuaddr) begin
	if rising_edge(clk) then
		if sel_akiko='0' then
			akiko_req<='0';
			akiko_wr<='0';
		end if;
		if sel_akiko='1' and state(1)='1' and slower(2)='0' then
			akiko_req<=not clkena;
			if state(0)='1' then -- write cycle
				akiko_wr<='1';
			end if;	
		end if;
	end if;
end process;


buslogic : block
	signal throttle         : std_logic_vector(2 downto 0);
	signal chipset_cycle    : std_logic;
	SIGNAL vpad             : std_logic;
	SIGNAL waitm            : std_logic;
	SIGNAL S_state          : std_logic_vector(1 downto 0);
	SIGNAL vmaena           : std_logic;
	SIGNAL eind             : std_logic;
	SIGNAL eindd            : std_logic;
	TYPE   sync_states      IS (sync0, sync1, sync2, sync3, sync4, sync5, sync6, sync7, sync8, sync9);
	SIGNAL sync_state       : sync_states;
	signal sel_chip_d       : std_logic; 
	signal fast_rd_d        : std_logic;
	signal clkena_pre		: std_logic;
begin

	process(clk) begin
		if rising_edge(clk) then
			clkena_pre <= '0';
			if clkena='0' and ((slower(2)='0' and cpu_internal='1') or (slower(1)='0' and (sel_undecoded_d='1' or akiko_ack='1'))) then
				clkena_pre <= '1';
			end if;
		end if;
	end process;

	clkena <= '1' WHEN clkena_pre='1' or (slower(0)='0' and
					   ((clkena_in='1' and ((ena7RDreg='1' AND clkena_e='1') OR (ena7WRreg='1' AND clkena_f='1') or fast_rd='1')) OR
					   (ramready='1' and block_turbo='0')))
				  ELSE '0';

	-- AMR - attempt to imitate A1200 speed more closely on chipram fetches:
	-- Perform throttling of the CPU depending on turbo mode:  (Temporary mapping for evaluation)
	-- Turbo set to both: no throttling
	-- Turbo set to kick only: mild throttling
	-- Turbo set to chip only: more severe throttling
	-- Turbo set to none: severe throttling selected but has no effect since all chipram accesses go through the slow path.

	-- When throttling is enabled:
	--   Data reads go through the slow path as normal
	--   Fetches go via the cache (unless CACR says otherwise) but the CPU is slowed by the throttling
	--   Writes go through the fast path (since real AGA hardware buffers writes.) but again the CPU is slowed by throttling.

	-- Need to decide how to handle C00000 RAM and Fast RAM in throttled modes
	--   For compatibility, C00000 RAM should probably run at chip RAM speeds
	--   Fast RAM should perhaps be throttled in Chip (i.e. A1200) mode, but not otherwise?

	PROCESS (clk) BEGIN
		IF rising_edge(clk) THEN
			IF (reset='0' OR nResetOut='0') THEN
				throttle_sel <= "00";
			ELSIF cpu_internal='1' THEN
				-- If throttling is enabled, block turbo for CPU data reads, and instruction fetch if cache is disabled.
				throttle_sel(0) <= freeze or (turbochipram xor turbokick);
				throttle_sel(1) <= freeze or (turbochipram and not turbokick);
			END IF;
			sel_chip_d  <= sel_chip;
			block_turbo <= aga and sel_chip_d and throttle_sel(0) and (cpu_read or (cpu_fetch and cpu_disablecache));

			cache_inhibit <= sel_kickram and aga and (throttle_sel(1) or throttle_sel(0));

		END IF;
	END PROCESS;

	process (clk) begin
		if rising_edge(clk) then
			if (clkena='1' or freeze='1') and cpu_write='0' and block_turbo='0' then
				throttle<=throttle_sel(1) & throttle_sel;
			elsif clkena_in='1' then
				throttle<='0'&throttle(throttle'high downto 1);
			end if;
		end if;
	end process;

	PROCESS (clk) BEGIN
		IF rising_edge(clk) THEN
			IF clkena='1' THEN
				slower <= "111"; -- rokk
			ELSE
				slower<= (aga and throttle(0))&slower(slower'high downto 1); -- enaWRreg&slower(3 downto 1);
			END IF;
		END IF;
	END PROCESS;

	chipset_cycle <= '1' when clkena_in='1' and slower(0)='0' and (sel_ram='0' OR sel_nmi_vector='1' or block_turbo='1')
		 and (sel_gayle_ide='0') AND sel_akiko='0' and sel_undecoded_d='0' else '0';

	PROCESS (clk) BEGIN
	  IF rising_edge(clk) THEN
		IF ena7WRreg='1' THEN
		  eind <= ein;
		  eindd <= eind;
		  CASE sync_state IS
			WHEN sync0  => sync_state <= sync1;
			WHEN sync1  => sync_state <= sync2;
			WHEN sync2  => sync_state <= sync3;
			WHEN sync3  => sync_state <= sync4;
					 vma <= vpa;
			WHEN sync4  => sync_state <= sync5;
			WHEN sync5  => sync_state <= sync6;
			WHEN sync6  => sync_state <= sync7;
			WHEN sync7  => sync_state <= sync8;
			WHEN sync8  => sync_state <= sync9;
			WHEN OTHERS => sync_state <= sync0;
					 vma <= '1';
		  END CASE;
		  IF eind='1' AND eindd='0' THEN
			sync_state <= sync7;
		  END IF;
		END IF;
	  END IF;
	END PROCESS;

	PROCESS (clk, reset)
	BEGIN
		IF reset='0' THEN
			S_state <= "00";
			as <= '1';
			rw <= '1';
			uds <= '1';
			lds <= '1';
			uds2 <= '1';
			lds2 <= '1';
			clkena_e <= '0';
			clkena_f <= '0';
		ELSIF rising_edge(clk) THEN
			IF S_state = "01" AND clkena_e = '1' THEN
				uds2 <= uds_in;
				lds2 <= lds_in;
				data_write2 <= w_datatg68;
			END IF;

			-- AMR - Fast chipset path for Gayle
			if slower(0)='0' and clkena_in='1' and sel_gayle_ide='1' and S_state="00" then
				addr <= cpuaddr;
				fast_rd <= '1';
			end if;
			
			if fast_rd='1' and clkena_in='1' then
				fast_rd <= '0';
			end if;

			if fast_rd='1' then
				r_data <= data_read;
			end if;

			-- Regular chipset path
			
			IF ena7WRreg='1' THEN
				CASE S_state IS
					WHEN "00" =>
						IF cpu_internal='0' AND chipset_cycle='1' THEN
							uds <= uds_in;
							lds <= lds_in;
							uds2 <= '1';
							lds2 <= '1';
							as <= '0';
							rw <= wr;
							data_write <= w_datatg68;
							addr <= cpuaddr;
							IF aga = '1' AND cpu(1) = '1' AND longword = '1' AND cpu_write = '1' AND cpuaddr(1 downto 0) = "00" AND sel_chip = '1' THEN
								-- 32 bit write
								clkena_e <= '1';
							END IF;
							S_state <= "01";
						END IF;
					WHEN "01" =>
						clkena_e <= '0';
						S_state <= "10";
					WHEN "10" =>
						IF waitm='0' OR (vma='0' AND sync_state=sync9) THEN
							S_state <= "11";
						END IF;
					WHEN "11" =>
						IF clkena_f = '1' THEN
							clkena_f <= '0';
							r_data <= data_read2;
						END IF;
					WHEN OTHERS => null;
				END CASE;
			ELSIF ena7RDreg='1' THEN
				clkena_f <= '0';
				CASE S_state IS
					WHEN "00" =>
						cpuIPL <= IPL;
					WHEN "01" =>
					WHEN "10" =>
						cpuIPL <= IPL;
						waitm <= dtack;
					WHEN "11" =>
						as <= '1';
						rw <= '1';
						uds <= '1';
						lds <= '1';
						uds2 <= '1';
						lds2 <= '1';
						IF clkena_e = '0' THEN
							r_data <= data_read;
						END IF;

						clkena_e <= '1';
						-- AMR - can't do 32-bit read when reading NMI vector
						IF aga = '1' AND sel_nmi_vector='0' and cpu(1) = '1' AND longword = '1' AND state(0) = '0' AND cpuaddr(1 downto 0) = "00" AND (sel_chip = '1' OR sel_kick = '1') THEN
							-- 32 bit read
							clkena_f <= '1';
						END IF;
						IF clkena = '1' THEN
							S_state <= "00";
							clkena_e <= '0';
						END IF;
					WHEN OTHERS => null;
				END CASE;
			END IF;
		END IF;
	END PROCESS;

end block;


genprofiler : if useprofiler generate
	profiler : component profile_cpu
	port map (
		clk => clk,
		reset_n => reset,
		clkena => clkena,
		cpustate => state,
		sel_chip => sel_chip,
		sel_kick => sel_kick,
		sel_fast24 => sel_z2ram,
		sel_fast32 => sel_z3ram
	);
end generate;

END;
