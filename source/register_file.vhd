-- Horizon: register_file.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity register_file is
    port(
        i_Clock       : in  std_logic;
        i_Reset       : in  std_logic;
        i_RS1         : in  register_id_vector_t;
        i_RS2         : in  register_id_vector_t;
        i_RD          : in  register_id_vector_t;
        i_WriteEnable : in  std_logic;
        i_D           : in  data_vector_t;
        o_DS1         : out data_vector_t;
        o_DS2         : out data_vector_t
    );
end register_file;

architecture implementation of register_file is

signal s_WriteEnableX : std_logic_vector(31 downto 0);
signal s_WriteEnableM : std_logic_vector(31 downto 0);

signal s_Rx : array_t(0 to 31);

begin

    -----------------------------------------------------
    -- decoding and register generation
    -----------------------------------------------------

    g_Decoder: entity work.decoder_5to32
        port map(
            i_S => i_RD,
            o_Q => s_WriteEnableX
        );

    -- local and global write enable masking
    s_WriteEnableM <= s_WriteEnableX and 32x"FFFFFFFF" when i_WriteEnable = '1' else 32x"0";

    g_NRegisters: for i in 1 to 31 generate
        REGISTERI: entity work.register_N
            generic map(
                N => DATA_WIDTH
            )
            port map(
                i_Clock       => i_Clock,
                i_Reset       => i_Reset,
                i_WriteEnable => s_WriteEnableM(i),
                i_D           => i_D,
                o_Q           => s_Rx(i)
            );
    end generate g_NRegisters;

    -- hardwired zero register assignment
    s_Rx(0) <= x"00000000";

    -----------------------------------------------------


    -----------------------------------------------------
    -- dual read port multiplexers
    -----------------------------------------------------

    g_Multiplexer1: entity work.multiplexer_32to1
        port map(
            i_S => i_RS1,
            i_D => s_Rx,
            o_Q => o_DS1
        );

    g_Multiplexer2: entity work.multiplexer_32to1
        port map(
            i_S => i_RS2,
            i_D => s_Rx,
            o_Q => o_DS2
        );
        
    -----------------------------------------------------

end implementation;
