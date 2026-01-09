-- Horizon: instruction_pointer.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity instruction_pointer is
    generic(
        p_ResetAddress : std_logic_vector(31 downto 0) := 32x"00400000" -- default data page address in RARS
    );
    port(
        i_Clock       : in  std_logic;
        i_Reset       : in  std_logic;
        i_Load        : in  std_logic;
        i_LoadAddress : in  std_logic_vector(31 downto 0);
        i_Stride      : in  std_logic; -- 0: increment 2 bytes, 1: increment 4 bytes
        i_Stall       : in  std_logic;
        o_Address     : out std_logic_vector(31 downto 0);
        o_LinkAddress : out std_logic_vector(31 downto 0)
    );
end instruction_pointer;

architecture implementation of instruction_pointer is

-- Signals for pointer register logic
signal s_IPWriteEnable : std_logic;
signal s_IPData        : std_logic_vector(31 downto 0);
signal s_IPAddress     : std_logic_vector(31 downto 0);

-- Signals for upcounting logic
signal s_IPStride    : std_logic_vector(31 downto 0);
signal s_LinkAddress : std_logic_vector(31 downto 0);

begin

    s_IPData <= p_ResetAddress when i_Reset = '1' else
                i_LoadAddress  when i_Load  = '1' else
                s_LinkAddress;

    -- Upcounting disabled when pipeline stall needed only
    s_IPWriteEnable <= '1' when i_Load  = '1' else
                       '0' when i_Stall = '1' else
                       '1';

    g_InstructionPointer: entity work.register_N
        generic map(
            N => DATA_WIDTH
        )
        port map(
            i_Clock       => i_Clock,
            i_Reset       => '0', -- NOTE: not asynchronous! but I kinda need to reset synchronously because I want to be able to choose the reset address.
            i_WriteEnable => s_IPWriteEnable,
            i_D           => s_IPData,
            o_Q           => s_IPAddress
        );

    s_IPStride <= 32x"2" when i_Stride = '0' else
                  32x"4";

    g_Upcounter: entity work.adder_N
        generic map(
            N => DATA_WIDTH
        )
        port map(
            i_A     => s_IPAddress,
            i_B     => s_IPStride,
            i_Carry => '0',
            o_S     => s_LinkAddress,
            o_Carry => open
        );

    o_Address     <= s_IPAddress;
    o_LinkAddress <= s_LinkAddress;
    
end implementation;
