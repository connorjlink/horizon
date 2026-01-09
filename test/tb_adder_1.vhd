-- Horizon: tb_adder_1.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_adder_1 is
    generic(
        CLOCK_HALF_PERIOD : time    := 10 ns;
        DATA_WIDTH        : integer := 8
    );
end tb_adder_1;

architecture implementation of tb_adder_1 is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iA     : std_logic := '0';
signal s_iB     : std_logic := '0';
signal s_iCarry : std_logic := '0';
signal s_oS     : std_logic;
signal s_oCarry : std_logic;

begin

    -- Design-under-test instantiation
    DUT: entity work.adder_1
        port map(
            i_A     => s_iA,
            i_B     => s_iB,
            i_Carry => s_iCarry,
            o_S     => s_oS,
            o_Carry => s_oCarry
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

        s_iA  <= '0';
        s_iB  <= '0';
        s_iCarry <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oS = '0' and s_oCarry = '0')
            report "tb_adder_1: testcase 1 failed (expected S=0, Carry=0)"
            severity error;

        s_iA  <= '0';
        s_iB  <= '0';
        s_iCarry <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oS = '1' and s_oCarry = '0')
            report "tb_adder_1: testcase 2 failed (expected S=1, Carry=0)"
            severity error;

        s_iA  <= '0';
        s_iB  <= '1';
        s_iCarry <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oS = '1' and s_oCarry = '0')
            report "tb_adder_1: testcase 3 failed (expected S=1, Carry=0)"
            severity error;

        s_iA  <= '0';
        s_iB  <= '1';
        s_iCarry <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oS = '0' and s_oCarry = '1')
            report "tb_adder_1: testcase 4 failed (expected S=0, Carry=1)"
            severity error;

        s_iA  <= '1';
        s_iB  <= '0';
        s_iCarry <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oS = '1' and s_oCarry = '0')
            report "tb_adder_1: testcase 5 failed (expected S=1, Carry=0)"
            severity error;

        s_iA  <= '1';
        s_iB  <= '0';
        s_iCarry <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oS = '0' and s_oCarry = '1')
            report "tb_adder_1: testcase 6 failed (expected S=0, Carry=1)"
            severity error;

        s_iA  <= '1';
        s_iB  <= '1';
        s_iCarry <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oS = '0' and s_oCarry = '1')
            report "tb_adder_1: testcase 7 failed (expected S=0, Carry=1)"
            severity error;

        s_iA  <= '1';
        s_iB  <= '1';
        s_iCarry <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oS = '1' and s_oCarry = '1')
            report "tb_adder_1: testcase 8 failed (expected S=1, Carry=1)"
            severity error;

        finish;

    end process;

end implementation;
