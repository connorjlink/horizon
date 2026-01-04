-------------------------------------------------------------------------
-- Connor Link
-- Iowa State University
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- tb_regfile.vhd
-- DESCRIPTION: This file contains a testbench to verify the regfile.vhd module.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- For logic types I/O
library std;
use std.env.all;                -- For hierarchical/external signals
use std.textio.all;             -- For basic I/O
use work.RISCV_types.all;

entity tb_regfile is
	generic(gCLK_HPER  : time := 10 ns;
     	    DATA_WIDTH : integer := 32);
end tb_regfile;

architecture mixed of tb_regfile is

-- Total clock period
constant cCLK_PER : time := gCLK_HPER * 2;

-- Element under test
component regfile is
    port(i_Clock : in  std_logic;
         i_Reset : in  std_logic;
         i_RS1 : in  std_logic_vector(4 downto 0);
         i_RS2 : in  std_logic_vector(4 downto 0);
         i_RD  : in  std_logic_vector(4 downto 0);
         i_WE  : in  std_logic;
         i_D   : in  std_logic_vector(31 downto 0);
         o_DS1 : out std_logic_vector(31 downto 0);
         o_DS2 : out std_logic_vector(31 downto 0));
end component;

-- Create helper signals
signal CLK, reset : std_logic := '0';

-- Create input and output signals for the module under test
signal s_iRS1 : std_logic_vector(4 downto 0) := b"00000";
signal s_iRS2 : std_logic_vector(4 downto 0) := b"00000";
signal s_iRD : std_logic_vector(4 downto 0) := b"00000";
signal s_iWE : std_logic := '0';
signal s_iD :std_logic_vector(31 downto 0) := x"00000000";
signal s_oDS1 : std_logic_vector(31 downto 0);
signal s_oDS2 : std_logic_vector(31 downto 0);

begin

-- Instantiate the module under test
DUT0: regfile
	port map(i_Clock => CLK,
             i_Reset => reset,
             i_RS1 => s_iRS1,
             i_RS2 => s_iRS2,
             i_RD  => s_iRD,
             i_WE  => s_iWE,
             i_D   => s_iD,
             o_DS1 => s_oDS1,
             o_DS2 => s_oDS2);


--This first process is to setup the clock for the test bench
P_CLK: process
begin
	CLK <= '1';         -- clock starts at 1
	wait for gCLK_HPER; -- after half a cycle
	CLK <= '0';         -- clock becomes a 0 (negative edge)
	wait for gCLK_HPER; -- after half a cycle, process begins evaluation again
end process;

-- This process resets the sequential components of the design.
-- It is held to be 1 across both the negative and positive edges of the clock
-- so it works regardless of whether the design uses synchronous (pos or neg edge)
-- or asynchronous resets.
P_RST: process
begin
	reset <= '0';   
	wait for gCLK_HPER/2;
	reset <= '1';
	wait for gCLK_HPER*2;
	reset <= '0';
	wait;
end process;  


-- Assign inputs 
P_TEST_CASES: process
begin
	wait for gCLK_HPER;
	wait for gCLK_HPER/2; -- don't change inputs on clock edges
    wait for gCLK_HPER * 2;

    -- Test Case 1:
    s_iRD <= b"00001";
    s_iWE <= '1';
    s_iD  <= x"FEEDFACE";
    wait for gCLK_HPER * 2;
    -- Expect: s_oDS1 to be $00000000, s_oDS2 to be $00000000

    -- Test Case 2:
    s_iRD <= b"00101";
    s_iWE <= '1';
    s_iD  <= x"DEADBEEF";
    wait for gCLK_HPER * 2;
    -- Expect: s_oDS1 to be $00000000, s_oDS2 to be $00000000

    -- Test Case 3:
    s_iRD <= b"00100";
    s_iWE <= '0'; -- NOTE: not being written here
    s_iD  <= x"DEADBEEF";
    wait for gCLK_HPER * 2;
    -- Expect: s_oDS1 to be $00000000, s_oDS2 to be $00000000

    -- Test Case 4:
    s_iRD  <= b"10000";
    s_iWE  <= '1';
    s_iD   <= x"C0FFEEEE";
    s_iRS1 <= b"00101";
    wait for gCLK_HPER * 2;
    -- Expect: s_oDS1 to be $DEADBEEF, s_oDS2 to be $00000000

    -- Test Case 5:
    s_iRD <= b"00000";
    s_iWE <= '0'; 
    s_iD  <= x"00000000";
    s_iRS1 <= b"00001";
    s_iRS2 <= b"00101";
    wait for gCLK_HPER * 2;
    -- Expect: s_oDS1 to be $FEEDFACE, s_oDS2 to be $DEADBEEF

    -- Test Case 6:
    s_iRS1 <= b"00000";
    s_iRS2 <= b"00101";
    wait for gCLK_HPER * 2;
    -- Expect: s_oDS1 to be $00000000, s_oDS2 to be $DEADBEEF

    -- Test Case 7:
    s_iRS1 <= b"10000";
    s_iRS2 <= b"10000";
    wait for gCLK_HPER * 2;
    -- Expect: s_oDS1 to be $C0FFEEEE, s_oDS2 to be $C0FFEEEE

    -- Test Case 8:
    s_iRS1 <= b"00000";
    s_iRS2 <= b"00000";
    wait for gCLK_HPER * 2;
    -- Expect: s_oDS1 to be $00000000, s_oDS2 to be $00000000

	wait;
end process;

end mixed;
