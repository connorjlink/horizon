-------------------------------------------------------------------------
-- Connor Link
-- Iowa State University
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- reg_insn.vhd
-- DESCRIPTION: This file contains an implementation of a RISC-V pipeline stage register.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.RISCV_types.all;

entity reg_insn is
    port(
        i_Clock      : in  std_logic;
        i_Reset      : in  std_logic;
        i_Stall    : in  std_logic;
        i_Flush    : in  std_logic;

        i_Signals  : in  work.RISCV_types.insn_record_t;
        o_Signals  : out work.RISCV_types.insn_record_t
    );
end reg_insn;

architecture behavioral of reg_insn is

begin

    process(all)
    begin
        -- insert a NOP
        if i_Reset = '1' then
            o_Signals.IPAddr   <= (others => '0');
            o_Signals.LinkAddr <= (others => '0');
            o_Signals.Insn     <= 32x"00000013";

        elsif rising_edge(i_Clock) then

            -- insert a NOP
            if i_Flush = '1' then
                o_Signals.IPAddr   <= (others => '0');
                o_Signals.LinkAddr <= (others => '0');
                o_Signals.Insn     <= 32x"00000013";

            -- instruction register contents
            elsif i_Stall = '0' then
                o_Signals.IPAddr   <= i_Signals.IPAddr;
                o_Signals.LinkAddr <= i_Signals.LinkAddr;
                o_Signals.Insn     <= i_Signals.Insn;

            end if;

        end if;

    end process;

end behavioral;
