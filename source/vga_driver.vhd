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

    -- Signals to hold the pixel counters
    signal s_HCounter : unsigned(9 downto 0) := (others => '0');
    signal s_VCounter : unsigned(9 downto 0) := (others => '0');

    signal s_HCounter_Incremented : std_logic_vector(9 downto 0) := (others => '0');
    signal s_VCounter_Incremented : std_logic_vector(9 downto 0) := (others => '0');

begin

    ------------------------------------------------------
    -- Adder instances to increment the counters
    ------------------------------------------------------

    e_HCounter: entity work.adder_N
        generic map(
            N => 10
        )
        port map(
            i_A     => std_logic_vector(s_HCounter),
            i_B     => "0000000001", -- increment by 1
            i_Carry => '0',
            o_S     => s_HCounter_Incremented,
            o_Carry => open
        );

    e_VCounter: entity work.adder_N
        generic map(
            N => 10
        )
        port map(
            i_A     => std_logic_vector(s_VCounter),
            i_B     => "0000000001", -- increment by 1
            i_Carry => '0',
            o_S     => s_VCounter_Incremented,
            o_Carry => open
        );


    -- horizontal and vertical counters + asynchronous reset
    process(
        i_Clock, i_Reset
    )
    begin
        if i_Reset = '1' then
            s_HCounter <= (others => '0');
            s_VCounter <= (others => '0');

        elsif rising_edge(i_Clock) then
            if s_HCounter = 799 then
                s_HCounter <= (others => '0');

                if s_VCounter = 524 then
                    s_VCounter <= (others => '0');
                else
                    s_VCounter <= unsigned(s_VCounter_Incremented);
                end if;

            else
                s_HCounter <= unsigned(s_HCounter_Incremented);

            end if;

        end if;

    end process;

    -- generate sync signals based on counter values
    o_HSync <= '0' when (s_HCounter >= 656) and (s_HCounter < 752) else
               '1';

    o_VSync <= '0' when (s_VCounter >= 490) and (s_VCounter < 492) else
               '1';


    -- generate RGB signals based on visible area
    -- color pattern: red increases with X, green increases with Y (UV colorization), blue is 0

    o_Red <= std_logic_vector(s_HCounter(9 downto 6)) when s_HCounter < 640 and s_VCounter < 480 else
             (others => '0');

    o_Green <= std_logic_vector(s_VCounter(9 downto 6)) when s_HCounter < 640 and s_VCounter < 480 else
               (others => '0');

    o_Blue <= std_logic_vector(s_VCounter(9 downto 6)) when s_HCounter < 640 and s_VCounter < 480 else
              (others => '0');

end implementation;
