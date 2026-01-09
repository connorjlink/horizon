-------------------------------------------------------------------------
-- Connor Link
-- Iowa State University
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- tb_mux2t1.vhd
-- DESCRIPTION: This file contains a testbench to verify the mux2t1.vhd module.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- For logic types I/O
library std;
use std.env.all;                -- For hierarchical/external signals
use std.textio.all;             -- For basic I/O

entity tb_mux2t1 is
	generic(CLOCK_HALF_PERIOD  : time := 10 ns;
     	    DATA_WIDTH : integer := 8);
end tb_mux2t1;

architecture mixed of tb_mux2t1 is


constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Element under test
component mux2t1 is
	port(i_D0 : in  std_logic;
	     i_D1 : in  std_logic;
	     i_S  : in  std_logic;
	     o_O  : out std_logic);
end component;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iD0 : std_logic := '0';
signal s_iD1 : std_logic := '0';
signal s_iS  : std_logic := '0';
signal s_oO  : std_logic;

begin

-- Design-under-test instantiation
DUT0: mux2t1
	port map(i_D0 => s_iD0,
 		 i_D1 => s_iD1,
		 i_S  => s_iS,
		 o_O  => s_oO);


--This first process is to setup the clock for the test bench
P_CLK: process
begin
	CLK <= '1';         -- clock starts at 1
	wait for CLOCK_HALF_PERIOD; -- after half a cycle
	CLK <= '0';         -- clock becomes a 0 (negative edge)
	wait for CLOCK_HALF_PERIOD; -- after half a cycle, process begins evaluation again
end process;

-- This process resets the sequential components of the design.
-- It is held to be 1 across both the negative and positive edges of the clock
-- so it works regardless of whether the design uses synchronous (pos or neg edge)
-- or asynchronous resets.
P_RST: process
begin
	reset <= '0';   
	wait for CLOCK_HALF_PERIOD/2;
	reset <= '1';
	wait for CLOCK_HALF_PERIOD*2;
	reset <= '0';
	wait;
end process;  


-- Assign inputs 
P_TEST_CASES: process
begin
	wait for CLOCK_HALF_PERIOD;
	wait for CLOCK_HALF_PERIOD/2; -- don't change inputs on clock edges

	-- Test Case 1:
	s_iS  <= '0';
	s_iD0 <= '0';
	s_iD1 <= '0';
	wait for CLOCK_HALF_PERIOD*2;
	-- Expect: s_oO to be 0

	-- Test Case 2:
	s_iS  <= '0';
	s_iD0 <= '0';
	s_iD1 <= '1';
	wait for CLOCK_HALF_PERIOD*2;
	-- Expect: s_oO to be 0

	-- Test Case 3:
	s_iS  <= '0';
	s_iD0 <= '1';
	s_iD1 <= '0';
	wait for CLOCK_HALF_PERIOD*2;
	-- Expect: s_oO to be 1

	-- Test Case 4:
	s_iS  <= '0';
	s_iD0 <= '1';
	s_iD1 <= '1';
	wait for CLOCK_HALF_PERIOD*2;
	-- Expect: s_oO to be 1

	-- Test Case 5:
	s_iS  <= '1';
	s_iD0 <= '0';
	s_iD1 <= '0';
	wait for CLOCK_HALF_PERIOD*2;
	-- Expect: s_oO to be 0

	-- Test Case 6:
	s_iS  <= '1';
	s_iD0 <= '0';
	s_iD1 <= '1';
	wait for CLOCK_HALF_PERIOD*2;
	-- Expect: s_oO to be 1

	-- Test Case 7:
	s_iS  <= '1';
	s_iD0 <= '1';
	s_iD1 <= '0';
	wait for CLOCK_HALF_PERIOD*2;
	-- Expect: s_oO to be 0

	-- Test Case 8:
	s_iS  <= '1';
	s_iD0 <= '1';
	s_iD1 <= '1';
	wait for CLOCK_HALF_PERIOD*2;
	-- Expect: s_oO to be 1

	wait;
end process;

end mixed;
