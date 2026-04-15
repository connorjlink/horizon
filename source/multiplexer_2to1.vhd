-- Horizon: multiplexer_2to1.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;

entity multiplexer_2to1 is
    port(
        i_D0 : in  std_logic;
        i_D1 : in  std_logic;
        i_S  : in  std_logic;
        o_O  : out std_logic
    );
end multiplexer_2to1;

architecture implementation of multiplexer_2to1 is

signal s_Scomplement : std_logic;
signal s_D0          : std_logic;
signal s_D1          : std_logic;

begin

    g_Not: entity work.not_1
        port map(
            i_S => i_S,
            o_F => s_Scomplement
        );

    g_Mask1: entity work.and_2
        port map(
            i_A => s_Scomplement,
            i_B => i_D0,
            o_F => s_D0
        );

    g_Mask2: entity work.and_2
        port map(
            i_A => i_S,
            i_B => i_D1,
            o_F => s_D1
        );

    g_Combine: entity work.or_2
        port map(
            i_A => s_D0,
            i_B => s_D1,
            o_F => o_O
        );

end implementation;
