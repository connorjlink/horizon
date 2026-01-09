-- Horizon: tb_not_N.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;
library work;
use work.types.all;

entity tb_not_N is
    generic(
        CLOCK_HALF_PERIOD : time    := 10 ns;
        DATA_WIDTH        : integer := 32
    );
end tb_not_N;

architecture implementation of tb_not_N is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iS : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000000";
signal s_oF : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

    -- Design-under-test instantiation
    DUT: entity work.not_N
        generic map(
            N => DATA_WIDTH
        )
        port map(
            i_S => s_iS,
            o_F => s_oF
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

        s_iS <= x"00000000";
        wait for CLOCK_PERIOD;
        assert s_oF = x"FFFFFFFF"
            report "tb_not_N: testcase 1 failed (expected $FFFFFFFF)"
            severity error;

        s_iS <= x"FFFFFFFF";
        wait for CLOCK_PERIOD;
        assert s_oF = x"00000000"
            report "tb_not_N: testcase 2 failed (expected $00000000)"
            severity error;

        s_iS <= x"33333333";
        wait for CLOCK_PERIOD;
        assert s_oF = x"CCCCCCCC"
            report "tb_not_N: testcase 3 failed (expected $CCCCCCCC)"
            severity error;

        s_iS <= x"88888888";
        wait for CLOCK_PERIOD;
        assert s_oF = x"77777777"
            report "tb_not_N: testcase 4 failed (expected $77777777)"
            severity error;

        finish;

    end process;

end implementation;
