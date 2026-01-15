-- Horizon: instruction_decoder.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity instruction_decoder is
    port(
        i_Instruction : in  std_logic_vector(31 downto 0);
        o_Opcode      : out std_logic_vector(6 downto 0);
        o_RD          : out std_logic_vector(4 downto 0);
        o_RS1         : out std_logic_vector(4 downto 0);
        o_RS2         : out std_logic_vector(4 downto 0);
        o_Func3       : out std_logic_vector(2 downto 0);
        o_Func7       : out std_logic_vector(6 downto 0);
        o_Func5       : out std_logic_vector(4 downto 0);
        o_Aq          : out std_logic;
        o_Rl          : out std_logic;
        o_iImmediate  : out std_logic_vector(11 downto 0);
        o_sImmediate  : out std_logic_vector(11 downto 0);
        o_bImmediate  : out std_logic_vector(12 downto 0);
        o_uImmediate  : out std_logic_vector(31 downto 12);
        o_jImmediate  : out std_logic_vector(20 downto 0);
        o_hImmediate  : out std_logic_vector(4 downto 0)
    );
end instruction_decoder;

architecture implementation of instruction_decoder is
begin

    o_Opcode <= i_Instruction(6 downto 0);

    o_RD  <= i_Instruction(11 downto 7);
    o_RS1 <= i_Instruction(19 downto 15);
    o_RS2 <= i_Instruction(24 downto 20);

    -- shamt field is in the same position as RS2
    o_hImmediate <= i_Instruction(24 downto 20);

    o_Func3 <= i_Instruction(14 downto 12);

    o_Func7 <= i_Instruction(31 downto 25);

    o_Func5 <= i_Instruction(31 downto 27);

    o_Aq <= i_Instruction(26);
    o_Rl <= i_Instruction(25);

    o_iImmediate <= i_Instruction(31 downto 20);

    o_sImmediate(11 downto 5) <= i_Instruction(31 downto 25);
    o_sImmediate(4 downto 0)  <= i_Instruction(11 downto 7);

    o_bImmediate(12)          <= i_Instruction(31);
    o_bImmediate(11)          <= i_Instruction(7);
    o_bImmediate(10 downto 5) <= i_Instruction(30 downto 25);
    o_bImmediate(4 downto 1)  <= i_Instruction(11 downto 8);
    o_bImmediate(0)           <= '0';

    o_uImmediate <= i_Instruction(31 downto 12);

    o_jImmediate(20)           <= i_Instruction(31);
    o_jImmediate(19 downto 12) <= i_Instruction(19 downto 12);
    o_jImmediate(11)           <= i_Instruction(20);
    o_jImmediate(10 downto 1)  <= i_Instruction(30 downto 21);
    o_jImmediate(0)            <= '0';
    
end implementation;
