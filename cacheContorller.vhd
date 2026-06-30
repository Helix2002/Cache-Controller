----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    23:07:50 10/14/2025 
-- Design Name: 
-- Module Name:    cacheContorller - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity cacheContorller is
    Port ( 
	 --clock and reset
	clk : in  std_logic;
	rst : in  std_logic;
	add: out std_logic_vector(15 downto 0);
	cache_dout: out  std_logic_vector(7 downto 0);
	cache_add: out  std_logic_vector(7 downto 0);
   wr_rd: out std_logic;
	memstrb: out std_logic;
	rdy: out std_logic;
	cs: out std_logic;

	--SRAM
	sram_outa : out  std_logic_vector(7 downto 0);
	sram_ina : out  std_logic_vector(7 downto 0);
	sram_adda : out  std_logic_vector(7 downto 0);

	-- SDRAM
	sdram_adda : out std_logic_vector(15 downto 0);
	sdram_dina : out  std_logic_vector(7 downto 0);
	sdram_douta : out  std_logic_vector(7 downto 0));
end cacheContorller;

architecture Behavioral of cacheContorller is

 --CPU
   signal cpu_din : std_logic_vector(7 downto 0);
	signal cpu_dout : std_logic_vector(7 downto 0);
	signal cpu_add : std_logic_vector(15 downto 0);
	signal cpu_cs : std_logic;
	signal cpu_rdy : std_logic;
	signal cpu_wr_rd : std_logic;
	signal awr_tag: std_logic_vector(7 downto 0);
	signal awr_index: std_logic_vector(2 downto 0); 
   signal awr_offset: std_logic_vector(4 downto 0);

	--SRAM
	signal sram_out : std_logic_vector(7 downto 0);
	signal sram_in : std_logic_vector(7 downto 0);
	signal sram_wen : std_logic_vector(0 downto 0);
	signal sram_add : std_logic_vector(7 downto 0);
	signal dirty_bit : std_logic_vector(7 downto 0):= "00000000";
	signal valid_bit : std_logic_vector(7 downto 0):= "00000000";
   signal awr_tag_wen : std_logic := '0';
	
	-- SDRAM
	signal sdram_wr_rd : std_logic; 
	signal sdram_add : std_logic_vector(15 downto 0);
	signal sdram_din : std_logic_vector(7 downto 0);
	signal sdram_dout : std_logic_vector(7 downto 0);
	signal sdram_memstrb : std_logic;
	signal sdram_offset : integer := 0; 
	signal counter : integer := 0;
	
	type cache_mem is array (7 downto 0) of std_logic_vector(7 downto 0);
	signal cachetag : cache_mem  := ((others => (others => '0')));
	
	signal control0 : std_logic_vector(35 downto 0);
	signal ila_data : std_logic_vector(63 downto 0);
	signal trig0 : std_logic_vector(7 downto 0);
	
	--State of Address
	-- Ready : state0
	-- idle : state1
	-- hit : state2
	-- Miss/load from main memory : state3
	-- write from main memory : state4
	
	type soa is (state0,state1,state2,state3,state4);
	signal current_soa : soa;
	signal state : std_logic_vector(3 downto 0);
	

---------------------------------------------------------
-- ChipScope components and signals.
---------------------------------------------------------
component icon
port (
    CONTROL0: inout std_logic_vector(35 downto 0));
end component;

component ila
port (
    CONTROL: inout std_logic_vector(35 downto 0);
    CLK: in std_logic;
    DATA: in std_logic_vector(63 downto 0);
    TRIG0: in std_logic_vector(7 downto 0));
end component;

component CPU_gen
	Port ( 
		clk 		: in  STD_LOGIC;
      rst 		: in  STD_LOGIC;
      trig 		: in  STD_LOGIC;
		-- Interface to the Cache Controller.
      Address 	: out  STD_LOGIC_VECTOR (15 downto 0);
      wr_rd 	: out  STD_LOGIC;
      cs 		: out  STD_LOGIC;
      DOut 		: out  STD_LOGIC_VECTOR (7 downto 0)
	);
end component;

