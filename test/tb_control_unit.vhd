-- Horizon: tb_control_unit.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library std;
use std.env.all;
use std.textio.all;
library work;
use work.types.all;

entity tb_control_unit is
    generic(
        CLOCK_HALF_PERIOD  : time := 10 ns;
        DATA_WIDTH : integer := 32
    );
end tb_control_unit;

architecture implementation of tb_control_unit is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';
signal s_iThreadId      : std_logic := '0';

-- Stimulus signals
signal s_iInstruction                   : std_logic_vector(31 downto 0) := 32x"0";
signal s_oMemoryWriteEnable             : std_logic;
signal s_oRegisterFileWriteEnable       : std_logic;
signal s_oRegisterSource                : rf_source_t;
signal s_oALUSource                     : alu_source_t;
signal s_oALUOperator                   : alu_operator_t;
signal s_oBranchOperator                : branch_operator_t;
signal s_oMemoryWidth                   : data_width_t;
signal s_oBranchMode                    : branch_mode_t;
signal s_oRD                            : std_logic_vector(4 downto 0);
signal s_oRS1                           : std_logic_vector(4 downto 0);
signal s_oRS2                           : std_logic_vector(4 downto 0);
signal s_oImmediate                     : std_logic_vector(31 downto 0);
signal s_oBreak                         : std_logic;
signal s_oIsBranch                      : std_logic;
signal s_oIsStride4                     : std_logic;
signal s_oIsSignExtend                  : std_logic;
signal s_oIPToALU                       : std_logic;
signal s_oRS1ToMemoryAddress            : std_logic;
signal s_oPendingMemoryOperationsThread : std_logic_vector(THREAD_COUNT-1 downto 0);
signal s_oStallThread                   : std_logic_vector(THREAD_COUNT-1 downto 0);
signal s_oAtomicSequesterThread         : std_logic_vector(THREAD_COUNT-1 downto 0);
signal s_oAqStallPendingThread          : std_logic_vector(THREAD_COUNT-1 downto 0);

