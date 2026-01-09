-------------------------------------------------------------------------
-- Connor Link
-- Iowa State University
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- tb_mux32t1.vhd
-- DESCRIPTION: This file contains a testbench to verify the mux32t1.vhd module.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- For logic types I/O
library std;
use std.env.all;                -- For hierarchical/external signals
use std.textio.all;             -- For basic I/O
use work.types.all;

entity tb_mux32t1 is
	generic(CLOCK_HALF_PERIOD  : time := 10 ns;
     	    DATA_WIDTH : integer := 32);
end tb_mux32t1;

architecture mixed of tb_mux32t1 is


constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Element under test
component mux32t1 is
    port(i_S : in  std_logic_vector(4 downto 0);
         i_D : in  array_t(0 to 31);
         o_Q : out std_logic_vector(31 downto 0));
end component;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iS : std_logic_vector(4 downto 0) := b"00000";
signal s_iD : array_t(0 to 31);
signal s_oQ : std_logic_vector(31 downto 0);

begin

-- Design-under-test instantiation
DUT0: mux32t1
	port map(i_S => s_iS,
             i_D => s_iD,
             o_Q => s_oQ);


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

    -- Initial setup for all testcases
    s_iD(0)  <= x"00000000";
    s_iD(1)  <= x"00001111";
    s_iD(2)  <= x"00002222";
    s_iD(3)  <= x"00003333";
    s_iD(4)  <= x"00004444";
    s_iD(5)  <= x"00005555";
    s_iD(6)  <= x"00006666";
    s_iD(7)  <= x"00007777";
    s_iD(8)  <= x"00008888";
    s_iD(9)  <= x"00009999";
    s_iD(10) <= x"0000AAAA";
    s_iD(11) <= x"0000BBBB";
    s_iD(12) <= x"0000CCCC";
    s_iD(13) <= x"0000DDDD";
    s_iD(14) <= x"0000EEEE";
    s_iD(15) <= x"0000FFFF";
    s_iD(16) <= x"00000000";
    s_iD(17) <= x"11110000";
    s_iD(18) <= x"22220000";
    s_iD(19) <= x"33330000";
    s_iD(20) <= x"44440000";
    s_iD(21) <= x"55550000";
    s_iD(22) <= x"66660000";
    s_iD(23) <= x"77770000";
    s_iD(24) <= x"88880000";
    s_iD(25) <= x"99990000";
    s_iD(26) <= x"AAAA0000";
    s_iD(27) <= x"BBBB0000";
    s_iD(28) <= x"CCCC0000";
    s_iD(29) <= x"DDDD0000";
    s_iD(30) <= x"EEEE0000";
    s_iD(31) <= x"FFFF0000";

    -- Test Case 1:
    s_iS <= b"00000";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $00000000

        -- Test Case 2:
    s_iS <= b"00001";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $00001111

    -- Test Case 3:
    s_iS <= b"00010";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $00002222

    -- Test Case 4:
    s_iS <= b"00011";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $00003333

    -- Test Case 5:
    s_iS <= b"00100";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $00004444

    -- Test Case 6:
    s_iS <= b"00101";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $00005555

    -- Test Case 7:
    s_iS <= b"00110";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $00006666

    -- Test Case 8:
    s_iS <= b"00111";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $00007777

    -- Test Case 9:
    s_iS <= b"01000";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $00008888

    -- Test Case 10:
    s_iS <= b"01001";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $00009999

    -- Test Case 11:
    s_iS <= b"01010";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $0000AAAA

    -- Test Case 12:
    s_iS <= b"01011";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $0000BBBB

    -- Test Case 13:
    s_iS <= b"01100";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $0000CCCC

    -- Test Case 14:
    s_iS <= b"01101";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $0000DDDD

    -- Test Case 15:
    s_iS <= b"01110";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $0000EEEE

    -- Test Case 16:
    s_iS <= b"01111";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $0000FFFF

    -- Test Case 17:
    s_iS <= b"10000";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $00000000

    -- Test Case 18:
    s_iS <= b"10001";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $11110000

    -- Test Case 19:
    s_iS <= b"10010";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $22220000

    -- Test Case 20:
    s_iS <= b"10011";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $33330000

    -- Test Case 21:
    s_iS <= b"10100";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $44440000

    -- Test Case 22:
    s_iS <= b"10101";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $55550000

    -- Test Case 23:
    s_iS <= b"10110";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $66660000

    -- Test Case 24:
    s_iS <= b"10111";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $77770000

    -- Test Case 25:
    s_iS <= b"11000";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $88880000

    -- Test Case 26:
    s_iS <= b"11001";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $99990000

    -- Test Case 27:
    s_iS <= b"11010";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $AAAA0000

    -- Test Case 28:
    s_iS <= b"11011";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $BBBB0000

    -- Test Case 29:
    s_iS <= b"11100";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $CCCC0000

    -- Test Case 30:
    s_iS <= b"11101";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $DDDD0000

    -- Test Case 31:
    s_iS <= b"11110";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $EEEE0000

    -- Test Case 32:
    s_iS <= b"11111";
    wait for CLOCK_HALF_PERIOD * 2;
    -- Expect: s_oQ to be $FFFF0000

	wait;
end process;

end mixed;
