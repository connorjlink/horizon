-- Horizon: or_2.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;

entity or_2 is
    port(
        i_A : in std_logic;
        i_B : in std_logic;
        o_F : out std_logic
    );
end or_2;

architecture implementation of or_2 is
begin

  o_F <= i_A or i_B;
  
end implementation;
