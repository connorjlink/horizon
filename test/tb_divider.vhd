-- Horizon: tb_divider.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
use IEEE.numeric_std.all;
library std;
use std.env.all;
use std.textio.all;
library work;
use work.types.all;

entity tb_divider is
    generic(
        CLOCK_HALF_PERIOD : time := 10 ns
    );
end tb_divider;

architecture implementation of tb_divider is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iDividend         : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
signal s_iDivisor          : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
signal s_iDividendIsSigned : std_logic := '0';
signal s_iDivisorIsSigned  : std_logic := '0';
signal s_oDone             : std_logic;
signal s_oQuotient         : std_logic_vector(DATA_WIDTH-1 downto 0);
signal s_oRemainder        : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

    -- Design-under-test instantiation
    DUT: entity work.divider
        port map(
            i_Clock            => s_Clock,
            i_Reset            => s_Reset,
            i_Dividend         => s_iDividend,
            i_Divisor          => s_iDivisor,
            i_DividendIsSigned => s_iDividendIsSigned,
            i_DivisorIsSigned  => s_iDivisorIsSigned,
            o_Done             => s_oDone,
            o_Quotient         => s_oQuotient,
            o_Remainder        => s_oRemainder
        );

    p_Clock: process
    begin
        s_Clock <= '1';
        wait for CLOCK_HALF_PERIOD;
        s_Clock <= '0';
        wait for CLOCK_HALF_PERIOD;
    end process;

    p_Reset: process
    begin
        s_Reset <= '0';
        wait for CLOCK_HALF_PERIOD / 2;
        s_Reset <= '1';
        wait for CLOCK_PERIOD;
        s_Reset <= '0';
        wait;
    end process;

    p_Stimulus: process

        variable v_Cycles : natural := 0;

    begin
        -- Await reset and stabilization; trigger off-edge
        wait for CLOCK_HALF_PERIOD;
        wait for CLOCK_HALF_PERIOD / 2; 

        
        -- 100 / 4 = 25, remainder 0
        wait for CLOCK_PERIOD;
        s_iDividend <= std_logic_vector(to_unsigned(100, DATA_WIDTH));
        s_iDivisor  <= std_logic_vector(to_unsigned(4, DATA_WIDTH));
        s_iDividendIsSigned <= '0';
        s_iDivisorIsSigned  <= '0';
        v_Cycles := 0;
        while (s_oDone = '0') loop
            wait for CLOCK_PERIOD;
            v_Cycles := v_Cycles + 1;
        end loop;
        assert s_oQuotient = std_logic_vector(to_unsigned(25, DATA_WIDTH)) and 
               s_oRemainder = std_logic_vector(to_unsigned(0, DATA_WIDTH)) and 
               v_Cycles = DATA_WIDTH+1
        report "tb_divider: testcase 1 failed(100 / 4 = 25R0)" severity error;

        -- 255 / 16 = 15, remainder 15
        wait for CLOCK_PERIOD;
        s_iDividend <= std_logic_vector(to_unsigned(255, DATA_WIDTH));
        s_iDivisor  <= std_logic_vector(to_unsigned(16, DATA_WIDTH));
        s_iDividendIsSigned <= '0';
        s_iDivisorIsSigned  <= '0';
        v_Cycles := 0;
        while (s_oDone = '0') loop
            wait for CLOCK_PERIOD;
            v_Cycles := v_Cycles + 1;
        end loop;
        assert s_oQuotient = std_logic_vector(to_unsigned(15, DATA_WIDTH)) and 
               s_oRemainder = std_logic_vector(to_unsigned(15, DATA_WIDTH)) and 
               v_Cycles = DATA_WIDTH+1
        report "tb_divider: testcase 2 failed(255 / 16 = 15R15)" severity error;

        -- 10 / 0 = all 1s, remainder 10
        wait for CLOCK_PERIOD;
        s_iDividend <= std_logic_vector(to_unsigned(10, DATA_WIDTH));
        s_iDivisor  <= std_logic_vector(to_unsigned(0, DATA_WIDTH));
        s_iDividendIsSigned <= '0';
        s_iDivisorIsSigned  <= '0';
        v_Cycles := 0;
        while (s_oDone = '0') loop
            wait for CLOCK_PERIOD;
            v_Cycles := v_Cycles + 1;
        end loop;
        assert s_oQuotient = (s_oQuotient'range => '1') and 
               s_oRemainder = std_logic_vector(to_unsigned(10, DATA_WIDTH)) and 
               v_Cycles = 1
        report "tb_divider: testcase 3 failed(10 / 0 = all 1s, remainder 10)" severity error;

        -- -100 / 4 = -25, remainder 0
        wait for CLOCK_PERIOD;
        s_iDividend <= std_logic_vector(to_signed(-100, DATA_WIDTH));
        s_iDivisor  <= std_logic_vector(to_unsigned(4, DATA_WIDTH));
        s_iDividendIsSigned <= '1';
        s_iDivisorIsSigned  <= '0';
        v_Cycles := 0;
        while (s_oDone = '0') loop
            wait for CLOCK_PERIOD;
            v_Cycles := v_Cycles + 1;
        end loop;
        assert s_oQuotient = std_logic_vector(to_signed(-25, DATA_WIDTH)) and 
               s_oRemainder = std_logic_vector(to_unsigned(0, DATA_WIDTH)) and 
               v_Cycles = DATA_WIDTH+1
        report "tb_divider: testcase 4 failed(-100 / 4 = -25R0)" severity error;

        -- -255 / -16 = 15, remainder 15
        wait for CLOCK_PERIOD;
        s_iDividend <= std_logic_vector(to_signed(-255, DATA_WIDTH));
        s_iDivisor  <= std_logic_vector(to_signed(-16, DATA_WIDTH));
        s_iDividendIsSigned <= '1';
        s_iDivisorIsSigned  <= '1';
        v_Cycles := 0;
        while (s_oDone = '0') loop
            wait for CLOCK_PERIOD;
            v_Cycles := v_Cycles + 1;
        end loop;
        assert s_oQuotient = std_logic_vector(to_signed(15, DATA_WIDTH)) and 
               s_oRemainder = std_logic_vector(to_signed(-15, DATA_WIDTH)) and 
               v_Cycles = DATA_WIDTH+1
        report "tb_divider: testcase 5 failed(-255 / -16 = 15R15)" severity error;

        -- -10 / 3 = -3, remainder -1
        wait for CLOCK_PERIOD;
        s_iDividend <= std_logic_vector(to_signed(-10, DATA_WIDTH));
        s_iDivisor  <= std_logic_vector(to_signed(3, DATA_WIDTH));
        s_iDividendIsSigned <= '1';
        s_iDivisorIsSigned  <= '1';
        v_Cycles := 0;
        while (s_oDone = '0') loop
            wait for CLOCK_PERIOD;
            v_Cycles := v_Cycles + 1;
        end loop;
        assert s_oQuotient = std_logic_vector(to_signed(-3, DATA_WIDTH)) and 
               s_oRemainder = std_logic_vector(to_signed(-1, DATA_WIDTH)) and 
               v_Cycles = DATA_WIDTH+1
        report "tb_divider: testcase 6 failed(-10 / 3 = -3R-1)" severity error;

        finish;

    end process;

end implementation;
