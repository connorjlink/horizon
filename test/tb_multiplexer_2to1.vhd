-- Horizon: tb_multiplexer_2to1.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_multiplexer_2to1 is
    generic(
        CLOCK_HALF_PERIOD : time    := 10 ns;
        DATA_WIDTH        : integer := 8
    );
end tb_multiplexer_2to1;

architecture implementation of tb_multiplexer_2to1 is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iD0 : std_logic := '0';
signal s_iD1 : std_logic := '0';
signal s_iS  : std_logic := '0';
signal s_oO  : std_logic;

begin

    -- Design-under-test instantiation
    DUT: entity work.multiplexer_2to1
        port map(
            i_D0 => s_iD0,
            i_D1 => s_iD1,
            i_S  => s_iS,
            o_O  => s_oO
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

        s_iS  <= '0';
        s_iD0 <= '0';
        s_iD1 <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oO = '0')
            report "tb_multiplexer_2to1: testcase 1 failed (expected O=0)"
            severity error;

        s_iS  <= '0';
        s_iD0 <= '0';
        s_iD1 <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oO = '0')
            report "tb_multiplexer_2to1: testcase 2 failed (expected O=0)"
            severity error;

        s_iS  <= '0';
        s_iD0 <= '1';
        s_iD1 <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oO = '1')
            report "tb_multiplexer_2to1: testcase 3 failed (expected O=1)"
            severity error;

        s_iS  <= '0';
        s_iD0 <= '1';
        s_iD1 <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oO = '1')
            report "tb_multiplexer_2to1: testcase 4 failed (expected O=1)"
            severity error;

        s_iS  <= '1';
        s_iD0 <= '0';
        s_iD1 <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oO = '0')
            report "tb_multiplexer_2to1: testcase 5 failed (expected O=0)"
            severity error;
    
        s_iS  <= '1';
        s_iD0 <= '0';
        s_iD1 <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oO = '1')
            report "tb_multiplexer_2to1: testcase 6 failed (expected O=1)"
            severity error;
    
        s_iS  <= '1';
        s_iD0 <= '1';
        s_iD1 <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oO = '0')
            report "tb_multiplexer_2to1: testcase 7 failed (expected O=0)"
            severity error;

        s_iS  <= '1';
        s_iD0 <= '1';
        s_iD1 <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oO = '1')
            report "tb_multiplexer_2to1: testcase 8 failed (expected O=1)"
            severity error;
        
        finish;

    end process;

end implementation;
