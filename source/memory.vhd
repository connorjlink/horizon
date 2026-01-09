-- Horizon: memory.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity memory is
    generic(
        constant DATA_WIDTH    : natural := 32;
        constant ADDRESS_WIDTH : natural := 10
    );
    port(
        i_Clock       : in std_logic;
        i_Address     : in std_logic_vector((ADDRESS_WIDTH-1) downto 0);
        i_Data        : in std_logic_vector((DATA_WIDTH-1) downto 0);
        i_WriteEnable : in std_logic := '1';
        o_Data        : out std_logic_vector((DATA_WIDTH -1) downto 0)
    );
end memory;

architecture implementation of memory is

    subtype word_t is std_logic_vector((DATA_WIDTH-1) downto 0);
    type memory_t is array(2**ADDRESS_WIDTH-1 downto 0) of word_t;

    signal s_MemoryCells : memory_t;

begin

    process(
        i_Clock
    )
    begin

        if rising_edge(i_Clock) then
            if i_WriteEnable = '1' then
                s_MemoryCells(to_integer(unsigned(i_Address))) <= i_Data;
            end if;

        end if;

    end process;

    o_Data <= s_MemoryCells(to_integer(unsigned(i_Address)));

end implementation;
