-------------------------------------------------------------------------
-- Connor Link
-- Iowa State University
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- tb_bgu.vhd
-- DESCRIPTION: This file contains an implementation of a simple testbench for the RISC-V branch controller (branch generation unit)
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library std;
use std.env.all;
use std.textio.all;
use work.RISCV_types.all;

entity tb_bgu is
    generic(gCLK_HPER  : time := 10 ns;
     	    DATA_WIDTH : integer := 32);
end tb_bgu;

architecture mixed of tb_bgu is

-- Total clock period
constant cCLK_PER : time := gCLK_HPER * 2;

-- Element under test
component bgu is
    port(
        i_Clock    : in  std_logic;
        i_DS1    : in  std_logic_vector(31 downto 0);
        i_DS2    : in  std_logic_vector(31 downto 0);
        i_BGUOp  : in  natural;
        o_Branch : out std_logic 
    );
end component;

-- Create helper signals
signal CLK, reset : std_logic := '0';

-- Create input and output signals for the module under test
signal s_iDS1 : std_logic_vector(31 downto 0) := 32x"0";
signal s_iDS2 : std_logic_vector(31 downto 0) := 32x"0";
signal s_iBGUOp : natural := 0;
signal s_oBranch : std_logic;

begin

-- Instantiate the module under test
DUTO: bgu
    port map(
        i_Clock    => CLK,
        i_DS1    => s_iDS1,
        i_DS2    => s_iDS2,
        i_BGUOp  => s_iBGUOp,
        o_Branch => s_oBranch
    );

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
    s_iDS1 <= 32x"7";
    s_iDS2 <= 32x"5";
    s_iBGUOp <= work.RISCV_types.BEQ;
    wait for gCLK_HPER * 2;

    -- Test Case 2: 
    s_iDS1 <= 32x"5";
    s_iDS2 <= 32x"5";
    s_iBGUOp <= work.RISCV_types.BEQ;
    wait for gCLK_HPER * 2;

    -- Test Case 3: 
    s_iDS1 <= 32x"7";
    s_iDS2 <= 32x"5";
    s_iBGUOp <= work.RISCV_types.BNE;
    wait for gCLK_HPER * 2;

    -- Test Case 4: 
    s_iDS1 <= 32x"5";
    s_iDS2 <= 32x"5";
    s_iBGUOp <= work.RISCV_types.BNE;
    wait for gCLK_HPER * 2;

    -- Test Case 5: 
    s_iDS1 <= 32x"7";
    s_iDS2 <= 32x"5";
    s_iBGUOp <= work.RISCV_types.BLT;
    wait for gCLK_HPER * 2;

    -- Test Case 6: 
    s_iDS1 <= 32x"4";
    s_iDS2 <= 32x"5";
    s_iBGUOp <= work.RISCV_types.BLT;
    wait for gCLK_HPER * 2;

    -- Test Case 7: 
    s_iDS1 <= 32x"7";
    s_iDS2 <= 32x"5";
    s_iBGUOp <= work.RISCV_types.BGE;
    wait for gCLK_HPER * 2;

    -- Test Case 8: 
    s_iDS1 <= 32x"5";
    s_iDS2 <= 32x"5";
    s_iBGUOp <= work.RISCV_types.BGE;
    wait for gCLK_HPER * 2;

    -- Test Case 9: 
    s_iDS1 <= 32x"7";
    s_iDS2 <= 32x"5";
    s_iBGUOp <= work.RISCV_types.BLTU;
    wait for gCLK_HPER * 2;

    -- Test Case 10: 
    s_iDS1 <= 32x"4";
    s_iDS2 <= 32x"5";
    s_iBGUOp <= work.RISCV_types.BLTU;
    wait for gCLK_HPER * 2;

    -- Test Case 11: 
    s_iDS1 <= 32x"7";
    s_iDS2 <= 32x"5";
    s_iBGUOp <= work.RISCV_types.BGEU;
    wait for gCLK_HPER * 2;

    -- Test Case 12: 
    s_iDS1 <= 32x"5";
    s_iDS2 <= 32x"5";
    s_iBGUOp <= work.RISCV_types.BGEU;
    wait for gCLK_HPER * 2;

    -- Test Case 13: 
    s_iDS1 <= 32x"7";
    s_iDS2 <= 32x"5";
    s_iBGUOp <= work.RISCV_types.J;
    wait for gCLK_HPER * 2;

    -- Test Case 14: 
    s_iDS1 <= 32x"5";
    s_iDS2 <= 32x"5";
    s_iBGUOp <= work.RISCV_types.J;
    wait for gCLK_HPER * 2;

    wait;
end process;

end mixed;
