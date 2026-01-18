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
signal s_decRD         : std_logic_vector(4 downto 0);
signal s_decRS1        : std_logic_vector(4 downto 0);
signal s_decRS2        : std_logic_vector(4 downto 0);

-- Compressed (C) decoder fields
signal s_decCOpcode      : std_logic_vector(1 downto 0);
signal s_decCFunc2       : std_logic_vector(1 downto 0);
signal s_decCFunc2a      : std_logic_vector(1 downto 0);
signal s_decCFunc3       : std_logic_vector(2 downto 0);
signal s_decCFunc4       : std_logic_vector(3 downto 0);
signal s_decCFunc6       : std_logic_vector(5 downto 0);
signal s_decCiImmediate  : std_logic_vector(5 downto 0);
signal s_decCjImmediate  : std_logic_vector(11 downto 0);
signal s_decCuImmediate  : std_logic_vector(17 downto 0);
signal s_decCbImmediate  : std_logic_vector(8 downto 0);
signal s_decCwImmediate  : std_logic_vector(9 downto 0);
signal s_decClImmediate  : std_logic_vector(6 downto 0);
signal s_decCsImmediate  : std_logic_vector(7 downto 0);
signal s_decCRD_RS1      : std_logic_vector(4 downto 0);
signal s_decCRS2         : std_logic_vector(4 downto 0);
signal s_decCRS1Prime    : std_logic_vector(2 downto 0);
signal s_decCRD_RS2Prime : std_logic_vector(2 downto 0);

-- Signals to hold the results from the immediate extenders
-- Uncompressed
signal s_extiImmediate : std_logic_vector(31 downto 0);
signal s_extsImmediate : std_logic_vector(31 downto 0);
signal s_extbImmediate : std_logic_vector(31 downto 0);
signal s_extuImmediate : std_logic_vector(31 downto 0);
signal s_extjImmediate : std_logic_vector(31 downto 0);
signal s_exthImmediate : std_logic_vector(31 downto 0);
-- Compressed
signal s_extCiImmediate : std_logic_vector(31 downto 0);
signal s_extCwImmediate : std_logic_vector(31 downto 0);
signal s_extClImmediate : std_logic_vector(31 downto 0);
signal s_extCuImmediate : std_logic_vector(31 downto 0);
signal s_extCjImmediate : std_logic_vector(31 downto 0);
signal s_extCbImmediate : std_logic_vector(31 downto 0);

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

function CompressedRegisterToRegister(
    constant c_Register : std_logic_vector(2 downto 0)
) return std_logic_vector is
    variable v_Register : std_logic_vector(4 downto 0);
begin

    v_Register := "00000";
    v_Register(4 downto 3) := "10";
    v_Register(2 downto 0) := c_Register;

    return v_Register;

end function;

-----------------------------------------------------