begin

    -- Design-under-test instantiation
    DUT: entity work.control_unit
        port map(
            i_Clock                         => s_Clock,
            i_Reset                         => s_Reset,
            i_Instruction                   => s_iInstruction,
            i_ThreadId                      => s_iThreadId,
            o_MemoryWriteEnable             => s_oMemoryWriteEnable,
            o_RegisterFileWriteEnable       => s_oRegisterFileWriteEnable,
            o_RegisterSource                => s_oRegisterSource,
            o_ALUSource                     => s_oALUSource,
            o_ALUOperator                   => s_oALUOperator,
            o_BranchOperator                => s_oBranchOperator,
            o_BranchMode                    => s_oBranchMode,
            o_MemoryWidth                   => s_oMemoryWidth,
            o_RD                            => s_oRD,
            o_RS1                           => s_oRS1,
            o_RS2                           => s_oRS2,
            o_Immediate                     => s_oImmediate,
            o_Break                         => s_oBreak,
            o_IsBranch                      => s_oIsBranch,
            o_IsStride4                     => s_oIsStride4,
            o_IsSignExtend                  => s_oIsSignExtend,
            o_IPToALU                       => s_oIPToALU,
            o_RS1ToMemoryAddress            => s_oRS1ToMemoryAddress,
            o_PendingMemoryOperationsThread => s_oPendingMemoryOperationsThread,
            o_StallThread                   => s_oStallThread,
            o_AtomicSequesterThread         => s_oAtomicSequesterThread,
            o_AqStallPendingThread          => s_oAqStallPendingThread
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


        -- addi x25, x0, 0
        s_iInstruction <= 32x"00000c93";
        wait for CLOCK_PERIOD;
        assert s_oMemoryWriteEnable = '0'
            and s_oRegisterFileWriteEnable = '1'
            and s_oRegisterSource = RFSOURCE_FROMALU
            and s_oALUSource = ALUSOURCE_IMMEDIATE
            and s_oALUOperator = ADD_OPERATOR
            -- NOTE: DON'T CARE: and s_oBranchOperator = 
            -- NOTE: DON'T CARE: and s_oBranchMode = 
            -- NOTE: DON'T CARE:and s_oMemoryWidth = BYTE_TYPE
            and s_oRD = b"11001" 
            and s_oRS1 = b"00000"
            and s_oRS2 = b"00000"
            and s_oImmediate = x"00000000"
            and s_oBreak = '0'
            and s_oIsBranch = '0'
            and s_oIsStride4 = '1'
            and s_oIsSignExtend = '1'
            and s_oIPToALU = '0'
            report "tb_control_unit: testcase 1 failed"
            severity error;

        -- addi x26, x0, 256
        s_iInstruction <= 32x"10000d13";
        wait for CLOCK_PERIOD;
        assert s_oMemoryWriteEnable = '0'
            and s_oRegisterFileWriteEnable = '1'
            and s_oRegisterSource = RFSOURCE_FROMALU
            and s_oALUSource = ALUSOURCE_IMMEDIATE
            and s_oALUOperator = ADD_OPERATOR
            -- NOTE: DON'T CARE: and s_oBranchOperator = 
            -- NOTE: DON'T CARE: and s_oBranchMode = 
            -- NOTE: DON'T CARE: and s_oMemoryWidth = BYTE_TYPE
            and s_oRD = b"11010" 
            and s_oRS1 = b"00000"
            and s_oRS2 = b"00000"
            and s_oImmediate = x"00000100"
            and s_oBreak = '0'
            and s_oIsBranch = '0'
            and s_oIsStride4 = '1'
            and s_oIsSignExtend = '1'
            and s_oIPToALU = '0'
            report "tb_control_unit: testcase 2 failed"
            severity error;

        -- lw x1, 0(x25)
        s_iInstruction <= 32x"000ca083";
        wait for CLOCK_PERIOD;
        assert s_oMemoryWriteEnable = '0'
            and s_oRegisterFileWriteEnable = '1'
            and s_oRegisterSource = RFSOURCE_FROMRAM
            and s_oALUSource = ALUSOURCE_IMMEDIATE
            and s_oALUOperator = ADD_OPERATOR
            -- NOTE: DON'T CARE: and s_oBranchOperator = 
            -- NOTE: DON'T CARE: and s_oBranchMode = 
            and s_oMemoryWidth = WORD_TYPE
            and s_oRD = b"00001" 
            and s_oRS1 = b"11001"
            and s_oRS2 = b"00000"
            and s_oImmediate = x"00000000"
            and s_oBreak = '0'
            and s_oIsBranch = '0'
            and s_oIsStride4 = '1'
            and s_oIsSignExtend = '1'
            and s_oIPToALU = '0'
            report "tb_control_unit: testcase 3 failed"
            severity error;

        -- lw x2, 4(x25)
        s_iInstruction <= 32x"004ca103";
        wait for CLOCK_PERIOD;
        assert s_oMemoryWriteEnable = '0'
            and s_oRegisterFileWriteEnable = '1'
            and s_oRegisterSource = RFSOURCE_FROMRAM
            and s_oALUSource = ALUSOURCE_IMMEDIATE
            and s_oALUOperator = ADD_OPERATOR
            -- NOTE: DON'T CARE: and s_oBranchOperator = 
            -- NOTE: DON'T CARE: and s_oBranchMode = 
            and s_oMemoryWidth = WORD_TYPE
            and s_oRD = b"00010" 
            and s_oRS1 = b"11001"
            -- NOTE: DON'T CARE: and s_oRS2 = 
            and s_oImmediate = x"00000004"
            and s_oBreak = '0'
            and s_oIsBranch = '0'
            and s_oIsStride4 = '1'
            and s_oIsSignExtend = '1'
            and s_oIPToALU = '0'
            report "tb_control_unit: testcase 4 failed"
            severity error;

        -- add x1, x1, x2
        s_iInstruction <= 32x"002080b3";
        wait for CLOCK_PERIOD;
        assert s_oMemoryWriteEnable = '0'
            and s_oRegisterFileWriteEnable = '1'
            and s_oRegisterSource = RFSOURCE_FROMALU
            and s_oALUSource = ALUSOURCE_REGISTER
            and s_oALUOperator = ADD_OPERATOR
            -- NOTE: DON'T CARE: and s_oBranchOperator = 
            -- NOTE: DON'T CARE: and s_oBranchMode = 
            -- NOTE: DON'T CARE: and s_oMemoryWidth = 
            and s_oRD = b"00001" 
            and s_oRS1 = b"00001"
            and s_oRS2 = b"00010"
            and s_oBreak = '0'
            and s_oIsBranch = '0'
            and s_oIsStride4 = '1'
            and s_oIsSignExtend = '1'
            and s_oIPToALU = '0'
            report "tb_control_unit: testcase 5 failed"
            severity error;

        -- sw x1, 0(x26)
        s_iInstruction <= 32x"001d2023";
        wait for CLOCK_PERIOD;
        assert s_oMemoryWriteEnable = '1'
            and s_oRegisterFileWriteEnable = '0'
            -- NOTE: DON'T CARE:and s_oRegisterSource = 
            and s_oALUSource = ALUSOURCE_IMMEDIATE
            and s_oALUOperator = ADD_OPERATOR
            -- NOTE: DON'T CARE: and s_oBranchOperator = 
            -- NOTE: DON'T CARE: and s_oBranchMode = 
            and s_oMemoryWidth = WORD_TYPE
            -- NOTE: DON'T CARE: and s_oRD = 
            and s_oRS1 = b"11010"
            and s_oRS2 = b"00001"
            and s_oImmediate = x"00000000"
            and s_oBreak = '0'
            and s_oIsBranch = '0'
            and s_oIsStride4 = '1'
            and s_oIsSignExtend = '1'
            and s_oIPToALU = '0'
            report "tb_control_unit: testcase 6 failed"
            severity error;
        
        -- sb x0, 255(x26)
        s_iInstruction <= 32x"0e0d0fa3";
        wait for CLOCK_PERIOD;
        assert s_oMemoryWriteEnable = '1'
            and s_oRegisterFileWriteEnable = '0'
            -- NOTE: DON'T CARE: and s_oRegisterSource = 
            and s_oALUSource = ALUSOURCE_IMMEDIATE
            and s_oALUOperator = ADD_OPERATOR
            -- NOTE: DON'T CARE: and s_oBranchOperator = 
            -- NOTE: DON'T CARE: and s_oBranchMode = 
            and s_oMemoryWidth = BYTE_TYPE
            -- NOTE: DON'T CARE: and s_oRD = 
            and s_oRS1 = b"11010"
            and s_oRS2 = b"00000"
            and s_oImmediate = x"000000ff"
            and s_oBreak = '0'
            and s_oIsBranch = '0'
            and s_oIsStride4 = '1'
            and s_oIsSignExtend = '1'
            and s_oIPToALU = '0'
            report "tb_control_unit: testcase 7 failed"
            severity error;

        finish;

    end process;

end implementation;
