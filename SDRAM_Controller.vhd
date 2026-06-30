----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    00:00:47 10/15/2025 
-- Design Name: 
-- Module Name:    SDRAM_Controller - Behavioral 
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity SDRAM_Controller is
  PORT (
    clka : IN STD_LOGIC;
	 wr_rd : IN STD_LOGIC;
	 memstrb : IN  STD_LOGIC;
    addra : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
end SDRAM_Controller;

architecture Behavioral of SDRAM_Controller is
	type ram_t is array (0 to 65535) of std_logic_vector(7 downto 0);
	signal ram : ram_t;

begin

process (clka)
begin
if rising_edge(clka) then
if memstrb = '1' then  
if(wr_rd = '0') then
douta <= ram(to_integer(unsigned(addra)));
elsif(wr_rd = '1') then
ram(to_integer(unsigned(addra))) <= dina;
end if;
end if;
end if;
 end process;
end Behavioral;