begin

    with i_ThreadId select
        s_ThreadId <=
            1 when '1',
            0 when others;

    -- 4-byte instructions are indicated by a 11 in the two least-significant bits
    o_IsStride4 <= '1' when s_decCOpcode = 2b"11" else
                  '0';

    -----------------------------------------------------
    -- Uncompressed Immediate Extenders
    -----------------------------------------------------

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

    -----------------------------------------------------



    -----------------------------------------------------
    -- Compressed Immediate Extenders
    -----------------------------------------------------

    -- CI-Format
    e_ControlUnitExtenderCI: entity work.extender_NtoM
        generic map(
            N => 6,
            M => DATA_WIDTH
        )
        port map(
            i_D            => s_decCiImmediate,
            i_IsSignExtend => s_IsSignExtend,
            o_Q            => s_extCiImmediate
        );

    -- CIW-Format
    e_ControlUnitExtenderCIW: entity work.extender_NtoM
        generic map(
            N => 10,
            M => DATA_WIDTH
        )
        port map(
            i_D            => s_decCwImmediate,
            i_IsSignExtend => s_IsSignExtend,
            o_Q            => s_extCwImmediate
        );

    -- CL-Format
    e_ControlUnitExtenderCL: entity work.extender_NtoM
        generic map(
            N => 7,
            M => DATA_WIDTH
        )
        port map(
            i_D            => s_decClImmediate,
            i_IsSignExtend => s_IsSignExtend,
            o_Q            => s_extClImmediate
        );

    -- CU-Format
    e_ControlUnitExtenderCU: entity work.extender_NtoM
        generic map(
            N => 18,
            M => DATA_WIDTH
        )
        port map(
            i_D            => s_decCuImmediate,
            i_IsSignExtend => s_IsSignExtend,
            o_Q            => s_extCuImmediate
        );

    -- CJ-Format
    e_ControlUnitExtenderCJ: entity work.extender_NtoM
        generic map(
            N => 12,
            M => DATA_WIDTH
        )
        port map(
            i_D            => s_decCjImmediate,
            i_IsSignExtend => s_IsSignExtend,
            o_Q            => s_extCjImmediate
        );

    -- CB-Format
    e_ControlUnitExtenderCB: entity work.extender_NtoM
        generic map(
            N => 9,
            M => DATA_WIDTH
        )
        port map(
            i_D            => s_decCbImmediate,
            i_IsSignExtend => s_IsSignExtend,
            o_Q            => s_extCbImmediate
        );

    -----------------------------------------------------


    e_InstructionDecoder: entity work.instruction_decoder
        port map(
            i_Instruction    => i_Instruction,
            -- Uncompressed instruction fields
            o_Opcode         => s_decOpcode,
            o_RD             => s_decRD,
            o_RS1            => s_decRS1,
            o_RS2            => s_decRS2,
            o_Func3          => s_decFunc3,
            o_Func7          => s_decFunc7,
            o_Func5          => s_decFunc5,
            o_Aq             => s_decAq,
            o_Rl             => s_decRl,
            o_iImmediate     => s_deciImmediate,
            o_sImmediate     => s_decsImmediate,
            o_bImmediate     => s_decbImmediate,
            o_uImmediate     => s_decuImmediate,
            o_jImmediate     => s_decjImmediate,
            o_hImmediate     => s_dechImmediate,
            -- Compressed instruction fields
            o_C_Opcode       => s_decCOpcode,
            o_C_Func2        => s_decCFunc2,
            o_C_Func2a       => s_decCFunc2a,
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
        variable v_RD                            : std_logic_vector(4 downto 0);
        variable v_RS1                           : std_logic_vector(4 downto 0);
        variable v_RS2                           : std_logic_vector(4 downto 0);
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

        v_RD  := s_decRD;
        v_RS1 := s_decRS1;
        v_RS2 := s_decRS2;

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
                    case s_decCFunc3 is

                        when 3b"000" =>
                            -- c.addi4spn
                            if s_decCwImmediate /= 10b"0" then
                                -- hardwired override to the stack pointer
                                v_RS1 := 5b"00010";
                                v_RD := CompressedRegisterToRegister(s_decCRD_RS2Prime);
                                v_ALUOperator := ADD_OPERATOR;
                                v_ALUSource := ALUSOURCE_IMMEDIATE;
                                v_Immediate := s_extCwImmediate;
                                v_RegisterFileWriteEnable := '1';
                                v_RegisterSource := RFSOURCE_FROMALU;
                                if ENABLE_DEBUG then
                                    report "c.addi4spn" severity note;
                                end if;

                            else
                                v_Break := '1';
                                if ENABLE_DEBUG then
                                    report "c.addi4spn (Illegal Instruction with immediate = 0)" severity note;
                                end if;

                            end if;

                        when 3b"001" =>
                            -- c.fld
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "c.fld (Illegal Compressed Instruction)" severity note;
                            end if;

                        when 3b"010" =>
                            -- c.lw
                            v_RegisterFileWriteEnable := '1';
                            v_RegisterSource := RFSOURCE_FROMRAM;
                            v_ALUSource := ALUSOURCE_IMMEDIATE;
                            v_Immediate := s_extClImmediate;
                            v_RS1 := CompressedRegisterToRegister(s_decCRS1Prime);
                            v_RD := CompressedRegisterToRegister(s_decCRD_RS2Prime);
                            v_MemoryWidth := WORD_TYPE;
                            if ENABLE_DEBUG then
                                report "c.lw" severity note;
                            end if;

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
                            v_MemoryWriteEnable := '1';
                            v_ALUSource := ALUSOURCE_IMMEDIATE;
                            v_Immediate := s_extClImmediate;
                            v_RS1 := CompressedRegisterToRegister(s_decCRS1Prime);
                            v_RS2 := CompressedRegisterToRegister(s_decCRD_RS2Prime);
                            v_MemoryWidth := WORD_TYPE;
                            if ENABLE_DEBUG then
                                report "c.sw" severity note;
                            end if;

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
                    case s_decCFunc3 is

                        when 3b"000" =>
                            -- c.addi / c.nop
                            if s_decCRD_RS1 /= 5b"00000" and s_decCiImmediate /= 6x"0" then
                                -- c.addi
                                v_ALUOperator := ADD_OPERATOR;
                                v_ALUSource := ALUSOURCE_IMMEDIATE;
                                v_Immediate := s_extCiImmediate;
                                v_RD := s_decCRD_RS1;
                                v_RS1 := s_decCRD_RS1;
                                v_RegisterFileWriteEnable := '1';
                                v_RegisterSource := RFSOURCE_FROMALU;
                                if ENABLE_DEBUG then
                                    report "c.addi" severity note;
                                end if;

                            elsif s_decCRD_RS1 = 5b"00000" then
                                -- c.nop
                                if ENABLE_DEBUG then
                                    report "c.nop" severity note;
                                end if;

                            else
                                v_Break := '1';
                                report "c.addi (Illegal Instruction with rd = x0 and immediate != 0)" severity note;

                            end if;

                        when 3b"001" =>
                            -- c.jal
                            null;

                        when 3b"010" =>
                            -- c.li
                            if s_decCRD_RS1 /= 5b"00000" then
                                v_ALUOperator := ADD_OPERATOR;
                                v_ALUSource := ALUSOURCE_IMMEDIATE;
                                v_Immediate := s_extCiImmediate;
                                v_RD := s_decCRD_RS1;
                                v_RS1 := 5b"00000"; -- addi xd, x0, imm
                                v_RegisterFileWriteEnable := '1';
                                v_RegisterSource := RFSOURCE_FROMALU;
                                if ENABLE_DEBUG then
                                    report "c.li" severity note;
                                end if;

                            else
                                v_Break := '1';
                                report "c.li (Illegal Instruction with rd = x0)" severity note;
                            
                            end if;

                        when 3b"011" =>
                            -- c.addi16sp / c.lui
                            if s_decCRD_RS1 /= 5b"00000" and s_decCuImmediate /= 18b"0" then

                                if s_decCRD_RS1 = 5b"00010" then
                                    -- c.addi16sp
                                    null;

                                else
                                    -- c.lui
                                    v_Immediate := s_extCuImmediate;
                                    v_RegisterSource := RFSOURCE_FROMIMMEDIATE;
                                    v_ALUSource := ALUSOURCE_BIGIMMEDIATE;
                                    v_RegisterFileWriteEnable := '1';
                                    v_RD := s_decCRD_RS1;
                                    if ENABLE_DEBUG then
                                        report "c.lui" severity note;
                                    end if;

                                end if;

                            else
                                v_Break := '1';
                                report "c.lui (Illegal Instruction with rd = x0/x2 or immediate = 0)" severity note;

                            end if;

                        when 3b"100" =>
                            -- c.srli / c.srai / c.andi / c.sub / c.xor / c.or / c.and
                            case s_decCFunc2a is

                                when 2b"00" =>
                                    -- c.srli
                                    v_ALUOperator := SRL_OPERATOR;
                                    v_ALUSource := ALUSOURCE_IMMEDIATE;
                                    v_Immediate := s_extCiImmediate;
                                    v_RD := CompressedRegisterToRegister(s_decCRS1Prime);
                                    v_RS1 := CompressedRegisterToRegister(s_decCRS1Prime);
                                    v_RegisterFileWriteEnable := '1';
                                    v_RegisterSource := RFSOURCE_FROMALU;
                                    if ENABLE_DEBUG then
                                        report "c.srli" severity note;
                                    end if;

                                when 2b"01" =>
                                    -- c.srai
                                    v_ALUOperator := SRA_OPERATOR;
                                    v_ALUSource := ALUSOURCE_IMMEDIATE;
                                    v_Immediate := s_extCiImmediate;
                                    v_RD := CompressedRegisterToRegister(s_decCRS1Prime);
                                    v_RS1 := CompressedRegisterToRegister(s_decCRS1Prime);
                                    v_RegisterFileWriteEnable := '1';
                                    v_RegisterSource := RFSOURCE_FROMALU;
                                    if ENABLE_DEBUG then
                                        report "c.srai" severity note;
                                    end if;

                                when 2b"10" =>
                                    -- c.andi
                                    v_ALUOperator := AND_OPERATOR;
                                    v_ALUSource := ALUSOURCE_IMMEDIATE;
                                    v_Immediate := s_extCiImmediate;
                                    v_RD := CompressedRegisterToRegister(s_decCRS1Prime);
                                    v_RS1 := CompressedRegisterToRegister(s_decCRS1Prime);
                                    v_RegisterFileWriteEnable := '1';
                                    v_RegisterSource := RFSOURCE_FROMALU;
                                    if ENABLE_DEBUG then
                                        report "c.andi" severity note;
                                    end if;

                                when 2b"11" =>
                                    -- c.sub / c.xor / c.or / c.and
                                    v_ALUSource := ALUSOURCE_REGISTER;
                                    v_RD := CompressedRegisterToRegister(s_decCRS1Prime);
                                    v_RS1 := CompressedRegisterToRegister(s_decCRS1Prime);
                                    v_RS2 := CompressedRegisterToRegister(s_decCRD_RS2Prime);
                                    v_RegisterFileWriteEnable := '1';
                                    v_RegisterSource := RFSOURCE_FROMALU;

                                    case s_decCFunc2 is

                                        when "00" =>
                                            -- c.sub
                                            v_ALUOperator := SUB_OPERATOR;
                                            if ENABLE_DEBUG then
                                                report "c.sub" severity note;
                                            end if;

                                        when "01" =>
                                            -- c.xor
                                            v_ALUOperator := XOR_OPERATOR;
                                            if ENABLE_DEBUG then
                                                report "c.xor" severity note;
                                            end if;

                                        when "10" =>
                                            -- c.or
                                            v_ALUOperator := OR_OPERATOR;
                                            if ENABLE_DEBUG then
                                                report "c.or" severity note;
                                            end if;

                                        when "11" =>
                                            -- c.and
                                            v_ALUOperator := AND_OPERATOR;
                                            if ENABLE_DEBUG then
                                                report "c.and" severity note;
                                            end if;

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
                            v_Immediate := s_extCjImmediate;
                            v_BranchOperator := BEQ_TYPE;
                            v_BranchMode := BRANCHMODE_JAL_OR_BCC;
                            v_IsBranch := '1';
                            v_RS1 := 5b"00000"; -- force x0 = x0
                            v_RS2 := 5b"00000";
                            if ENABLE_DEBUG then
                                report "c.j" severity note;
                            end if;

                            null;

                        when 3b"110" =>
                            -- c.beqz
                            v_BranchOperator := BEQ_TYPE;
                            v_BranchMode := BRANCHMODE_JAL_OR_BCC;
                            v_IsBranch := '1';
                            v_Immediate := s_extCbImmediate;
                            v_RS1 := CompressedRegisterToRegister(s_decCRS1Prime);
                            if ENABLE_DEBUG then
                                report "c.beqz" severity note;
                            end if;

                        when 3b"111" =>
                            -- c.bnez
                            v_BranchOperator := BNE_TYPE;
                            v_BranchMode := BRANCHMODE_JAL_OR_BCC;
                            v_IsBranch := '1';
                            v_Immediate := s_extCbImmediate;
                            v_RS1 := CompressedRegisterToRegister(s_decCRS1Prime);
                            if ENABLE_DEBUG then
                                report "c.bnez" severity note;
                            end if;

                        when others =>
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "Illegal instruction: quadrant 1 compressed instruction" severity note;
                            end if;

                    end case;

                when "10" =>
                    -- compressed instructions (quadrant 2)
                    case s_decCFunc3 is

                        when 3b"000" =>
                            -- c.slli
                            v_ALUOperator := SLL_OPERATOR;
                            v_ALUSource := ALUSOURCE_IMMEDIATE;
                            v_Immediate := s_extCiImmediate;
                            v_RD := s_decCRD_RS1;
                            v_RS1 := s_decCRD_RS1;
                            v_RegisterFileWriteEnable := '1';
                            v_RegisterSource := RFSOURCE_FROMALU;
                            if ENABLE_DEBUG then
                                report "c.slli" severity note;
                            end if;

                        when 3b"001" =>
                            -- c.fldsp
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "c.fldsp (Illegal Compressed Instruction)" severity note;
                            end if;

                        when 3b"010" =>
                            -- c.lwsp
                            if s_decCRD_RS1 /= 5b"00000" then
                                v_RegisterFileWriteEnable := '1';
                                v_RegisterSource := RFSOURCE_FROMRAM;
                                v_ALUSource := ALUSOURCE_IMMEDIATE;
                                v_Immediate := s_extClImmediate;
                                v_RS1 := 5b"00010"; -- stack pointer
                                v_RD := s_decCRD_RS1;
                                v_MemoryWidth := WORD_TYPE;
                                if ENABLE_DEBUG then
                                    report "c.lwsp" severity note;
                                end if;

                            else
                                v_Break := '1';
                                if ENABLE_DEBUG then
                                    report "c.lwsp (Illegal Instruction with rd = x0)" severity note;
                                end if;

                            end if;

                        when 3b"011" =>
                            -- c.flwsp
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "c.flwsp (Illegal Compressed Instruction)" severity note;
                            end if;

                        when 3b"100" =>
                            -- c.jr / c.mv / c.ebreak / c.jalr / c.add
                            if s_decCFunc4(0) = '0' then

                                if s_decCRS2 = 5b"00000" then
                                    -- c.jr
                                    if s_decCRD_RS1 /= 5b"00000" then
                                        v_Immediate := 32x"0";
                                        v_BranchOperator := JALR_TYPE;
                                        v_BranchMode := BRANCHMODE_JALR;
                                        v_RS1 := s_decCRD_RS1;
                                        v_RD := 5b"00000"; -- discard the link address
                                        v_Immediate := 32x"0";
                                        if ENABLE_DEBUG then
                                            report "c.jr" severity note;
                                        end if;

                                    else
                                        v_Break := '1';
                                        if ENABLE_DEBUG then
                                            report "c.jr (Illegal Instruction with rs1 = x0)" severity note;
                                        end if;

                                    end if;

                                else
                                    -- c.mv
                                    if s_decCRD_RS1 /= 5b"00000" then
                                        v_ALUOperator := ADD_OPERATOR;
                                        v_ALUSource := ALUSOURCE_REGISTER;
                                        v_RD := s_decCRD_RS1;
                                        v_RS1 := 5b"00000"; -- x0
                                        v_RS2 := s_decCRS2;
                                        v_RegisterFileWriteEnable := '1';
                                        v_RegisterSource := RFSOURCE_FROMALU;
                                        if ENABLE_DEBUG then
                                            report "c.mv" severity note;
                                        end if;

                                    else
                                        v_Break := '1';
                                        if ENABLE_DEBUG then
                                            report "c.mv (Illegal Instruction with rd = x0 or rs2 = x0)" severity note;
                                        end if;

                                    end if;

                                end if;

                            else
                                if s_decCRS2 = 5b"00000" then

                                    if s_decCRD_RS1 = 5b"00000" then
                                        -- c.ebreak
                                        v_Break := '1';
                                        if ENABLE_DEBUG then
                                            report "c.ebreak" severity note;
                                        end if;

                                    else
                                        -- c.jalr
                                        if s_decCRD_RS1 /= 5b"00000" then
                                            v_Immediate := 32x"0";
                                            v_BranchOperator := JALR_TYPE;
                                            v_RegisterFileWriteEnable := '1';
                                            v_RegisterSource := RFSOURCE_FROMNEXTIP;
                                            v_BranchMode := BRANCHMODE_JALR;
                                            v_RS1 := s_decCRD_RS1;
                                            v_RD := s_decCRD_RS1; -- link address
                                            v_Immediate := 32x"0";
                                            if ENABLE_DEBUG then
                                                report "c.jalr" severity note;
                                            end if;

                                        else
                                            v_Break := '1';
                                            if ENABLE_DEBUG then
                                                report "c.jalr (Illegal Instruction with rd = x0)" severity note;
                                            end if;

                                        end if;

                                    end if;

                                else
                                    -- c.add
                                    if s_decCRD_RS1 /= 5b"00000" then
                                        v_ALUOperator := ADD_OPERATOR;
                                        v_ALUSource := ALUSOURCE_REGISTER;
                                        v_RD := s_decCRD_RS1;
                                        v_RS1 := s_decCRD_RS1;
                                        v_RS2 := s_decCRS2;
                                        v_RegisterFileWriteEnable := '1';
                                        v_RegisterSource := RFSOURCE_FROMALU;
                                        if ENABLE_DEBUG then
                                            report "c.add" severity note;
                                        end if;

                                    else
                                        v_Break := '1';
                                        if ENABLE_DEBUG then
                                            report "c.add (Illegal Instruction with rd = x0)" severity note;
                                        end if;

                                    end if;

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

        o_RD                            <= v_RD;
        o_RS1                           <= v_RS1;
        o_RS2                           <= v_RS2;
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
