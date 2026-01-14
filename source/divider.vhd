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
        i_Clock     : in  std_logic;
        i_Reset     : in  std_logic;
        i_Dividend  : in  std_logic_vector(N-1 downto 0);
        i_Divisor   : in  std_logic_vector(N-1 downto 0);
        o_Done      : out std_logic;
        o_Quotient  : out std_logic_vector(N-1 downto 0);
        o_Remainder : out std_logic_vector(N-1 downto 0)
    );
end divider;

architecture implementation of divider is

    type divider_state_t is (
        STATE_LOAD,
        STATE_RUN,
        STATE_DONE
    );

    signal s_State : divider_state_t := STATE_LOAD;

    signal s_Dividend : unsigned(N-1 downto 0) := (others => '0');
    signal s_Divisor  : unsigned(N-1 downto 0) := (others => '0');

    signal s_Quotient  : unsigned(N-1 downto 0) := (others => '0');
    signal s_Remainder : unsigned(N downto 0) := (others => '0');

    -- Number of quotient bits left to produce (counts down from N to 0)
    signal s_Count : natural range 0 to N := 0;

begin

    o_Quotient  <= std_logic_vector(s_Quotient);
    o_Remainder <= std_logic_vector(s_Remainder(N-1 downto 0));
    o_Done      <= '1' when (s_State = STATE_DONE) else '0';

    process(
        i_Clock, i_Reset
    )
        variable v_RemainderShifted : unsigned(N downto 0);
        variable v_DivisorExtended  : unsigned(N downto 0);
        variable v_RemainderNext    : unsigned(N downto 0);
    begin
        if (i_Reset = '1') then
            s_State     <= STATE_LOAD;
            s_Dividend  <= (others => '0');
            s_Divisor   <= (others => '0');
            s_Quotient  <= (others => '0');
            s_Remainder <= (others => '0');
            s_Count     <= 0;

        elsif rising_edge(i_Clock) then

            case s_State is

                when STATE_LOAD =>
                    s_Dividend  <= unsigned(i_Dividend);
                    s_Divisor   <= unsigned(i_Divisor);
                    s_Quotient  <= (others => '0');
                    s_Remainder <= (others => '0');
                    s_Count     <= N;

                    if unsigned(i_Divisor) = 0 then
                        -- per RISC-V M spec, division by zero is well-defined as
                        -- quotient = all 1s, remainder = dividend
                        s_Quotient  <= (others => '1');
                        s_Remainder <= resize(unsigned(i_Dividend), N+1);
                        s_State     <= STATE_DONE;
                    else
                        s_State <= STATE_RUN;
                    end if;

                when STATE_RUN =>
                    -- restoration-division iteration
                    v_DivisorExtended := resize(s_Divisor, N+1);

                    v_RemainderShifted := shift_left(s_Remainder, 1);
                    if s_Count > 0 then
                        v_RemainderShifted(0) := s_Dividend(s_Count - 1);
                    end if;

                    if v_RemainderShifted >= v_DivisorExtended then
                        v_RemainderNext := v_RemainderShifted - v_DivisorExtended;
                        if s_Count > 0 then
                            s_Quotient(s_Count - 1) <= '1';
                        end if;
                    else
                        v_RemainderNext := v_RemainderShifted;
                        if s_Count > 0 then
                            s_Quotient(s_Count - 1) <= '0';
                        end if;
                    end if;

                    s_Remainder <= v_RemainderNext;

                    if s_Count > 0 then
                        s_Count <= s_Count - 1;
                        if s_Count = 1 then
                            s_State <= STATE_DONE;
                        end if;
                    else
                        s_State <= STATE_DONE;
                    end if;

                when STATE_DONE =>
                    -- provide results for a cycle, then re-load
                    s_State <= STATE_LOAD;

            end case;

        end if;

    end process;

end implementation;