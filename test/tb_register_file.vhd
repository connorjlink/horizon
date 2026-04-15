-- Horizon: tb_register_file.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_register_file is
    generic(
        CLOCK_HALF_PERIOD : time    := 10 ns;
        DATA_WIDTH        : integer := 32
    );
end tb_register_file;

architecture implementation of tb_register_file is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iRS1         : std_logic_vector(4 downto 0) := b"00000";
signal s_iRS2         : std_logic_vector(4 downto 0) := b"00000";
signal s_iRD          : std_logic_vector(4 downto 0) := b"00000";
signal s_iWriteEnable : std_logic := '0';
signal s_iD           : std_logic_vector(31 downto 0) := x"00000000";
signal s_oDS1         : std_logic_vector(31 downto 0);
signal s_oDS2         : std_logic_vector(31 downto 0);

begin

    -- Design-under-test instantiation
    DUT: entity work.register_file
        port map(
            i_Clock       => s_Clock,
            i_Reset       => s_Reset,
            i_RS1         => s_iRS1,
            i_RS2         => s_iRS2,
            i_RD          => s_iRD,
            i_WriteEnable => s_iWriteEnable,
            i_D           => s_iD,
            o_DS1         => s_oDS1,
            o_DS2         => s_oDS2
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
        wait for CLOCK_PERIOD;

        s_iRD <= b"00001";
        s_iWriteEnable <= '1';
        s_iD  <= x"FEEDFACE";
        wait for CLOCK_PERIOD;
        assert s_oDS1 = x"00000000" and s_oDS2 = x"00000000"
            report "tb_register_file: testcase 1 failed (expected DS1=0x00000000, DS2=0x00000000)"
            severity error;

        s_iRD <= b"00101";
        s_iWriteEnable <= '1';
        s_iD  <= x"DEADBEEF";
        wait for CLOCK_PERIOD;
        assert s_oDS1 = x"00000000" and s_oDS2 = x"00000000"
            report "tb_register_file: testcase 2 failed (expected DS1=0x00000000, DS2=0x00000000)"
            severity error;

        s_iRD <= b"00100";
        s_iWriteEnable <= '0'; -- NOTE: not being written here
        s_iD  <= x"DEADBEEF";
        wait for CLOCK_PERIOD;
        assert s_oDS1 = x"00000000" and s_oDS2 = x"00000000"
            report "tb_register_file: testcase 3 failed (expected DS1=0x00000000, DS2=0x00000000)"
            severity error;

        s_iRD  <= b"10000";
        s_iWriteEnable <= '1';
        s_iD   <= x"C0FFEEEE";
        s_iRS1 <= b"00101";
        wait for CLOCK_PERIOD;
        assert s_oDS1 = x"DEADBEEF" and s_oDS2 = x"00000000"
            report "tb_register_file: testcase 4 failed (expected DS1=0xDEADBEEF, DS2=0x00000000)"
            severity error;

        s_iRD <= b"00000";
        s_iWriteEnable <= '0'; 
        s_iD  <= x"00000000";
        s_iRS1 <= b"00001";
        s_iRS2 <= b"00101";
        wait for CLOCK_PERIOD;
        assert s_oDS1 = x"FEEDFACE" and s_oDS2 = x"DEADBEEF"
            report "tb_register_file: testcase 5 failed (expected DS1=0xFEEDFACE, DS2=0xDEADBEEF)"
            severity error;

        s_iRS1 <= b"00000";
        s_iRS2 <= b"00101";
        wait for CLOCK_PERIOD;
        assert s_oDS1 = x"00000000" and s_oDS2 = x"DEADBEEF"
            report "tb_register_file: testcase 6 failed (expected DS1=0x00000000, DS2=0xDEADBEEF)"
            severity error;

        s_iRS1 <= b"10000";
        s_iRS2 <= b"10000";
        wait for CLOCK_PERIOD;
        assert s_oDS1 = x"C0FFEEEE" and s_oDS2 = x"C0FFEEEE"
            report "tb_register_file: testcase 7 failed (expected DS1=0xC0FFEEEE, DS2=0xC0FFEEEE)"
            severity error;

        s_iRS1 <= b"00000";
        s_iRS2 <= b"00000";
        wait for CLOCK_PERIOD;
        assert s_oDS1 = x"00000000" and s_oDS2 = x"00000000"
            report "tb_register_file: testcase 8 failed (expected DS1=0x00000000, DS2=0x00000000)"
            severity error;

        finish;
    
    end process;

end implementation;
