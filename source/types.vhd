-- Horizon: types.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;

package types is

-- Generic placeholders to define the bit widths for the architecture
constant DATA_WIDTH : natural := 32;
constant ADDR_WIDTH : natural := 10;

-- Type declaration for the register file storage
type array_t is array (natural range <>) of std_logic_vector(31 downto 0);

-- Corresponding func3 values for each branch type
type branch_operator_t is (
    BEQ_TYPE,
    BNE_TYPE,
    BLT_TYPE,
    BGE_TYPE,
    BLTU_TYPE,
    BGEU_TYPE,
    JAL_TYPE, -- force (unconditional) jump for `jal` and `jalr`
    JALR_TYPE
);

-- Corresponding to each load/store data width
type data_width_t is (
    BYTE_TYPE,
    HALF_TYPE,
    WORD_TYPE,
    DOUBLE_TYPE
);

-- Corresponding to each ALU operation code input signal
type alu_operator_t is (
    ADD_OPERATOR,
    SUB_OPERATOR,
    AND_OPERATOR,
    OR_OPERATOR,
    XOR_OPERATOR,
    SLL_OPERATOR,
    SRL_OPERATOR,
    SRA_OPERATOR,
    SLT_OPERATOR,
    SLTU_OPERATOR
);

-- Corresponding to each ALU source
type alu_source_t is (
    ALUSOURCE_REGISTER,
    ALUSOURCE_IMMEDIATE,
    ALUSOURCE_BIGIMMEDIATE
);

-- Corresponding to each RF source command
type rf_source_t is (
    RFSOURCE_FROMRAM,
    RFSOURCE_FROMALU,
    RFSOURCE_FROMNEXTIP,
    RFSOURCE_FROMIMMEDIATE
);

-- Corresponding to each branch mode type (for correct effective address calculation)
type branch_mode_t is (
    BRANCHMODE_JAL_OR_BCC,
    BRANCHMODE_JALR
);

-- Corresponding to each data fowarding path
type forwarding_path_t is (
    FORWARDING_FROMEX,
    FORWARDING_FROMMEM,
    FORWARDING_FROMEXMEM_ALU,
    FORWARDING_FROMMEMWB_ALU
);

-- Record type declarations for the pipeline setup

------------------------------------------------------
-- Instruction Fetch -> Control Unit
------------------------------------------------------

type IF_record_t is record
    InstructionAddress : std_logic_vector(31 downto 0);
    LinkAddress        : std_logic_vector(31 downto 0);
    Instruction        : std_logic_vector(31 downto 0);
end record IF_record_t;

constant IF_NOP : IF_record_t := (
    InstructionAddress => (others => '0'),
    LinkAddress        => (others => '0'),
    Instruction        => 32x"00000013"
);

------------------------------------------------------


------------------------------------------------------
-- Control Unit -> Arithmetic Logic Unit
------------------------------------------------------

-- NOTE: Control unit is the first cause of exceptions: illegal instructions.

type ID_record_t is record
    MemoryWriteEnable   : std_logic;
    RegisterWriteEnable : std_logic;
    RegisterSource      : natural;
    ALUSource           : alu_source_t;
    ALUOperator         : natural;
    BGUOperator         : natural;
    MemoryWidth         : natural;
    RD                  : std_logic_vector(4 downto 0);
    RS1                 : std_logic_vector(4 downto 0);
    RS2                 : std_logic_vector(4 downto 0);
    DS1                 : std_logic_vector(31 downto 0);
    DS2                 : std_logic_vector(31 downto 0);
    Immediate           : std_logic_vector(31 downto 0);
    IsFaulted           : std_logic;
    BranchMode          : natural;
    IsBranch            : std_logic;
    IPStride            : std_logic; -- 0: 2 bytes, 1: 4 bytes
    IsSignExtend        : std_logic; -- 0: zero-extend, 1: sign-extend
    IPToALU             : std_logic;
    Data                : std_logic_vector(31 downto 0);
end record ID_record_t;

constant ID_NOP : ID_record_t := (
    MemoryWriteEnable   => '0',
    RegisterWriteEnable => '0',
    RegisterSource      => 0,
    ALUSource           => ALUSOURCE_REGISTER,
    ALUOperator         => 0,
    BGUOperator         => 0,
    MemoryWidth         => 0,
    RD                  => (others => '0'),
    RS1                 => (others => '0'),
    RS2                 => (others => '0'),
    DS1                 => (others => '0'),
    DS2                 => (others => '0'),
    Immediate           => (others => '0'),
    IsFaulted           => '0',
    BranchMode          => 0,
    IsBranch            => '0',
    IPStride            => '0',
    IsSignExtend        => '0',
    IPToALU             => '0',
    Data                => (others => '0')
);

------------------------------------------------------


------------------------------------------------------
-- Arithmetic Logic Unit -> Memory
------------------------------------------------------

type EX_record_t is record
    Result   : std_logic_vector(31 downto 0);
    CarryOut : std_logic;
end record EX_record_t;

constant EX_NOP : EX_record_t := (
    Result   => (others => '0'),
    CarryOut => '0'
);

------------------------------------------------------


------------------------------------------------------
-- Memory -> Register File
------------------------------------------------------

type MEM_record_t is record
    Data : std_logic_vector(31 downto 0);
end record MEM_record_t;

constant MEM_NOP : MEM_record_t := (
    Data => (others => '0')
);

------------------------------------------------------


------------------------------------------------------
-- Register File -> x (delay circuit)
------------------------------------------------------

type WB_record_t is record
    Result      : std_logic_vector(31 downto 0); -- MEMWB ALU result delayed
    Data        : std_logic_vector(31 downto 0); -- MEMWB MemData delayed
    Forward     : natural;                       -- ForwardedMemData delayed
    MemoryWidth : natural;
end record WB_record_t;

constant WB_NOP : WB_record_t := (
    Result       => (others => '0'),
    Data         => (others => '0'),
    Forward      => 0,
    MemoryWidth  => 0
);

------------------------------------------------------

end package types;
