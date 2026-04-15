-- Horizon: not_1.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;

entity not_1 is
    port(
        i_S : in  std_logic;
        o_F : out std_logic
    );
end not_1;

architecture implementation of not_1 is
begin

  o_F <= not i_S;
  
end implementation;
