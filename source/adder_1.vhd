-- Horizon: adder_1.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use work.xor_2.all;
use work.and_2.all;
use work.or_2.all;

entity adder_1 is
    port(
        i_A     : in  std_logic;
        i_B     : in  std_logic;
        i_Carry : in  std_logic;
        o_S     : out std_logic;
        o_Carry : out std_logic
    );
end adder_1;

architecture implementation of adder_1 is

signal s_S  : std_logic;
signal s_C0 : std_logic;
signal s_C1 : std_logic;

begin

    g_PartialSum: entity work.xor_2
        port map(
            i_A => i_A,
            i_B => i_B,
            o_F => s_S
        );

    g_PartialCarry1: entity work.and_2
        port map(
            i_A => i_A,
            i_B => i_B,
            o_F => s_C0
        );

    g_PartialCarry2: entity work.and_2
        port map(
            i_A => s_S,
            i_B => i_Carry,
            o_F => s_C1
        );

    g_Sum: entity work.xor_2
        port map(
            i_A => s_S,
            i_B => i_Carry,
            o_F => o_S
        );

    g_Carry: entity work.or_2
        port map(
            i_A => s_C0,
            i_B => s_C1,
            o_F => o_Carry
        );

end implementation;