component SDRAM_Controller
  PORT (
    clka : IN STD_LOGIC;
	 addra : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
	 wr_rd : IN STD_LOGIC;
	 memstrb : IN  STD_LOGIC;
    dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
end component;

component SRAM_SDRAM
PORT(
	 clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
);
end component;

begin

call_Cpu_gen : Cpu_gen port map(
clk,
'0',
cpu_rdy,
cpu_add,
cpu_wr_rd,
cpu_cs,cpu_dout);

call_SDRAM : SDRAM_Controller port map(
clk,
sdram_add,
sdram_wr_rd,
sdram_memstrb,
sdram_din,
sdram_dout);

call_SRAM : SRAM_SDRAM port map(
clk,
sram_wen,
sram_add,
sram_in,
sram_out);

myicon : icon port map(
control0);

myila : ila port map(
control0,
clk,
ila_data,
trig0);

process(clk,cpu_cs)
	begin
		if rising_edge(clk) then
			case current_soa is
				when state0 =>
					cpu_rdy <= '0';
					awr_tag <= cpu_add(15 downto 8);
					awr_index <= cpu_add(7 downto 5);
					awr_offset <= cpu_add(4 downto 0);
					sdram_add(15 downto 5) <= cpu_add(15 downto 5);
					sram_add(7 downto 0) <= cpu_add(7 downto 0);
					sram_wen <= "0";
					-- Hit or miss
					if(valid_bit(to_integer(unsigned(awr_index))) = '1' and 
					cachetag(to_integer(unsigned(awr_index))) = awr_tag) then
						-- if hit
						awr_tag_wen <= '1';
						current_soa <= state2;
						state <= "0000";
					else --miss
						awr_tag_wen <= '0';
						if(dirty_bit(to_integer(unsigned(awr_index))) = '1' and valid_bit(to_integer(unsigned(awr_index))) = '1') then
							current_soa <= state4; -- write back to 
							state <= "0100";
						else
							current_soa <= state3;
							state <= "0011";
					end if;
				end if;
		  
		  when state2 =>
			if(cpu_wr_rd = '1') then
				sram_wen <= "1";
				dirty_bit(to_integer(unsigned(awr_index))) <= '1';
				valid_bit(to_integer(unsigned(awr_index))) <= '1';
				sram_in <= cpu_dout;
				cpu_din <="00000000";
			else
				cpu_din <= sram_out;
			end if;
			
			current_soa <= state1;
			state <= "0001";
			
		  
		 when state3 =>
			if(counter = 64) then
				counter <= 0;
				valid_bit(to_integer(unsigned(awr_index))) <= '1';
				cachetag(to_integer(unsigned(awr_index))) <= awr_tag;
				sdram_offset <= 0;
				current_soa <= state2;
				state <= "0010";
				
			else
				if(counter mod 2 = 1) then
					sdram_memstrb <= '0';
				else
					sdram_add(4 downto 0) <= std_logic_vector(to_unsigned(sdram_offset,awr_offset'length));
					sdram_wr_rd <= '0';
					sdram_memstrb <= '1';
					sram_add(7 downto 5) <= awr_index;
					sram_add(4 downto 0) <= std_logic_vector(to_unsigned(sdram_offset,awr_offset'length));
					sram_in <= sdram_dout;
					sram_wen <="1";
					sdram_offset <= sdram_offset +1;
				end if;
				counter <= counter +1;
			end if;
					
					
				
		  
		  when state4 =>
			if(counter = 64) then
				counter <= 0;
				dirty_bit(to_integer(unsigned(awr_index))) <= '0';
				sdram_offset <= 0;
				current_soa <= state3;
				state <= "0011";
			else
				if(counter mod 2 = 1) then
					sdram_memstrb <= '0';
				else
					sdram_add(4 downto 0) <= std_logic_vector(to_unsigned(sdram_offset,awr_offset'length));
					sdram_wr_rd <= '1';
					sram_add(7 downto 5) <= awr_index;
					sram_add(4 downto 0) <= std_logic_vector(to_unsigned(sdram_offset,awr_offset'length));
					sram_wen <= "0";
					sdram_din <= sram_out;
					sdram_memstrb <= '1';
					sdram_offset <= sdram_offset + 1;
				end if;
				counter <= counter + 1;
			end if;
			
		when state1 =>
			cpu_rdy <= '1';
			if(cpu_cs = '1') then
				current_soa <= state0;
				state <= "0000";
			end if;
		end case;
	end if;
end process;

cs <= cpu_cs;
memstrb <= sdram_memstrb;
wr_rd <= cpu_wr_rd;
cache_dout <= cpu_din;
rdy <= cpu_rdy;
add <= cpu_add;

sram_adda <= sram_add;
sram_ina <= sram_in;
sram_outa <= sram_out;

sdram_adda <= sdram_add;
sdram_dina <= sdram_din;
sdram_douta <= sdram_dout;

cache_add <= cpu_add(15 downto 8);

ila_data(15 downto 0) <= cpu_add;
ila_data(16) <= cpu_wr_rd;
ila_data(17) <= cpu_cs;
ila_data(18) <= cpu_rdy;
ila_data(22 downto 19) <= state;
ila_data(23) <= valid_bit(to_integer(unsigned(awr_index)));
ila_data(24) <= dirty_bit(to_integer(unsigned(awr_index)));
ila_data(25) <= awr_tag_wen;
ila_data(41 downto 26) <= sdram_add;
ila_data(49 downto 42) <= sram_add;
ila_data(57 downto 50) <= sdram_dout;
ila_data(63 downto 58) <= (others =>  '0');
				


end Behavioral;

