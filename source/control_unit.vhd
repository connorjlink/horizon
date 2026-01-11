-- Horizon: control_unit.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity control_unit is
    generic(
        constant ENABLE_DEBUG : boolean := false
    );
    port(
        i_Clock               : in  std_logic;
        i_Reset               : in  std_logic;
        i_Instruction         : in  std_logic_vector(31 downto 0);
        o_MemoryWriteEnable   : out std_logic;
        o_RegisterWriteEnable : out std_logic;
        o_RegisterSource      : out rf_source_t;
        o_ALUSource           : out alu_source_t;
        o_ALUOperator         : out alu_operator_t;
        o_BranchOperator      : out branch_operator_t;
        o_MemoryWidth         : out data_width_t;
        o_BranchMode          : out branch_mode_t;
        o_RD                  : out std_logic_vector(4 downto 0);
        o_RS1                 : out std_logic_vector(4 downto 0);
        o_RS2                 : out std_logic_vector(4 downto 0);
        o_Immediate           : out std_logic_vector(31 downto 0);
        o_Break               : out std_logic;
        o_IsBranch            : out std_logic;
        o_IPToALU             : out std_logic;
        o_IsStride4           : out std_logic;
        o_IsSignExtend        : out std_logic
    );
end control_unit;

architecture implementation of control_unit is

-- Signals to hold the results from the decoder
signal s_decOpcode     : std_logic_vector(6 downto 0);
signal s_decFunc3      : std_logic_vector(2 downto 0);
signal s_decFunc7      : std_logic_vector(6 downto 0);
signal s_deciImmediate : std_logic_vector(11 downto 0);
signal s_decsImmediate : std_logic_vector(11 downto 0);
signal s_decbImmediate : std_logic_vector(12 downto 0);
signal s_decuImmediate : std_logic_vector(31 downto 12);
signal s_decjImmediate : std_logic_vector(20 downto 0);
signal s_dechImmediate : std_logic_vector(4 downto 0);

-- Signals to hold the results from the immediate extenders
signal s_extiImmediate : std_logic_vector(31 downto 0);
signal s_extsImmediate : std_logic_vector(31 downto 0);
signal s_extbImmediate : std_logic_vector(31 downto 0);
signal s_extuImmediate : std_logic_vector(31 downto 0);
signal s_extjImmediate : std_logic_vector(31 downto 0);
signal s_exthImmediate : std_logic_vector(31 downto 0);

signal s_SignExtend : std_logic := '0';

