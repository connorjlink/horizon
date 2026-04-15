-- Horizon: register_WB.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity register_WB is
    port(
        i_Clock   : in  std_logic;
        i_Reset   : in  std_logic;
        i_Stall   : in  std_logic;
        i_Flush   : in  std_logic;
        i_Signals : in  WB_record_t;
        o_Signals : out WB_record_t
    );
end register_WB;

architecture implementation of register_WB is
begin

    g_PipelineRegister: entity work.pipeline_register
        generic map(
            T   => WB_record_t,
            NOP => WB_NOP
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
