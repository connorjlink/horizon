-- Horizon: arithmetic_logic_unit.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.barrel_shifter.all;
use work.addersubtractor_N.all;
use work.and_2.all;
use work.or_2.all;
use work.xor_2.all;
use work.multiplexer_2to1_N.all;
use work.RISCV_types.all;

entity arithmetic_logic_unit is
    generic(
        constant N : natural := 32
    );
    port(
        i_A        : in  std_logic_vector(31 downto 0);
        i_B        : in  std_logic_vector(31 downto 0);
        i_Operator : in  natural;
        o_F        : out std_logic_vector(31 downto 0);
        o_Co       : out std_logic
    );
end arithmetic_logic_unit;

architecture implementation of arithmetic_logic_unit is

-- Signals to hold the results of each logical unit
signal s_xorF  : std_logic_vector(N-1 downto 0) := (others => '0');
signal s_orF   : std_logic_vector(N-1 downto 0) := (others => '0');
signal s_andF  : std_logic_vector(N-1 downto 0) := (others => '0');
signal s_addF  : std_logic_vector(N-1 downto 0) := (others => '0');
signal s_subF  : std_logic_vector(N-1 downto 0) := (others => '0');
signal s_sllF  : std_logic_vector(N-1 downto 0) := (others => '0');
signal s_srlF  : std_logic_vector(N-1 downto 0) := (others => '0');
signal s_sraF  : std_logic_vector(N-1 downto 0) := (others => '0');
signal s_sltF  : std_logic_vector(N-1 downto 0) := (others => '0');
signal s_sltuF : std_logic_vector(N-1 downto 0) := (others => '0');

signal s_IsLessSigned   : std_logic := '0';
signal s_IsLessUnsigned : std_logic := '0';

signal s_IsArithmetic     : std_logic := '0';
signal s_IsRight          : std_logic := '0';
signal s_BarrelShifterOut : std_logic_vector(N-1 downto 0) := (others => '0');

signal s_IsSubtraction      : std_logic := '0';
signal s_AdderSubtractorOut : std_logic_vector(N-1 downto 0) := (others => '0');
signal s_CarryOut : std_logic := '0';


begin

    ------------------------------------------------------
    -- Logical XOR, OR, AND
    ------------------------------------------------------

    g_NBit_XOR: for i in 0 to N-1
    generate
        XORI: entity work.xor_2
            port map(
                i_A => i_A(i),
                i_B => i_B(i),
                o_F => s_xorF(i)
            );
    end generate g_NBit_XOR;

    g_NBit_OR: for i in 0 to N-1
    generate
        ORI: entity work.or_2
            port map(
                i_A => i_A(i),
                i_B => i_B(i),
                o_F => s_orF(i)
            );
    end generate g_NBit_OR;

    g_NBit_AND: for i in 0 to N-1
    generate
        ANDI: entity work.and_2
            port map(
                i_A => i_A(i),
                i_B => i_B(i),
                o_F => s_andF(i)
            );
    end generate g_NBit_AND;


    ------------------------------------------------------
    -- Adder/Subtractor
    ------------------------------------------------------

    s_IsSubtraction <= '0' when i_Operator = ALU_ADD else
                       '1' when i_Operator = ALU_SUB else
                       '0';

    g_NBit_ALUAdder: entity work.addersubtractor_N
        port map(
            i_A        => i_A,
            i_B        => i_B,
            i_nAdd_Sub => s_IsSubtraction,
            o_S        => s_AdderSubtractorOut,
            o_Co       => s_CarryOut
        );


    ------------------------------------------------------
    -- Barrel Shifter
    ------------------------------------------------------

    s_IsArithmetic <= '0' when i_Operator = ALU_SLL or i_Operator = ALU_SRL else
                      '1';

    s_IsRight <= '1' when i_Operator = ALU_SRL or i_Operator = ALU_SRA else
                '0';

    g_BarrelShifter: barrel_shifter
        port map(
            i_A            => i_A,
            i_B            => i_B(4 downto 0), -- log2(32) = 5
            i_IsArithmetic => s_IsArithmetic,
            i_IsRight      => s_IsRight,
            o_S            => s_BarrelShifterOut
        );


    ------------------------------------------------------
    -- Comparator
    ------------------------------------------------------

    s_IsLessUnsigned <= 32x"1" when (unsigned(i_A) < unsigned(i_B)) else
               32x"0";
        
    s_IsLessSigned <= 32x"1" when (signed(i_A) < signed(i_B)) else
              32x"0";

    
    ------------------------------------------------------
    -- Output Multiplexing
    ------------------------------------------------------
        
    with i_Operator select o_F <= 
        s_addF  when ALU_ADD,
        s_subF  when ALU_SUB,
        s_andF  when ALU_AND,
        s_orF   when ALU_OR,
        s_xorF  when ALU_XOR,
        s_BarrelShifterOut when ALU_SLL,
        s_BarrelShifterOut when ALU_SRL,
        s_BarrelShifterOut when ALU_SRA,
        s_IsLessSigned     when ALU_SLT,
        s_IsLessUnsigned   when ALU_SLTU,
        (others => '0')    when others;

    with i_Operator select o_Co <=
        s_CarryOut when ALU_ADD,
        s_subCo when ALU_SUB,
        '0'     when others;

end implementation;
