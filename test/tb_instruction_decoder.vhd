-- Horizon: tb_instruction_decoder.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_instruction_decoder is
    generic(
        CLOCK_HALF_PERIOD : time    := 10 ns;
        DATA_WIDTH        : integer := 32
    );
end tb_instruction_decoder;

architecture implementation of tb_instruction_decoder is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iInstruction : std_logic_vector(31 downto 0) := 32x"0";
signal s_oOpcode      : std_logic_vector(6 downto 0);
signal s_oRD          : std_logic_vector(4 downto 0);
signal s_oRS1         : std_logic_vector(4 downto 0);
signal s_oRS2         : std_logic_vector(4 downto 0);
signal s_oFunc3       : std_logic_vector(2 downto 0);
signal s_oFunc7       : std_logic_vector(6 downto 0);
signal s_oFunc5       : std_logic_vector(4 downto 0);
signal s_oAq          : std_logic;
signal s_oRl          : std_logic;
signal s_oiImmediate  : std_logic_vector(11 downto 0);
signal s_osImmediate  : std_logic_vector(11 downto 0);
signal s_obImmediate  : std_logic_vector(12 downto 0);
signal s_ouImmediate  : std_logic_vector(31 downto 12);
signal s_ojImmediate  : std_logic_vector(20 downto 0);
signal s_ohImmediate  : std_logic_vector(4 downto 0);

-- Compressed (C) instruction field signals
signal s_oC_Opcode       : std_logic_vector(1 downto 0);
signal s_oC_Func2        : std_logic_vector(1 downto 0);
signal s_oC_Func3        : std_logic_vector(2 downto 0);
signal s_oC_Func4        : std_logic_vector(3 downto 0);
signal s_oC_Func6        : std_logic_vector(5 downto 0);
signal s_oC_iImmediate   : std_logic_vector(5 downto 0);
signal s_oC_jImmediate   : std_logic_vector(11 downto 0);
signal s_oC_uImmediate   : std_logic_vector(17 downto 0);
signal s_oC_bImmediate   : std_logic_vector(8 downto 0);
signal s_oC_wImmediate   : std_logic_vector(9 downto 0);
signal s_oC_lImmediate   : std_logic_vector(6 downto 0);
signal s_oC_sImmediate   : std_logic_vector(7 downto 0);
signal s_oC_RD_RS1       : std_logic_vector(4 downto 0);
signal s_oC_RS2          : std_logic_vector(4 downto 0);
signal s_oC_RS1_Prime    : std_logic_vector(2 downto 0);
signal s_oC_RD_RS2_Prime : std_logic_vector(2 downto 0);

