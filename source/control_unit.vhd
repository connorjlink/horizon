-- Horizon: control_unit.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity control_unit is
    generic(
        constant ENABLE_DEBUG : boolean := true
    );
    port(
        i_Clock                         : in  std_logic;
        i_Reset                         : in  std_logic;
        i_Instruction                   : in  std_logic_vector(31 downto 0);
        i_ThreadId                      : in  std_logic;
        o_MemoryWriteEnable             : out std_logic;
        o_RegisterFileWriteEnable       : out std_logic;
        o_RegisterSource                : out rf_source_t;
        o_ALUSource                     : out alu_source_t;
        o_ALUOperator                   : out alu_operator_t;
        o_BranchOperator                : out branch_operator_t;
        o_MemoryWidth                   : out data_width_t;
        o_BranchMode                    : out branch_mode_t;
        o_RD                            : out std_logic_vector(4 downto 0);
        o_RS1                           : out std_logic_vector(4 downto 0);
        o_RS2                           : out std_logic_vector(4 downto 0);
        o_Immediate                     : out std_logic_vector(31 downto 0);
        o_Break                         : out std_logic;
        o_IsBranch                      : out std_logic;
        o_IPToALU                       : out std_logic;
        o_IsStride4                     : out std_logic;
        o_IsSignExtend                  : out std_logic;
        o_RS1ToMemoryAddress            : out std_logic;
        o_PendingMemoryOperationsThread : out std_logic_vector(THREAD_COUNT-1 downto 0);
        o_StallThread                   : out std_logic_vector(THREAD_COUNT-1 downto 0);
        o_AtomicSequesterThread         : out std_logic_vector(THREAD_COUNT-1 downto 0);
        o_AqStallPendingThread          : out std_logic_vector(THREAD_COUNT-1 downto 0)
    );
end control_unit;

architecture implementation of control_unit is

-- Signals to hold the results from the decoder
signal s_decOpcode     : std_logic_vector(6 downto 0);
signal s_decFunc3      : std_logic_vector(2 downto 0);
signal s_decFunc7      : std_logic_vector(6 downto 0);
signal s_decFunc5      : std_logic_vector(4 downto 0);
signal s_decAq         : std_logic;
signal s_decRl         : std_logic;
signal s_deciImmediate : std_logic_vector(11 downto 0);
signal s_decsImmediate : std_logic_vector(11 downto 0);
signal s_decbImmediate : std_logic_vector(12 downto 0);
signal s_decuImmediate : std_logic_vector(31 downto 12);
signal s_decjImmediate : std_logic_vector(20 downto 0);
signal s_dechImmediate : std_logic_vector(4 downto 0);

-- Compressed (C) decoder fields
signal s_decCOpcode       : std_logic_vector(1 downto 0);
signal s_decCFunc2        : std_logic_vector(1 downto 0);
signal s_decCFunc3        : std_logic_vector(2 downto 0);
signal s_decCFunc4        : std_logic_vector(3 downto 0);
signal s_decCFunc6        : std_logic_vector(5 downto 0);
signal s_decCiImmediate   : std_logic_vector(5 downto 0);
signal s_decCjImmediate   : std_logic_vector(11 downto 0);
signal s_decCuImmediate   : std_logic_vector(17 downto 0);
signal s_decCbImmediate   : std_logic_vector(8 downto 0);
signal s_decCwImmediate   : std_logic_vector(9 downto 0);
signal s_decClImmediate   : std_logic_vector(6 downto 0);
signal s_decCsImmediate   : std_logic_vector(7 downto 0);
signal s_decCRD_RS1       : std_logic_vector(4 downto 0);
signal s_decCRS2          : std_logic_vector(4 downto 0);
signal s_decCRS1Prime     : std_logic_vector(2 downto 0);
signal s_decCRD_RS2Prime  : std_logic_vector(2 downto 0);

-- Signals to hold the results from the immediate extenders
signal s_extiImmediate : std_logic_vector(31 downto 0);
signal s_extsImmediate : std_logic_vector(31 downto 0);
signal s_extbImmediate : std_logic_vector(31 downto 0);
signal s_extuImmediate : std_logic_vector(31 downto 0);
signal s_extjImmediate : std_logic_vector(31 downto 0);
signal s_exthImmediate : std_logic_vector(31 downto 0);

signal s_IsSignExtend : std_logic := '0';
signal s_ThreadId     : integer   := 0;

-----------------------------------------------------
-- Helper Functions
-----------------------------------------------------

function OneHot(
    constant m_Index : in integer;
    constant m_Size  : in integer
) return std_logic_vector is
    variable v_Result : std_logic_vector(m_Size-1 downto 0) := (others => '0');
begin
    
    if m_Index >= 0 and m_Index < m_Size then
        v_Result(m_Index) := '1';
    
    end if;
    
    return v_Result;

end function;

procedure SequesterOrAwait(
    constant m_ThreadId                      : in    integer;
    constant m_AqBit                         : in    std_logic;
    constant m_RlBit                         : in    std_logic;
    constant m_PendingMemoryOperationsThread : in    std_logic_vector(THREAD_COUNT-1 downto 0);
    variable m_AtomicSequesterThread         : inout std_logic_vector(THREAD_COUNT-1 downto 0);
    variable m_StallThread                   : inout std_logic_vector(THREAD_COUNT-1 downto 0);
    variable m_AqStallPendingThread          : inout std_logic_vector(THREAD_COUNT-1 downto 0)
) is
    variable v_Mask : std_logic_vector(THREAD_COUNT-1 downto 0);
