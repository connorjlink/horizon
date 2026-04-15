-- Horizon: multiplexer_2to1_N.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;

entity multiplexer_2to1_N is
    generic(
      N : integer := 32
    );
    port(
        i_S  : in  std_logic;
        i_D0 : in  std_logic_vector(N-1 downto 0);
        i_D1 : in  std_logic_vector(N-1 downto 0);
        o_O  : out std_logic_vector(N-1 downto 0)
    );
end multiplexer_2to1_N;

architecture implementation of multiplexer_2to1_N is
begin

    g_NBit_MUX: for i in 0 to N-1 generate
        MUXI: entity work.multiplexer_2to1 
            port map(
                i_S  => i_S,
                i_D0 => i_D0(i),
                i_D1 => i_D1(i),
                o_O  => o_O(i)
            );
    end generate g_NBit_MUX;
  
end implementation;
