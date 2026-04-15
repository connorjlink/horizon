-- Horizon: register_N.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;

entity register_N is
    generic(
        N : integer := 32
    );
    port(
        i_Clock       : in  std_logic;
        i_Reset       : in  std_logic;
        i_WriteEnable : in  std_logic;
        i_D           : in  std_logic_vector(N-1 downto 0); 
        o_Q           : out std_logic_vector(N-1 downto 0)
    );
end register_N;

architecture implementation of register_N is

begin

    g_NBit_Register: for i in 0 to N-1
    generate
        REGISTERI: entity work.register_1 
            port map(
                i_Clock       => i_Clock,
                i_Reset       => i_Reset,
                i_WriteEnable => i_WriteEnable,
                i_D           => i_D(i),
                o_Q           => o_Q(i)
            );
    end generate g_NBit_Register;

end implementation;
