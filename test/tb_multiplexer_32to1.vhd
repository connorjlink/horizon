-- Horizon: tb_multiplexer_32to1.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;
library work;
use work.types.all;

entity tb_multiplexer_32to1 is
    generic(
        CLOCK_HALF_PERIOD : time    := 10 ns;
        DATA_WIDTH        : integer := 32
    );
end tb_multiplexer_32to1;

architecture implementation of tb_multiplexer_32to1 is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iS : std_logic_vector(4 downto 0) := b"00000";
signal s_iD : array_t(0 to 31);
signal s_oQ : std_logic_vector(31 downto 0);

begin

    -- Design-under-test instantiation
    DUT: entity work.multiplexer_32to1
        port map(
            i_S => s_iS,
            i_D => s_iD,
            o_Q => s_oQ
        );

    
    p_Clock: process
    begin
        s_Clock <= '1';
        wait for CLOCK_HALF_PERIOD;
        s_Clock <= '0';
        wait for CLOCK_HALF_PERIOD;
    end process;

    p_Reset: process
    begin
        s_Reset <= '0';
        wait for CLOCK_HALF_PERIOD / 2;
        s_Reset <= '1';
        wait for CLOCK_PERIOD;
        s_Reset <= '0';
        wait;
    end process;


    p_Stimulus: process
    begin
        -- Await reset and stabilization; trigger off-edge
        wait for CLOCK_HALF_PERIOD;
        wait for CLOCK_HALF_PERIOD / 2; 

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

        s_iS <= b"00000";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00000000")
            report "tb_multiplexer_32to1: testcase 1 failed (expected Q=$00000000)"
            severity error;

        s_iS <= b"00001";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00001111")
            report "tb_multiplexer_32to1: testcase 2 failed (expected Q=$00001111)"
            severity error;

        s_iS <= b"00010";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00002222")
            report "tb_multiplexer_32to1: testcase 3 failed (expected Q=$00002222)"
            severity error;

        s_iS <= b"00011";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00003333")
            report "tb_multiplexer_32to1: testcase 4 failed (expected Q=$00003333)"
            severity error;

        s_iS <= b"00100";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00004444")
            report "tb_multiplexer_32to1: testcase 5 failed (expected Q=$00004444)"
            severity error;

        s_iS <= b"00101";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00005555")
            report "tb_multiplexer_32to1: testcase 6 failed (expected Q=$00005555)"
            severity error;

        s_iS <= b"00110";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00006666")
            report "tb_multiplexer_32to1: testcase 7 failed (expected Q=$00006666)"
            severity error;

        s_iS <= b"00111";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00007777")
            report "tb_multiplexer_32to1: testcase 8 failed (expected Q=$00007777)"
            severity error;

        s_iS <= b"01000";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00008888")
            report "tb_multiplexer_32to1: testcase 9 failed (expected Q=$00008888)"
            severity error;

        s_iS <= b"01001";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00009999")
            report "tb_multiplexer_32to1: testcase 10 failed (expected Q=$00009999)"
            severity error;

        s_iS <= b"01010";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"0000AAAA")
            report "tb_multiplexer_32to1: testcase 11 failed (expected Q=$0000AAAA)"
            severity error;

        s_iS <= b"01011";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"0000BBBB")
            report "tb_multiplexer_32to1: testcase 12 failed (expected Q=$0000BBBB)"
            severity error;

        s_iS <= b"01100";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"0000CCCC")
            report "tb_multiplexer_32to1: testcase 13 failed (expected Q=$0000CCCC)"
            severity error;

        s_iS <= b"01101";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"0000DDDD")
            report "tb_multiplexer_32to1: testcase 14 failed (expected Q=$0000DDDD)"
            severity error;

        s_iS <= b"01110";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"0000EEEE")
            report "tb_multiplexer_32to1: testcase 15 failed (expected Q=$0000EEEE)"
            severity error;

        s_iS <= b"01111";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"0000FFFF")
            report "tb_multiplexer_32to1: testcase 16 failed (expected Q=$0000FFFF)"
            severity error;

        s_iS <= b"10000";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00000000")
            report "tb_multiplexer_32to1: testcase 17 failed (expected Q=$00000000)"
            severity error;

        s_iS <= b"10001";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"11110000")
            report "tb_multiplexer_32to1: testcase 18 failed (expected Q=$11110000)"
            severity error;

        s_iS <= b"10010";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"22220000")
            report "tb_multiplexer_32to1: testcase 19 failed (expected Q=$22220000)"
            severity error;

        s_iS <= b"10011";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"33330000")
            report "tb_multiplexer_32to1: testcase 20 failed (expected Q=$33330000)"
            severity error;

        s_iS <= b"10100";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"44440000")
            report "tb_multiplexer_32to1: testcase 21 failed (expected Q=$44440000)"
            severity error;

        s_iS <= b"10101";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"55550000")
            report "tb_multiplexer_32to1: testcase 22 failed (expected Q=$55550000)"
            severity error;

        s_iS <= b"10110";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"66660000")
            report "tb_multiplexer_32to1: testcase 23 failed (expected Q=$66660000)"
            severity error;

        s_iS <= b"10111";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"77770000")
            report "tb_multiplexer_32to1: testcase 24 failed (expected Q=$77770000)"
            severity error;

        s_iS <= b"11000";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"88880000")
            report "tb_multiplexer_32to1: testcase 25 failed (expected Q=$88880000)"
            severity error;

        s_iS <= b"11001";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"99990000")
            report "tb_multiplexer_32to1: testcase 26 failed (expected Q=$99990000)"
            severity error;

        s_iS <= b"11010";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"AAAA0000")
            report "tb_multiplexer_32to1: testcase 27 failed (expected Q=$AAAA0000)"
            severity error;

        s_iS <= b"11011";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"BBBB0000")
            report "tb_multiplexer_32to1: testcase 28 failed (expected Q=$BBBB0000)"
            severity error;

        s_iS <= b"11100";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"CCCC0000")
            report "tb_multiplexer_32to1: testcase 29 failed (expected Q=$CCCC0000)"
            severity error;

        s_iS <= b"11101";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"DDDD0000")
            report "tb_multiplexer_32to1: testcase 30 failed (expected Q=$DDDD0000)"
            severity error;

        s_iS <= b"11110";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"EEEE0000")
            report "tb_multiplexer_32to1: testcase 31 failed (expected Q=$EEEE0000)"
            severity error;

        s_iS <= b"11111";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"FFFF0000")
            report "tb_multiplexer_32to1: testcase 32 failed (expected Q=$FFFF0000)"
            severity error;

        finish;

    end process;

end implementation;
