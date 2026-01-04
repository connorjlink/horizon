-------------------------------------------------------------------------
-- Connor Link
-- Iowa State University
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- reg_alu.vhd
-- DESCRIPTION: This file contains an implementation of an alu-stage RISC-V pipeline stage register.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.RISCV_types.all;

entity reg_alu is
    port(
        i_Clock      : in  std_logic;
        i_Reset      : in  std_logic;
        i_Stall    : in  std_logic;
        i_Flush    : in  std_logic;

        i_Signals  : in  work.RISCV_types.alu_record_t;
        o_Signals  : out work.RISCV_types.alu_record_t
    );
end reg_alu;

architecture behavioral of reg_alu is

begin

    process(all)
    begin
        -- insert a NOP
        if i_Reset = '1' then
            o_Signals.F  <= (others => '0');
            o_Signals.Co <= '0';

        elsif rising_edge(i_Clock) then
            
            -- insert a NOP
            if i_Flush = '1' then
                o_Signals.F  <= (others => '0');
                o_Signals.Co <= '0';

            -- alu register contents
            elsif i_Stall = '0' then
                o_Signals.F  <= i_Signals.F;
                o_Signals.Co <= i_Signals.Co;

            end if;

        end if;

    end process;

end behavioral;
