-- Horizon: tb_extender_NtoM.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_extender_NtoM is
    generic(
        CLOCK_HALF_PERIOD : time := 10 ns;
        DATA_WIDTH        : integer := 8
    );
end tb_extender_NtoM;

architecture implementation of tb_extender_NtoM is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iD          : std_logic_vector(11 downto 0) := b"000000000000";
signal s_iIsSignExtend : std_logic := '0';
signal s_oQ          : std_logic_vector(31 downto 0);

begin

    -- Design-under-test instantiation
    DUT: entity work.extender_NtoM
        port map(
            i_D            => s_iD,
            i_IsSignExtend => s_iIsSignExtend,
            o_Q            => s_oQ
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


        s_iD <= b"000000000000";
        s_iIsSignExtend <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00000000")
            report "tb_extender_NtoM: testcase 1 failed (expected Q=$00000000)"
            severity error;

        s_iD <= b"000000000000";
        s_iIsSignExtend <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00000000")
            report "tb_extender_NtoM: testcase 2 failed (expected Q=$00000000)"
            severity error;

        s_iD <= b"000000000111";
        s_iIsSignExtend <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00000007")
            report "tb_extender_NtoM: testcase 3 failed (expected Q=$00000007)"
            severity error;

        s_iD <= b"000000000111";
        s_iIsSignExtend <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00000007")
            report "tb_extender_NtoM: testcase 4 failed (expected Q=$00000007)"
            severity error;

        s_iD <= b"100000000111";
        s_iIsSignExtend <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00000807")
            report "tb_extender_NtoM: testcase 5 failed (expected Q=$00000807)"
            severity error;

        s_iD <= b"100000000111";
        s_iIsSignExtend <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"FFFFF807")
            report "tb_extender_NtoM: testcase 6 failed (expected Q=$FFFFF807)"
            severity error;

        s_iD <= b"100000000111";
        s_iIsSignExtend <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00000807")
            report "tb_extender_NtoM: testcase 7 failed (expected Q=$00000807)"
            severity error;

        s_iD <= b"111111111111";
        s_iIsSignExtend <= '0';
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"00000FFF")
            report "tb_extender_NtoM: testcase 8 failed (expected Q=$00000FFF)"
            severity error;

        s_iD <= b"111111111111";
        s_iIsSignExtend <= '1';
        wait for CLOCK_PERIOD;
        assert (s_oQ = x"FFFFFFFF")
            report "tb_extender_NtoM: testcase 9 failed (expected Q=$FFFFFFFF)"
            severity error;

        finish;

    end process;

end implementation;
