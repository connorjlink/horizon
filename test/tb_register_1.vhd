-- Horizon: tb_register_1.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_register_1 is
    generic(
        CLOCK_HALF_PERIOD : time := 10 ns
    );
end tb_register_1;

architecture implementation of tb_register_1 is

constant CLOCK_PERIOD  : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_WriteEnable : std_logic := '0';
signal s_Data : std_logic := '0';
signal s_Q : std_logic;

begin

    -- Design-under-test instantiation
    DUT: entity work.register_1
        port map(
            i_Clock       => s_Clock,
            i_Reset       => s_Reset,
            i_WriteEnable => s_WriteEnable,
            i_D           => s_Data,
            o_Q           => s_Q
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

        s_Reset <= '1';
        s_WriteEnable <= '0';
        s_Data <= '0';
        wait for CLOCK_PERIOD;
        assert (s_Q = '0')
            report "tb_register_1: testcase reset failed (expected Q=0, got Q=" & std_logic'image(s_Q) & ")"
            severity error;

        s_Reset <= '0';
        s_WriteEnable <= '1';
        s_Data <= '1';
        wait for CLOCK_PERIOD;
        assert (s_Q = '1')
            report "tb_register_1: testcase write '1' failed (expected Q=1, got Q=" & std_logic'image(s_Q) & ")"
            severity error;

        s_Reset <= '0';
        s_WriteEnable  <= '0';
        s_Data <= '0';
        wait for CLOCK_PERIOD;
        assert (s_Q = '1')
            report "tb_register_1: testcase hold '1' failed (expected Q=1, got Q=" & std_logic'image(s_Q) & ")"
            severity error;

        s_Reset <= '0';
        s_WriteEnable <= '1';
        s_Data <= '0';
        wait for CLOCK_PERIOD;
        assert (s_Q = '0')
            report "tb_register_1: testcase write '0' failed (expected Q=0, got Q=" & std_logic'image(s_Q) & ")"
            severity error;

        s_Reset <= '0';
        s_WriteEnable <= '0';
        s_Data <= '1';
        wait for CLOCK_PERIOD;
        assert (s_Q = '0')
            report "tb_register_1: testcase hold '0' failed (expected Q=0, got Q=" & std_logic'image(s_Q) & ")"
            severity error;

        finish;

    end process;
  
end implementation;
