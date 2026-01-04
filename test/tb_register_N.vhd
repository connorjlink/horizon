-------------------------------------------------------------------------
-- Connor Link
-- Iowa State University
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- tb_register_N.vhd
-- DESCRIPTION: This file contains a testbench to verify the register_N.vhd module.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- For logic types I/O
library std;
use std.env.all;                -- For hierarchical/external signals
use std.textio.all;             -- For basic I/O

entity tb_register_N is
	generic(gCLK_HPER  : time := 10 ns;
     	    DATA_WIDTH : integer := 32);
end tb_register_N;

architecture mixed of tb_register_N is

-- Total clock period
constant cCLK_PER : time := gCLK_HPER * 2;

-- Element under test
component register_N is
    generic(N : integer := 32);
	port(i_Clock : in  std_logic;                       -- Clock input
         i_Reset : in  std_logic;                       -- Reset input
         i_WE  : in  std_logic;                       -- Write enable input
         i_D   : in  std_logic_vector(N-1 downto 0);  -- Data value input
         o_Q   : out std_logic_vector(N-1 downto 0)); -- Data value output
end component;

-- Create helper signals
signal CLK, reset : std_logic := '0';

-- Create input and output signals for the module under test
signal s_iWE : std_logic;
signal s_iD  : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000000";
signal s_oQ  : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

-- Instantiate the module under test
DUT0: register_N
    generic map(N => DATA_WIDTH)
	port map(i_Clock => CLK,
             i_Reset => reset,
             i_WE  => s_iWE,
             i_D   => s_iD,
             o_Q   => s_oQ);


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

    -- Test Case 1:
    s_iWE <= '0';
    s_iD <= x"0000FFFF";
    wait for gCLK_HPER * 2;
    -- Expect: s_oQ to be $00000000

    -- Test Case 2:
    s_iWE <= '1';
    s_iD <= x"0000FFFF";
    wait for gCLK_HPER * 2;
    -- Expect: s_oQ to be $0000FFFF
    
    -- Test Case 3:
    s_iWE <= '0';
    s_iD <= x"00000000";
    wait for gCLK_HPER * 2;
    -- Expect: s_oQ to be $0000FFFF

    -- Test Case 4:
    s_iWE <= '0';
    s_iD <= x"AAAA0000";
    wait for gCLK_HPER * 2;
    -- Expect: s_oQ to be $0000FFFF

    -- Test Case 5:
    s_iWE <= '1';
    s_iD <= x"AAAA0000";
    wait for gCLK_HPER * 2;
    -- Expect: s_oQ to be $AAAA0000

    -- Test Case 6:
    s_iWE <= '1';
    s_iD <= x"FEEDFACE";
    wait for gCLK_HPER * 2;
    -- Expect: s_oQ to be $FEEDFACE

    -- Test Case 7:
    s_iWE <= '0';
    s_iD <= x"DEADBEEF";
    wait for gCLK_HPER * 2;
    -- Expect: s_oQ to be $FEEDFACE

	wait;
end process;

end mixed;
