-- Horizon: multiplier.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
library work;
use work.RISCV_types.all;

entity multiplier is
    generic(
        constant N : natural := RISCV_types.DATA_WIDTH
    );
    port(
        i_A : in  std_logic_vector(N-1 downto 0);
        i_B : in  std_logic_vector(N-1 downto 0);
        o_P : out std_logic_vector((2*N)-1 downto 0)
    );
end multiplier;

architecture implementation of multiplier is



end implementation;