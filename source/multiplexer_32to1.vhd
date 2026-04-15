-- Horizon: multiplexer_32to1.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity multiplexer_32to1 is
    port(
        i_S : in  std_logic_vector(4 downto 0);
        i_D : in  array_t(0 to 31);
        o_Q : out std_logic_vector(31 downto 0)
    );
end multiplexer_32to1;

architecture implementation of multiplexer_32to1 is
begin

    o_Q <= i_D(to_integer(unsigned(i_S)));

end implementation;
