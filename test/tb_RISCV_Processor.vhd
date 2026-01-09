-------------------------------------------------------------------------
-- Connor Link
-- Iowa State University
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- tb_RISCV_Processor.vhd
-- DESCRIPTION: This file contains a testbench to verify the RISCV_Processor.vhd module.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- For logic types I/O
library std;
use std.env.all;                -- For hierarchical/external signals
use std.textio.all;             -- For basic I/O
use work.types.all;

entity tb_RISCV_Processor is
	generic(CLOCK_HALF_PERIOD  : time := 10 ns;
     	    DATA_WIDTH : integer := 32);
end tb_RISCV_Processor;

architecture mixed of tb_RISCV_Processor is

component RISCV_Processor is
	generic(
		N : integer := work.types.DATA_WIDTH
	);
	port(
		i_Clock      : in  std_logic;
		i_Reset      : in  std_logic;
		iInstLd   : in  std_logic;
		iInstAddr : in  std_logic_vector(N-1 downto 0);
		iInstExt  : in  std_logic_vector(N-1 downto 0);
		oALUOut   : out std_logic_vector(N-1 downto 0)
	); 
end component;


constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Create inputs signals
signal iInstLd : std_logic := '0';
signal iInstAddr, iInstExt, oALUOut : std_logic_vector(31 downto 0) := 32x"0";


begin

-- Design-under-test instantiation
DUT0: RISCV_Processor
	port map(
		i_Clock      => CLK,
		i_Reset      => reset,
		iInstLd   => iInstLd,
		iInstAddr => iInstAddr,
		iInstExt  => iInstExt,
		oALUOut   => oALUOut
	);

-- This process resets the sequential components of the design.
-- It is held to be 1 across both the negative and positive edges of the clock
-- so it works regardless of whether the design uses synchronous (pos or neg edge)
-- or asynchronous resets.
P_RST: process
begin
	reset <= '1';
	wait for CLOCK_HALF_PERIOD*2;
	wait for CLOCK_HALF_PERIOD*2;
	wait for CLOCK_HALF_PERIOD/2; -- don't change inputs on clock edges
	reset <= '0';
	wait;
end process;  

--This first process is to setup the clock for the test bench
P_CLK: process
begin
	CLK <= '1';         -- clock starts at 1
	wait for CLOCK_HALF_PERIOD; -- after half a cycle
	CLK <= '0';         -- clock becomes a 0 (negative edge)
	wait for CLOCK_HALF_PERIOD; -- after half a cycle, process begins evaluation again
end process;


-- Assign inputs 
P_TEST_CASES: process
begin
	wait for CLOCK_HALF_PERIOD;
	wait for CLOCK_HALF_PERIOD/2; -- don't change inputs on clock edges
    wait for CLOCK_HALF_PERIOD * 2;

    -- running loaded hex binary image
    
	wait;
end process;

end mixed;
