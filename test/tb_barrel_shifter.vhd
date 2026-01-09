-- Horizon: tb_barrel_shifter.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library std;
use std.env.all;
use std.textio.all;
library work;
use work.types.all;

entity tb_barrel_shifter is
    generic(
        CLOCK_HALF_PERIOD : time := 10 ns;
        DATA_WIDTH        : integer := 32
    );
end tb_barrel_shifter;

architecture implementation of tb_barrel_shifter is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iA            : std_logic_vector(31 downto 0) := 32x"0";
signal s_iB            : std_logic_vector(31 downto 0) := 32x"0";
signal s_iIsArithmetic : std_logic := '0';
signal s_iIsRight      : std_logic := '0';
signal s_oS            : std_logic_vector(31 downto 0);

begin

    -- Design-under-test instantiation
    DUT: entity work.barrel_shifter
        port map(
            i_A            => s_iA,
            i_B            => s_iB(4 downto 0),
            i_IsArithmetic => s_iIsArithmetic,
            i_IsRight      => s_iIsRight,
            o_S            => s_oS
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

        -- srl
        s_iA <= 32x"80000000";
        s_iB <= 32x"1";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"40000000"
            report "tb_barrel_shifter: testcase 1 failed (srl 1)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"2";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"20000000"
            report "tb_barrel_shifter: testcase 2 failed (srl 2)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"3";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"10000000"
            report "tb_barrel_shifter: testcase 3 failed (srl 3)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"4";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"08000000"
            report "tb_barrel_shifter: testcase 4 failed (srl 4)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"5";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"04000000"
            report "tb_barrel_shifter: testcase 5 failed (srl 5)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"6";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"02000000"
            report "tb_barrel_shifter: testcase 6 failed (srl 6)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"7";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"01000000"
            report "tb_barrel_shifter: testcase 7 failed (srl 7)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"8";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00800000"
            report "tb_barrel_shifter: testcase 8 failed (srl 8)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"9";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00400000"
            report "tb_barrel_shifter: testcase 9 failed (srl 9)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"A";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00200000"
            report "tb_barrel_shifter: testcase 10 failed (srl 10)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"B";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00100000"
            report "tb_barrel_shifter: testcase 11 failed (srl 11)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"C";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00080000"
            report "tb_barrel_shifter: testcase 12 failed (srl 12)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"D";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00040000"
            report "tb_barrel_shifter: testcase 13 failed (srl 13)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"E";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00020000"
            report "tb_barrel_shifter: testcase 14 failed (srl 14)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"F";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00010000"
            report "tb_barrel_shifter: testcase 15 failed (srl 15)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"10";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00008000"
            report "tb_barrel_shifter: testcase 16 failed (srl 16)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"11";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00004000"
            report "tb_barrel_shifter: testcase 17 failed (srl 17)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"12";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00002000"
            report "tb_barrel_shifter: testcase 18 failed (srl 18)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"13";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00001000"
            report "tb_barrel_shifter: testcase 19 failed (srl 19)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"14";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000800"
            report "tb_barrel_shifter: testcase 20 failed (srl 20)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"15";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000400"
            report "tb_barrel_shifter: testcase 21 failed (srl 21)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"16";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000200"
            report "tb_barrel_shifter: testcase 22 failed (srl 22)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"17";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000100"
            report "tb_barrel_shifter: testcase 23 failed (srl 23)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"18";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000080"
            report "tb_barrel_shifter: testcase 24 failed (srl 24)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"19";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000040"
            report "tb_barrel_shifter: testcase 25 failed (srl 25)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"1A";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000020"
            report "tb_barrel_shifter: testcase 26 failed (srl 26)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"1B";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000010"
            report "tb_barrel_shifter: testcase 27 failed (srl 27)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"1C";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000008"
            report "tb_barrel_shifter: testcase 28 failed (srl 28)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"1D";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000004"
            report "tb_barrel_shifter: testcase 29 failed (srl 29)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"1E";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000002"
            report "tb_barrel_shifter: testcase 30 failed (srl 30)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"1F";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000001"
            report "tb_barrel_shifter: testcase 31 failed (srl 31)"
            severity error;

        s_iA <= 32x"00FF0000";
        s_iB <= 32x"1";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"007F8000"
            report "tb_barrel_shifter: testcase 32 failed (srl 1)"
            severity error;

        s_iA <= 32x"00FF0000";
        s_iB <= 32x"1F";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000000"
            report "tb_barrel_shifter: testcase 33 failed (srl 31)"
            severity error;

        s_iA <= 32x"00FF0000";
        s_iB <= 32x"10";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"000000FF"
            report "tb_barrel_shifter: testcase 34 failed (srl 16)"
            severity error;


        -- sra
        s_iA <= 32x"80000000";
        s_iB <= 32x"1";
        s_iIsArithmetic <= '1';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"C0000000"
            report "tb_barrel_shifter: testcase 35 failed (sra 1)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"2";
        s_iIsArithmetic <= '1';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"E0000000"
            report "tb_barrel_shifter: testcase 36 failed (sra 2)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"3";
        s_iIsArithmetic <= '1';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"F0000000"
            report "tb_barrel_shifter: testcase 37 failed (sra 3)"
            severity error;    

        s_iA <= 32x"80000000";
        s_iB <= 32x"1";
        s_iIsArithmetic <= '1';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"C0000000"
            report "tb_barrel_shifter: testcase 38 failed (sra 1)"
            severity error;

        s_iA <= 32x"80000000";
        s_iB <= 32x"1F";
        s_iIsArithmetic <= '1';
        s_iIsRight <= '1';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"FFFFFFFF"
            report "tb_barrel_shifter: testcase 39 failed (sra 31)"
            severity error;


        -- sll
        s_iA <= 32x"80000000";
        s_iB <= 32x"1";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '0';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000000"
            report "tb_barrel_shifter: testcase 40 failed (sll 1)"
            severity error;

        s_iA <= 32x"00000001";
        s_iB <= 32x"2";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '0';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000004"
            report "tb_barrel_shifter: testcase 41 failed (sll 2)"
            severity error;

        s_iA <= 32x"00000001";
        s_iB <= 32x"1";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '0';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"00000002"
            report "tb_barrel_shifter: testcase 42 failed (sll 1)"
            severity error;

        s_iA <= 32x"00000001";
        s_iB <= 32x"1F";
        s_iIsArithmetic <= '0';
        s_iIsRight <= '0';
        wait for CLOCK_PERIOD;
        assert s_oS = 32x"80000000"
            report "tb_barrel_shifter: testcase 43 failed (sll 31)"
            severity error;

        finish;

    end process;

end implementation;