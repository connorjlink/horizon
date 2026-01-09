-- Horizon: tb_entity.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_<ENTITY_NAME> is
    generic(
        CLOCK_HALF_PERIOD : time := 10 ns
    );
end tb_<ENTITY_NAME>;

architecture implementation of tb_<ENTITY_NAME> is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
-- TODO: port signals here

begin

    -- Design-under-test instantiation
    DUT: entity work.<ENTITY_NAME>
        port map(
            i_Clock => s_Clock,
            i_Reset => s_Reset
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

        -- TODO: stimulus implementation here

        finish;

    end process;

end implementation;
