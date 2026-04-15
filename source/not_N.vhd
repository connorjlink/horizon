-- Horizon: not_N.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;

entity not_N is
    generic(
        N : integer := 32
    );
    port(
        i_S : in  std_logic_vector(N-1 downto 0);
        o_F : out std_logic_vector(N-1 downto 0)
    );
end not_N;

architecture implementation of not_N is
begin

    g_Nbit_Not: for i in 0 to N-1 generate
        NOTI: entity work.not_1 
            port map(
                i_S => i_S(i),
                o_F => o_F(i)
            );
    end generate g_Nbit_Not;

end implementation;
