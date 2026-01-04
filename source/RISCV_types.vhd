-------------------------------------------------------------------------
-- Author: Connor Link
-- Date: 02.11.2025
-- Files: RISCV_types.vhd
-------------------------------------------------------------------------
-- Description: This file contains some types that 3810 students
-- may want to use for their RISC-V implementation. This file is guaranteed to 
-- compile first, so if any types, constants, functions, etc., etc., are wanted, 
-- students should declare them here.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

package RISCV_types is

-- Generic placeholders to define the bit widths for our architecture
constant DATA_WIDTH : natural := 32;
constant ADDR_WIDTH : natural := 10;

-- Type declaration for the register file storage
type array_t is array (natural range <>) of std_logic_vector(31 downto 0);

-- Corresponding func3 values for each branch type
constant BEQ  : natural := 1;
constant BNE  : natural := 2;
constant BLT  : natural := 3;
constant BGE  : natural := 4;
constant BLTU : natural := 5;
constant BGEU : natural := 6;
constant J    : natural := 7; -- force jump for `jal` and `jalr`

-- Corresponding to each load/store data width
constant BYTE   : natural := 1;
constant HALF   : natural := 2;
constant WORD   : natural := 3;
constant DOUBLE : natural := 4;

-- Corresponding to each ALU operation code input signal
constant ADD  : natural := 0;
constant SUB  : natural := 1;
constant BAND : natural := 2;
constant BOR  : natural := 3;
constant BXOR : natural := 4;
constant BSLL : natural := 5;
constant BSRL : natural := 6;
constant BSRA : natural := 7;
constant SLT  : natural := 8;
constant SLTU : natural := 9;

-- Corresponding to each ALU source
constant ALUSRC_REG    : natural := 1;
constant ALUSRC_IMM    : natural := 2;
constant ALUSRC_BIGIMM : natural := 3;

-- Corresponding to each RF source command
constant FROM_RAM    : natural := 1;
constant FROM_ALU    : natural := 2;
constant FROM_NEXTIP : natural := 3;
constant FROM_IMM    : natural := 4;

-- Corresponding to each branch mode type (for correct effective address calculation)
constant JAL_OR_BCC : natural := 1;
constant JALR       : natural := 2;

-- Corresponding to each data fowarding path
constant FROM_EX        : natural := 1;
constant FROM_MEM       : natural := 2;
constant FROM_EXMEM_ALU : natural := 3;
constant FROM_MEMWB_ALU : natural := 4;


-- Record type declarations for the pipeline setup
-- Instruction register -> Driver
type instruction_record_t is record
    InstructionAddress : std_logic_vector(31 downto 0);
    LinkAddr : std_logic_vector(31 downto 0);
    Instruction     : std_logic_vector(31 downto 0);
end record instruction_record_t;

-- Driver -> ALU
type driver_record_t is record
    MemWrite   : std_logic;
    RegWrite   : std_logic;
    RFSrc      : natural;
    ALUSrc     : natural;
    ALUOp      : natural;
    BGUOp      : natural;
    LSWidth    : natural;
    RD         : std_logic_vector(4 downto 0);
    RS1        : std_logic_vector(4 downto 0);
    RS2        : std_logic_vector(4 downto 0);
    DS1        : std_logic_vector(31 downto 0);
    DS2        : std_logic_vector(31 downto 0);
    Imm        : std_logic_vector(31 downto 0);
    Break      : std_logic;
    BranchMode : natural;
    IsBranch   : std_logic;
    IPStride   : std_logic; -- 0: 2 bytes, 1: 4 bytes
    SignExtend : std_logic; -- 0: zero-extend, 1: sign-extend
    IPToALU    : std_logic;
    Data       : std_logic_vector(31 downto 0);
end record driver_record_t;

-- ALU -> Memory
type alu_record_t is record
    F  : std_logic_vector(31 downto 0);
    Co : std_logic;
end record alu_record_t;

-- Memory -> Register file
type memory_record_t is record
    Data : std_logic_vector(31 downto 0);
end record memory_record_t;

-- Register File -> x (delay circuit)
type register_record_t is record
    F       : std_logic_vector(31 downto 0); -- MEMWB ALU result delayed
    Data    : std_logic_vector(31 downto 0); -- MEMWB MemData delayed
    Forward : natural;                       -- ForwardedMemData delayed
    LSWidth    : natural;
end record register_record_t;

end package RISCV_types;
