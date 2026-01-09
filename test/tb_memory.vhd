-- Horizon: tb_memory.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_memory is
    generic(
        CLOCK_HALF_PERIOD : time    := 10 ns;
        DATA_WIDTH        : integer := 32;
        ADDRESS_WIDTH     : integer := 10
    );
end tb_memory;

architecture implementation of tb_memory is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iAddress     : std_logic_vector(9 downto 0) := b"0000000000";
signal s_iData        : std_logic_vector(31 downto 0) := x"00000000";
signal s_iWriteEnable : std_logic := '0';
signal s_oData        : std_logic_vector(31 downto 0);

begin

    -- Design-under-test instantiation
    DUT: entity work.memory
        generic map(
            DATA_WIDTH => DATA_WIDTH,
            ADDRESS_WIDTH => ADDRESS_WIDTH
        )
        port map(
            i_Clock       => s_Clock,
            i_Address     => s_iAddress,
            i_Data        => s_iData,
            i_WriteEnable => s_iWriteEnable,
            o_Data        => s_oData
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
        
        -- Write values consecutively starting at $100

        s_iAddress  <= b"0100000000";
        s_iData  <= x"FFFFFFFF";
        s_iWriteEnable <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"FFFFFFFF")
            report "tb_memory: testcase 1 write failed (expected Data=$FFFFFFFF)"
            severity error;

        s_iAddress  <= b"0100000001";
        s_iData  <= x"00000002";
        s_iWriteEnable <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"00000002")
            report "tb_memory: testcase 2 write failed (expected Data=$00000002)"
            severity error;

        s_iAddress  <= b"0100000010";
        s_iData  <= x"FFFFFFFD";
        s_iWriteEnable <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"FFFFFFFD")
            report "tb_memory: testcase 3 write failed (expected Data=$FFFFFFFD)"
            severity error;

        s_iAddress  <= b"0100000011";
        s_iData  <= x"00000004";
        s_iWriteEnable <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"00000004")
            report "tb_memory: testcase 4 write failed (expected Data=$00000004)"
            severity error;

        s_iAddress  <= b"0100000100";
        s_iData  <= x"00000005";
        s_iWriteEnable <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"00000005")
            report "tb_memory: testcase 5 write failed (expected Data=$00000005)"
            severity error;

        s_iAddress  <= b"0100000101";
        s_iData  <= x"00000006";
        s_iWriteEnable <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"00000006")
            report "tb_memory: testcase 6 write failed (expected Data=$00000006)"
            severity error;

        s_iAddress  <= b"0100000110";
        s_iData  <= x"FFFFFFF9";
        s_iWriteEnable <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"FFFFFFF9")
            report "tb_memory: testcase 7 write failed (expected Data=$FFFFFFF9)"
            severity error;

        s_iAddress  <= b"0100000111";
        s_iData  <= x"FFFFFFF8";
        s_iWriteEnable <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"FFFFFFF8")
            report "tb_memory: testcase 8 write failed (expected Data=$FFFFFFF8)"
            severity error;

        s_iAddress  <= b"0100001000";
        s_iData  <= x"00000009";
        s_iWriteEnable <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"00000009")
            report "tb_memory: testcase 9 write failed (expected Data=$00000009)"
            severity error;

        s_iAddress  <= b"0100001001";
        s_iData  <= x"FFFFFFF6";
        s_iWriteEnable <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"FFFFFFF6")
            report "tb_memory: testcase 10 write failed (expected Data=$FFFFFFF6)"
            severity error;

        
        -- Read values consecutively starting at $100
        
        s_iAddress <= b"0100000000";
        s_iWriteEnable <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"FFFFFFFF")
            report "tb_memory: testcase 11 read failed (expected Data=$FFFFFFFF)"
            severity error;

        s_iAddress <= b"0100000001";
        s_iWriteEnable <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"00000002")
            report "tb_memory: testcase 12 read failed (expected Data=$00000002)"
            severity error;

        s_iAddress <= b"0100000010";
        s_iWriteEnable <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"FFFFFFFD")
            report "tb_memory: testcase 13 read failed (expected Data=$FFFFFFFD)"
            severity error;

        s_iAddress <= b"0100000011";
        s_iWriteEnable <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"00000004")
            report "tb_memory: testcase 14 read failed (expected Data=$00000004)"
            severity error;

        s_iAddress <= b"0100000100";
        s_iWriteEnable <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"00000005")
            report "tb_memory: testcase 15 read failed (expected Data=$00000005)"
            severity error;

        s_iAddress <= b"0100000101";
        s_iWriteEnable <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"00000006")
            report "tb_memory: testcase 16 read failed (expected Data=$00000006)"
            severity error;

        s_iAddress <= b"0100000110";
        s_iWriteEnable <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"FFFFFFF9")
            report "tb_memory: testcase 17 read failed (expected Data=$FFFFFFF9)"
            severity error;

        s_iAddress <= b"0100000111";
        s_iWriteEnable <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"FFFFFFF8")
            report "tb_memory: testcase 18 read failed (expected Data=$FFFFFFF8)"
            severity error;

        s_iAddress <= b"0100001000";
        s_iWriteEnable <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"00000009")
            report "tb_memory: testcase 19 read failed (expected Data=$00000009)"
            severity error;

        s_iAddress <= b"0100001001";
        s_iWriteEnable <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oData = x"FFFFFFF6")
            report "tb_memory: testcase 20 read failed (expected Data=$FFFFFFF6)"
            severity error;

        finish;

    end process;

end implementation;
