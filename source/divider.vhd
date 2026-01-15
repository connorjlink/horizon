-- Horizon: divider.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity divider is
    generic(
        constant N : natural := DATA_WIDTH
    );
    port(
        i_Clock            : in  std_logic;
        i_Reset            : in  std_logic;
        i_Dividend         : in  std_logic_vector(N-1 downto 0);
        i_Divisor          : in  std_logic_vector(N-1 downto 0);
        i_DividendIsSigned : in  std_logic;
        i_DivisorIsSigned  : in  std_logic;
        o_Done             : out std_logic;
        o_Quotient         : out std_logic_vector(N-1 downto 0);
        o_Remainder        : out std_logic_vector(N-1 downto 0)
    );
end divider;

architecture implementation of divider is

    type divider_state_t is (
        STATE_LOAD,
        STATE_RUN,
        STATE_DONE
    );

    signal s_State : divider_state_t := STATE_LOAD;
    signal s_Quotient  : std_logic_vector(N-1 downto 0) := (others => '0');
    signal s_Remainder : std_logic_vector(N downto 0)   := (others => '0'); -- extra bit required for restoration division

    signal s_DividendIsNegative  : std_logic := '0';
    signal s_DivisorIsNegative   : std_logic := '0';
    signal s_QuotientIsNegative  : std_logic := '0';
    signal s_RemainderIsNegative : std_logic := '0';

    signal s_NegativeDividend  : std_logic_vector(N-1 downto 0) := (others => '0');
    signal s_NegativeDivisor   : std_logic_vector(N-1 downto 0) := (others => '0');
    signal s_NegativeQuotient  : std_logic_vector(N-1 downto 0) := (others => '0');
    signal s_NegativeRemainder : std_logic_vector(N-1 downto 0) := (others => '0');

    signal s_AbsoluteValueDividend  : std_logic_vector(N-1 downto 0) := (others => '0');
    signal s_AbsoluteValueDivisor   : std_logic_vector(N-1 downto 0) := (others => '0');
    signal s_AbsoluteValueQuotient  : std_logic_vector(N-1 downto 0) := (others => '0');
    signal s_AbsoluteValueRemainder : std_logic_vector(N-1 downto 0) := (others => '0');

