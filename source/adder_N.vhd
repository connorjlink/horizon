-- Horizon: adder_N.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;

entity adder_N is
    generic(
        constant N : integer := 32
    );
    port(
        i_A     : in  std_logic_vector(N-1 downto 0);
        i_B     : in  std_logic_vector(N-1 downto 0);
        i_Carry : in  std_logic;
        o_S     : out std_logic_vector(N-1 downto 0);
        o_Carry : out std_logic
    );
end adder_N;

architecture implementation of adder_N is

-- NOTE: requires an additional intermediate carry bit
signal s_C : std_logic_vector(N downto 0);

begin

    s_C(0) <= i_Carry;
    o_Carry <= s_C(N);

    -- Ripple-carry adder design, NOTE: limits maximum frequency to about 5 MHz per Quartus synthesis reports on Cyclone V
    g_NBit_Adder: for i in 0 to N-1
    generate
        ADDERI: entity work.adder_1
            port map(
                i_A     => i_A(i),
                i_B     => i_B(i),
                i_Carry => s_C(i),
                o_S     => o_S(i),
                o_Carry => s_C(i + 1)
            );
    end generate g_NBit_Adder;

end implementation;
