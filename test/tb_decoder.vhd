-------------------------------------------------------------------------
-- Connor Link
-- Iowa State University
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- tb_decoder.vhd
-- DESCRIPTION: This file contains an implementation of a simple testbench for the RISC-V frontend.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library std;
use std.env.all;
use std.textio.all;

entity tb_decoder is
    generic(gCLK_HPER  : time := 10 ns;
     	    DATA_WIDTH : integer := 32);
end tb_decoder;

architecture mixed of tb_decoder is

-- Total clock period
constant cCLK_PER : time := gCLK_HPER * 2;

-- Create helper signals
signal CLK, reset : std_logic := '0';

-- Create input and output signals for the module under test
signal s_iInsn   : std_logic_vector(31 downto 0) := 32x"0";
signal s_oOpcode : std_logic_vector(6 downto 0);
signal s_oRD     : std_logic_vector(4 downto 0);
signal s_oRS1    : std_logic_vector(4 downto 0);
signal s_oRS2    : std_logic_vector(4 downto 0);
signal s_oFunc3  : std_logic_vector(2 downto 0);
signal s_oFunc7  : std_logic_vector(6 downto 0);
signal s_oiImm   : std_logic_vector(11 downto 0);
signal s_osImm   : std_logic_vector(11 downto 0);
signal s_obImm   : std_logic_vector(12 downto 0);
signal s_ouImm   : std_logic_vector(31 downto 12);
signal s_ojImm   : std_logic_vector(20 downto 0);
signal s_ohImm   : std_logic_vector(4 downto 0);

begin

-- Instantiate the module under test
DUTO: entity work.decoder
    port map(
        i_Clock    => CLK,
        i_Reset    => reset,
        i_Insn   => s_iInsn,
        o_Opcode => s_oOpcode,
        o_RD     => s_oRD,
        o_RS1    => s_oRS1,
        o_RS2    => s_oRS2,
        o_Func3  => s_oFunc3,
        o_Func7  => s_oFunc7,
        o_iImm   => s_oiImm,
        o_sImm   => s_osImm,
        o_bImm   => s_obImm,
        o_uImm   => s_ouImm,
        o_jImm   => s_ojImm,
        o_hImm   => s_ohImm
    );

--This first process is to setup the clock for the test bench
P_CLK: process
begin
	CLK <= '1';         -- clock starts at 1
	wait for gCLK_HPER; -- after half a cycle
	CLK <= '0';         -- clock becomes a 0 (negative edge)
	wait for gCLK_HPER; -- after half a cycle, process begins evaluation again
end process;

-- This process resets the sequential components of the design.
-- It is held to be 1 across both the negative and positive edges of the clock
-- so it works regardless of whether the design uses synchronous (pos or neg edge)
-- or asynchronous resets.
P_RST: process
begin
	reset <= '0';   
	wait for gCLK_HPER/2;
	reset <= '1';
	wait for gCLK_HPER*2;
	reset <= '0';
	wait;
end process;  


-- Assign inputs 
P_TEST_CASES: process
begin
    wait for gCLK_HPER;
	wait for gCLK_HPER/2; -- don't change inputs on clock edges
    wait for gCLK_HPER * 2;

    -- R-format instructions
    -- add x5, x10, x15 ; 0x00f502b3
    s_iInsn <= "0000000" & "01111" & "01010" & "000" & "00101" & "0110011"; 
    -- Expected: Opcode = 0110011, RD = 00101, RS1 = 01010, RS2 = 01111, Func3 = 000, Func7 = 0000000
    wait for gCLK_HPER * 2;
    
    -- sub x6, x12, x14 ; 0x40e60333
    s_iInsn <= "0100000" & "01110" & "01100" & "000" & "00110" & "0110011"; 
    -- Expected: Opcode = 0110011, RD = 00110, RS1 = 01100, RS2 = 01110, Func3 = 000, Func7 = 0100000
    wait for gCLK_HPER * 2;


    -- I-format instructions
    -- addi x5, x10, 127 ; 0x07f50293
    s_iInsn <= "000001111111" & "01010" & "000" & "00101" & "0010011";
    -- Expected: Opcode = 0010011, RD = 00101, RS1 = 01010, Func3 = 000, iImm = 000001111111 (127)
    wait for gCLK_HPER * 2;
    
    -- ori x7, x9, -5 ; 0xffb4e393
    s_iInsn <= "111111111011" & "01001" & "110" & "00111" & "0010011";
    -- Expected: Opcode = 0010011, RD = 00111, RS1 = 01001, Func3 = 110, iImm = 111111111011 (-5)
    wait for gCLK_HPER * 2;
    

    -- S-format instructions
    -- sw x15, 20(x10) ; 0x00f52a23
    s_iInsn <= "0000000" & "01111" & "01010" & "010" & "10100" & "0100011";
    -- Expected: Opcode = 0100011, RS2 = 01111, RS1 = 01010, Func3 = 010, sImm = 00000010100 (20)
    wait for gCLK_HPER * 2;
    
    -- sh x8, -32(x11) ; 0xfe859023
    s_iInsn <= "1111111" & "01000" & "01011" & "001" & "00000" & "0100011";
    -- Expected: Opcode = 0100011, RS2 = 01000, RS1 = 01011, Func3 = 001, sImm = 11111100000 (-32)
    wait for gCLK_HPER * 2;
    

    -- B-format instructions
    -- beq x10, x15, 16 ; 0x00f50863
    s_iInsn <= "0000000" & "01111" & "01010" & "000" & "10000" & "1100011";
    -- Expected: Opcode = 1100011, RS1 = 01010, RS2 = 01111, Func3 = 000, bImm = 00000010000 (16) 
    wait for gCLK_HPER * 2;
    
    -- bne x4, x6, -8 ; 0xfe621ce3
    s_iInsn <= "1111111" & "00110" & "00100" & "001" & "11001" & "1100011";
    -- Expected: Opcode = 1100011, RS1 = 00100, RS2 = 00110, Func3 = 001, bImm = 11111111000 (-8)
    wait for gCLK_HPER * 2;
    

    -- U-format instructions
    -- lui x5, 0xBEEF1 ; 0xbeef12b7
    s_iInsn <= "10111110111011110001" & "00101" & "0110111";
    -- Expected: Opcode = 0110111, RD = 00101, uImm = 10111110111011110001  (BEEF1)
    wait for gCLK_HPER * 2;
    
    -- auipc x8, 0xFACED ; 0xfaced417
    s_iInsn <= "11111010110011101101" & "01000" & "0010111";
    -- Expected: Opcode = 0010111, RD = 01000, uImm = 11111010110011101101
    wait for gCLK_HPER * 2;
    

    -- J-format instructions
    -- jal x5, 2048 ; 0x001002ef
    s_iInsn <= "00000000000100000000" & "00101" & "1101111";
    -- Expected: Opcode = 1101111, RD = 00101, jImm = 00000000000100000000 (2048)
    wait for gCLK_HPER * 2;
    
    -- jal x3, -1024 ; 0xc01ff1ef
    s_iInsn <= "11000000000111111111" & "00011" & "1101111";
    -- Expected: Opcode = 1101111, RD = 00011, jImm = 11111111111000000000 (-1024)
    wait for gCLK_HPER * 2;

    wait;
end process;

end mixed;
