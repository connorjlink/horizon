-- Horizon: instruction_decoder.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity instruction_decoder is
    port(
        i_Instruction    : in  std_logic_vector(31 downto 0);

        -- uncompressed instruction fields
        o_Opcode         : out std_logic_vector(6 downto 0);
        o_RD             : out std_logic_vector(4 downto 0);
        o_RS1            : out std_logic_vector(4 downto 0);
        o_RS2            : out std_logic_vector(4 downto 0);
        o_Func3          : out std_logic_vector(2 downto 0);
        o_Func7          : out std_logic_vector(6 downto 0);
        o_Func5          : out std_logic_vector(4 downto 0);
        o_Aq             : out std_logic;
        o_Rl             : out std_logic;
        o_iImmediate     : out std_logic_vector(11 downto 0);
        o_sImmediate     : out std_logic_vector(11 downto 0);
        o_bImmediate     : out std_logic_vector(12 downto 0);
        o_uImmediate     : out std_logic_vector(31 downto 12);
        o_jImmediate     : out std_logic_vector(20 downto 0);
        o_hImmediate     : out std_logic_vector(4 downto 0);

        -- compressed (C) instruction fields
        o_C_Opcode       : out std_logic_vector(1 downto 0);
        o_C_Func2        : out std_logic_vector(1 downto 0);
        o_C_Func2a       : out std_logic_vector(1 downto 0);
        o_C_Func3        : out std_logic_vector(2 downto 0);
        o_C_Func4        : out std_logic_vector(3 downto 0);
        o_C_Func6        : out std_logic_vector(5 downto 0);
        o_C_iImmediate   : out std_logic_vector(5 downto 0);
        o_C_jImmediate   : out std_logic_vector(11 downto 0);
        o_C_uImmediate   : out std_logic_vector(17 downto 0);
        o_C_bImmediate   : out std_logic_vector(8 downto 0);
        o_C_wImmediate   : out std_logic_vector(9 downto 0);
        o_C_lImmediate   : out std_logic_vector(6 downto 0);
        o_C_sImmediate   : out std_logic_vector(7 downto 0);
        o_C_RD_RS1       : out std_logic_vector(4 downto 0);
        o_C_RS2          : out std_logic_vector(4 downto 0);
        o_C_RS1_Prime    : out std_logic_vector(2 downto 0);
        o_C_RD_RS2_Prime : out std_logic_vector(2 downto 0)
    );
end instruction_decoder;

architecture implementation of instruction_decoder is
begin

    -----------------------------------------------------
    -- Uncompressed Instruction Fields
    -----------------------------------------------------

    o_Opcode <= i_Instruction(6 downto 0);

    o_RD  <= i_Instruction(11 downto 7);
    o_RS1 <= i_Instruction(19 downto 15);
    o_RS2 <= i_Instruction(24 downto 20);

    o_Func3 <= i_Instruction(14 downto 12);
    o_Func7 <= i_Instruction(31 downto 25);
    o_Func5 <= i_Instruction(31 downto 27);

    o_Aq <= i_Instruction(26);
    o_Rl <= i_Instruction(25);

    o_iImmediate <= i_Instruction(31 downto 20);

    -- shamt field is in the same position as RS2
    o_hImmediate <= i_Instruction(24 downto 20);

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

    -----------------------------------------------------


    -----------------------------------------------------
    -- Uncompressed Instruction Fields
    -----------------------------------------------------

    o_C_Opcode <= i_Instruction(1 downto 0);

    o_C_Func2a <= i_Instruction(11 downto 10);
    o_C_Func2  <= i_Instruction(6 downto 5);
    o_C_Func3  <= i_Instruction(15 downto 13);
    o_C_Func4  <= i_Instruction(15 downto 12);
    o_C_Func6  <= i_Instruction(15 downto 10);

    o_C_RD_RS1 <= i_Instruction(11 downto 7);
    o_C_RS2    <= i_Instruction(6 downto 2);

    o_C_RS1_Prime    <= i_Instruction(9 downto 7);
    o_C_RD_RS2_Prime <= i_Instruction(4 downto 2);

    -- c.j, c.jal
    o_C_jImmediate(11)         <= i_Instruction(12);
    o_C_jImmediate(10)         <= i_Instruction(8);
    o_C_jImmediate(9 downto 8) <= i_Instruction(10 downto 9);
    o_C_jImmediate(7)          <= i_Instruction(6);
    o_C_jImmediate(6)          <= i_Instruction(7);
    o_C_jImmediate(5)          <= i_Instruction(2);
    o_C_jImmediate(4)          <= i_Instruction(11);
    o_C_jImmediate(3 downto 1) <= i_Instruction(5 downto 3);
    o_C_jImmediate(0)          <= '0';

    -- c.beqz, c.bnez
    o_C_bImmediate(8)          <= i_Instruction(12);
    o_C_bImmediate(7 downto 6) <= i_Instruction(6 downto 5);
    o_C_bImmediate(5)          <= i_Instruction(2);
    o_C_bImmediate(4 downto 3) <= i_Instruction(11 downto 10);
    o_C_bImmediate(2 downto 1) <= i_Instruction(4 downto 3);
    o_C_bImmediate(0)          <= '0';

    -- c.lui, c.addi16sp
    o_C_uImmediate(5)          <= i_Instruction(12);
    o_C_uImmediate(4 downto 0) <= i_Instruction(6 downto 2);

    -- c.addi4spn
    o_C_wImmediate(9 downto 6) <= i_Instruction(10 downto 7);
    o_C_wImmediate(5 downto 4) <= i_Instruction(12 downto 11);
    o_C_wImmediate(3)          <= i_Instruction(5);
    o_C_wImmediate(2)          <= i_Instruction(6);
    o_C_wImmediate(1 downto 0) <= (others => '0');

    -- c.addi / c.srli / c.srai / c.andi / c.sub / c.xor / c.or / c.and
    o_C_iImmediate(5)          <= i_Instruction(12);
    o_C_iImmediate(4 downto 0) <= i_Instruction(6 downto 2);

    -- c.lw / c.sw
    o_C_lImmediate(6)          <= i_Instruction(5);
    o_C_lImmediate(5 downto 3) <= i_Instruction(12 downto 10);
    o_C_lImmediate(2)          <= i_Instruction(6);
    o_C_lImmediate(1 downto 0) <= (others => '0');

    -----------------------------------------------------
    
end implementation;
