-- Horizon: tb_multiplier.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_multiplier is
    generic(
        CLOCK_HALF_PERIOD : time := 10 ns
    );
end tb_multiplier;

architecture implementation of tb_multiplier is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iA         : std_logic_vector(15 downto 0) := x"0000";
signal s_iB         : std_logic_vector(15 downto 0) := x"0000";
signal s_iAIsSigned : std_logic := '0';
signal s_iBIsSigned : std_logic := '0';
signal s_oP         : std_logic_vector(31 downto 0);

begin

    -- Design-under-test instantiation
    DUT: entity work.multiplier
        generic map(
            N => 16
        )
        port map(
            i_A => s_iA,
            i_B => s_iB,
            i_AIsSigned => s_iAIsSigned,
            i_BIsSigned => s_iBIsSigned,
            o_P => s_oP
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

        s_iA <= x"0003";
        s_iB <= x"0004";
        s_iAIsSigned <= '0';
        s_iBIsSigned <= '0';
        wait for CLOCK_PERIOD;
        assert s_oP = x"0000000C"
            report "tb_multiplier: testcase 1 failed (expected 0x0000000C)"
            severity error;

        s_iA <= x"00FF";
        s_iB <= x"0002";
        s_iAIsSigned <= '0';
        s_iBIsSigned <= '0';
        wait for CLOCK_PERIOD;
        assert s_oP = x"000001FE"
            report "tb_multiplier: testcase 2 failed (expected 0x000001FE)"
            severity error;

        s_iA <= x"FFFF";
        s_iB <= x"FFFF";
        s_iAIsSigned <= '0';
        s_iBIsSigned <= '0';
        wait for CLOCK_PERIOD;
        assert s_oP = x"FFFE0001"
            report "tb_multiplier: testcase 3 failed (expected 0xFFFE0001)"
            severity error;

        s_iA <= x"1234";
        s_iB <= x"5678";
        s_iAIsSigned <= '0';
        s_iBIsSigned <= '0';
        wait for CLOCK_PERIOD;
        assert s_oP = x"06260060"
            report "tb_multiplier: testcase 4 failed (expected 0x06260060)"
            severity error;

        -- -1 * -1 = 1
        s_iA <= x"FFFF";
        s_iB <= x"FFFF";
        s_iAIsSigned <= '1';
        s_iBIsSigned <= '1';
        wait for CLOCK_PERIOD;
        assert s_oP = x"00000001"
            report "tb_multiplier: testcase 5 failed (expected 0x00000001)"
            severity error;

        -- -2 * 3 = -6
        s_iA <= x"FFFE";
        s_iB <= x"0003";
        s_iAIsSigned <= '1';
        s_iBIsSigned <= '1';
        wait for CLOCK_PERIOD;
        assert s_oP = x"FFFFFFFA"
            report "tb_multiplier: testcase 6 failed (expected 0xFFFFFFFA)"
            severity error;


        -- 4 * -5 = -20
        s_iA <= x"0004";
        s_iB <= x"FFFB";
        s_iAIsSigned <= '0';
        s_iBIsSigned <= '1';
        wait for CLOCK_PERIOD;
        assert s_oP = x"FFFFFFEC"
            report "tb_multiplier: testcase 7 failed (expected 0xFFFFFFEC)"
            severity error;

        -- 6 * 7 = 42
        s_iA <= x"0006";
        s_iB <= x"0007";
        s_iAIsSigned <= '1';
        s_iBIsSigned <= '1';
        wait for CLOCK_PERIOD;
        assert s_oP = x"0000002A"
            report "tb_multiplier: testcase 8 failed (expected 0x0000002A)"
            severity error;

        finish;

    end process;

end implementation;
