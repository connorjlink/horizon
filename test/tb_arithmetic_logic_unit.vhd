-- Horizon: tb_arithmetic_logic_unit.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
use IEEE.numeric_std.all;
library std;
use std.env.all;
use std.textio.all;
library work;
use work.types.all;

entity tb_arithmetic_logic_unit is
    generic(
        CLOCK_HALF_PERIOD : time    := 10 ns;
        DATA_WIDTH        : integer := 32
    );
end tb_arithmetic_logic_unit;

architecture implementation of tb_arithmetic_logic_unit is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iA        : std_logic_vector(31 downto 0) := 32x"0";
signal s_iB        : std_logic_vector(31 downto 0) := 32x"0";
signal s_iOperator : alu_operator_t := ADD_OPERATOR;
signal s_oF        : std_logic_vector(31 downto 0) := 32x"0";
signal s_oCarry    : std_logic;

begin

    -- Design-under-test instantiation
    DUT: entity work.arithmetic_logic_unit
        generic map(
            N => DATA_WIDTH
        )
        port map(
            i_A        => s_iA,
            i_B        => s_iB,
            i_Operator => s_iOperator,
            o_F        => s_oF,
            o_Carry    => s_oCarry
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
        -- Await s_Reset and stabilization; trigger off-edge
        wait for CLOCK_HALF_PERIOD;
        wait for CLOCK_HALF_PERIOD / 2; 

        s_iA <= 32x"5";
        s_iB <= 32x"7";
        s_iOperator <= ADD_OPERATOR;
        wait for CLOCK_PERIOD;
        assert (s_oF = 32x"C" and s_oCarry = '0')
            report "tb_arithmetic_logic_unit: testcase 1 failed (expected F=$C, Co=0)"
            severity error;

        s_iA <= 32x"7";
        s_iB <= 32x"5";
        s_iOperator <= SUB_OPERATOR;
        wait for CLOCK_PERIOD;
        assert (s_oF = 32x"2" and s_oCarry = '0')
            report "tb_arithmetic_logic_unit: testcase 2 failed (expected F=$2, Co=0)"
            severity error;

        s_iA <= 32x"FFFFFFFF";
        s_iB <= 32x"CCCCCCCC";
        s_iOperator <= AND_OPERATOR;
        wait for CLOCK_PERIOD;
        assert (s_oF = 32x"CCCCCCCC" and s_oCarry = '0')
            report "tb_arithmetic_logic_unit: testcase 3 failed (expected F=$CCCCCCCC, Co=0)"
            severity error;

        s_iA <= 32x"33333333";
        s_iB <= 32x"CCCCCCCC";
        s_iOperator <= OR_OPERATOR;
        wait for CLOCK_PERIOD;
        assert (s_oF = 32x"FFFFFFFF" and s_oCarry = '0')
            report "tb_arithmetic_logic_unit: testcase 4 failed (expected F=$FFFFFFFF, Co=0)"
            severity error;

        s_iA <= 32x"33333333";
        s_iB <= 32x"FFFFFFFF";
        s_iOperator <= XOR_OPERATOR;
        wait for CLOCK_PERIOD;
        assert (s_oF = 32x"CCCCCCCC" and s_oCarry = '0')
            report "tb_arithmetic_logic_unit: testcase 5 failed (expected F=$CCCCCCCC, Co=0)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"1";
        s_iOperator <= SLL_OPERATOR;
        wait for CLOCK_PERIOD;
        assert (s_oF = 32x"00000000" and s_oCarry = '0')
            report "tb_arithmetic_logic_unit: testcase 6 failed (expected F=$00000000, Co=0)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"1";
        s_iOperator <= SRL_OPERATOR;
        wait for CLOCK_PERIOD;
        assert (s_oF = 32x"40000000" and s_oCarry = '0')
            report "tb_arithmetic_logic_unit: testcase 7 failed (expected F=$40000000, Co=0)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"1";
        s_iOperator <= SRA_OPERATOR;
        wait for CLOCK_PERIOD;
        assert (s_oF = 32x"C0000000" and s_oCarry = '0')
            report "tb_arithmetic_logic_unit: testcase 8 failed (expected F=$C0000000, Co=0)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"1";
        s_iOperator <= SLT_OPERATOR;
        wait for CLOCK_PERIOD;
        assert (s_oF = 32x"1" and s_oCarry = '0')
            report "tb_arithmetic_logic_unit: testcase 9 failed (expected F=$1, Co=0)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"1";
        s_iOperator <= SLTU_OPERATOR;
        wait for CLOCK_PERIOD;
        assert (s_oF = 32x"0" and s_oCarry = '0')
            report "tb_arithmetic_logic_unit: testcase 10 failed (expected F=$0, Co=0)"
            severity error;

        finish;

    end process;

end implementation;
