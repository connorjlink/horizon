-- Horizon: multiplier.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
library work;
use work.types.all;

entity multiplier is
    generic(
        constant N : natural := DATA_WIDTH;
        constant M : natural := 2*N
    );
    port(
        i_A         : in  std_logic_vector(N-1 downto 0);
        i_B         : in  std_logic_vector(N-1 downto 0);
        i_AIsSigned : in  std_logic := '0';
        i_BIsSigned : in  std_logic := '0';
        o_P         : out std_logic_vector(M-1 downto 0)
    );
end multiplier;

architecture implementation of multiplier is

    type t_word_array is array (natural range <>) of std_logic_vector(M-1 downto 0);

    -- Partial products (N rows), and accumulators (N+1 stages)
    signal s_PartialProducts : t_word_array(0 to N-1);
    signal s_Accumulators    : t_word_array(0 to N);

    signal s_Carry : std_logic_vector(0 to N);

    signal s_AIsNegative : std_logic;
    signal s_BIsNegative : std_logic;
    signal s_PIsNegative : std_logic;

    signal s_NegativeA      : std_logic_vector(N-1 downto 0);
    signal s_NegativeB      : std_logic_vector(N-1 downto 0);
    signal s_NegativeP      : std_logic_vector(M-1 downto 0); -- output bit width

    signal s_AbsoluteValueA : std_logic_vector(N-1 downto 0);
    signal s_AbsoluteValueB : std_logic_vector(N-1 downto 0);
    signal s_AbsoluteValueP : std_logic_vector(M-1 downto 0); -- output bit width

begin

    s_AIsNegative <= i_AIsSigned and i_A(N-1);
    s_BIsNegative <= i_BIsSigned and i_B(N-1);
    s_PIsNegative <= s_AIsNegative xor s_BIsNegative;

    -- compute magnitudes for unsigned multiplication
    e_NegativeA : entity work.addersubtractor_N
        generic map(
            N => N
        )
        port map(
            i_A             => (others => '0'),
            i_B             => i_A,
            i_IsSubtraction => '1',
            o_S             => s_NegativeA,
            o_Carry         => open
        );

    e_NegativeB : entity work.addersubtractor_N
        generic map(
            N => N
        )
        port map(
            i_A             => (others => '0'),
            i_B             => i_B,
            i_IsSubtraction => '1',
            o_S             => s_NegativeB,
            o_Carry         => open
        );

    e_AbsoluteValueMultiplexerA : entity work.multiplexer_2to1_N
        generic map(
            N => N
        )
        port map(
            i_S  => s_AIsNegative,
            i_D0 => i_A,
            i_D1 => s_NegativeA,
            o_O  => s_AbsoluteValueA
        );

    e_AbsoluteValueMultiplexerB : entity work.multiplexer_2to1_N
        generic map(
            N => N
        )
        port map(
            i_S  => s_BIsNegative,
            i_D0 => i_B,
            i_D1 => s_NegativeB,
            o_O  => s_AbsoluteValueB
        );

    s_Accumulators(0) <= (others => '0');
    s_Carry(0) <= '0';
    s_AbsoluteValueP <= s_Accumulators(N);

    -- conditional negate to form signed product when needed
    e_NegativeP : entity work.addersubtractor_N
        generic map(
            N => M
        )
        port map(
            i_A             => (others => '0'),
            i_B             => s_AbsoluteValueP,
            i_IsSubtraction => '1',
            o_S             => s_NegativeP,
            o_Carry         => open
        );

    e_AbsoluteValueMultiplexerP : entity work.multiplexer_2to1_N
        generic map(
            N => M
        )
        port map(
            i_S  => s_PIsNegative,
            i_D0 => s_AbsoluteValueP,
            i_D1 => s_NegativeP,
            o_O  => o_P
        );

    g_PartialProductRows: for j in 0 to N-1 generate
        g_PartialProductColumns : for w in 0 to M-1 generate

            g_IsInRange : if (w >= j) and (w < (j + N)) generate
                e_AND : entity work.and_2
                    port map(
                        i_A => s_AbsoluteValueA(w - j),
                        i_B => s_AbsoluteValueB(j),
                        o_F => s_PartialProducts(j)(w)
                    );
            end generate g_IsInRange;

            g_OUT_RANGE : if not ((w >= j) and (w < (j + N))) generate
                s_PartialProducts(j)(w) <= '0';
            end generate g_OUT_RANGE;

        end generate g_PartialProductColumns;

    end generate g_PartialProductRows;


    g_ACCUMULATOR : for j in 0 to N-1 generate
        e_ADDER : entity work.adder_N
            generic map(
                N => M
            )
            port map(
                i_A     => s_Accumulators(j),
                i_B     => s_PartialProducts(j),
                i_Carry => '0',
                o_S     => s_Accumulators(j + 1),
                o_Carry => s_Carry(j + 1)
            );
    end generate g_ACCUMULATOR;

end implementation;