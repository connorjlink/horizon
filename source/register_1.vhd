-- Horizon: register_1.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;

entity register_1 is
    port(
        i_Clock       : in  std_logic;
        i_Reset       : in  std_logic;
        i_WriteEnable : in  std_logic;
        i_D           : in  std_logic;
        o_Q           : out std_logic
    );
end register_1;

architecture implementation of register_1 is

signal s_F : std_logic;
signal s_Q : std_logic;

begin

    o_Q <= s_Q;
  
    with i_WriteEnable select
        s_F <= i_D when '1',
        s_Q        when others;
    
    process (i_Clock, i_Reset)
    begin
        if (i_Reset = '1') then
            s_Q <= '0';
        elsif (rising_edge(i_Clock)) then
            s_Q <= s_F;
        end if;
    end process;
  
end implementation;