begin

    v_Mask := OneHot(m_ThreadId, THREAD_COUNT);

    -----------------------------------------------------
    -- RELEASE (rl): prior memory ops must complete before AMO
    -----------------------------------------------------
    if (m_RlBit = '1') and (m_PendingMemoryOperationsThread(m_ThreadId) = '1') then
        -- Cannot even attempt to take atomic ownership yet
        m_StallThread(m_ThreadId) := '1';
        return;
    end if;

    -- check if there are any outstanding sequestrations from another thread
    if (or (m_AtomicSequesterThread and not v_Mask) = '1') then
        -- cannot proceed, yield to the other thread
        m_StallThread(m_ThreadId) := '1';
        return;
    end if;

    m_AtomicSequesterThread := v_Mask;

    -----------------------------------------------------
    -- ACQUIRE (aq): block later memory instructions after AMO completes
    -----------------------------------------------------
    if (m_AqBit = '1') then
        -- schedule stall after retiring this instruction
        m_AqStallPendingThread(m_ThreadId) := '1';
    end if;

end procedure;

-----------------------------------------------------

begin

    with i_ThreadId select
        s_ThreadId <=
            1 when '1',
            0 when others;

    -- 4-byte instructions are indicated by a 11 in the two least-significant bits
    o_IsStride4 <= '1' when s_decCOpcode = 2b"11" else
                  '0';

    -- I-format
    e_ControlUnitExtenderI: entity work.extender_NtoM
        generic map(
            N => 12,
            M => DATA_WIDTH
        )
        port map(
            i_D            => s_deciImmediate,
            i_IsSignExtend => s_IsSignExtend,
            o_Q            => s_extiImmediate
        );

    -- S-format
    e_ControlUnitExtenderS: entity work.extender_NtoM
        generic map(
            N => 12,
            M => DATA_WIDTH
        )
        port map(
            i_D            => s_decsImmediate,
            i_IsSignExtend => s_IsSignExtend,
            o_Q            => s_extsImmediate
        );

    -- B-format
    e_ControlUnitExtenderB: entity work.extender_NtoM
        generic map(
            N => 13,
            M => DATA_WIDTH
        )
        port map(
            i_D            => s_decbImmediate,
            i_IsSignExtend => s_IsSignExtend,
            o_Q            => s_extbImmediate
        );

    -- U-Format
    s_extuImmediate(31 downto 12) <= s_decuImmediate;
    s_extuImmediate(11 downto 0)  <= 12x"0";

    -- J-Format
    e_ControlUnitExtenderJ: entity work.extender_NtoM
        generic map(
            N => 21,
            M => DATA_WIDTH
        )
        port map(
            i_D            => s_decjImmediate,
            i_IsSignExtend => s_IsSignExtend,
            o_Q            => s_extjImmediate
        );

    -- "H"-format for shift immediate
    s_exthImmediate(31 downto 5) <= 27x"0";
    s_exthImmediate(4 downto 0)  <= s_dechImmediate;


    e_InstructionDecoder: entity work.instruction_decoder
        port map(
            i_Instruction => i_Instruction,
            -- Uncompressed instruction fields
            o_Opcode      => s_decOpcode,
            o_RD          => o_RD,
            o_RS1         => o_RS1,
            o_RS2         => o_RS2,
            o_Func3       => s_decFunc3,
            o_Func7       => s_decFunc7,
            o_Func5       => s_decFunc5,
            o_Aq          => s_decAq,
            o_Rl          => s_decRl,
            o_iImmediate  => s_deciImmediate,
            o_sImmediate  => s_decsImmediate,
            o_bImmediate  => s_decbImmediate,
            o_uImmediate  => s_decuImmediate,
            o_jImmediate  => s_decjImmediate,
            o_hImmediate  => s_dechImmediate,
            -- Compressed instruction fields
            o_C_Opcode       => s_decCOpcode,
            o_C_Func2        => s_decCFunc2,
            o_C_Func3        => s_decCFunc3,
            o_C_Func4        => s_decCFunc4,
            o_C_Func6        => s_decCFunc6,
            o_C_iImmediate   => s_decCiImmediate,
            o_C_jImmediate   => s_decCjImmediate,
            o_C_uImmediate   => s_decCuImmediate,
            o_C_bImmediate   => s_decCbImmediate,
            o_C_wImmediate   => s_decCwImmediate,
            o_C_lImmediate   => s_decClImmediate,
            o_C_sImmediate   => s_decCsImmediate,
            o_C_RD_RS1       => s_decCRD_RS1,
            o_C_RS2          => s_decCRS2,
            o_C_RS1_Prime    => s_decCRS1Prime,
            o_C_RD_RS2_Prime => s_decCRD_RS2Prime
        );

    process(
        all
    )
        variable v_Quadrant                      : std_logic_vector(1 downto 0);
        variable v_IsBranch                      : std_logic;
        variable v_Break                         : std_logic;
        variable v_IsSignExtend                  : std_logic;
        variable v_MemoryWriteEnable             : std_logic;
        variable v_RegisterFileWriteEnable       : std_logic;
        variable v_ALUSource                     : alu_source_t;
        variable v_RegisterSource                : rf_source_t;
        variable v_ALUOperator                   : alu_operator_t;
        variable v_BranchOperator                : branch_operator_t;
        variable v_MemoryWidth                   : data_width_t;
        variable v_BranchMode                    : branch_mode_t;
        variable v_Immediate                     : std_logic_vector(31 downto 0);
        variable v_IPToALU                       : std_logic;
        variable v_RS1ToMemoryAddress            : std_logic;
        variable v_PendingMemoryOperationsThread : std_logic_vector(THREAD_COUNT-1 downto 0);
        variable v_StallThread                   : std_logic_vector(THREAD_COUNT-1 downto 0);
        variable v_AtomicSequesterThread         : std_logic_vector(THREAD_COUNT-1 downto 0);
        variable v_AqStallPendingThread          : std_logic_vector(THREAD_COUNT-1 downto 0);

    begin 

        v_Quadrant := s_decCOpcode;

        if i_Reset = '0' then
            v_IsBranch                      := '0';
            v_Break                         := '0';
            v_IsSignExtend                  := '1'; -- 0: zero-extend, 1: sign-extend
            v_MemoryWriteEnable             := '0';
            v_RegisterFileWriteEnable       := '0';
            v_ALUSource                     := ALUSOURCE_REGISTER; -- default is to put DS1 and DS2 into the ALU
            v_RegisterSource                := RFSOURCE_FROMALU;
            v_ALUOperator                   := ADD_OPERATOR;
            v_BranchOperator                := BRANCH_NONE;
            v_MemoryWidth                   := NONE_TYPE;
            v_Immediate                     := 32x"0";
            v_BranchMode                    := BRANCHMODE_NONE;
            v_IPToALU                       := '0'; -- 0: no, 1: yes
            v_RS1ToMemoryAddress            := '0'; -- 0: ALU result, 1: RS1
            v_PendingMemoryOperationsThread := (others => '0');
            v_StallThread                   := (others => '0');
            v_AtomicSequesterThread         := (others => '0');
            v_AqStallPendingThread          := (others => '0');


            case v_Quadrant is

                when "00" =>
                    -- compressed instructions (quadrant 0)
                    case i_Instruction(15 downto 13) is

                        when 3b"000" =>
                            -- c.addi4spn
                            null;

                        when 3b"001" =>
                            -- c.fld
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "c.fld (Illegal Compressed Instruction)" severity note;
                            end if;

                        when 3b"010" =>
                            -- c.lw
                            null;

                        when 3b"011" =>
                            -- c.flw
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "c.flw (Illegal Compressed Instruction)" severity note;
                            end if;

                        when 3b"100" =>
                            -- reserved
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "Illegal instruction: reserved quadrant 0 compressed instruction" severity note;
                            end if;

                        when 3b"101" =>
                            -- c.fsd
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "c.fsd (Illegal Compressed Instruction)" severity note;
                            end if;

                        when 3b"110" =>
                            -- c.sw
                            null;

                        when 3b"111" =>
                            -- c.fsw
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "c.fsw (Illegal Compressed Instruction)" severity note;
                            end if;

                        when others =>
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "Illegal instruction: quadrant 0 compressed instruction" severity note;
                            end if;

                    end case;

                when "01" =>
                    -- compressed instructions (quadrant 1)
                    case i_Instruction(15 downto 13) is

                        when 3b"000" =>
                            -- c.addi / c.nop
                            null;

                        when 3b"001" =>
                            -- c.jal
                            null;

                        when 3b"010" =>
                            -- c.li
                            if s_decCRD_RS1 /= "00000" then
                                -- TODO:
                                null;

                            else
                                v_Break := '1';
                                report "c.li (Illegal Instruction with rd = x0)" severity note;
                            
                            end if;

                        when 3b"011" =>
                            -- c.addi16sp / c.lui
                            if s_decCRD_RS1 /= "00000" and s_decCuImmediate /= 18b"0" then

                                if s_decCRD_RS1 = "00010" then
                                    -- c.addi16sp
                                    null;

                                else
                                    -- c.lui
                                    null;

                                end if;

                            else
                                v_Break := '1';
                                report "c.lui (Illegal Instruction with rd = x0/x2 or immediate = 0)" severity note;

                            end if;

                        when 3b"100" =>
                            -- c.srli / c.srai / c.andi / c.sub / c.xor / c.or / c.and
                            case i_Instruction(11 downto 10) is

                                when 2b"00" =>
                                    -- c.srli
                                    null;

                                when 2b"01" =>
                                    -- c.srai
                                    null;

                                when 2b"10" =>
                                    -- c.andi
                                    null;

                                when 2b"11" =>
                                    -- c.sub / c.xor / c.or / c.and
                                    case i_Instruction(6 downto 5) is

                                        when "00" =>
                                            -- c.sub
                                            null;

                                        when "01" =>
                                            -- c.xor
                                            null;

                                        when "10" =>
                                            -- c.or
                                            null;

                                        when "11" =>
                                            -- c.and
                                            null;

                                        when others =>
                                            v_Break := '1';
                                            if ENABLE_DEBUG then
                                                report "Illegal instruction: quadrant 1 compressed instruction" severity note;
                                            end if;

                                    end case;

                                when others =>
                                    v_Break := '1';
                                    if ENABLE_DEBUG then
                                        report "Illegal instruction: quadrant 1 compressed instruction" severity note;
                                    end if;

                            end case;

                        when 3b"101" =>
                            -- c.j
                            null;

                        when 3b"110" =>
                            -- c.beqz
                            null;

                        when 3b"111" =>
                            -- c.bnez
                            null;

                        when others =>
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "Illegal instruction: quadrant 1 compressed instruction" severity note;
                            end if;

                    end case;

                when "10" =>
                    -- compressed instructions (quadrant 2)
                    case i_Instruction(15 downto 13) is

                        when 3b"000" =>
                            -- c.slli
                            null;

                        when 3b"001" =>
                            -- c.fldsp
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "c.fldsp (Illegal Compressed Instruction)" severity note;
                            end if;

                        when 3b"010" =>
                            -- c.lwsp
                            null;

                        when 3b"011" =>
                            -- c.flwsp
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "c.flwsp (Illegal Compressed Instruction)" severity note;
                            end if;

                        when 3b"100" =>
                            -- C.JR / C.MV / C.EBREAK / C.JALR / C.ADD
                            if i_Instruction(12) = '0' then
                                if i_Instruction(6 downto 2) = 5b"00000" then
                                    -- C.JR
                                    null;
                                else
                                    -- C.MV
                                    null;
                                end if;
                            else
                                if i_Instruction(6 downto 2) = 5b"00000" then
                                    if i_Instruction(11 downto 7) = 5b"00000" then
                                        -- C.EBREAK
                                        null;
                                    else
                                        -- C.JALR
                                        null;
                                    end if;
                                else
                                    -- C.ADD
                                    null;
                                end if;
                            end if;

                        when 3b"101" =>
                            -- c.fsdsp
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "c.fsdsp (Illegal Compressed Instruction)" severity note;
                            end if;

                        when 3b"110" =>
                            -- c.swsp
                            null;

                        when 3b"111" =>
                            -- c.fswsp
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "c.fswsp (Illegal Compressed Instruction)" severity note;
                            end if;

                        when others =>
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "Illegal instruction: quadrant 2 compressed instruction" severity note;
                            end if;

                    end case;

                when "11" =>
                    -- uncompressed instructions (quadrant 3)
                    case s_decOpcode is 

                        when 7b"1101111" => -- J-Format
                            -- jal    - rd <= linkAddr
                            v_Immediate := s_extjImmediate;
                            v_BranchOperator := JAL_TYPE;
                            v_RegisterFileWriteEnable := '1';
                            v_RegisterSource := RFSOURCE_FROMNEXTIP;
                            v_BranchMode := BRANCHMODE_JAL_OR_BCC;
                            -- NOTE: not setting the branch flag to indicate that this is a jump instead of a branch
                            --v_IsBranch := '1';
                            if ENABLE_DEBUG then
                                report "jal" severity note;
                            end if;

                        when 7b"1100111" => -- I-Format
                            -- jalr - func3=000 - rd <= linkAddr
                            v_Immediate := s_extiImmediate;
                            v_BranchOperator := JALR_TYPE;
                            v_RegisterFileWriteEnable := '1';
                            v_RegisterSource := RFSOURCE_FROMNEXTIP;
                            v_BranchMode := BRANCHMODE_JALR;
                            -- NOTE: not setting the branch flag to indicate that this is a jump instead of a branch
                            --v_IsBranch := '1';
                            if ENABLE_DEBUG then
                                report "jalr" severity note;
                            end if;

                        when 7b"0010011" => -- I-format
                            v_RegisterFileWriteEnable := '1';
                            v_ALUSource := ALUSOURCE_IMMEDIATE;
                            v_RegisterSource := RFSOURCE_FROMALU;
                            v_Immediate := s_extiImmediate;

                            case s_decFunc3 is
                                when 3b"000" =>
                                    -- NOTE: there is no `subi` because addi with negative is mostly equivalent
                                    v_ALUOperator := ADD_OPERATOR;
                                    if ENABLE_DEBUG then
                                        report "addi" severity note;
                                    end if;

                                when 3b"001" =>
                                    -- slli  - 001
                                    v_ALUOperator := SLL_OPERATOR;
                                    v_Immediate := s_exthImmediate; -- override for shamt
                                    if ENABLE_DEBUG then
                                        report "slli" severity note;
                                    end if;

                                when 3b"010" => 
                                    -- slti  - 010
                                    v_ALUOperator := SLT_OPERATOR;
                                    if ENABLE_DEBUG then
                                        report "slti" severity note;
                                    end if;

                                when 3b"011" =>
                                    -- sltiu - 011
                                    v_ALUOperator := SLTU_OPERATOR;
                                    if ENABLE_DEBUG then
                                        report "sltiu" severity note;
                                    end if;

                                when 3b"100" =>
                                    -- xori  - 100
                                    v_ALUOperator := XOR_OPERATOR;
                                    if ENABLE_DEBUG then
                                        report "xori" severity note;
                                    end if;

                                when 3b"101" =>
                                    -- shtype field is equivalent to func7
                                    if s_decFunc7 = 7b"0100000" then
                                        -- srai - 101 + 0100000
                                        v_ALUOperator := SRA_OPERATOR;
                                        v_Immediate := s_exthImmediate; -- override for shamt
                                        if ENABLE_DEBUG then
                                            report "srai" severity note;
                                        end if;

                                    else
                                        -- srli - 101 + 0000000
                                        v_ALUOperator := SRL_OPERATOR;
                                        v_Immediate := s_exthImmediate; -- override for shamt
                                        if ENABLE_DEBUG then
                                            report "srli" severity note;
                                        end if;
                                    
                                    end if;

                                when 3b"110" =>
                                    -- ori  - 110
                                    v_ALUOperator := OR_OPERATOR;
                                    if ENABLE_DEBUG then
                                        report "ori" severity note;
                                    end if;

                                when 3b"111" =>
                                    -- andi - 111
                                    v_ALUOperator := AND_OPERATOR;
                                    if ENABLE_DEBUG then
                                        report "andi" severity note;
                                    end if;

                                when others =>
                                    v_Break := '1';
                                    if ENABLE_DEBUG then
                                        report "Illegal I-Format Instruction" severity note;
                                    end if;
                            end case;

                        when 7b"0000011" => -- I-Format? More
                            v_RegisterFileWriteEnable := '1';
                            v_RegisterSource := RFSOURCE_FROMRAM;
                            v_ALUSource := ALUSOURCE_IMMEDIATE;
                            v_Immediate := s_extiImmediate;

                            case s_decFunc3 is
                                when 3b"000" =>
                                    -- lb   - 000
                                    v_IsSignExtend := '1';
                                    v_MemoryWidth := BYTE_TYPE;
                                    if ENABLE_DEBUG then
                                        report "lb" severity note;
                                    end if;

                                when 3b"001" =>
                                    -- lh   - 001
                                    v_IsSignExtend := '1';
                                    v_MemoryWidth := HALF_TYPE;
                                    if ENABLE_DEBUG then
                                        report "lh" severity note;
                                    end if;

                                when 3b"010" =>
                                    -- lw   - 010
                                    v_IsSignExtend := '1';
                                    v_MemoryWidth := WORD_TYPE;
                                    if ENABLE_DEBUG then
                                        report "lw" severity note;
                                    end if;

                                -- NOTE: RV64I only
                                when 3b"011" =>
                                -- ld   - 011
                                v_Break := '1';
                                if ENABLE_DEBUG then
                                    report "ld (Illegal I-Format (Alternate) Instruction)" severity note;
                                end if;

                                when 3b"100" =>
                                    -- lbu  - 100
                                    v_IsSignExtend := '0';
                                    v_MemoryWidth := BYTE_TYPE;
                                    if ENABLE_DEBUG then
                                        report "lbu" severity note;
                                    end if;

                                when 3b"101" =>
                                    -- lhu  - 101
                                    v_IsSignExtend := '0';
                                    v_MemoryWidth := HALF_TYPE;
                                    if ENABLE_DEBUG then
                                        report "lhu" severity note;
                                    end if;

                                -- NOTE: RV64I only
                                when 3b"110" =>
                                    -- lwu  - 110
                                    v_Break := '1';
                                    if ENABLE_DEBUG then
                                        report "lwu (Illegal I-Format (Alternate) Instruction)" severity note;
                                    end if;

                                -- NOTE: RV64I only
                                when 3b"111" =>
                                -- ldu  - 111
                                v_Break := '1';
                                if ENABLE_DEBUG then
                                    report "ldu (Illegal I-Format (Alternate) Instruction)" severity note;
                                end if;

                                when others =>
                                    v_Break := '1';
                                    if ENABLE_DEBUG then
                                        report "Illegal I-Format (Alternate) Instruction" severity note;
                                    end if;

                            end case;

                        when 7b"0100011" => -- S-Format
                            v_MemoryWriteEnable := '1';
                            v_ALUSource := ALUSOURCE_IMMEDIATE;
                            v_Immediate := s_extsImmediate;

                            case s_decFunc3 is
                                when 3b"000" =>
                                    -- sb   - 000
                                    v_MemoryWidth := BYTE_TYPE;
                                    if ENABLE_DEBUG then
                                        report "sb" severity note;
                                    end if;

                                when 3b"001" =>
                                    -- sh   - 001
                                    v_MemoryWidth := HALF_TYPE;
                                    if ENABLE_DEBUG then
                                        report "sh" severity note;
                                    end if;

                                when 3b"010" =>
                                    -- sw   - 010
                                    v_MemoryWidth := WORD_TYPE;
                                    if ENABLE_DEBUG then
                                        report "sw" severity note;
                                    end if;

                                -- NOTE: RV64I only
                                when 3b"011" =>
                                -- sd   - 011
                                v_Break := '1';
                                if ENABLE_DEBUG then
                                    report "sd (Illegal S-Format Instruction)" severity note;
                                end if;

                                when others =>
                                    v_Break := '1';
                                    if ENABLE_DEBUG then
                                        report "Illegal S-Format Instruction" severity note;
                                    end if;

                            end case;

                        when 7b"0110011" => -- R-format
                            v_RegisterFileWriteEnable := '1';
                            v_RegisterSource := RFSOURCE_FROMALU;
                            v_ALUSource := ALUSOURCE_REGISTER;

                            if s_decFunc7 = 7b"0000001" then
                                -- M-Extension
                                case s_decFunc3 is
                                    when 3b"000" =>
                                        -- mul  - 000
                                        v_ALUOperator := MUL_OPERATOR;
                                        if ENABLE_DEBUG then
                                            report "mul" severity note;
                                        end if;

                                    when 3b"001" =>
                                        -- mulh - 001
                                        v_ALUOperator := MULH_OPERATOR;
                                        if ENABLE_DEBUG then
                                            report "mulh" severity note;
                                        end if;

                                    when 3b"010" =>
                                        -- mulhsu - 010
                                        v_ALUOperator := MULHSU_OPERATOR;
                                        if ENABLE_DEBUG then
                                            report "mulhu" severity note;
                                        end if;

                                    when 3b"011" =>
                                        -- mulhu - 011
                                        v_ALUOperator := MULHU_OPERATOR;
                                        if ENABLE_DEBUG then
                                            report "mulhsu" severity note;
                                        end if;

                                    when 3b"100" =>
                                        -- div  - 100
                                        v_ALUOperator := DIV_OPERATOR;
                                        if ENABLE_DEBUG then
                                            report "div" severity note;
                                        end if;

                                    when 3b"101" =>
                                        -- divu - 101
                                        v_ALUOperator := DIVU_OPERATOR;
                                        if ENABLE_DEBUG then
                                            report "divu" severity note;
                                        end if;

                                    when 3b"110" =>
                                        -- rem  - 110
                                        v_ALUOperator := REM_OPERATOR;
                                        if ENABLE_DEBUG then
                                            report "rem" severity note;
                                        end if;

                                    when 3b"111" =>
                                        -- remu - 111
                                        v_ALUOperator := REMU_OPERATOR;
                                        if ENABLE_DEBUG then
                                            report "remu" severity note;
                                        end if;

                                    when others =>
                                        v_Break := '1';
                                        if ENABLE_DEBUG then
                                            report "Illegal M-Extension Instruction" severity note;
                                        end if;

                                end case;

                            else -- RV32I

                                case s_decFunc3 is
                                    when 3b"000" =>
                                        if s_decFunc7 = 7b"0100000" then
                                            -- sub  - 000 + 0100000
                                            v_ALUOperator := SUB_OPERATOR;
                                            if ENABLE_DEBUG then
                                                report "sub" severity note;
                                            end if;

                                        else
                                            -- add  - 000 + 0000000
                                            v_ALUOperator := ADD_OPERATOR;
                                            if ENABLE_DEBUG then
                                                report "add" severity note;
                                            end if;

                                        end if;

                                    when 3b"001" =>
                                        -- sll  - 001 + 0000000
                                        v_ALUOperator := SLL_OPERATOR;
                                        if ENABLE_DEBUG then
                                            report "sll" severity note;
                                        end if;

                                    when 3b"010" =>
                                        -- slt  - 010 + 0000000
                                        v_ALUOperator := SLT_OPERATOR;
                                        if ENABLE_DEBUG then
                                            report "slt" severity note;
                                        end if;

                                    when 3b"011" =>
                                        -- sltu - 011 + 0000000
                                        v_ALUOperator := SLTU_OPERATOR;
                                        if ENABLE_DEBUG then
                                            report "sltu" severity note;
                                        end if;

                                    when 3b"100" =>
                                        -- xor  - 100 + 0000000
                                        v_ALUOperator := XOR_OPERATOR;
                                        if ENABLE_DEBUG then
                                            report "xor" severity note;
                                        end if;

                                    when 3b"101" =>
                                        -- shtype field is equivalent to func7
                                        if s_decFunc7 = 7b"0100000" then
                                            -- sra - 101 + 0100000
                                            v_ALUOperator := SRA_OPERATOR;
                                            if ENABLE_DEBUG then
                                                report "sra" severity note;
                                            end if;

                                        else
                                            -- srl - 101 + 0000000
                                            v_ALUOperator := SRL_OPERATOR;
                                            if ENABLE_DEBUG then
                                                report "srl" severity note;
                                            end if;

                                        end if;

                                    when 3b"110" =>
                                        -- or   - 110 + 0000000
                                        v_ALUOperator := OR_OPERATOR;
                                        if ENABLE_DEBUG then
                                            report "or" severity note;
                                        end if;

                                    when 3b"111" =>
                                        -- and  - 111 + 0000000
                                        v_ALUOperator := AND_OPERATOR;
                                        if ENABLE_DEBUG then
                                            report "and" severity note;
                                        end if;

                                    when others =>
                                        v_Break := '1';
                                        if ENABLE_DEBUG then
                                            report "Illegal R-Format Instruction" severity note;
                                        end if;
                                    
                                end case;

                            end if;


                        when 7b"1100011" => -- B-Format
                            v_Immediate := s_extbImmediate;
                            -- TODO: restructure to use ALU for branch target address calculation
                            -- v_ALUSource := ALUSOURCE_IMMEDIATE;
                            -- v_IPToALU := '1';
                            v_BranchMode := BRANCHMODE_JAL_OR_BCC;
                            v_IsBranch := '1';

                            case s_decFunc3 is 
                                when 3b"000" =>
                                    -- beq  - 000
                                    v_BranchOperator := BEQ_TYPE;
                                    if ENABLE_DEBUG then
                                        report "beq" severity note;
                                    end if;

                                when 3b"001" =>
                                    -- bne  - 001
                                    v_BranchOperator := BNE_TYPE;
                                    if ENABLE_DEBUG then
                                        report "bne" severity note;
                                    end if;

                                when 3b"100" =>
                                    -- blt  - 100
                                    v_BranchOperator := BLT_TYPE;
                                    if ENABLE_DEBUG then
                                        report "blt" severity note;
                                    end if;

                                when 3b"101" =>
                                    -- bge  - 101
                                    v_BranchOperator := BGE_TYPE;
                                    if ENABLE_DEBUG then
                                        report "bge" severity note;
                                    end if;

                                when 3b"110" =>
                                    -- bltu - 110
                                    v_BranchOperator := BLTU_TYPE;
                                    if ENABLE_DEBUG then
                                        report "bltu" severity note;
                                    end if;

                                when 3b"111" =>
                                    -- bgeu - 111
                                    v_BranchOperator := BGEU_TYPE;
                                    if ENABLE_DEBUG then
                                        report "bgeu" severity note;
                                    end if;

                                when others =>
                                    v_Break := '1';
                                    if ENABLE_DEBUG then
                                        report "Illegal B-Format Instruction" severity note;
                                    end if;

                            end case;

                        when 7b"0101111" => -- A-Extension

                            if s_decFunc3 = 3b"010" then

                                case s_decFunc5 is

                                    when 5b"00010" =>
                                        -- lr.w  - 00010
                                        v_MemoryWidth := WORD_TYPE;
                                        -- TODO: Aq and Rl
                                        SequesterOrAwait(
                                            s_ThreadId,
                                            s_decAq,
                                            s_decRl,
                                            v_PendingMemoryOperationsThread,
                                            v_AtomicSequesterThread,
                                            v_StallThread,
                                            v_AqStallPendingThread
                                        );
                                        if ENABLE_DEBUG then
                                            report "lr.w" severity note;
                                        end if;

                                    when 5b"00011" =>
                                        -- sc.w  - 00011
                                        v_MemoryWidth := WORD_TYPE;
                                        v_MemoryWriteEnable := '1';
                                        SequesterOrAwait(
                                            s_ThreadId,
                                            s_decAq,
                                            s_decRl,
                                            v_PendingMemoryOperationsThread,
                                            v_AtomicSequesterThread,
                                            v_StallThread,
                                            v_AqStallPendingThread
                                        );
                                        if ENABLE_DEBUG then
                                            report "sc.w" severity note;
                                        end if;

                                    when 5b"00001" =>
                                        -- amoswap.w - 00001
                                        v_MemoryWidth := WORD_TYPE;
                                        v_MemoryWriteEnable := '1';
                                        v_RS1ToMemoryAddress := '1';
                                        SequesterOrAwait(
                                            s_ThreadId,
                                            s_decAq,
                                            s_decRl,
                                            v_PendingMemoryOperationsThread,
                                            v_AtomicSequesterThread,
                                            v_StallThread,
                                            v_AqStallPendingThread
                                        );
                                        if ENABLE_DEBUG then
                                            report "amoswap.w" severity note;
                                        end if;

                                    when 5b"00000" =>
                                        -- amoadd.w  - 00000
                                        v_MemoryWidth := WORD_TYPE;
                                        v_MemoryWriteEnable := '1';
                                        v_ALUOperator := ADD_OPERATOR;
                                        v_RS1ToMemoryAddress := '1';
                                        SequesterOrAwait(
                                            s_ThreadId,
                                            s_decAq,
                                            s_decRl,
                                            v_PendingMemoryOperationsThread,
                                            v_AtomicSequesterThread,
                                            v_StallThread,
                                            v_AqStallPendingThread
                                        );
                                        if ENABLE_DEBUG then
                                            report "amoadd.w" severity note;
                                        end if;

                                    when 5b"00100" =>
                                        -- amoxor.w  - 00100
                                        v_MemoryWidth := WORD_TYPE;
                                        v_MemoryWriteEnable := '1';
                                        v_ALUOperator := XOR_OPERATOR;
                                        v_RS1ToMemoryAddress := '1';
                                        SequesterOrAwait(
                                            s_ThreadId,
                                            s_decAq,
                                            s_decRl,
                                            v_PendingMemoryOperationsThread,
                                            v_AtomicSequesterThread,
                                            v_StallThread,
                                            v_AqStallPendingThread
                                        );
                                        if ENABLE_DEBUG then
                                            report "amoxor.w" severity note;
                                        end if;

                                    when 5b"01100" =>
                                        -- amoand.w  - 01100
                                        v_MemoryWidth := WORD_TYPE;
                                        v_MemoryWriteEnable := '1';
                                        v_ALUOperator := AND_OPERATOR;
                                        v_RS1ToMemoryAddress := '1';
                                        SequesterOrAwait(
                                            s_ThreadId,
                                            s_decAq,
                                            s_decRl,
                                            v_PendingMemoryOperationsThread,
                                            v_AtomicSequesterThread,
                                            v_StallThread,
                                            v_AqStallPendingThread
                                        );
                                        if ENABLE_DEBUG then
                                            report "amoand.w" severity note;
                                        end if;

                                    when 5b"01000" =>
                                        -- amoor.w  - 01000
                                        v_MemoryWidth := WORD_TYPE;
                                        v_MemoryWriteEnable := '1';
                                        v_ALUOperator := OR_OPERATOR;
                                        v_RS1ToMemoryAddress := '1';
                                        SequesterOrAwait(
                                            s_ThreadId,
                                            s_decAq,
                                            s_decRl,
                                            v_PendingMemoryOperationsThread,
                                            v_AtomicSequesterThread,
                                            v_StallThread,
                                            v_AqStallPendingThread
                                        );
                                        if ENABLE_DEBUG then
                                            report "amoor.w" severity note;
                                        end if;

                                    when 5b"10000" =>
                                        -- amomin.w  - 10000
                                        v_MemoryWidth := WORD_TYPE;
                                        v_MemoryWriteEnable := '1';
                                        v_ALUOperator := MIN_OPERATOR;
                                        v_RS1ToMemoryAddress := '1';
                                        SequesterOrAwait(
                                            s_ThreadId,
                                            s_decAq,
                                            s_decRl,
                                            v_PendingMemoryOperationsThread,
                                            v_AtomicSequesterThread,
                                            v_StallThread,
                                            v_AqStallPendingThread
                                        );
                                        if ENABLE_DEBUG then
                                            report "amomin.w" severity note;
                                        end if;

                                    when 5b"10100" =>
                                        -- amomax.w  - 10100
                                        v_MemoryWidth := WORD_TYPE;
                                        v_MemoryWriteEnable := '1';
                                        v_ALUOperator := MAX_OPERATOR;
                                        v_RS1ToMemoryAddress := '1';
                                        SequesterOrAwait(
                                            s_ThreadId,
                                            s_decAq,
                                            s_decRl,
                                            v_PendingMemoryOperationsThread,
                                            v_AtomicSequesterThread,
                                            v_StallThread,
                                            v_AqStallPendingThread
                                        );
                                        if ENABLE_DEBUG then
                                            report "amomax.w" severity note;
                                        end if;

                                    when 5b"11000" =>
                                        -- amominu.w  - 11000
                                        v_MemoryWidth := WORD_TYPE;
                                        v_MemoryWriteEnable := '1';
                                        v_ALUOperator := MINU_OPERATOR;
                                        v_RS1ToMemoryAddress := '1';
                                        SequesterOrAwait(
                                            s_ThreadId,
                                            s_decAq,
                                            s_decRl,
                                            v_PendingMemoryOperationsThread,
                                            v_AtomicSequesterThread,
                                            v_StallThread,
                                            v_AqStallPendingThread
                                        );
                                        if ENABLE_DEBUG then
                                            report "amominu.w" severity note;
                                        end if;

                                    when 5b"11100" =>
                                        -- amomaxu.w  - 11100
                                        v_MemoryWidth := WORD_TYPE;
                                        v_MemoryWriteEnable := '1';
                                        v_ALUOperator := MAXU_OPERATOR;
                                        v_RS1ToMemoryAddress := '1';
                                        SequesterOrAwait(
                                            s_ThreadId,
                                            s_decAq,
                                            s_decRl,
                                            v_PendingMemoryOperationsThread,
                                            v_AtomicSequesterThread,
                                            v_StallThread,
                                            v_AqStallPendingThread
                                        );
                                        if ENABLE_DEBUG then
                                            report "amomaxu.w" severity note;
                                        end if;

                                    when others =>
                                        v_Break := '1';
                                        if ENABLE_DEBUG then
                                            report "Illegal A-Extension Instruction" severity note;
                                        end if;

                                end case;

                            else 

                                v_Break := '1';
                                if ENABLE_DEBUG then
                                    report "Illegal A-Extension Instruction" severity note;
                                end if;

                            end if;

                        when 7b"0110111" => -- U-Format
                            -- lui   - rd = imm << 12
                            v_Immediate := s_extuImmediate;
                            v_RegisterSource := RFSOURCE_FROMIMMEDIATE;
                            v_ALUSource := ALUSOURCE_BIGIMMEDIATE;
                            v_RegisterFileWriteEnable := '1';
                            if ENABLE_DEBUG then
                                report "lui" severity note;
                            end if;

                        when 7b"0010111" => -- U-Format
                            -- auipc - rd = pc + (imm << 12)
                            v_Immediate := s_extuImmediate;
                            v_RegisterSource := RFSOURCE_FROMALU;
                            v_ALUSource := ALUSOURCE_IMMEDIATE;
                            v_IPToALU := '1';
                            v_RegisterFileWriteEnable := '1';
                            if ENABLE_DEBUG then
                                report "auipc" severity note;
                            end if;

                        when 7b"0001111" => -- fence
                            case s_decFunc3 is
                                when 3b"000" =>
                                    -- fence   - 000
                                    -- TODO: implement properly once multithreading
                                    if ENABLE_DEBUG then
                                        report "fence" severity note;
                                    end if;
                                
                                when 3b"001" =>
                                    -- fence.i - 001
                                    v_StallThread(s_ThreadId) := '1';
                                    if ENABLE_DEBUG then
                                        report "fence.i" severity note;
                                    end if;

                                when others =>
                                    v_Break := '1';
                                    if ENABLE_DEBUG then
                                        report "Illegal fence Instruction" severity note;
                                    end if;

                            end case;

                        when 7b"1110011" => -- ecall/ebreak
                            if i_Instruction = 32b"00000000000100000000000001110011" then
                                -- ebreak
                                v_Break := '1';
                                if ENABLE_DEBUG then
                                    report "ebreak" severity note; 
                                end if;
                            else
                                -- ecall
                                if ENABLE_DEBUG then
                                    report "ecall" severity note; 
                                end if;
                            end if;

                        when others =>
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "Illegal Instruction (0x" & to_string(i_Instruction) & ")" severity note;
                            end if;

                    end case;

                when others =>
                    v_Break := '1';
                    if ENABLE_DEBUG then
                        report "Illegal Instruction (0x" & to_string(i_Instruction) & ")" severity note;
                    end if;

            end case;

        else
            v_IsBranch                      := '0';
            v_Break                         := '0';
            v_IsSignExtend                  := '1'; -- default case is sign extension
            v_MemoryWriteEnable             := '0';
            v_RegisterFileWriteEnable       := '0';
            v_RegisterSource                := RFSOURCE_FROMALU;
            v_ALUSource                     := ALUSOURCE_REGISTER;
            v_ALUOperator                   := ADD_OPERATOR;
            v_BranchOperator                := BEQ_TYPE;
            v_MemoryWidth                   := WORD_TYPE;
            v_Immediate                     := 32x"0";
            v_BranchMode                    := BRANCHMODE_JAL_OR_BCC;
            v_IPToALU                       := '0';
            v_PendingMemoryOperationsThread := (others => '0');
            v_StallThread                   := (others => '0');
            v_AtomicSequesterThread         := (others => '0');
            v_AqStallPendingThread          := (others => '0');

        end if;

        o_IsBranch                      <= v_IsBranch;
        o_Break                         <= v_Break;
        o_IsSignExtend                  <= v_IsSignExtend;
        s_IsSignExtend                  <= v_IsSignExtend;
        o_MemoryWriteEnable             <= v_MemoryWriteEnable;
        o_RegisterFileWriteEnable       <= v_RegisterFileWriteEnable;
        o_RegisterSource                <= v_RegisterSource;
        o_ALUSource                     <= v_ALUSource;
        o_ALUOperator                   <= v_ALUOperator;
        o_BranchOperator                <= v_BranchOperator;
        o_MemoryWidth                   <= v_MemoryWidth;
        o_Immediate                     <= v_Immediate;
        o_BranchMode                    <= v_BranchMode;
        o_IPToALU                       <= v_IPToALU;
        o_PendingMemoryOperationsThread <= v_PendingMemoryOperationsThread;
        o_StallThread                   <= v_StallThread;
        o_AtomicSequesterThread         <= v_AtomicSequesterThread;
        o_AqStallPendingThread          <= v_AqStallPendingThread;

    end process;

end implementation;
