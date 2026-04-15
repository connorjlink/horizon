-- Horizon: tb_vga_driver.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_vga_driver is
    generic(
        CLOCK_HALF_PERIOD : time := 20 ns
    );
end tb_vga_driver;

architecture implementation of tb_vga_driver is

constant TOTAL_PIXELS_X   : integer := 800;
constant TOTAL_PIXELS_Y   : integer := 525;
constant TOTAL_PIXELS     : integer := TOTAL_PIXELS_X * TOTAL_PIXELS_Y;
constant PIXELS_PER_CLOCK : integer := 1;
constant FRAMES_TO_SIM    : integer := 2;

constant CLOCK_PERIOD        : time := CLOCK_HALF_PERIOD * 2;
constant SIMULATION_DURATION : time := CLOCK_PERIOD * TOTAL_PIXELS * FRAMES_TO_SIM / PIXELS_PER_CLOCK;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_oHSync : std_logic;
signal s_oVSync : std_logic;
signal s_oRed   : std_logic_vector(3 downto 0);
signal s_oGreen : std_logic_vector(3 downto 0);
signal s_oBlue  : std_logic_vector(3 downto 0);

-- Output file signals
file output_file : text;
signal is_open : boolean := false;

begin

    -- Design-under-test instantiation
    DUT: entity work.vga_driver
        port map(
            i_Clock => s_Clock,
            i_Reset => s_Reset,
            o_HSync => s_oHSync,
            o_VSync => s_oVSync,
            o_Red   => s_oRed,
            o_Green => s_oGreen,
            o_Blue  => s_oBlue
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
        s_Reset <= '1';
        wait for 2 * CLOCK_PERIOD;
        s_Reset <= '0';
        wait until rising_edge(s_Clock);
        wait;
    end process;

    p_Stimulus: process
    begin
        wait until s_Reset = '0';
        wait until rising_edge(s_Clock);

        file_open(output_file, "vga_output.txt", write_mode);
        is_open <= true;

        report "Starting simulation at " & time'image(now);
        wait for SIMULATION_DURATION;
        report "Finished simulation at " & time'image(now);

        file_close(output_file);
        is_open <= false;
        finish;

    end process;

    process
        variable output_line : line;

    begin
        while true loop
            wait until rising_edge(s_Clock);
            wait for 0 ns;

            -- format: https://madlittlemods.github.io/vga-simulator/
            if is_open then
                write(output_line, now);
                write(output_line, string'(": "));
                write(output_line, s_oHSync);
                write(output_line, string'(" "));
                write(output_line, s_oVSync);
                write(output_line, string'(" "));
                write(output_line, s_oRed);
                write(output_line, string'(" "));
                write(output_line, s_oGreen);
                write(output_line, string'(" "));
                write(output_line, s_oBlue);
                writeline(output_file, output_line);

            end if;

        end loop;

    end process;

end implementation;