begin

    -- Design-under-test instantiation
    DUT: entity work.instruction_decoder
        port map(
            i_Instruction => s_iInstruction,
            o_Opcode      => s_oOpcode,
            o_RD          => s_oRD,
            o_RS1         => s_oRS1,
            o_RS2         => s_oRS2,
            o_Func3       => s_oFunc3,
            o_Func7       => s_oFunc7,
            o_Func5       => s_oFunc5,
            o_Aq          => s_oAq,
            o_Rl          => s_oRl,
            o_iImmediate  => s_oiImmediate,
            o_sImmediate  => s_osImmediate,
            o_bImmediate  => s_obImmediate,
            o_uImmediate  => s_ouImmediate,
            o_jImmediate  => s_ojImmediate,
            o_hImmediate  => s_ohImmediate,

            o_C_Opcode       => s_oC_Opcode,
            o_C_Func2        => s_oC_Func2,
            o_C_Func3        => s_oC_Func3,
            o_C_Func4        => s_oC_Func4,
            o_C_Func6        => s_oC_Func6,
            o_C_iImmediate   => s_oC_iImmediate,
            o_C_jImmediate   => s_oC_jImmediate,
            o_C_uImmediate   => s_oC_uImmediate,
            o_C_bImmediate   => s_oC_bImmediate,
            o_C_wImmediate   => s_oC_wImmediate,
            o_C_lImmediate   => s_oC_lImmediate,
            o_C_sImmediate   => s_oC_sImmediate,
            o_C_RD_RS1       => s_oC_RD_RS1,
            o_C_RS2          => s_oC_RS2,
            o_C_RS1_Prime    => s_oC_RS1_Prime,
            o_C_RD_RS2_Prime => s_oC_RD_RS2_Prime
        );

    p_Clock: process
    begin
        s_Clock <= '1';
        wait for CLOCK_HALF_PERIOD;
        s_Clock <= '0';
        wait for CLOCK_HALF_PERIOD;
    end process;

    p_Reset: process
    begin
        s_Reset <= '0';   
        wait for CLOCK_HALF_PERIOD / 2;
        s_Reset <= '1';
        wait for CLOCK_PERIOD;
        s_Reset <= '0';
        wait;
    end process;

    p_Stimulus: process
    begin
        -- Await reset and stabilization; trigger off-edge
        wait for CLOCK_HALF_PERIOD;
        wait for CLOCK_HALF_PERIOD / 2; 

        -- R-format instructions
        -- add x5, x10, x15
        s_iInstruction <= 32x"00f502b3";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "0110011" and s_oRD = "00101" and s_oRS1 = "01010" and s_oRS2 = "01111" and s_oFunc3 = "000" and s_oFunc7 = "0000000")
            report "tb_instruction_decoder: testcase add failed (expected Opcode=0110011, RD=00101, RS1=01010, RS2=01111, Func3=000, Func7=0000000)"
            severity error;

        -- sub x6, x12, x14
        s_iInstruction <= 32x"40e60333";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "0110011" and s_oRD = "00110" and s_oRS1 = "01100" and s_oRS2 = "01110" and s_oFunc3 = "000" and s_oFunc7 = "0100000")
            report "tb_instruction_decoder: testcase sub failed (expected Opcode=0110011, RD=00110, RS1=01100, RS2=01110, Func3=000, Func7=0100000)"
            severity error;


        -- I-format instructions
        -- addi x5, x10, 127
        s_iInstruction <= 32x"07f50293";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "0010011" and s_oRD = "00101" and s_oRS1 = "01010" and s_oFunc3 = "000" and s_oiImmediate = "000001111111")
            report "tb_instruction_decoder: testcase addi failed (expected Opcode=0010011, RD=00101, RS1=01010, Func3=000, iImmediate=000001111111)"
            severity error;

        -- ori x7, x9, -5
        s_iInstruction <= 32x"ffb4e393";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "0010011" and s_oRD = "00111" and s_oRS1 = "01001" and s_oFunc3 = "110" and s_oiImmediate = "111111111011")
            report "tb_instruction_decoder: testcase ori failed (expected Opcode=0010011, RD=00111, RS1=01001, Func3=110, iImmediate=111111111011)"
            severity error;


        -- S-format instructions
        -- sw x15, 20(x10)
        s_iInstruction <= 32x"00f52a23";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "0100011" and s_oRS2 = "01111" and s_oRS1 = "01010" and s_oFunc3 = "010" and s_osImmediate = "000000010100")
            report "tb_instruction_decoder: testcase sw failed (expected Opcode=0100011, RS2=01111, RS1=01010, Func3=010, sImmediate=00000010100)"
            severity error;

        -- sh x8, -32(x11)
        s_iInstruction <= 32x"fe859023";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "0100011" and s_oRS2 = "01000" and s_oRS1 = "01011" and s_oFunc3 = "001" and s_osImmediate = "111111100000")
            report "tb_instruction_decoder: testcase sh failed (expected Opcode=0100011, RS2=01000, RS1=01011, Func3=001, sImmediate=11111100000)"
            severity error;


        -- B-format instructions
        -- beq x10, x15, 16
        s_iInstruction <= 32x"00f50863";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "1100011" and s_oRS1 = "01010" and s_oRS2 = "01111" and s_oFunc3 = "000" and s_obImmediate = "0000000010000")
            report "tb_instruction_decoder: testcase beq failed (expected Opcode=1100011, RS1=01010, RS2=01111, Func3=000, bImmediate=0000000010000)"
            severity error;

        -- bne x4, x6, -8
        s_iInstruction <= 32x"fe621ce3";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "1100011" and s_oRS1 = "00100" and s_oRS2 = "00110" and s_oFunc3 = "001" and s_obImmediate = "1111111111000")
            report "tb_instruction_decoder: testcase bne failed (expected Opcode=1100011, RS1=00100, RS2=00110, Func3=001, bImmediate=1111111111000)"
            severity error;


        -- U-format instructions
        -- lui x5, 0xBEEF1
        s_iInstruction <= 32x"beef12b7";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "0110111" and s_oRD = "00101" and s_ouImmediate = "10111110111011110001")
            report "tb_instruction_decoder: testcase lui failed (expected Opcode=0110111, RD=00101, uImmediate=10111110111011110001)"
            severity error;

        -- auipc x8, 0xFACED
        s_iInstruction <= 32x"faced417";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "0010111" and s_oRD = "01000" and s_ouImmediate = "11111010110011101101")
            report "tb_instruction_decoder: testcase auipc failed (expected Opcode=0010111, RD=01000, uImmediate=11111010110011101101)"
            severity error;


        -- J-format instructions
        -- jal x5, 2048
        s_iInstruction <= 32x"001002ef";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "1101111" and s_oRD = "00101" and s_ojImmediate = "000000000100000000000")
            report "tb_instruction_decoder: testcase jal failed (expected Opcode=1101111, RD=00101, jImmediate=000000000100000000000)"
            severity error;

        -- jal x3, -1024
        s_iInstruction <= 32x"c01ff1ef";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "1101111" and s_oRD = "00011" and s_ojImmediate = "111111111110000000000")
            report "tb_instruction_decoder: testcase jal failed (expected Opcode=1101111, RD=00011, jImmediate=111111111110000000000)"
            severity error;

        finish;

    end process;

end implementation;
