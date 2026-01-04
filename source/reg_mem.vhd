-------------------------------------------------------------------------
-- Connor Link
-- Iowa State University
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- reg_mem.vhd
-- DESCRIPTION: This file contains an implementation of a mem-stage RISC-V pipeline stage register.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.RISCV_types.all;

entity reg_mem is
    port(
        i_Clock      : in  std_logic;
        i_Reset      : in  std_logic;
        i_Stall    : in  std_logic;
        i_Flush    : in  std_logic;

        i_Signals  : in  work.RISCV_types.mem_record_t;
        o_Signals  : out work.RISCV_types.mem_record_t
    );
end reg_mem;

architecture behavioral of reg_mem is

begin

    process(all)
    begin
        -- insert a NOP
        if i_Reset = '1' then
            o_Signals.Data <= (others => '0');

        elsif rising_edge(i_Clock) then

            -- insert a NOP
            if i_Flush = '1' then
                o_Signals.Data <= (others => '0');

            -- alu register contents
            elsif i_STALL = '0' then
                o_Signals.Data <= i_Signals.Data;
            
            end if;

        end if;
        
    end process;

end behavioral;
