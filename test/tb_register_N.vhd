-- Horizon: tb_register_N.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_register_N is
    generic(
        CLOCK_HALF_PERIOD : time    := 10 ns;
        DATA_WIDTH        : integer := 32
    );
end tb_register_N;

architecture implementation of tb_register_N is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iWriteEnable : std_logic;
signal s_iD           : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000000";
signal s_oQ           : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

    -- Design-under-test instantiation
    DUT: entity work.register_N
        generic map(
            N => DATA_WIDTH
        )
        port map(
            i_Clock       => s_Clock,
            i_Reset       => s_Reset,
            i_WriteEnable => s_iWriteEnable,
            i_D           => s_iD,
            o_Q           => s_oQ
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

        s_iWriteEnable <= '0';
        s_iD <= x"0000FFFF";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00000000")
            report "tb_register_N: testcase reset failed (expected Q=$00000000, got Q=" & to_hstring(s_oQ) & ")"
            severity error;

        s_iWriteEnable <= '1';
        s_iD <= x"0000FFFF";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"0000FFFF")
            report "tb_register_N: testcase write '0000FFFF' failed (expected Q=$0000FFFF, got Q=" & to_hstring(s_oQ) & ")"
            severity error;
    
        s_iWriteEnable <= '0';
        s_iD <= x"00000000";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"0000FFFF")
            report "tb_register_N: testcase hold '0000FFFF' failed (expected Q=$0000FFFF, got Q=" & to_hstring(s_oQ) & ")"
            severity error;

        s_iWriteEnable <= '0';
        s_iD <= x"AAAA0000";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"0000FFFF")
            report "tb_register_N: testcase hold '0000FFFF' (expected Q=$0000FFFF, got Q=" & to_hstring(s_oQ) & ")"
            severity error;

        s_iWriteEnable <= '1';
        s_iD <= x"AAAA0000";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"AAAA0000")
            report "tb_register_N: testcase write 'AAAA0000' failed (expected Q=$AAAA0000, got Q=" & to_hstring(s_oQ) & ")"
            severity error;

        s_iWriteEnable <= '1';
        s_iD <= x"FEEDFACE";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"FEEDFACE")
            report "tb_register_N: testcase write 'FEEDFACE' failed (expected Q=$FEEDFACE, got Q=" & to_hstring(s_oQ) & ")"
            severity error;

        s_iWriteEnable <= '0';
        s_iD <= x"DEADBEEF";
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"FEEDFACE")
            report "tb_register_N: testcase hold 'FEEDFACE' failed (expected Q=$FEEDFACE, got Q=" & to_hstring(s_oQ) & ")"
            severity error;

        finish;

    end process;

end implementation;
