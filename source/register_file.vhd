-- Horizon: register_file.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity register_file is
    port(
        i_Clock       : in  std_logic;
        i_Reset       : in  std_logic;
        i_RS1         : in  std_logic_vector(4 downto 0);
        i_RS2         : in  std_logic_vector(4 downto 0);
        i_RD          : in  std_logic_vector(4 downto 0);
        i_WriteEnable : in  std_logic;
        i_D           : in  std_logic_vector(31 downto 0);
        o_DS1         : out std_logic_vector(31 downto 0);
        o_DS2         : out std_logic_vector(31 downto 0)
    );
end register_file;

architecture implementation of register_file is

signal s_WEx : std_logic_vector(31 downto 0);
signal s_WEm : std_logic_vector(31 downto 0);

signal s_Rx : array_t(0 to 31);

begin

    g_Decoder: entity work.decoder_5to32
        port map(
            i_S => i_RD,
            o_Q => s_WEx
        );

    -- Local and global write enable masking
    s_WEm <= s_WEx and 32x"FFFFFFFF" when i_WriteEnable = '1' else 32x"0";

    g_NRegisters: for i in 1 to 31 generate
        REGISTERI: entity work.register_N
            generic map(
                N => DATA_WIDTH
            )
            port map(
                i_Clock       => i_Clock,
                i_Reset       => i_Reset,
                i_WriteEnable => s_WEm(i),
                i_D           => i_D,
                o_Q           => s_Rx(i)
            );
    end generate g_NRegisters;

    -- Hardwired zero register assignment
    s_Rx(0) <= x"00000000";


    -- Dual read port multiplexers

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

end implementation;
