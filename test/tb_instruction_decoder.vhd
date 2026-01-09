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
signal s_oiImm        : std_logic_vector(11 downto 0);
signal s_osImm        : std_logic_vector(11 downto 0);
signal s_obImm        : std_logic_vector(12 downto 0);
signal s_ouImm        : std_logic_vector(31 downto 12);
signal s_ojImm        : std_logic_vector(20 downto 0);
signal s_ohImm        : std_logic_vector(4 downto 0);

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
            o_iImm        => s_oiImm,
            o_sImm        => s_osImm,
            o_bImm        => s_obImm,
            o_uImm        => s_ouImm,
            o_jImm        => s_ojImm,
            o_hImm        => s_ohImm
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
        assert (s_oOpcode = "0010011" and s_oRD = "00101" and s_oRS1 = "01010" and s_oFunc3 = "000" and s_oiImm = "000001111111")
            report "tb_instruction_decoder: testcase addi failed (expected Opcode=0010011, RD=00101, RS1=01010, Func3=000, iImm=000001111111)"
            severity error;

        -- ori x7, x9, -5
        s_iInstruction <= 32x"ffb4e393";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "0010011" and s_oRD = "00111" and s_oRS1 = "01001" and s_oFunc3 = "110" and s_oiImm = "111111111011")
            report "tb_instruction_decoder: testcase ori failed (expected Opcode=0010011, RD=00111, RS1=01001, Func3=110, iImm=111111111011)"
            severity error;


        -- S-format instructions
        -- sw x15, 20(x10)
        s_iInstruction <= 32x"00f52a23";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "0100011" and s_oRS2 = "01111" and s_oRS1 = "01010" and s_oFunc3 = "010" and s_osImm = "000000010100")
            report "tb_instruction_decoder: testcase sw failed (expected Opcode=0100011, RS2=01111, RS1=01010, Func3=010, sImm=00000010100)"
            severity error;

        -- sh x8, -32(x11)
        s_iInstruction <= 32x"fe859023";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "0100011" and s_oRS2 = "01000" and s_oRS1 = "01011" and s_oFunc3 = "001" and s_osImm = "111111100000")
            report "tb_instruction_decoder: testcase sh failed (expected Opcode=0100011, RS2=01000, RS1=01011, Func3=001, sImm=11111100000)"
            severity error;


        -- B-format instructions
        -- beq x10, x15, 16
        s_iInstruction <= 32x"00f50863";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "1100011" and s_oRS1 = "01010" and s_oRS2 = "01111" and s_oFunc3 = "000" and s_obImm = "0000000010000")
            report "tb_instruction_decoder: testcase beq failed (expected Opcode=1100011, RS1=01010, RS2=01111, Func3=000, bImm=0000000010000)"
            severity error;

        -- bne x4, x6, -8
        s_iInstruction <= 32x"fe621ce3";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "1100011" and s_oRS1 = "00100" and s_oRS2 = "00110" and s_oFunc3 = "001" and s_obImm = "1111111111000")
            report "tb_instruction_decoder: testcase bne failed (expected Opcode=1100011, RS1=00100, RS2=00110, Func3=001, bImm=1111111111000)"
            severity error;


        -- U-format instructions
        -- lui x5, 0xBEEF1
        s_iInstruction <= 32x"beef12b7";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "0110111" and s_oRD = "00101" and s_ouImm = "10111110111011110001")
            report "tb_instruction_decoder: testcase lui failed (expected Opcode=0110111, RD=00101, uImm=10111110111011110001)"
            severity error;

        -- auipc x8, 0xFACED
        s_iInstruction <= 32x"faced417";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "0010111" and s_oRD = "01000" and s_ouImm = "11111010110011101101")
            report "tb_instruction_decoder: testcase auipc failed (expected Opcode=0010111, RD=01000, uImm=11111010110011101101)"
            severity error;


        -- J-format instructions
        -- jal x5, 2048
        s_iInstruction <= 32x"001002ef";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "1101111" and s_oRD = "00101" and s_ojImm = "000000000100000000000")
            report "tb_instruction_decoder: testcase jal failed (expected Opcode=1101111, RD=00101, jImm=000000000100000000000)"
            severity error;

        -- jal x3, -1024
        s_iInstruction <= 32x"c01ff1ef";
        wait for CLOCK_PERIOD;
        assert (s_oOpcode = "1101111" and s_oRD = "00011" and s_ojImm = "111111111110000000000")
            report "tb_instruction_decoder: testcase jal failed (expected Opcode=1101111, RD=00011, jImm=111111111110000000000)"
            severity error;

        finish;

    end process;

end implementation;
