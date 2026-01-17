-- Horizon: tb_branch_unit.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library std;
use std.env.all;
use std.textio.all;
library work;
use work.types.all;

entity tb_branch_unit is
    generic(
        CLOCK_HALF_PERIOD : time    := 10 ns;
        DATA_WIDTH        : integer := 32
    );
end tb_branch_unit;

architecture implementation of tb_branch_unit is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';

-- Stimulus signals
signal s_iDS1            : std_logic_vector(31 downto 0) := 32x"0";
signal s_iDS2            : std_logic_vector(31 downto 0) := 32x"0";
signal s_iBranchOperator : branch_operator_t := BEQ_TYPE;
signal s_oBranchTaken    : std_logic;
signal s_oBranchNotTaken : std_logic;

-- Predictor interface signals
signal s_iLookupEnable : std_logic := '0';
signal s_iLookupIP     : std_logic_vector(31 downto 0) := (others => '0');
signal s_iLookupInstruction : std_logic_vector(31 downto 0) := (others => '0');
signal s_oPrediction   : std_logic;
signal s_oBTBIsHit     : std_logic;
signal s_oPredictedTarget   : std_logic_vector(31 downto 0);
signal s_oPredictedOperator : branch_operator_t;

-- RAS / return prediction
signal s_oIsReturnPrediction : std_logic;
signal s_oRASPointer         : std_logic_vector(RAS_POINTER_BITS-1 downto 0);
signal s_oRASCount           : std_logic_vector(RAS_COUNT_BITS-1 downto 0);

signal s_iSpeculateEnable      : std_logic := '0';
signal s_iSpeculateIP          : std_logic_vector(31 downto 0) := (others => '0');
signal s_iSpeculateInstruction : std_logic_vector(31 downto 0) := (others => '0');

signal s_iRASRestoreEnable  : std_logic := '0';
signal s_iRASRestorePointer : std_logic_vector(RAS_POINTER_BITS-1 downto 0) := (others => '0');
signal s_iRASRestoreCount   : std_logic_vector(RAS_COUNT_BITS-1 downto 0) := (others => '0');

signal s_iUpdateEnable   : std_logic := '0';
signal s_iUpdateIP       : std_logic_vector(31 downto 0) := (others => '0');
signal s_iUpdateTarget   : std_logic_vector(31 downto 0) := (others => '0');
signal s_iUpdateTaken    : std_logic := '0';
signal s_iUpdateOperator : branch_operator_t := BRANCH_NONE;
signal s_iUpdateInstruction      : std_logic_vector(31 downto 0) := (others => '0');
signal s_iUpdateIsPredictionUsed : std_logic := '0';

