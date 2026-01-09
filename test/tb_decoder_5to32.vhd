-- Horizon: tb_decoder_5to32.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_decoder_5to32 is
    generic(
        CLOCK_HALF_PERIOD : time    := 10 ns;
        DATA_WIDTH        : integer := 8
    );
end tb_decoder_5to32;

architecture implementation of tb_decoder_5to32 is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iS : std_logic_vector(4 downto 0) := b"00000";
signal s_oQ : std_logic_vector(31 downto 0);

begin

    -- Design-under-test instantiation
    DUT: entity work.decoder_5to32
        port map(
            i_S => s_iS,
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

        s_iS <= "00000";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000000000000000000001"
            report "tb_decoder_5to32: testcase 1 failed (expected 00000000000000000000000000000001)"
            severity error;

        s_iS <= "00001";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000000000000000000010"
            report "tb_decoder_5to32: testcase 2 failed (expected 00000000000000000000000000000010)"
            severity error;

        s_iS <= "00010";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000000000000000000100"
            report "tb_decoder_5to32: testcase 3 failed (expected 00000000000000000000000000000100)"
            severity error;

        s_iS <= "00011";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000000000000000001000"
            report "tb_decoder_5to32: testcase 4 failed (expected 00000000000000000000000000001000)"
            severity error;

        s_iS <= "00100";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000000000000000010000"
            report "tb_decoder_5to32: testcase 5 failed (expected 00000000000000000000000000010000)"
            severity error;

        s_iS <= "00101";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000000000000000100000"
            report "tb_decoder_5to32: testcase 6 failed (expected 00000000000000000000000000100000)"
            severity error;

        s_iS <= "00110";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000000000000001000000"
            report "tb_decoder_5to32: testcase 7 failed (expected 00000000000000000000000001000000)"
            severity error;

        s_iS <= "00111";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000000000000010000000"
            report "tb_decoder_5to32: testcase 8 failed (expected 00000000000000000000000010000000)"
            severity error;

        s_iS <= "01000";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000000000000100000000"
            report "tb_decoder_5to32: testcase 9 failed (expected 00000000000000000000000100000000)"
            severity error;

        s_iS <= "01001";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000000000001000000000"
            report "tb_decoder_5to32: testcase 10 failed (expected 00000000000000000000001000000000)"
            severity error;

        s_iS <= "01010";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000000000010000000000"
            report "tb_decoder_5to32: testcase 11 failed (expected 00000000000000000000010000000000)"
            severity error;

        s_iS <= "01011";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000000000100000000000"
            report "tb_decoder_5to32: testcase 12 failed (expected 00000000000000000000100000000000)"
            severity error;

        s_iS <= "01100";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000000001000000000000"
            report "tb_decoder_5to32: testcase 13 failed (expected 00000000000000000001000000000000)"
            severity error;

        s_iS <= "01101";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000000010000000000000"
            report "tb_decoder_5to32: testcase 14 failed (expected 00000000000000000010000000000000)"
            severity error;

        s_iS <= "01110";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000000100000000000000"
            report "tb_decoder_5to32: testcase 15 failed (expected 00000000000000000100000000000000)"
            severity error;

        s_iS <= "01111";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000001000000000000000"
            report "tb_decoder_5to32: testcase 16 failed (expected 00000000000000001000000000000000)"
            severity error;

        s_iS <= "10000";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000010000000000000000"
            report "tb_decoder_5to32: testcase 17 failed (expected 00000000000000010000000000000000)"
            severity error;

        s_iS <= "10001";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000000100000000000000000"
            report "tb_decoder_5to32: testcase 18 failed (expected 00000000000000100000000000000000)"
            severity error;

        s_iS <= "10010";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000001000000000000000000"
            report "tb_decoder_5to32: testcase 19 failed (expected 00000000000001000000000000000000)"
            severity error;

        s_iS <= "10011";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000010000000000000000000"
            report "tb_decoder_5to32: testcase 20 failed (expected 00000000000010000000000000000000)"
            severity error;

        s_iS <= "10100";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000000100000000000000000000"
            report "tb_decoder_5to32: testcase 21 failed (expected 00000000000100000000000000000000)"
            severity error;

        s_iS <= "10101";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000001000000000000000000000"
            report "tb_decoder_5to32: testcase 22 failed (expected 00000000001000000000000000000000)"
            severity error;

        s_iS <= "10110";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000010000000000000000000000"
            report "tb_decoder_5to32: testcase 23 failed (expected 00000000010000000000000000000000)"
            severity error;

        s_iS <= "10111";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000000100000000000000000000000"
            report "tb_decoder_5to32: testcase 24 failed (expected 00000000100000000000000000000000)"
            severity error;

        s_iS <= "11000";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000001000000000000000000000000"
            report "tb_decoder_5to32: testcase 25 failed (expected 00000001000000000000000000000000)"
            severity error;

        s_iS <= "11001";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000010000000000000000000000000"
            report "tb_decoder_5to32: testcase 26 failed (expected 00000010000000000000000000000000)"
            severity error;

        s_iS <= "11010";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00000100000000000000000000000000"
            report "tb_decoder_5to32: testcase 27 failed (expected 00000100000000000000000000000000)"
            severity error;

        s_iS <= "11011";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00001000000000000000000000000000"
            report "tb_decoder_5to32: testcase 28 failed (expected 00001000000000000000000000000000)"
            severity error;

        s_iS <= "11100";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00010000000000000000000000000000"
            report "tb_decoder_5to32: testcase 29 failed (expected 00010000000000000000000000000000)"
            severity error;

        s_iS <= "11101";
        wait for CLOCK_PERIOD;
        assert s_oQ = "00100000000000000000000000000000"
            report "tb_decoder_5to32: testcase 30 failed (expected 00100000000000000000000000000000)"
            severity error;

        s_iS <= "11110";
        wait for CLOCK_PERIOD;
        assert s_oQ = "01000000000000000000000000000000"
            report "tb_decoder_5to32: testcase 31 failed (expected 01000000000000000000000000000000)"
            severity error;

        s_iS <= "11111";
        wait for CLOCK_PERIOD;
        assert s_oQ = "10000000000000000000000000000000"
            report "tb_decoder_5to32: testcase 32 failed (expected 10000000000000000000000000000000)"
            severity error;

        finish;

    end process;

end implementation;
