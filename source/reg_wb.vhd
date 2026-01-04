-------------------------------------------------------------------------
-- Connor Link
-- Iowa State University
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- reg_wb.vhd
-- DESCRIPTION: This file contains an implementation of a wb-stage RISC-V pipeline stage register.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.RISCV_types.all;

entity reg_wb is
    port(
        i_Clock      : in  std_logic;
        i_Reset      : in  std_logic;
        i_Stall    : in  std_logic;
        i_Flush    : in  std_logic;

        i_Signals  : in  work.RISCV_types.wb_record_t;
        o_Signals  : out work.RISCV_types.wb_record_t
    );
end reg_wb;

architecture behavioral of reg_wb is

begin

    process(all)
    begin
        -- insert a NOP
        if i_Reset = '1' then
            o_Signals.F       <= (others => '0');
            o_Signals.Data    <= (others => '0');
            o_Signals.Forward <= 0;
            o_Signals.LSWidth <= 0;

        elsif rising_edge(i_Clock) then

            -- insert a NOP
            if i_Flush = '1' then
                o_Signals.F       <= (others => '0');
                o_Signals.Data    <= (others => '0');
                o_Signals.Forward <= 0;
                o_Signals.LSWidth <= 0;

            -- alu register contents
            elsif i_STALL = '0' then
                o_Signals.F       <= i_Signals.F;
                o_Signals.Data    <= i_Signals.Data;
                o_Signals.Forward <= i_Signals.Forward;
                o_Signals.LSWidth <= i_Signals.LSWidth;
            
            end if;

        end if;
        
    end process;

end behavioral;
