library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity drivesounds is
port (
	clk : in std_logic;
	reset_n : in std_logic;
	mem_addr : out std_logic_vector(31 downto 0);
	mem_d : in std_logic_vector(15 downto 0);
	mem_req : out std_logic;
	mem_ack : in std_logic;
	fd_step : in std_logic;
	fd_motor : in std_logic;
	fd_insert : in std_logic;
	fd_eject : in std_logic;
	hd_step : in std_logic;
	aud_q : out std_logic_vector(15 downto 0)
);
end entity;

-- Drive sounds are stored in memory at Amiga address 0xeb0000, SDRAM address 0x6b0000
-- The drive sounds are stored in the following structure:
-- 32bit signature 1 "DRIV" - the 'V' is replaced with a configuration nybble to enable or disable sounds.
-- 32bit signature 2 "ESND"
-- for each sound:
-- {
--   (32 bit BE) index number
--   (32 bit BE) length of sound data
--   (length bytes of 16-bit BE) sound data
-- } repeated for each sound
-- (32 bit BE) 0 - null index
-- (32 bit BE) 0 - null length

-- Host RAM interface sends an eight-word burst, the first word coinciding with mem_ack.

architecture rtl of drivesounds is
	constant DRIVESOUND_BASE : unsigned(23 downto 0) := X"6B0000";

	constant DRIVESOUND_INSERT : natural := 0;
	constant DRIVESOUND_EJECT : natural := 1;
	constant DRIVESOUND_MOTORSTART : natural := 2;
	constant DRIVESOUND_MOTORLOOP : natural := 3;
	constant DRIVESOUND_MOTORSTOP : natural := 4;
	constant DRIVESOUND_STEP1 : natural := 5;
	constant DRIVESOUND_STEP2 : natural := 6;
	constant DRIVESOUND_STEP3 : natural := 7;
	constant DRIVESOUND_STEP4 : natural := 8;
	constant DRIVESOUND_HDDSTEP1 : natural := 9;
	constant DRIVESOUND_HDDSTEP2 : natural := 10;
	constant DRIVESOUND_HDDSTEP3 : natural := 11;
	constant DRIVESOUND_HDDSTEP4 : natural := 12;
	constant DRIVESOUND_END : natural := 13;
	constant DRIVESOUND_COUNT : natural := 16;
	constant DRIVESOUND_COUNT_LOG2 : natural := 4;

	-- Use a RAM block to keep track of variables for each sound, with eight words per record
	constant DS_BASE : natural := 0;
	constant DS_LENGTH : natural :=1;
	constant DS_PTR : natural := 2;
	constant DS_BUF : natural := 4; -- Four 32-bit words of cached data
	constant DS_RECORDSIZE : natural := 8;
	constant DS_RECORDSIZE_LOG2 : natural := 3;
		
	type ds_words is array (0 to DS_RECORDSIZE*DRIVESOUND_COUNT-1) of std_logic_vector(31 downto 0);
	signal ds_storage : ds_words;
	signal ds_addr : unsigned(DRIVESOUND_COUNT_LOG2 + DS_RECORDSIZE_LOG2 - 1 downto 0); -- 4 bits for sounds, 3 bits for each record
	signal ds_d : std_logic_vector(31 downto 0);
	signal ds_q : std_logic_vector(31 downto 0);
	signal ds_wr : std_logic;
	
	signal sampletick : std_logic;

	signal mem_addr_i : std_logic_vector(23 downto 0);
	signal mem_req_i : std_logic;
	
	signal config : std_logic_vector(3 downto 0);
	constant CONFIG_FLOPPY_BIT : integer := 0;
	constant CONFIG_HDD_BIT : integer := 1;	
