-- Horizon: tb_multiplexer_2to1_N.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;
library work;
use work.types.all;

entity tb_multiplexer_2to1_N is
    generic(
        CLOCK_HALF_PERIOD : time    := 10 ns;
        DATA_WIDTH        : integer := 8
    );
end tb_multiplexer_2to1_N;

architecture implementation of tb_multiplexer_2to1_N is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iD0 : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00";
signal s_iD1 : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00";
signal s_iS  : std_logic := '0';
signal s_oO  : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

    -- Design-under-test instantiation
    DUT: entity work.multiplexer_2to1_N
        generic map(
            N => DATA_WIDTH
        )
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
        s_iD0 <= x"00";
        s_iD1 <= x"00";
        wait for CLOCK_PERIOD;
        assert (s_oO = x"00")
            report "tb_multiplexer_2to1_N: testcase 1 failed (expected O=$00)"
            severity error;

        s_iS  <= '0';
        s_iD0 <= x"00";
        s_iD1 <= x"EE";
        wait for CLOCK_PERIOD;
        assert (s_oO = x"00")
            report "tb_multiplexer_2to1_N: testcase 2 failed (expected O=$00)"
            severity error;
    
        s_iS  <= '0';
        s_iD0 <= x"11";
        s_iD1 <= x"00";
        wait for CLOCK_PERIOD;
        assert (s_oO = x"11")
            report "tb_multiplexer_2to1_N: testcase 3 failed (expected O=$11)"
            severity error;

        s_iS  <= '0';
        s_iD0 <= x"11";
        s_iD1 <= x"EE";
        wait for CLOCK_PERIOD;
        assert (s_oO = x"11")
            report "tb_multiplexer_2to1_N: testcase 4 failed (expected O=$11)"
            severity error;
    
        s_iS  <= '1';
        s_iD0 <= x"00";
        s_iD1 <= x"00";
        wait for CLOCK_PERIOD;
        assert (s_oO = x"00")
            report "tb_multiplexer_2to1_N: testcase 5 failed (expected O=$00)"
            severity error;

        s_iS  <= '1';
        s_iD0 <= x"00";
        s_iD1 <= x"EE";
        wait for CLOCK_PERIOD;
        assert (s_oO = x"EE")
            report "tb_multiplexer_2to1_N: testcase 6 failed (expected O=$EE)"
            severity error;

        s_iS  <= '1';
        s_iD0 <= x"11";
        s_iD1 <= x"00";
        wait for CLOCK_PERIOD;
        assert (s_oO = x"00")
            report "tb_multiplexer_2to1_N: testcase 7 failed (expected O=$00)"
            severity error;

        s_iS  <= '1';
        s_iD0 <= x"11";
        s_iD1 <= x"EE";
        wait for CLOCK_PERIOD;
        assert (s_oO = x"EE")
            report "tb_multiplexer_2to1_N: testcase 8 failed (expected O=$EE)"
            severity error;

        finish;

    end process;

end implementation;
