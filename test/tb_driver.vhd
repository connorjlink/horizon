-------------------------------------------------------------------------
-- Connor Link
-- Iowa State University
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- tb_driver.vhd
-- DESCRIPTION: This file contains an implementation of a simple testbench for the RISC-V control driver.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_driver is
    generic(gCLK_HPER  : time := 10 ns;
     	    DATA_WIDTH : integer := 32);
end tb_driver;

architecture mixed of tb_driver is

-- Total clock period
constant cCLK_PER : time := gCLK_HPER * 2;

-- Element under test
component driver is
    port(
        i_Clock        : in  std_logic;
        i_Reset        : in  std_logic;
        i_Insn       : in  std_logic_vector(31 downto 0);
        i_MaskStall  : in  std_logic;
        o_MemWrite   : out std_logic;
        o_RegWrite   : out std_logic;
        o_RFSrc      : out natural; -- 0 = memory, 1 = ALU, 2 = IP+4
        o_ALUSrc     : out std_logic; -- 0 = register, 1 = immediate
        o_ALUOp      : out natural;
        o_BGUOp      : out natural;
        o_LSWidth    : out natural;
        o_RD         : out std_logic_vector(4 downto 0);
        o_RS1        : out std_logic_vector(4 downto 0);
        o_RS2        : out std_logic_vector(4 downto 0);
        o_Imm        : out std_logic_vector(31 downto 0);
        o_BranchMode : out natural;
        o_Break      : out std_logic;
        o_IsBranch   : out std_logic;
        o_nInc2_Inc4 : out std_logic;
        o_nZero_Sign : out std_logic;
        o_IPToALU    : out std_logic
    );
end component;

-- Create helper signals
signal CLK, reset : std_logic := '0';

-- Create input and output signals for the module under test
signal s_iInsn       : std_logic_vector(31 downto 0) := 32x"0";
signal s_iMaskStall  : std_logic := '0';  -- This will only be used for the pipelined implementation, so safe to ignore for now!
signal s_oMemWrite   : std_logic;
signal s_oRegWrite   : std_logic;
signal s_oRFSrc      : natural;
signal s_oALUSrc     : std_logic;
signal s_oALUOp      : natural;
signal s_oBGUOp      : natural;
signal s_oLSWidth    : natural;
signal s_oRD         : std_logic_vector(4 downto 0);
signal s_oRS1        : std_logic_vector(4 downto 0);
signal s_oRS2        : std_logic_vector(4 downto 0);
signal s_oImm        : std_logic_vector(31 downto 0);
signal s_oBreak      : std_logic;
signal s_oIsBranch   : std_logic;
signal s_onInc2_Inc4 : std_logic;
signal s_onZero_Sign : std_logic;
signal s_oIPToALU    : std_logic;

begin

-- Instantiate the module under test
DUTO: driver
    port map(
        i_Clock        => CLK,
        i_Reset        => reset,
        i_Insn       => s_iInsn,
        i_MaskStall  => s_iMaskStall,
        o_MemWrite   => s_oMemWrite,
        o_RegWrite   => s_oRegWrite,
        o_RFSrc      => s_oRFSrc,
        o_ALUSrc     => s_oALUSrc,
        o_ALUOp      => s_oALUOp,
        o_BGUOp      => s_oBGUOp,
        o_LSWidth    => s_oLSWidth,
        o_RD         => s_oRD,
        o_RS1        => s_oRS1,
        o_RS2        => s_oRS2,
        o_Imm        => s_oImm,
        o_Break      => s_oBreak,
        o_IsBranch   => s_oIsBranch,
        o_nInc2_Inc4 => s_onInc2_Inc4,
        o_nZero_Sign => s_onZero_Sign,
        o_IPToALU    => s_oIPToALU
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
    -- addi x25, x0, 0   # 0x00000c93
    s_iInsn <= 32x"00000c93";
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;

    -- Test Case 2:
    -- addi x26, x0, 256 # 0x10000d13
    s_iInsn <= 32x"10000d13";
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;

    -- Test Case 3:
    -- lw x1, 0(x25)     # 0x000ca083
    s_iInsn <= 32x"000ca083";
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;

    -- Test Case 4:
    -- lw x2, 4(x25)     # 0x004ca103
    s_iInsn <= 32x"004ca103";
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;

    -- Test Case 5:
    -- add x1, x1, x2    # 0x002080b3
    s_iInsn <= 32x"002080b3";
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;

    -- Test Case 6:
    -- sw x1, 0(x26)     # 0x001d2023
    s_iInsn <= 32x"001d2023";
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;

    wait;
end process;

end mixed;