begin

    -- 4-byte instructions are indicated by a 11 in the two least-significant bits of the opcode
    o_IsStride4 <= '1' when s_decOpcode(1 downto 0) = 2b"11" else
                  '0';

    -- I-format
    g_ControlUnitExtenderI: entity work.extender_NtoM
        generic map(
            N => 12,
            M => DATA_WIDTH
        )
        port map(
            i_D            => s_deciImmediate,
            i_IsSignExtend => s_SignExtend,
            o_Q            => s_extiImmediate
        );

    -- S-format
    g_ControlUnitExtenderS: entity work.extender_NtoM
        generic map(
            N => 12,
            M => DATA_WIDTH
        )
        port map(
            i_D            => s_decsImmediate,
            i_IsSignExtend => s_SignExtend,
            o_Q            => s_extsImmediate
        );

    -- B-format
    g_ControlUnitExtenderB: entity work.extender_NtoM
        generic map(
            N => 13,
            M => DATA_WIDTH
        )
        port map(
            i_D            => s_decbImmediate,
            i_IsSignExtend => s_SignExtend,
            o_Q            => s_extbImmediate
        );

    -- U-Format
    s_extuImmediate(31 downto 12) <= s_decuImmediate;
    s_extuImmediate(11 downto 0)  <= 12x"0";

    -- J-Format
    g_ControlUnitExtenderJ: entity work.extender_NtoM
        generic map(
            N => 21,
            M => DATA_WIDTH
        )
        port map(
            i_D            => s_decjImmediate,
            i_IsSignExtend => s_SignExtend,
            o_Q            => s_extjImmediate
        );

    -- "H"-format for shift immediate
    s_exthImmediate(31 downto 5) <= 27x"0";
    s_exthImmediate(4 downto 0)  <= s_dechImmediate;


    g_InstructionDecoder: entity work.instruction_decoder
        port map(
            i_Instruction => i_Instruction,
            o_Opcode      => s_decOpcode,
            o_RD          => o_RD,
            o_RS1         => o_RS1,
            o_RS2         => o_RS2,
            o_Func3       => s_decFunc3,
            o_Func7       => s_decFunc7,
            o_iImmediate  => s_deciImmediate,
            o_sImmediate  => s_decsImmediate,
            o_bImmediate  => s_decbImmediate,
            o_uImmediate  => s_decuImmediate,
            o_jImmediate  => s_decjImmediate,
            o_hImmediate  => s_dechImmediate
        );

    process(
        all
    )
        variable v_IsBranch            : std_logic;
        variable v_Break               : std_logic;
        variable v_IsSignExtend        : std_logic;
        variable v_MemoryWriteEnable   : std_logic;
        variable v_RegisterWriteEnable : std_logic;
        variable v_ALUSource           : alu_source_t;
        variable v_RegisterSource      : rf_source_t;
        variable v_ALUOperator         : alu_operator_t;
        variable v_BranchOperator      : branch_operator_t;
        variable v_MemoryWidth         : data_width_t;
        variable v_BranchMode          : branch_mode_t;
        variable v_Immediate           : std_logic_vector(31 downto 0);
        variable v_IPToALU             : std_logic;

    begin 
        if i_Reset = '0' then
            v_IsBranch            := '0';
            v_Break               := '0';
            v_IsSignExtend        := '1'; -- 0: zero-extend, 1: sign-extend
            v_MemoryWriteEnable   := '0';
            v_RegisterWriteEnable := '0';
            v_ALUSource           := ALUSOURCE_REGISTER; -- default is to put DS1 and DS2 into the ALU
            v_RegisterSource      := RFSOURCE_FROMALU;
            v_ALUOperator         := ADD_OPERATOR;
            v_BranchOperator      := BEQ_TYPE;
            v_MemoryWidth         := WORD_TYPE;
            v_Immediate           := 32x"0";
            v_BranchMode          := BRANCHMODE_JAL_OR_BCC;
            v_IPToALU             := '0'; -- 0: no, 1: yes

            case s_decOpcode is 
                when 7b"1101111" => -- J-Format
                    -- jal    - rd <= linkAddr
                    v_Immediate := s_extjImmediate;
                    v_BranchOperator := JAL_TYPE;
                    v_RegisterWriteEnable := '1';
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
                    v_RegisterWriteEnable := '1';
                    v_RegisterSource := RFSOURCE_FROMNEXTIP;
                    v_BranchMode := BRANCHMODE_JALR;
                    -- NOTE: not setting the branch flag to indicate that this is a jump instead of a branch
                    --v_IsBranch := '1';
                    if ENABLE_DEBUG then
                        report "jalr" severity note;
                    end if;

                when 7b"0010011" => -- I-format
                    v_RegisterWriteEnable := '1';
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
                                report "Illegal I-Format Instruction" severity error;
                            end if;
                    end case;

                when 7b"0000011" => -- I-Format? More
                    v_RegisterWriteEnable := '1';
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
                           v_MemoryWidth := DOUBLE_TYPE;
                           if ENABLE_DEBUG then
                               report "ld" severity note;
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

                        -- NOTE: unoffical instruction for RV32I
                        when 3b"110" =>
                            -- lwu  - 110
                            v_IsSignExtend := '0';
                            v_MemoryWidth := WORD_TYPE;
                            if ENABLE_DEBUG then
                                report "lwu" severity note;
                            end if;

                        -- NOTE: unoffical instruction for RV64I
                        when 3b"111" =>
                           -- ldu  - 111
                           v_IsSignExtend := '0';
                           v_MemoryWidth := DOUBLE_TYPE;
                           if ENABLE_DEBUG then
                               report "ldu" severity note;
                           end if;

                        when others =>
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "Illegal I-Format (Alternate) Instruction" severity error;
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
                           v_MemoryWidth := DOUBLE_TYPE;
                           if ENABLE_DEBUG then
                               report "sd" severity note;
                           end if;

                        when others =>
                            v_Break := '1';
                            if ENABLE_DEBUG then
                                report "Illegal S-Format Instruction" severity error;
                            end if;

                    end case;

                when 7b"0110011" => -- R-format
                    v_RegisterWriteEnable := '1';
                    v_RegisterSource := RFSOURCE_FROMALU;
                    v_ALUSource := ALUSOURCE_REGISTER;

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
                                report "Illegal R-Format Instruction" severity error;
                            end if;
                            
                    end case;

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
                                report "Illegal B-Format Instruction" severity error;
                            end if;

                    end case;

                when 7b"0110111" => -- U-Format
                    -- lui   - rd = imm << 12
                    v_Immediate := s_extuImmediate;
                    v_RegisterSource := RFSOURCE_FROMIMMEDIATE;
                    v_ALUSource := ALUSOURCE_BIGIMMEDIATE;
                    v_RegisterWriteEnable := '1';
                    if ENABLE_DEBUG then
                        report "lui" severity note;
                    end if;

                when 7b"0010111" => -- U-Format
                    -- auipc - rd = pc + (imm << 12)
                    v_Immediate := s_extuImmediate;
                    v_RegisterSource := RFSOURCE_FROMALU;
                    v_ALUSource := ALUSOURCE_IMMEDIATE;
                    v_IPToALU := '1';
                    v_RegisterWriteEnable := '1';
                    if ENABLE_DEBUG then
                        report "auipc" severity note;
                    end if;

                when 7b"0001111" => -- fence
                    -- TODO: since this core is running scalar, in-order, and single-tasking, this can safely be left as a NOP
                    if ENABLE_DEBUG then
                        report "fence" severity note;
                    end if;

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
                        report "Illegal Instruction" severity error;
                    end if;

            end case;
        else
            v_IsBranch            := '0';
            v_Break               := '0';
            v_IsSignExtend        := '1'; -- default case is sign extension
            v_MemoryWriteEnable   := '0';
            v_RegisterWriteEnable := '0';
            v_RegisterSource      := RFSOURCE_FROMALU;
            v_ALUSource           := ALUSOURCE_REGISTER;
            v_ALUOperator         := ADD_OPERATOR;
            v_BranchOperator      := BEQ_TYPE;
            v_MemoryWidth         := WORD_TYPE;
            v_Immediate           := 32x"0";
            v_BranchMode          := BRANCHMODE_JAL_OR_BCC;
            v_IPToALU             := '0';
        end if;

        o_IsBranch            <= v_IsBranch;
        o_Break               <= v_Break;
        o_IsSignExtend        <= v_IsSignExtend;
        s_SignExtend          <= v_IsSignExtend;
        o_MemoryWriteEnable   <= v_MemoryWriteEnable;
        o_RegisterWriteEnable <= v_RegisterWriteEnable;
        o_RegisterSource      <= v_RegisterSource;
        o_ALUSource           <= v_ALUSource;
        o_ALUOperator         <= v_ALUOperator;
        o_BranchOperator      <= v_BranchOperator;
        o_MemoryWidth         <= v_MemoryWidth;
        o_Immediate           <= v_Immediate;
        o_BranchMode          <= v_BranchMode;
        o_IPToALU             <= v_IPToALU;

    end process;

end implementation;
