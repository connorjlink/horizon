-- Horizon: tb_branch_unit.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library std;
use std.env.all;
use std.textio.all;
library work;
use work.types.all;

entity tb_branch_unit is
    generic(
        CLOCK_HALF_PERIOD : time    := 10 ns;
        DATA_WIDTH        : integer := 32
    );
end tb_branch_unit;

architecture implementation of tb_branch_unit is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iDS1            : std_logic_vector(31 downto 0) := 32x"0";
signal s_iDS2            : std_logic_vector(31 downto 0) := 32x"0";
signal s_iBranchOperator : branch_operator_t := BEQ_TYPE;
signal s_oBranchTaken    : std_logic;
signal s_oBranchNotTaken : std_logic;

begin

    -- Design-under-test instantiation
    DUT: entity work.branch_unit
        port map(
            i_Clock          => s_Clock,
            i_DS1            => s_iDS1,
            i_DS2            => s_iDS2,
            i_BranchOperator => s_iBranchOperator,
            o_BranchTaken    => s_oBranchTaken,
            o_BranchNotTaken => s_oBranchNotTaken
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

        s_iDS1 <= 32x"7";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BEQ_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '0' and s_oBranchNotTaken = '1')
            report "tb_branch_unit: testcase 1 failed (expected BranchTaken=0, BranchNotTaken=1)"
            severity error;

        s_iDS1 <= 32x"5";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BEQ_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 2 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"7";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BNE_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 3 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"5";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BNE_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '0' and s_oBranchNotTaken = '1')
            report "tb_branch_unit: testcase 4 failed (expected BranchTaken=0, BranchNotTaken=1)"
            severity error;

        s_iDS1 <= 32x"7";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BLT_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '0' and s_oBranchNotTaken = '1')
            report "tb_branch_unit: testcase 5 failed (expected BranchTaken=0, BranchNotTaken=1)"
            severity error;

        s_iDS1 <= 32x"4";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BLT_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 6 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"7";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BGE_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 7 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"5";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BGE_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 8 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"7";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BLTU_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '0' and s_oBranchNotTaken = '1')
            report "tb_branch_unit: testcase 9 failed (expected BranchTaken=0, BranchNotTaken=1)"
            severity error;

        s_iDS1 <= 32x"4";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BLTU_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 10 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"7";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BGEU_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 11 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"5";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BGEU_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 12 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"7";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= JAL_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 13 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"5";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= JALR_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 14 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        finish;
        
    end process;

end implementation;
