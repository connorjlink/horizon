-- Horizon: barrel_shifter.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
library work;
use work.multiplexer_2to1.all;

entity barrel_shifter is
    port(
        i_A            : in  std_logic_vector(31 downto 0);
        i_B            : in  std_logic_vector(4 downto 0);
        i_IsArithmetic : in  std_logic; -- 0: logical, 1: arithmetic
        i_IsRight      : in  std_logic; -- 0: left, 1: right
        o_S            : out std_logic_vector(31 downto 0)
    );
end barrel_shifter;

architecture implementation of barrel_shifter is

signal s_ReversedD    : std_logic_vector(63 downto 0) := (others => '0');
signal s_ReversedQ    : std_logic_vector(63 downto 0) := (others => '0');

signal s_TempInput    : std_logic_vector(63 downto 0) := (others => '0');
signal s_Level0Input  : std_logic_vector(63 downto 0) := (others => '0');
signal s_Level0Output : std_logic_vector(63 downto 0) := (others => '0');
signal s_Level1Output : std_logic_vector(63 downto 0) := (others => '0');
signal s_Level2Output : std_logic_vector(63 downto 0) := (others => '0');
signal s_Level3Output : std_logic_vector(63 downto 0) := (others => '0');
signal s_Level4Output : std_logic_vector(63 downto 0) := (others => '0');

signal s_Padding : std_logic := '0';

begin

    -- Assign the reverse bit order of both the input and output
    g_InputReverser: for i in 0 to 63 generate
        s_ReversedD(i) <= s_TempInput(63 - i);
    end generate g_InputReverser;

    g_OutputReverser: for i in 0 to 63 generate
        s_ReversedQ(i) <= s_Level4Output(63 - i);
    end generate g_OutputReverser;

    s_TempInput(31 downto 0) <= i_A;
    s_TempInput(63 downto 32) <= (others => s_Padding);

    s_Padding <= '1' when (i_IsRight = '1' and i_IsArithmetic = '1' and i_A(31) = '1') else
                 '0';

    -- Respect shift direction 
    o_S <= s_Level4Output(31 downto 0) when i_IsRight = '1' else
           s_ReversedQ(31 downto 0);

    s_Level0Input <= s_TempInput when i_IsRight = '1' else
                     s_ReversedD;

    g_MUXLevel0: for i in 0 to 63-1 generate
        MUXI: entity work.multiplexer_2to1
            port map(
                i_D0 => s_Level0Input(i),
                i_D1 => s_Level0Input(i + 1),
                i_S  => i_B(0),
                o_O  => s_Level0Output(i)
            );
    end generate g_MUXLevel0;

    s_Level0Output(63) <= s_Level0Input(63) when i_B(0) = '0' else
                          '0';


    g_MUXLevel1: for i in 0 to 63-2 generate
        MUXI: entity work.multiplexer_2to1
            port map(
                i_D0 => s_Level0Output(i),
                i_D1 => s_Level0Output(i + 2),
                i_S  => i_B(1),
                o_O  => s_Level1Output(i)
            );
    end generate g_MUXLevel1;

    s_Level1Output(63 downto 62) <= s_Level0Output(63 downto 62) when i_B(1) = '0' else
                                    (others => '0');


    g_MUXLevel2: for i in 0 to 63-4 generate
        MUXI: entity work.multiplexer_2to1
            port map(
                i_D0 => s_Level1Output(i),
                i_D1 => s_Level1Output(i + 4),
                i_S  => i_B(2),
                o_O  => s_Level2Output(i)
            );
    end generate g_MUXLevel2;

    s_Level2Output(63 downto 60) <= s_Level1Output(63 downto 60) when i_B(2) = '0' else
                                    (others => '0');


    g_MUXLevel3: for i in 0 to 63-8 generate
        MUXI: entity work.multiplexer_2to1
            port map(
                i_D0 => s_Level2Output(i),
                i_D1 => s_Level2Output(i + 8),
                i_S  => i_B(3),
                o_O  => s_Level3Output(i)
            );
    end generate g_MUXLevel3;

    s_Level3Output(63 downto 56) <= s_Level2Output(63 downto 56) when i_B(3) = '0' else
                                    (others => '0');

    -- Level 4
    g_MUXLevel4: for i in 0 to 63-16 generate
        MUXI: entity work.multiplexer_2to1
            port map(
                i_D0 => s_Level3Output(i),
                i_D1 => s_Level3Output(i + 16),
                i_S  => i_B(4),
                o_O  => s_Level4Output(i)
            );
    end generate g_MUXLevel4;

    s_Level4Output(63 downto 48) <= s_Level3Output(63 downto 48) when i_B(4) = '0' else
                                    (others => '0');

end implementation;
