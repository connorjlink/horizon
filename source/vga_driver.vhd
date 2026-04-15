-- Horizon: vga_driver.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity vga_driver is
    port(
        i_Clock : in  std_logic;
        i_Reset : in  std_logic;
        o_HSync : out std_logic;
        o_VSync : out std_logic;
        o_Red   : out std_logic_vector(3 downto 0);
        o_Green : out std_logic_vector(3 downto 0);
        o_Blue  : out std_logic_vector(3 downto 0)
    );
end vga_driver;

-- 640x480 @ 60Hz timing specification:
--     pixel clock: 25.175 MHz
--     horizontal:
--         visible area: 640 pixels
--         front porch: 16 pixels
--         sync pulse: 96 pixels
--         back porch: 48 pixels
--         total: 800 pixels
--     vertical:
--         visible area: 480 lines
--         front porch: 10 lines
--         sync pulse: 2 lines
--         back porch: 33 lines
--         total: 525 lines

architecture implementation of vga_driver is
begin

    -- Signals to hold the pixel counters
    signal s_HCounter : std_logic_vector(9 downto 0) := (others => '0');
    signal s_VCounter : std_logic_vector(9 downto 0) := (others => '0');

    signal s_HCounter_Incremented : std_logic_vector(9 downto 0) := (others => '0');
    signal s_VCounter_Incremented : std_logic_vector(9 downto 0) := (others => '0');

    ------------------------------------------------------
    -- Adder instances to increment the counters
    ------------------------------------------------------

    e_HCounter: entity work.adder_N
        generic map(
            N => 10
        )
        port map(
            i_A => s_HCounter,
            i_B => "0000000001", -- increment by 1
            i_CarryIn => '0',
            o_Sum => s_HCounter_Incremented,
            o_CarryOut => open
        );

    e_VCounter: entity work.adder_N
        generic map(
            N => 10
        )
        port map(
            i_A => s_VCounter,
            i_B => "0000000001", -- increment by 1
            i_CarryIn => '0',
            o_Sum => s_VCounter_Incremented,
            o_CarryOut => open
        );


    -- asynchronous reset, re-begin raster after vblank in front porch
    process(
        i_Reset
    )
    begin
        if i_Reset = '1' then
            s_HCounter <= (others => '0');
            s_VCounter <= (others => '0');

        end if;

    end process;

    -- horizontal and vertical counters
    process(
        i_Clock
    )
    begin
        if rising_edge(i_Clock) then
            if s_HCounter = 10"800" then
                s_HCounter <= (others => '0');

                if s_VCounter = 10"525" then
                    s_VCounter <= (others => '0');
                else
                    s_VCounter <= s_VCounter_Incremented;
                end if;

            else
                s_HCounter <= s_HCounter_Incremented;
            end if;

        end if;

    end process;

    -- generate sync signals based on counter values
    o_HSync <= '0' when (s_HCounter >= 10"656") and (s_HCounter < 10"752") else
               '1';

    o_VSync <= '0' when (s_VCounter >= 10"490") and (s_VCounter < 10"492") else
               '1';


    -- generate RGB signals based on visible area
    -- color pattern: red increases with X, green increases with Y (UV colorization), blue is 0

    -- TODO: does the front and bach porch count against this?
    o_Red <= s_HCounter(9 downto 6) when s_HCounter < 10"640" and s_VCounter < 10"480" else
             (others => '0');

    o_Green <= s_VCounter(9 downto 6) when s_HCounter < 10"640" and s_VCounter < 10"480" else
               (others => '0');

    o_Blue <= (others => '0') when s_HCounter < 10"640" and s_VCounter < 10"480" else
              (others => '0');

end implementation;
