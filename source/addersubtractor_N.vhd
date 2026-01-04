-- Horizon: addersubtractor_N.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
library work;
use work.adder_N.all;
use work.multiplexer_2to1_N.all;
use work.not_N.all;

entity addersubtractor_N is
    generic(
        N : integer := 32
    );
    port(
        i_A             : in  std_logic_vector(N-1 downto 0);
        i_B             : in  std_logic_vector(N-1 downto 0);
        i_IsSubtraction : in  std_logic; -- 0: addition, 1: subtraction
        o_S             : out std_logic_vector(N-1 downto 0);
        o_Carry         : out std_logic
    );
end addersubtractor_N;

architecture implementation of addsub_N is

signal s_Bi : std_logic_vector(N-1 downto 0);
signal s_Bm : std_logic_vector(N-1 downto 0);

begin

    g_Complementor: entity work.not_N
        generic map(
            N => N
        )
        port map(
            i_A => i_B,
            o_F => s_Bi
        );

    g_Multiplexer: entity work.multiplexer_2to1_N
        generic map(
            N => N
        )
        port map(
            i_S  => i_IsSubtraction,
            i_D0 => i_B,
            i_D1 => s_Bi,
            o_O  => s_Bm
        );

    g_NBit_Adder: entity work.adder_N
        generic map(
            N => N
        )
        port map(
            i_A     => i_A,
            i_B     => s_Bm,
            i_Ci    => i_IsSubtraction,
            o_S     => o_S,
            o_Carry => o_Carry
        );

end structural;