begin

	-- SDRAM - for timing
	process(clk) begin
		if rising_edge(clk) then
			mem_addr(23 downto 0) <= mem_addr_i;
			mem_req <= mem_req_i;
		end if;
	end process;

	-- internal RAM logic
	process(clk) begin
		if rising_edge(clk) then
			if ds_wr='1' then
				ds_storage(to_integer(ds_addr))<=ds_d;
			end if;
			ds_q <= ds_storage(to_integer(ds_addr));
		end if;
	end process;

	samplecounter : block
		signal counter : unsigned(11 downto 0);
		constant ticks : integer := (7090000 * 16) / 44100;
	begin
		process(clk) begin
			if rising_edge(clk) then
				sampletick <= '0';
				counter<=counter-1;
				if counter=0 then
					sampletick<='1';
					counter<=to_unsigned(ticks,counter'high+1);
				end if;
			end if;
		end process;
	end block;
	
	statemachine : block
		type ds_states is (
			validate,validate2,
			bram,
			init,init2,init3,init4,
			fetch, fetch2, fetch3,
			mem,mem2,mem3,mem4,mem5,
			idle,play,play2,play3,play4,play5,
			trigger,trigger2
		);
		signal ds_state : ds_states := validate;
		signal ds_memreturnstate : ds_states;
		signal ds_bramreturnstate : ds_states;
		signal mema : unsigned(23 downto 0);
		signal soundslot : unsigned(DRIVESOUND_COUNT_LOG2-1 downto 0);
		signal nextslot : unsigned(DRIVESOUND_COUNT_LOG2-1 downto 0);
		signal fetch_addr : unsigned(23 downto 0);
		signal fetch_q : std_logic_vector(31 downto 0);
		
		signal offset : unsigned(23 downto 0);
		signal wordtoggle : std_logic;
		
		signal triggers : std_logic_vector(DRIVESOUND_END-1 downto 0);
		signal playing : std_logic_vector(DRIVESOUND_END-1 downto 0);
		signal accumulator : unsigned(15 downto 0);
		signal fd_motor_d : std_logic;
		signal lfsr_reg : unsigned(24 downto 0) := X"A5A5A5"&"0"; -- FIXME - use a much smaller LFSR
		signal lfsr_t : unsigned(1 downto 0);
		signal lfsr_t2 : unsigned(1 downto 0);
		signal cycle_lfsr : std_logic;
		signal fd_prev : std_logic;
		signal hd_prev : std_logic;
	begin
		mem_addr(31 downto 24) <= (others => '0');
--		mem_addr(23 downto 0) <= std_logic_vector(mema);

		process(clk) begin
			if rising_edge(clk) then
				if cycle_lfsr='1' then
					lfsr_t2<=lfsr_t;
					lfsr_t<=lfsr_reg(1 downto 0);
				end if;
				
				if lfsr_t=lfsr_reg(1 downto 0) or lfsr_t2=lfsr_reg(1 downto 0) then
					lfsr_reg<=lfsr_reg(23 downto 0) & (lfsr_reg(24) xor lfsr_reg(21));
				end if;
			end if;
		end process;

		-- Main state machine
		process(clk) begin
			if rising_edge(clk) then

				fd_prev <= fd_step;
				hd_prev <= hd_step;
			
				if reset_n='0' then
					triggers <= (others => '0');
				else
					cycle_lfsr <= '0';

					if fd_step='1' and fd_prev='0' and config(CONFIG_FLOPPY_BIT)='1' then	-- Use an LFSR to pick a random step sound
						case(lfsr_reg(1 downto 0)) is
							when "00" =>
								triggers(DRIVESOUND_STEP1)<= '1';
							when "01" =>
								triggers(DRIVESOUND_STEP2)<= '1';
							when "10" =>
								triggers(DRIVESOUND_STEP3)<= '1';
							when "11" =>
								triggers(DRIVESOUND_STEP4)<= '1';
							when others =>
								null;
						end case;
						cycle_lfsr<='1';
					end if;

					if hd_step='1' and hd_prev='0' and config(CONFIG_HDD_BIT)='1' then	-- Use an LFSR to pick a random step sound
						case(lfsr_reg(1 downto 0)) is
							when "00" =>
								triggers(DRIVESOUND_HDDSTEP1)<= '1';
							when "01" =>
								triggers(DRIVESOUND_HDDSTEP2)<= '1';
							when "10" =>
								triggers(DRIVESOUND_HDDSTEP3)<= '1';
							when "11" =>
								triggers(DRIVESOUND_HDDSTEP4)<= '1';
							when others =>
								null;
						end case;
						cycle_lfsr<='1';
					end if;
				
					if fd_motor='1' and fd_motor_d='0' and config(CONFIG_FLOPPY_BIT)='1' then
						triggers(DRIVESOUND_MOTORSTART)<='1';
						triggers(DRIVESOUND_MOTORLOOP)<='1';
					end if;

					if fd_motor='0' and fd_motor_d='1' then
						playing(DRIVESOUND_MOTORLOOP)<='0';
						triggers(DRIVESOUND_MOTORSTOP)<=config(CONFIG_FLOPPY_BIT);
					end if;
					fd_motor_d<=fd_motor;
					
					if fd_insert='1' and config(CONFIG_FLOPPY_BIT)='1' then
						triggers(DRIVESOUND_INSERT)<='1';					
					end if;
					
					if fd_eject='1' and config(CONFIG_FLOPPY_BIT)='1' then
						triggers(DRIVESOUND_EJECT)<='1';					
					end if;				
				end if;

				ds_wr<='0';
				if reset_n='0' then
					ds_state<=validate;
					mem_req_i<='0';
					soundslot<=(others => '1');	-- Use the last soundslot to fetch and index the others
					nextslot<=(others => '0');
				else
					case ds_state is

						when bram =>
							ds_state <= ds_bramreturnstate;

						-- Memory interface - checks the cache, and defers to the Fetch stateline if necessary

						-- Fetch the current soundslot's pointer
						when mem =>
							ds_addr(ds_addr'high downto DS_RECORDSIZE_LOG2) <= soundslot;
							ds_addr(DS_RECORDSIZE_LOG2-1 downto 0) <= to_unsigned(DS_PTR,DS_RECORDSIZE_LOG2); 
							ds_bramreturnstate<=mem3;
							ds_state<=bram;

						-- Compare fetch address and pointer (at cacheline granularity) and trigger a fetch if necessary
						when mem3 =>
							-- Update current soundslot's pointer with fetch_addr.
							ds_d <= X"00" & std_logic_vector(fetch_addr(23 downto 0));
							ds_wr <= '1';
							if std_logic_vector(fetch_addr(23 downto 4)) = ds_q(23 downto 4) then
								-- If we have the right cacheline in BRAM then read and return the appropriate word
								ds_state<=mem4;
							else
								-- Trigger a fetch
								mem_addr_i(23 downto 4) <= std_logic_vector(fetch_addr(23 downto 4));
								mem_addr_i(3 downto 0) <= (others => '0');
								mem_req_i<='1';
								ds_state<=fetch;
							end if;

						when mem4 =>
							-- Fetch the appropriate word from BRAM
							ds_addr(DS_RECORDSIZE_LOG2-1) <= '1';
							ds_addr(DS_RECORDSIZE_LOG2-2 downto 0) <= fetch_addr(3 downto 2);
							ds_bramreturnstate<=mem5;
							ds_state<=bram;
						
						when mem5 =>
							-- Handle potential misaligned reads.
							if fetch_addr(1)='1' then
								fetch_q <= fetch_q(15 downto 0) & ds_q(15 downto 0);
							else
								fetch_q <= fetch_q(15 downto 0) & ds_q(31 downto 16);
							end if;
							ds_state<=ds_memreturnstate;


						-- Fetch interface - fills a cacheline from SDRAM, then returns to the Mem stateline to fulfil the original request.

						when fetch =>
							ds_addr(DS_RECORDSIZE_LOG2-1 downto 0) <= to_unsigned(DS_BUF,DS_RECORDSIZE_LOG2); -- Point to cacheline address
							-- Wait for burst and receive first high word
							if mem_ack='1' then
								mem_req_i<='0';
								ds_d(31 downto 16) <= mem_d;
								ds_state <= fetch2;
							end if;
							
						when fetch2 =>
							-- Receive low word and write to the buffer
							ds_d(15 downto 0) <= mem_d;	-- Record a word of the cacheline
							ds_wr<='1';
							if ds_addr(DS_RECORDSIZE_LOG2-1 downto 0) = "111" then -- Have we filled the cacheline?
								ds_state<=mem; -- Now restart the access cycle, which will be satisfied by the newly-cached data.
							else
								ds_state<=fetch3;
							end if;

						when fetch3 =>
							-- Receive the next high word and advance the cacheline pointer.
							ds_addr<=ds_addr+1;
							ds_d(31 downto 16) <= mem_d;
							ds_state<=fetch2;

						-- Make sure we have viable drivesound data
						when validate =>
							soundslot <= to_unsigned(15,DRIVESOUND_COUNT_LOG2);	-- Use a dummy soundslot to read the sound setup data
							ds_addr(ds_addr'high downto DS_RECORDSIZE_LOG2) <= (others => '1'); -- Clear the pointer to force it to be re-read from RAM
							ds_addr(DS_RECORDSIZE_LOG2-1 downto 0) <= to_unsigned(DS_PTR,DS_RECORDSIZE_LOG2); 
							ds_d<=(others =>'0');
							ds_wr<='1';
							fetch_addr <= DRIVESOUND_BASE; -- Validate the drivesounds data
							ds_memreturnstate<=validate2;
							ds_state<=mem;
							
						when validate2 =>
							if fetch_q(15 downto 4) = X"445" then
								config <= fetch_q(3 downto 0);
								ds_state<=init;
							end if;
							
						-- Initialisation - reads and stores the base and length of each sample.
						when init =>
							fetch_addr <= DRIVESOUND_BASE + X"E"; -- Read first length field
							nextslot <= (others => '0');
							ds_state<=mem;
							ds_memreturnstate<=init3;

						when init3 => -- Record the end pointer for the next sample
							fetch_addr <= fetch_addr+2;
							ds_addr(ds_addr'high downto DS_RECORDSIZE_LOG2) <= nextslot;	-- Record the size
							ds_addr(DS_RECORDSIZE_LOG2-1 downto 0) <= to_unsigned(DS_LENGTH,DS_RECORDSIZE_LOG2);
							ds_d <= X"00" & std_logic_vector(unsigned(fetch_q(15 downto 0)) + fetch_addr + 2);
							ds_wr<='1';
							nextslot<=nextslot+1;
							ds_state<=init4;
							
						when init4 =>
							-- Record buffer address
							ds_addr(DS_RECORDSIZE_LOG2-1 downto 0) <= to_unsigned(DS_BASE,DS_RECORDSIZE_LOG2);
							ds_d <= X"00" & std_logic_vector(fetch_addr);
							ds_wr<='1';
							fetch_addr<=fetch_addr + 6 + unsigned(fetch_q(15 downto 0));
							if nextslot = DRIVESOUND_END then
								ds_state<=idle;
							else
								ds_memreturnstate<=init3;
								ds_state<=mem;
							end if;
						
						
						when idle =>
							aud_q<=std_logic_vector(accumulator);
							if sampletick='1' then
								accumulator<=(others => '0');
								soundslot<=(others => '0');
								ds_state<=play;
							end if;

						when play =>
							if soundslot=DRIVESOUND_END then
								ds_state<=idle;
							else
								if triggers(to_integer(soundslot))='1' then
									triggers(to_integer(soundslot))<='0';
									ds_state<=trigger;
								elsif playing(to_integer(soundslot))='1' then
									ds_state<=play2;
								else
									soundslot<=soundslot+1;
								end if;
							end if;
							
						when play2 =>
							ds_addr(ds_addr'high downto DS_RECORDSIZE_LOG2) <= soundslot;
							ds_addr(DS_RECORDSIZE_LOG2-1 downto 0) <= to_unsigned(DS_PTR,DS_RECORDSIZE_LOG2); 
							ds_bramreturnstate<=play3;
							ds_state<=bram;
						
						when play3 =>
							fetch_addr<=unsigned(ds_q(23 downto 0))+2;
							ds_memreturnstate<=play4;
							ds_state<=mem;
							
						when play4 =>
							ds_addr(DS_RECORDSIZE_LOG2-1 downto 0) <= to_unsigned(DS_LENGTH,DS_RECORDSIZE_LOG2);
							ds_bramreturnstate<=play5;
							ds_state<=bram;
							
						when play5 =>
							if ds_q(23 downto 0)=std_logic_vector(fetch_addr) then
								if soundslot=DRIVESOUND_MOTORLOOP then
									ds_state<=trigger;
								else
									playing(to_integer(soundslot))<='0';
									soundslot<=soundslot+1;
									ds_state<=play;
								end if;
							else
								accumulator<=accumulator+unsigned(fetch_q(15 downto 0));
								soundslot<=soundslot+1;
								ds_state<=play;
							end if;
							
						when trigger =>	-- Set the sample pointer to the start.
							ds_addr(ds_addr'high downto DS_RECORDSIZE_LOG2) <= soundslot;
							ds_addr(DS_RECORDSIZE_LOG2-1 downto 0) <= to_unsigned(DS_BASE,DS_RECORDSIZE_LOG2); 
							ds_bramreturnstate<=trigger2;
							ds_state<=bram;

						when trigger2 =>
							ds_addr(DS_RECORDSIZE_LOG2-1 downto 0) <= to_unsigned(DS_PTR,DS_RECORDSIZE_LOG2);
							ds_d<=ds_q;
							ds_wr<='1';
							playing(to_integer(soundslot))<='1';
							ds_state<=play;

						when others =>
							null;
					end case;			
				end if;
			end if;
		end process;
	end block;

end architecture;