begin

    -- Design-under-test instantiation
    DUT: entity work.branch_unit
        port map(
            i_Clock             => s_Clock,
            i_Reset             => s_Reset,
            i_DS1               => s_iDS1,
            i_DS2               => s_iDS2,
            i_BranchOperator    => s_iBranchOperator,
            i_LookupEnable      => s_iLookupEnable,
            i_LookupIP          => s_iLookupIP,
            i_LookupInstruction => s_iLookupInstruction,

            o_IsReturnPrediction => s_oIsReturnPrediction,
            o_RASPointer         => s_oRASPointer,
            o_RASCount           => s_oRASCount,

            i_SpeculateEnable      => s_iSpeculateEnable,
            i_SpeculateIP          => s_iSpeculateIP,
            i_SpeculateInstruction => s_iSpeculateInstruction,

            i_RASRestoreEnable  => s_iRASRestoreEnable,
            i_RASRestorePointer => s_iRASRestorePointer,
            i_RASRestoreCount   => s_iRASRestoreCount,

            i_UpdateEnable      => s_iUpdateEnable,
            i_UpdateIP          => s_iUpdateIP,
            i_UpdateTarget      => s_iUpdateTarget,
            i_UpdateTaken       => s_iUpdateTaken,
            i_UpdateOperator    => s_iUpdateOperator,
            i_UpdateInstruction      => s_iUpdateInstruction,
            i_UpdateIsPredictionUsed => s_iUpdateIsPredictionUsed,
            o_BranchTaken       => s_oBranchTaken,
            o_BranchNotTaken    => s_oBranchNotTaken,
            o_BTBIsHit          => s_oBTBIsHit,
            o_Prediction        => s_oPrediction,
            o_PredictedTarget   => s_oPredictedTarget,
            o_PredictedOperator => s_oPredictedOperator
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

        procedure DoLookup(
            constant IP           : in  std_logic_vector(31 downto 0);
            variable o_IsHit      : out std_logic;
            variable o_Prediction : out std_logic;
            variable o_Target     : out std_logic_vector(31 downto 0);
            variable o_Operator   : out branch_operator_t
        ) is
        begin
            wait until falling_edge(s_Clock);

            s_iLookupEnable <= '1';
            s_iLookupIP     <= IP;
                -- Delta-cycle settling:
                --   1) input signals update
                --   2) DUT lookup process updates internal signals
                --   3) concurrent assigns propagate to outputs
                wait for 0 ns;
                wait for 0 ns;
                wait for 0 ns;

            o_IsHit      := s_oBTBIsHit;
            o_Prediction := s_oPrediction;
            o_Target     := s_oPredictedTarget;
            o_Operator   := s_oPredictedOperator;

            s_iLookupEnable <= '0';
            wait for 0 ns;
        end procedure;

        procedure DoLookupInstruction(
            constant IP           : in  std_logic_vector(31 downto 0);
            constant Instruction  : in  std_logic_vector(31 downto 0);
            variable o_IsHit      : out std_logic;
            variable o_Prediction : out std_logic;
            variable o_Target     : out std_logic_vector(31 downto 0);
            variable o_Operator   : out branch_operator_t;
            variable o_IsReturn   : out std_logic
        ) is
        begin
            wait until falling_edge(s_Clock);

            s_iLookupEnable      <= '1';
            s_iLookupIP          <= IP;
            s_iLookupInstruction <= Instruction;
                wait for 0 ns;
                wait for 0 ns;
                wait for 0 ns;

            o_IsHit      := s_oBTBIsHit;
            o_Prediction := s_oPrediction;
            o_Target     := s_oPredictedTarget;
            o_Operator   := s_oPredictedOperator;
            o_IsReturn   := s_oIsReturnPrediction;

            s_iLookupEnable      <= '0';
            s_iLookupInstruction <= (others => '0');
            wait for 0 ns;
        end procedure;

        procedure DoUpdate(
            constant IP       : in  std_logic_vector(31 downto 0);
            constant Target   : in  std_logic_vector(31 downto 0);
            constant IsTaken  : in  std_logic;
            constant Operator : in  branch_operator_t
        ) is
        begin
            wait until falling_edge(s_Clock);

            s_iUpdateEnable   <= '1';
            s_iUpdateIP       <= IP;
            s_iUpdateTarget   <= Target;
            s_iUpdateTaken    <= IsTaken;
            s_iUpdateOperator <= Operator;
            s_iUpdateInstruction      <= (others => '0');
            s_iUpdateIsPredictionUsed <= '0';

            wait until rising_edge(s_Clock);
            wait for 0 ns;
            wait for 0 ns;
            wait for 0 ns;

            s_iUpdateEnable   <= '0';
            s_iUpdateOperator <= BRANCH_NONE;
            s_iUpdateTaken    <= '0';
            s_iUpdateInstruction      <= (others => '0');
            s_iUpdateIsPredictionUsed <= '0';
            wait for 0 ns;
            
        end procedure;

        procedure DoSpeculate(
            constant IP          : in std_logic_vector(31 downto 0);
            constant Instruction : in std_logic_vector(31 downto 0)
        ) is
        begin
            wait until falling_edge(s_Clock);
            s_iSpeculateEnable      <= '1';
            s_iSpeculateIP          <= IP;
            s_iSpeculateInstruction <= Instruction;

            wait until rising_edge(s_Clock);
            wait for 0 ns;
            wait for 0 ns;
            wait for 0 ns;

            s_iSpeculateEnable      <= '0';
            s_iSpeculateIP          <= (others => '0');
            s_iSpeculateInstruction <= (others => '0');
            wait for 0 ns;
        end procedure;

        procedure DoRestore(
            constant Pointer : in std_logic_vector(RAS_POINTER_BITS-1 downto 0);
            constant Count   : in std_logic_vector(RAS_COUNT_BITS-1 downto 0)
        ) is
        begin
            wait until falling_edge(s_Clock);
            s_iRASRestoreEnable  <= '1';
            s_iRASRestorePointer <= Pointer;
            s_iRASRestoreCount   <= Count;

            wait until rising_edge(s_Clock);
            wait for 0 ns;
            wait for 0 ns;
            wait for 0 ns;

            s_iRASRestoreEnable  <= '0';
            s_iRASRestorePointer <= (others => '0');
            s_iRASRestoreCount   <= (others => '0');
            wait for 0 ns;
        end procedure;

        constant IP0     : std_logic_vector(31 downto 0) := 32x"00000100";
        constant IP1     : std_logic_vector(31 downto 0) := 32x"00010100";
        constant IP2     : std_logic_vector(31 downto 0) := 32x"00020100";
        constant IPU     : std_logic_vector(31 downto 0) := 32x"00000200";
        constant TARGET0 : std_logic_vector(31 downto 0) := 32x"00001000";
        constant TARGET1 : std_logic_vector(31 downto 0) := 32x"00001010";
        constant TARGET2 : std_logic_vector(31 downto 0) := 32x"00001020";
        constant TARGETU : std_logic_vector(31 downto 0) := 32x"00002000";

        -- scratch variables for DoLookup sampling
        variable v_IsHit      : std_logic;
        variable v_Prediction : std_logic;
        variable v_Target     : std_logic_vector(31 downto 0);
        variable v_Operator   : branch_operator_t;
        variable v_IsReturn   : std_logic;

        variable v_PointerCheckpoint : std_logic_vector(RAS_POINTER_BITS-1 downto 0);
        variable v_CountCheckpoint   : std_logic_vector(RAS_COUNT_BITS-1 downto 0);

        constant INSTR_JAL_X1_0 : std_logic_vector(31 downto 0) := 32x"000000EF"; -- jal x1, 0
        constant INSTR_RET      : std_logic_vector(31 downto 0) := 32x"00008067"; -- jalr x0, x1, 0

    begin
        -- Await reset and stabilization; trigger off-edge
        wait for CLOCK_HALF_PERIOD;
        wait for CLOCK_HALF_PERIOD / 2;

        -----------------------------------------------------
        -- Branch comparison testcases
        -----------------------------------------------------

        s_iDS1 <= 32x"7";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BEQ_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '0' and s_oBranchNotTaken = '1')
            report "tb_branch_unit: testcase 1 failed (expected BranchTaken=0, BranchNotTaken=1)"
            severity error;

        s_iDS1 <= 32x"5";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BEQ_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 2 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"7";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BNE_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 3 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"5";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BNE_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '0' and s_oBranchNotTaken = '1')
            report "tb_branch_unit: testcase 4 failed (expected BranchTaken=0, BranchNotTaken=1)"
            severity error;

        s_iDS1 <= 32x"7";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BLT_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '0' and s_oBranchNotTaken = '1')
            report "tb_branch_unit: testcase 5 failed (expected BranchTaken=0, BranchNotTaken=1)"
            severity error;

        s_iDS1 <= 32x"4";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BLT_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 6 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"7";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BGE_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 7 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"5";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BGE_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 8 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"7";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BLTU_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '0' and s_oBranchNotTaken = '1')
            report "tb_branch_unit: testcase 9 failed (expected BranchTaken=0, BranchNotTaken=1)"
            severity error;

        s_iDS1 <= 32x"4";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BLTU_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 10 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"7";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BGEU_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 11 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"5";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= BGEU_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 12 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"7";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= JAL_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 13 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;

        s_iDS1 <= 32x"5";
        s_iDS2 <= 32x"5";
        s_iBranchOperator <= JALR_TYPE;
        wait for CLOCK_PERIOD;
        assert (s_oBranchTaken = '1' and s_oBranchNotTaken = '0')
            report "tb_branch_unit: testcase 14 failed (expected BranchTaken=1, BranchNotTaken=0)"
            severity error;


        -----------------------------------------------------
        -- Predictor testcases (BTB + PHT)
        -----------------------------------------------------

        -- cold lookup: BTB miss => hit=0, prediction forced 0
        DoLookup(IP0, v_IsHit, v_Prediction, v_Target, v_Operator);
        assert (v_IsHit = '0' and v_Prediction = '0')
            report "tb_branch_unit: testcase 15 failed (expected cold BTB miss and Prediction=0)"
            severity error;

        -- insert a conditional branch into BTB (PHT starts at 00 => predict not taken)
        DoUpdate(IP0, TARGET0, '0', BEQ_TYPE);
        DoLookup(IP0, v_IsHit, v_Prediction, v_Target, v_Operator);
        assert (v_IsHit = '1' and v_Target = TARGET0 and v_Operator = BEQ_TYPE and v_Prediction = '0')
            report "tb_branch_unit: testcase 16 failed (expected BTB hit, correct target/op, Prediction=0)"
            severity error;

        -- train taken once: 00 -> 01, still predict not taken
        DoUpdate(IP0, TARGET0, '1', BEQ_TYPE);
        DoLookup(IP0, v_IsHit, v_Prediction, v_Target, v_Operator);
        assert (v_Prediction = '0')
            report "tb_branch_unit: testcase 17 failed (expected Prediction=0 after 1 taken update)"
            severity error;

        -- train taken again: 01 -> 10, now predict taken (MSB=1)
        DoUpdate(IP0, TARGET0, '1', BEQ_TYPE);
        DoLookup(IP0, v_IsHit, v_Prediction, v_Target, v_Operator);
        assert (v_Prediction = '1')
            report "tb_branch_unit: testcase 18 failed (expected Prediction=1 after 2 taken updates)"
            severity error;

        -- train not-taken: 10 -> 01, predict not taken again
        DoUpdate(IP0, TARGET0, '0', BEQ_TYPE);
        DoLookup(IP0, v_IsHit, v_Prediction, v_Target, v_Operator);
        assert (v_Prediction = '0')
            report "tb_branch_unit: testcase 19 failed (expected Prediction=0 after not-taken update)"
            severity error;

        -- unconditional branch predicts taken regardless of PHT
        DoUpdate(IPU, TARGETU, '0', JAL_TYPE);
        DoLookup(IPU, v_IsHit, v_Prediction, v_Target, v_Operator);
        assert (v_IsHit = '1' and v_Target = TARGETU and v_Operator = JAL_TYPE and v_Prediction = '1')
            report "tb_branch_unit: testcase 20 failed (expected unconditional Prediction=1)"
            severity error;

        -- 2-way replacement check (same set index, different tags)
        -- insert IP1 and IP2 without intermediate lookups to keep replacement deterministic.
        DoUpdate(IP1, TARGET1, '0', BNE_TYPE);
        DoUpdate(IP2, TARGET2, '0', BLT_TYPE);

        -- under pseudo-LRU policy, IP0 should be evicted from this set.
        DoLookup(IP0, v_IsHit, v_Prediction, v_Target, v_Operator);
        assert (v_IsHit = '0')
            report "tb_branch_unit: testcase 21 failed (expected IP0 BTB miss due to replacement)"
            severity error;

        DoLookup(IP1, v_IsHit, v_Prediction, v_Target, v_Operator);
        assert (v_IsHit = '1' and v_Target = TARGET1 and v_Operator = BNE_TYPE)
            report "tb_branch_unit: testcase 22 failed (expected IP1 BTB hit with correct metadata)"
            severity error;

        DoLookup(IP2, v_IsHit, v_Prediction, v_Target, v_Operator);
        assert (v_IsHit = '1' and v_Target = TARGET2 and v_Operator = BLT_TYPE)
            report "tb_branch_unit: testcase 23 failed (expected IP2 BTB hit with correct metadata)"
            severity error;


        -----------------------------------------------------
        -- RAS testcases (call/ret tracking)
        -----------------------------------------------------

        -- after reset, RAS should be empty
        assert (unsigned(s_oRASCount) = 0)
            report "tb_branch_unit: testcase 24 failed (expected RAS empty after reset)"
            severity error;

        -- push a return address via speculative CALL
        DoSpeculate(32x"00003000", INSTR_JAL_X1_0);
        assert (unsigned(s_oRASCount) = 1)
            report "tb_branch_unit: testcase 25 failed (expected RAS count=1 after CALL speculate push)"
            severity error;

        -- RET should predict from RAS top: target = call_ip + 4
        DoLookupInstruction(32x"00004000", INSTR_RET, v_IsHit, v_Prediction, v_Target, v_Operator, v_IsReturn);
        assert (v_IsReturn = '1' and v_Prediction = '1' and v_Target = 32x"00003004")
            report "tb_branch_unit: testcase 26 failed (expected RAS-based return prediction to call_ip+4)"
            severity error;

        -- pop on speculative RET
        DoSpeculate(32x"00004000", INSTR_RET);
        assert (unsigned(s_oRASCount) = 0)
            report "tb_branch_unit: testcase 27 failed (expected RAS count=0 after RET speculate pop)"
            severity error;

        -- restore/rollback: push two calls, then restore checkpoint to before second
        DoSpeculate(32x"00005000", INSTR_JAL_X1_0);
        v_PointerCheckpoint := s_oRASPointer;
        v_CountCheckpoint := s_oRASCount;
        DoSpeculate(32x"00006000", INSTR_JAL_X1_0);
        assert (unsigned(s_oRASCount) = 2)
            report "tb_branch_unit: testcase 28 failed (expected RAS count=2 after two CALL pushes)"
            severity error;

        DoRestore(v_PointerCheckpoint, v_CountCheckpoint);
        assert (unsigned(s_oRASCount) = 1)
            report "tb_branch_unit: testcase 29 failed (expected RAS rollback to count=1)"
            severity error;

        DoLookupInstruction(32x"00007000", INSTR_RET, v_IsHit, v_Prediction, v_Target, v_Operator, v_IsReturn);
        assert (v_IsReturn = '1' and v_Prediction = '1' and v_Target = 32x"00005004")
            report "tb_branch_unit: testcase 30 failed (expected RET target to match older call after rollback)"
            severity error;

        finish;
        
    end process;

end implementation;
