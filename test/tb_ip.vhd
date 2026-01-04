-------------------------------------------------------------------------
-- Connor Link
-- Iowa State University
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- tb_ip.vhd
-- DESCRIPTION: This file contains an implementation of a simple testbench for the RISC-V instruction pointer circuit.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_ip is
    generic(gCLK_HPER  : time := 10 ns;
     	    DATA_WIDTH : integer := 32);
end tb_ip;

architecture mixed of tb_ip is

-- Total clock period
constant cCLK_PER : time := gCLK_HPER * 2;

-- Element under test
component ip is
    generic(
        -- Signal to hold the default data page address (according to RARS at least)
        ResetAddress : std_logic_vector(31 downto 0) := 32x"00400000"
    );
    port(
        i_Clock        : in  std_logic;
        i_Reset        : in  std_logic;
        i_Load       : in  std_logic;
        i_Addr       : in  std_logic_vector(31 downto 0);
        i_nInc2_Inc4 : in  std_logic; -- 0 = inc2, 1 = inc4
        i_Stall      : in  std_logic;
        o_Addr       : out std_logic_vector(31 downto 0);
        o_LinkAddr   : out std_logic_vector(31 downto 0)
    );
end component;

-- Create helper signals
signal CLK, reset : std_logic := '0';

-- Create input and output signals for the module under test
signal s_iLoad       : std_logic := '0';
signal s_iAddr       : std_logic_vector(31 downto 0) := 32x"0";
signal s_inInc2_Inc4 : std_logic := '0';
signal s_iStall      : std_logic := '0';
signal s_oAddr       : std_logic_vector(31 downto 0);
signal s_oLinkAddr   : std_logic_vector(31 downto 0);

begin

-- Instantiate the module under test
DUTO: ip
    port map(
        i_Clock        => CLK,
        i_Reset        => reset,
        i_Load       => s_iLoad,
        i_Addr       => s_iAddr,
        i_nInc2_Inc4 => s_inInc2_Inc4,
        i_Stall      => s_iStall,
        o_Addr       => s_oAddr,
        o_LinkAddr   => s_oLinkAddr
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

    -- s_iLoad      
    -- s_iAddr      
    -- s_inInc2_Inc4
    -- s_iStall

    -- Test case 1: counting up by 4
    s_iLoad <= '0';
    s_iAddr <= 32x"0";
    s_inInc2_Inc4 <= '1';
    s_iStall <= '0';
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;
    
    -- Test case 2: counting up by 2
    s_iLoad <= '0';
    s_iAddr <= 32x"0";
    s_inInc2_Inc4 <= '0';
    s_iStall <= '0';
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;

    -- Test case 3: stall counting for both counting modes
    s_iLoad <= '0';
    s_iAddr <= 32x"0";
    s_inInc2_Inc4 <= '1';
    s_iStall <= '1';
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;
    s_inInc2_Inc4 <= '0';
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;

    -- Test case 4: loading a custom address
    s_iLoad <= '1';
    s_iAddr <= 32x"FEEDFACE";
    s_inInc2_Inc4 <= '0';
    s_iStall <= '0';
    wait for gCLK_HPER * 2;
    s_iLoad <= '0';
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;

    -- Test case 5: loading a custom address
    s_iLoad <= '1';
    s_iAddr <= 32x"0";
    s_inInc2_Inc4 <= '0';
    s_iStall <= '0';
    wait for gCLK_HPER * 2;
    s_iLoad <= '0';
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;
    wait for gCLK_HPER * 2;


    wait;
end process;

end mixed;
