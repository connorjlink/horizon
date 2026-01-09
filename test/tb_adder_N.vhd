-- Horizon: tb_adder_N.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_adder_N is
    generic(
        CLOCK_HALF_PERIOD : time    := 10 ns;
        DATA_WIDTH        : integer := 32
    );
end tb_adder_N;

architecture implementation of tb_adder_N is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iA     : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000000";
signal s_iB     : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000000";
signal s_iCarry : std_logic := '0';
signal s_oS     : std_logic_vector(DATA_WIDTH-1 downto 0);
signal s_oCarry : std_logic;

begin

    -- Design-under-test instantiation
    DUT: entity work.adder_N
        generic map(
            N => DATA_WIDTH
        )
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

        s_iA  <= x"00000000";
        s_iB  <= x"00000000";
        s_iCarry <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oS = x"00000000" and s_oCarry = '0')
            report "tb_adder_N: testcase 1 failed (expected S=0x00000000, Carry=0)"
            severity error;

        s_iA  <= x"00000005";
        s_iB  <= x"00000007";
        s_iCarry <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oS = x"0000000C" and s_oCarry = '0')
            report "tb_adder_N: testcase 2 failed (expected S=0x0000000C, Carry=0)"
            severity error;

        s_iA  <= x"000000FE";
        s_iB  <= x"00000001";
        s_iCarry <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oS = x"00000100" and s_oCarry = '0')
            report "tb_adder_N: testcase 3 failed (expected S=0x00000100, Carry=0)"
            severity error;

        s_iA  <= x"000000FE";
        s_iB  <= x"00000001";
        s_iCarry <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oS = x"000000FF" and s_oCarry = '0')
            report "tb_adder_N: testcase 4 failed (expected S=0x000000FF, Carry=0)"
            severity error;

        s_iA  <= x"FFFFFFFE";
        s_iB  <= x"00000001";
        s_iCarry <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oS = x"00000000" and s_oCarry = '1')
            report "tb_adder_N: testcase 5 failed (expected S=0x00000000, Carry=1)"
            severity error;

        s_iA  <= x"FFFFFFFE";
        s_iB  <= x"00000001";
        s_iCarry <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oS = x"FFFFFFFF" and s_oCarry = '0')
            report "tb_adder_N: testcase 6 failed (expected S=0xFFFFFFFF, Carry=0)"
            severity error;

        finish;

    end process;

end implementation;
