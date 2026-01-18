-- Horizon: tb_instruction_pointer.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_instruction_pointer is
    generic(
        CLOCK_HALF_PERIOD : time    := 10 ns;
        DATA_WIDTH        : integer := 32
    );
end tb_instruction_pointer;

architecture implementation of tb_instruction_pointer is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iLoad        : std_logic := '0';
signal s_iLoadAddress : std_logic_vector(31 downto 0) := 32x"0";
signal s_iIsStride4      : std_logic := '0';
signal s_iStall       : std_logic := '0';
signal s_oAddress     : std_logic_vector(31 downto 0);
signal s_oLinkAddress : std_logic_vector(31 downto 0);

begin

    -- Design-under-test instantiation
    DUT: entity work.instruction_pointer
        generic map(
            ResetAddress => 32x"00000000"
        )
        port map(
            i_Clock       => s_Clock,
            i_Reset       => s_Reset,
            i_Load        => s_iLoad,
            i_LoadAddress => s_iLoadAddress,
            i_IsStride4      => s_iIsStride4,
            i_Stall       => s_iStall,
            o_Address     => s_oAddress,
            o_LinkAddress => s_oLinkAddress
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


        -- Counting up by 4

        s_iLoad <= '0';
        s_iLoadAddress <= 32x"0";
        s_iIsStride4 <= '1';
        s_iStall <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"00000000")
            report "tb_instruction_pointer: testcase 1 failed (expected Address=$00000000)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"00000004")
            report "tb_instruction_pointer: testcase 1 failed (expected Address=$00000004)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"00000008")
            report "tb_instruction_pointer: testcase 1 failed (expected Address=$00000008)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"0000000C")
            report "tb_instruction_pointer: testcase 1 failed (expected Address=$0000000C)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"00000010")
            report "tb_instruction_pointer: testcase 1 failed (expected Address=$00000010)"
            severity error;
    

        -- Counting up by 2
    
        s_iLoad <= '0';
        s_iLoadAddress <= 32x"0";
        s_iIsStride4 <= '0';
        s_iStall <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"00000012")
            report "tb_instruction_pointer: testcase 2 failed (expected Address=$00000012)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"00000014")
            report "tb_instruction_pointer: testcase 2 failed (expected Address=$00000014)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"00000016")
            report "tb_instruction_pointer: testcase 2 failed (expected Address=$00000016)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"00000018")
            report "tb_instruction_pointer: testcase 2 failed (expected Address=$00000018)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"0000001A")
            report "tb_instruction_pointer: testcase 2 failed (expected Address=$0000001A)"
            severity error;


        -- Stalling for both counting modes

        s_iLoad <= '0';
        s_iLoadAddress <= 32x"0";
        s_iIsStride4 <= '1';
        s_iStall <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"0000001A")
            report "tb_instruction_pointer: testcase 3 failed (expected Address=$0000001A)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"0000001A")
            report "tb_instruction_pointer: testcase 3 failed (expected Address=$0000001A)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"0000001A")
            report "tb_instruction_pointer: testcase 3 failed (expected Address=$0000001A)"
            severity error;
        s_iIsStride4 <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"0000001A")
            report "tb_instruction_pointer: testcase 3 failed (expected Address=$0000001A)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"0000001A")
            report "tb_instruction_pointer: testcase 3 failed (expected Address=$0000001A)"
            severity error;
        wait for CLOCK_PERIOD;
        s_iStall <= '0';


        -- Loading a custom address
        
        s_iLoad <= '1';
        s_iLoadAddress <= 32x"FEEDFACE";
        s_iIsStride4 <= '0';
        s_iStall <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"FEEDFACE")
            report "tb_instruction_pointer: testcase 4 failed (expected Address=$FEEDFACE)"
            severity error;
        s_iLoad <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"FEEDFAD0")
            report "tb_instruction_pointer: testcase 4 failed (expected Address=$FEEDFAD0)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"FEEDFAD2")
            report "tb_instruction_pointer: testcase 4 failed (expected Address=$FEEDFAD2)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"FEEDFAD4")
            report "tb_instruction_pointer: testcase 4 failed (expected Address=$FEEDFAD4)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"FEEDFAD6")
            report "tb_instruction_pointer: testcase 4 failed (expected Address=$FEEDFAD6)"
            severity error;


        -- Test case 5: loading a custom address

        s_iLoad <= '1';
        s_iLoadAddress <= 32x"0";
        s_iIsStride4 <= '0';
        s_iStall <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"00000000")
            report "tb_instruction_pointer: testcase 5 failed (expected Address=$00000000)"
            severity error;
        s_iLoad <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"00000002")
            report "tb_instruction_pointer: testcase 5 failed (expected Address=$00000002)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"00000004")
            report "tb_instruction_pointer: testcase 5 failed (expected Address=$00000004)"
            severity error;
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"00000006")
            report "tb_instruction_pointer: testcase 5 failed (expected Address=$00000006)"
            severity error;
        s_iIsStride4 <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oAddress = 32x"0000000A")
            report "tb_instruction_pointer: testcase 5 failed (expected Address=$0000000A)"
            severity error;

        finish;

    end process;

end implementation;