begin

    -- dividend and divisor behavior per RISC-V M specification
    s_DividendIsNegative  <= i_DividendIsSigned and i_Dividend(N-1);
    s_DivisorIsNegative   <= i_DivisorIsSigned  and i_Divisor(N-1);
    s_QuotientIsNegative  <= s_DividendIsNegative xor s_DivisorIsNegative;
    s_RemainderIsNegative <= s_DividendIsNegative;

    -- conditional negate to form signed quotient and remainder when needed
    e_NegativeDividend : entity work.addersubtractor_N
        generic map(
            N => N
        )
        port map(
            i_A             => (others => '0'),
            i_B             => i_Dividend,
            i_IsSubtraction => '1',
            o_S             => s_NegativeDividend,
            o_Carry         => open
        );

    e_NegativeDivisor : entity work.addersubtractor_N
        generic map(
            N => N
        )
        port map(
            i_A             => (others => '0'),
            i_B             => i_Divisor,
            i_IsSubtraction => '1',
            o_S             => s_NegativeDivisor,
            o_Carry         => open
        );

    e_NegativeQuotient : entity work.addersubtractor_N
        generic map(
            N => N
        )
        port map(
            i_A             => (others => '0'),
            i_B             => s_Quotient,
            i_IsSubtraction => '1',
            o_S             => s_NegativeQuotient,
            o_Carry         => open
        );

    e_NegativeRemainder : entity work.addersubtractor_N
        generic map(
            N => N
        )
        port map(
            i_A             => (others => '0'),
            i_B             => s_Remainder(N-1 downto 0),
            i_IsSubtraction => '1',
            o_S             => s_NegativeRemainder,
            o_Carry         => open
        );

    e_AbsoluteValueMultiplexerDividend : entity work.multiplexer_2to1_N
        generic map(
            N => N
        )
        port map(
            i_S  => s_DividendIsNegative,
            i_D0 => i_Dividend,
            i_D1 => s_NegativeDividend,
            o_O  => s_AbsoluteValueDividend
        );

    e_AbsoluteValueMultiplexerDivisor : entity work.multiplexer_2to1_N
        generic map(
            N => N
        )
        port map(
            i_S  => s_DivisorIsNegative,
            i_D0 => i_Divisor,
            i_D1 => s_NegativeDivisor,
            o_O  => s_AbsoluteValueDivisor
        );

    e_AbsoluteValueMultiplexerQuotient : entity work.multiplexer_2to1_N
        generic map(
            N => N
        )
        port map(
            i_S  => s_QuotientIsNegative,
            i_D0 => s_Quotient,
            i_D1 => s_NegativeQuotient,
            o_O  => s_AbsoluteValueQuotient
        );

    e_AbsoluteValueMultiplexerRemainder : entity work.multiplexer_2to1_N
        generic map(
            N => N
        )
        port map(
            i_S  => s_RemainderIsNegative,
            i_D0 => s_Remainder(N-1 downto 0),
            i_D1 => s_NegativeRemainder,
            o_O  => s_AbsoluteValueRemainder
        );


    -- Signed/unsigned correction applied via quotient/remainder multiplexers.
    o_Quotient  <= s_AbsoluteValueQuotient;
    o_Remainder <= s_AbsoluteValueRemainder;
    o_Done      <= '1' when (s_State = STATE_DONE) else '0';

    process(
        i_Clock, i_Reset
    )
        variable v_Dividend         : unsigned(N-1 downto 0) := (others => '0');
        variable v_Divisor          : unsigned(N-1 downto 0) := (others => '0');
        variable v_Quotient         : unsigned(N-1 downto 0) := (others => '0');
        variable v_Remainder        : unsigned(N downto 0)   := (others => '0');
        variable v_RemainderShifted : unsigned(N downto 0)   := (others => '0');
        variable v_DivisorExtended  : unsigned(N downto 0)   := (others => '0');
        variable v_Count            : natural range 0 to N   := 0;
    begin
        if (i_Reset = '1') then
            s_State     <= STATE_LOAD;
            s_Quotient  <= (others => '0');
            s_Remainder <= (others => '0');
            v_Dividend  := (others => '0');
            v_Divisor   := (others => '0');
            v_Quotient  := (others => '0');
            v_Remainder := (others => '0');
            v_Count     := 0;

        elsif rising_edge(i_Clock) then

            case s_State is

                when STATE_LOAD =>
                    -- Work in magnitudes for the restoring division core.
                    v_Dividend  := unsigned(s_AbsoluteValueDividend);
                    v_Divisor   := unsigned(s_AbsoluteValueDivisor);
                    v_Quotient  := (others => '0');
                    v_Remainder := (others => '0');
                    v_Count     := N;

                    if v_Divisor = 0 then
                        -- per RISC-V M spec, division by zero is well-defined as
                        -- quotient = all 1s, remainder = dividend
                        v_Quotient  := (others => '1');
                        v_Remainder := resize(unsigned(s_AbsoluteValueDividend), N+1);
                        s_State     <= STATE_DONE;

                    elsif (i_DividendIsSigned = '1' and i_DivisorIsSigned = '1') and
                          (i_Dividend(N-1) = '1' and i_Dividend(N-2 downto 0) = (i_Dividend(N-2 downto 0)'range => '0')) and
                          (i_Divisor = (i_Divisor'range => '1')) then
                        v_Quotient  := unsigned(i_Dividend);
                        v_Remainder := (others => '0');
                        s_State     <= STATE_DONE;

                    else
                        s_State <= STATE_RUN;
                    end if;

                    s_Quotient  <= std_logic_vector(v_Quotient);
                    s_Remainder <= std_logic_vector(v_Remainder);

                when STATE_RUN =>
                    -- restoring-division iteration
                    v_DivisorExtended := resize(v_Divisor, N+1);

                    v_RemainderShifted := shift_left(v_Remainder, 1);
                    if v_Count > 0 then
                        v_RemainderShifted(0) := v_Dividend(v_Count - 1);
                    end if;

                    if v_RemainderShifted >= v_DivisorExtended then
                        v_Remainder := v_RemainderShifted - v_DivisorExtended;
                        if v_Count > 0 then
                            v_Quotient(v_Count - 1) := '1';
                        end if;
                    else
                        v_Remainder := v_RemainderShifted;
                        if v_Count > 0 then
                            v_Quotient(v_Count - 1) := '0';
                        end if;
                    end if;

                    if v_Count = 0 then
                        s_State <= STATE_DONE;
                    elsif v_Count = 1 then
                        v_Count := 0;
                        s_State <= STATE_DONE;
                    else
                        v_Count := v_Count - 1;
                    end if;

                    s_Quotient  <= std_logic_vector(v_Quotient);
                    s_Remainder <= std_logic_vector(v_Remainder);

                when STATE_DONE =>
                    -- provide results for a cycle, then re-load
                    s_State <= STATE_LOAD;
                    -- hold result registers stable
                    s_Quotient  <= std_logic_vector(v_Quotient);
                    s_Remainder <= std_logic_vector(v_Remainder);

            end case;

        end if;

    end process;

end implementation;