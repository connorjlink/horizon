-- Horizon: entity.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity saturating_counter is
    generic(
        constant N : natural := 2
    );
    port(
        i_Clock       : in  std_logic;
        i_Enable      : in  std_logic;
        i_IsIncrement : in  std_logic;
        o_Counter     : out std_logic_vector(N-1 downto 0)
    );
end saturating_counter;

architecture implementation of saturating_counter is

    signal s_Counter : std_logic_vector(N-1 downto 0) := (others => '0');

begin

    process(
        i_Clock
    )
    begin

        if rising_edge(i_Clock) then

            if i_Enable = '1' then

                if i_IsIncrement = '1' then

                    -- saturate increase
                    if s_Counter < std_logic_vector(to_unsigned(2**N - 1, N)) then
                        s_Counter <= std_logic_vector(unsigned(s_Counter) + 1);
                    end if;

                else

                    -- saturate decrease
                    if s_Counter > std_logic_vector(to_unsigned(0, N)) then
                        s_Counter <= std_logic_vector(unsigned(s_Counter) - 1);
                    end if;

                end if;

            end if;

        end if;

    end process;

end implementation;