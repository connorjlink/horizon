-- Horizon: register_MEM.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity register_MEM is
    port(
        i_Clock      : in  std_logic;
        i_Reset      : in  std_logic;
        i_Stall    : in  std_logic;
        i_Flush    : in  std_logic;

        i_Signals  : in  mem_record_t;
        o_Signals  : out mem_record_t
    );
end register_MEM;

architecture implementation of register_MEM is
begin

    g_PipelineRegister: entity work.pipeline_register
        generic map(
            T   => MEM_record_t,
            NOP => MEM_NOP
        )
        port map(
            i_Clock   => i_Clock,
            i_Reset   => i_Reset,
            i_Stall   => i_Stall,
            i_Flush   => i_Flush,
            i_Signals => i_Signals,
            o_Signals => o_Signals
        );

end implementation;
