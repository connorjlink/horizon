-- Horizon: types.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;

package types is

-- Generic placeholders to define the bit widths for the architecture
constant DATA_WIDTH : natural := 32;
constant ADDRESS_WIDTH : natural := 10;
constant THREAD_COUNT : natural := 2;

-- Type declaration for the register file storage
type array_t is array (natural range <>) of std_logic_vector(31 downto 0);

-- Corresponding func3 values for each branch type
type branch_operator_t is (
    BRANCH_NONE,
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
    NONE_TYPE,
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
    SLTU_OPERATOR,
    MUL_OPERATOR,
    MULH_OPERATOR,
    MULHSU_OPERATOR,
    MULHU_OPERATOR,
    DIV_OPERATOR,
    DIVU_OPERATOR,
    REM_OPERATOR,
    REMU_OPERATOR
);

pure function IsMulticycleALUOperator(
    constant op : alu_operator_t
) return boolean;

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
    BRANCHMODE_NONE,
    BRANCHMODE_JAL_OR_BCC,
    BRANCHMODE_JALR
);

-- Corresponding to each data fowarding path
type forwarding_path_t is (
    FORWARDING_NONE,
    FORWARDING_FROMEX,
    FORWARDING_FROMMEM,
    FORWARDING_FROMEXMEM_ALU,
    FORWARDING_FROMMEMWB_ALU
);

------------------------------------------------------

-- Record type declarations for the pipeline setup

------------------------------------------------------
-- Instruction Fetch -> Control Unit
------------------------------------------------------

type IF_record_t is record
    InstructionAddress : std_logic_vector(31 downto 0);
    LinkAddress        : std_logic_vector(31 downto 0);
    Instruction        : std_logic_vector(31 downto 0);
    ThreadId           : std_logic;
end record IF_record_t;

constant IF_NOP : IF_record_t := (
    InstructionAddress => (others => '0'),
    LinkAddress        => (others => '0'),
    Instruction        => 32x"00000013",
    ThreadId           => '0'
);

------------------------------------------------------


------------------------------------------------------
-- Control Unit -> Arithmetic Logic Unit
------------------------------------------------------

-- NOTE: Control unit is the first cause of exceptions: illegal instructions.

type ID_record_t is record
    MemoryWriteEnable   : std_logic;
    RegisterFileWriteEnable : std_logic;
    RegisterSource      : rf_source_t;
    ALUSource           : alu_source_t;
    ALUOperator         : alu_operator_t;
    BranchOperator      : branch_operator_t;
    MemoryWidth         : data_width_t;
    BranchMode          : branch_mode_t;
    RD                  : std_logic_vector(4 downto 0);
    RS1                 : std_logic_vector(4 downto 0);
    RS2                 : std_logic_vector(4 downto 0);
    DS1                 : std_logic_vector(31 downto 0);
    DS2                 : std_logic_vector(31 downto 0);
    Immediate           : std_logic_vector(31 downto 0);
    Break           : std_logic;
    IsBranch            : std_logic;
    IsStride4           : std_logic; -- 0: 2 bytes, 1: 4 bytes
    IsSignExtend        : std_logic; -- 0: zero-extend, 1: sign-extend
    IPToALU             : std_logic;
    Data                : std_logic_vector(31 downto 0);
end record ID_record_t;

constant ID_NOP : ID_record_t := (
    MemoryWriteEnable   => '0',
    RegisterFileWriteEnable => '0',
    RegisterSource      => RFSOURCE_FROMALU,
    ALUSource           => ALUSOURCE_IMMEDIATE,
    ALUOperator         => ADD_OPERATOR,
    MemoryWidth         => NONE_TYPE,
    BranchOperator      => BRANCH_NONE,
    BranchMode          => BRANCHMODE_NONE,
    RD                  => (others => '0'),
    RS1                 => (others => '0'),
    RS2                 => (others => '0'),
    DS1                 => (others => '0'),
    DS2                 => (others => '0'),
    Immediate           => (others => '0'),
    Break           => '0',
    IsBranch            => '0',
    IsStride4           => '0',
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
    Forward     : forwarding_path_t;             -- ForwardedMemData delayed
    MemoryWidth : data_width_t;
end record WB_record_t;

constant WB_NOP : WB_record_t := (
    Result       => (others => '0'),
    Data         => (others => '0'),
    Forward      => FORWARDING_NONE,
    MemoryWidth  => BYTE_TYPE
);

------------------------------------------------------

end package types;

package body types is

pure function IsMulticycleALUOperator(constant op : alu_operator_t) return boolean is
begin

    case op is
        when DIV_OPERATOR |
             DIVU_OPERATOR |
             REM_OPERATOR |
             REMU_OPERATOR =>
            return true;

        when others =>
            return false;

    end case;

end function;

end package body types;