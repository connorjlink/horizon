-- Horizon: pipeline_register.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;

entity pipeline_register is
    generic (
        type T;
        NOP : T
    );
    port (
        i_Clock   : in  std_logic;
        i_Reset   : in  std_logic;
        i_Stall   : in  std_logic;
        i_Flush   : in  std_logic;
        i_Signals : in  T;
        o_Signals : out T
    );
end entity;

architecture implementation of pipeline_register is
begin
    process(
        all
    )
    begin
        -- insert a NOP
        if i_Reset = '1' then
            o_Signals <= NOP;

        -- insert a NOP
        elsif rising_edge(i_Clock) then
            if i_Flush = '1' then
                o_Signals <= NOP;
            
        -- register contents
        elsif i_Stall = '0' then
            o_Signals <= i_Signals; 
        
        end if;

      end if;

    end process;

end implementation;