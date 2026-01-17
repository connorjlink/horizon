-- Horizon: branch_unit.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity branch_unit is
    port(
        i_Clock          : in  std_logic;

        -- branch decision inputs
        i_DS1               : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        i_DS2               : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        i_BranchOperator    : in  branch_operator_t;
        o_BranchTaken       : out std_logic;
        o_BranchNotTaken    : out std_logic;

        -- lookup interface
        i_LookupEnable      : in  std_logic := '0';
        i_LookupIP          : in  std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
        i_LookupInstruction : in  std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
        o_Prediction        : out std_logic;
        o_BTBIsHit          : out std_logic;
        o_PredictedTarget   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        o_PredictedOperator : out branch_operator_t;

        -- update interface
        i_UpdateEnable      : in  std_logic := '0';
        i_UpdateIP          : in  std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
        i_UpdateTarget      : in  std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
        i_UpdateTaken       : in  std_logic := '0';
        i_UpdateOperator    : in  branch_operator_t := BRANCH_NONE
    );
end branch_unit;

architecture implementation of branch_unit is

-- default LSB for branch addresses is half-word aligned (compressed instructions)
constant BRANCH_LSB : natural := 1;

-- 128 sets x 2-way set associative branch target buffer
constant BTB_SETS       : natural := 128;
constant BTB_WAYS       : natural := 2;
constant BTB_INDEX_BITS : natural := clog2(BTB_SETS);
constant BTB_INDEX_LSB  : natural := BRANCH_LSB;
constant BTB_INDEX_MSB  : natural := BTB_INDEX_LSB + BTB_INDEX_BITS - 1;
constant BTB_TAG_LSB    : natural := BTB_INDEX_MSB + 1;
constant BTB_TAG_MSB    : natural := DATA_WIDTH - 1;
constant BTB_TAG_BITS   : natural := BTB_TAG_MSB - BTB_TAG_LSB + 1;

type btb_entry_t is record
    IsValid        : std_logic;
    Tag            : std_logic_vector(BTB_TAG_BITS-1 downto 0);
    TargetAddress  : std_logic_vector(DATA_WIDTH-1 downto 0);
    BranchOperator : branch_operator_t;
end record;

type btb_way_array_t is array (0 to BTB_WAYS-1) of btb_entry_t;
type btb_set_array_t is array (0 to BTB_SETS-1) of btb_way_array_t;
signal s_BTB : btb_set_array_t := (others => (others => (
    IsValid        => '0',
    Tag            => (others => '0'),
    TargetAddress  => (others => '0'),
    BranchOperator => BRANCH_NONE
)));

-- pseudo-LRU replacement way selection with 1 bit per set
type btb_lru_t is array (0 to BTB_SETS-1) of std_logic;
signal s_BTBReplaceWay : btb_lru_t := (others => '0');


-- PHT is 256 entries, directly mapped
constant PHT_ENTRIES : natural := 256;
constant PHT_INDEX_BITS : natural := clog2(PHT_ENTRIES);
constant PHT_INDEX_LSB : natural := BRANCH_LSB;
constant PHT_INDEX_MSB : natural := PHT_INDEX_LSB + PHT_INDEX_BITS - 1;

subtype pht_counter_t is std_logic_vector(1 downto 0);
type pht_array_t is array (0 to PHT_ENTRIES-1) of pht_counter_t;
signal s_PHT : pht_array_t := (others => (others => '0'));

signal s_PHTUpdateEnable : std_logic := '0';
signal s_PHTUpdateIndex  : natural range 0 to PHT_ENTRIES-1 := 0;

signal s_LookupIsHit      : std_logic := '0';
signal s_LookupWay        : integer range 0 to BTB_WAYS-1 := 0;
signal s_LookupOperator   : branch_operator_t := BRANCH_NONE;
signal s_LookupTarget     : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
signal s_LookupPrediction : std_logic := '0';

signal s_PredecoderBranchOperator : branch_operator_t := BRANCH_NONE;

begin 

    -----------------------------------------------------
    -- Instruction Flow
    -----------------------------------------------------

    e_InstructionPredecoder : entity work.instruction_predecoder
        port map(
            i_Instruction    => i_LookupInstruction,
            o_BranchOperator => s_PredecoderBranchOperator
        );

    -----------------------------------------------------

    -----------------------------------------------------
    -- Pattern History Table (storage)
    -----------------------------------------------------

    s_PHTUpdateEnable <= '1' when (i_UpdateEnable = '1' and IsConditionalBranch(i_UpdateOperator)) else '0';
    s_PHTUpdateIndex  <= to_integer(unsigned(i_UpdateIP(PHT_INDEX_MSB downto PHT_INDEX_LSB)));

    g_PatternHistoryTable: for i in 0 to PHT_ENTRIES-1 generate
        signal s_Enable_i : std_logic;
    begin

        s_Enable_i <= '1' when (s_PHTUpdateEnable = '1' and s_PHTUpdateIndex = i) else '0';

        e_SaturatingCounter: entity work.saturating_counter
            generic map(
                N => 2
            )
            port map(
                i_Clock       => i_Clock,
                i_Enable      => s_Enable_i,
                i_IsIncrement => i_UpdateTaken,
                o_Counter     => s_PHT(i)
            );

    end generate g_PatternHistoryTable;

    -----------------------------------------------------
    -- BTB & PHT lookup
    -----------------------------------------------------

    process(
        all
    )
        variable v_BTBSetIndex    : natural range 0 to BTB_SETS-1;
        variable v_BTBTag         : std_logic_vector(BTB_TAG_BITS-1 downto 0);
        variable v_BTBIsHit       : std_logic;
        variable v_BTBHitWay      : integer range 0 to BTB_WAYS-1;
        variable v_BranchOperator : branch_operator_t;
        variable v_BranchTarget   : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable v_PHTIndex       : natural range 0 to PHT_ENTRIES-1;
        variable v_Counter        : pht_counter_t;
        variable v_PredictedTaken : std_logic;
    begin
        v_BTBSetIndex := to_integer(unsigned(i_LookupIP(BTB_INDEX_MSB downto BTB_INDEX_LSB)));
        v_BTBTag      := i_LookupIP(BTB_TAG_MSB downto BTB_TAG_LSB);
        v_PHTIndex    := to_integer(unsigned(i_LookupIP(PHT_INDEX_MSB downto PHT_INDEX_LSB)));
        v_Counter     := s_PHT(v_PHTIndex);

        v_BTBIsHit       := '0';
        v_BTBHitWay      := 0;
        v_BranchOperator := BRANCH_NONE;
        v_BranchTarget   := (others => '0');

        for i in 0 to BTB_WAYS-1 loop

            if s_BTB(v_BTBSetIndex)(i).IsValid = '1' and s_BTB(v_BTBSetIndex)(i).Tag = v_BTBTag then
                v_BTBIsHit       := '1';
                v_BTBHitWay      := i;
                v_BranchOperator := s_BTB(v_BTBSetIndex)(i).BranchOperator;
                v_BranchTarget   := s_BTB(v_BTBSetIndex)(i).TargetAddress;
            end if;

        end loop;

        if i_LookupEnable = '1' and v_BTBIsHit = '1' then

            if IsUnconditionalBranch(v_BranchOperator) then
                v_PredictedTaken := '1';
            elsif IsConditionalBranch(v_BranchOperator) then
                v_PredictedTaken := v_Counter(1);
            else
                v_PredictedTaken := '0';
            end if;

        else
            -- no hit; can predict taken only for unconditional branches
            if IsUnconditionalBranch(s_PredecoderBranchOperator) then
                v_PredictedTaken := '1';
            else
                v_PredictedTaken := '0';
            end if;

        end if;

        s_LookupIsHit      <= v_BTBIsHit when i_LookupEnable = '1' else '0';
        s_LookupWay        <= v_BTBHitWay;
        s_LookupOperator   <= v_BranchOperator;
        s_LookupTarget     <= v_BranchTarget;
        s_LookupPrediction <= v_PredictedTaken;

    end process;

    o_BTBIsHit          <= s_LookupIsHit;
    o_PredictedTarget   <= s_LookupTarget;
    o_PredictedOperator <= s_LookupOperator;
    o_Prediction        <= s_LookupPrediction;

    -----------------------------------------------------
    -- BTB & PHT update
    -----------------------------------------------------

    process(
        i_Clock
    )
        variable v_BTBSetIndex : natural range 0 to BTB_SETS-1;
        variable v_BTBTag      : std_logic_vector(BTB_TAG_BITS-1 downto 0);
        variable v_PHTIndex    : natural range 0 to PHT_ENTRIES-1;
        variable v_BTBIsHit    : boolean;
        variable v_Way         : integer range 0 to BTB_WAYS-1;
        variable v_Victim      : integer range 0 to BTB_WAYS-1;
    begin

        if rising_edge(i_Clock) then

            if i_LookupEnable = '1' and s_LookupIsHit = '1' then

                v_BTBSetIndex := to_integer(unsigned(i_LookupIP(BTB_INDEX_MSB downto BTB_INDEX_LSB)));

                if s_LookupWay = 0 then
                    s_BTBReplaceWay(v_BTBSetIndex) <= '1';
                else
                    s_BTBReplaceWay(v_BTBSetIndex) <= '0';
                end if;

            end if;

            if i_UpdateEnable = '1' and i_UpdateOperator /= BRANCH_NONE then
                v_BTBSetIndex := to_integer(unsigned(i_UpdateIP(BTB_INDEX_MSB downto BTB_INDEX_LSB)));
                v_BTBTag      := i_UpdateIP(BTB_TAG_MSB downto BTB_TAG_LSB);

                v_BTBIsHit := false;
                v_Way := 0;
                for i in 0 to BTB_WAYS-1 loop

                    if s_BTB(v_BTBSetIndex)(i).IsValid = '1' and s_BTB(v_BTBSetIndex)(i).Tag = v_BTBTag then
                        v_BTBIsHit := true;
                        v_Way := i;
                    end if;

                end loop;

                if v_BTBIsHit then

                    s_BTB(v_BTBSetIndex)(v_Way).IsValid        <= '1';
                    s_BTB(v_BTBSetIndex)(v_Way).Tag            <= v_BTBTag;
                    s_BTB(v_BTBSetIndex)(v_Way).TargetAddress  <= i_UpdateTarget;
                    s_BTB(v_BTBSetIndex)(v_Way).BranchOperator <= i_UpdateOperator;

                    if v_Way = 0 then
                        s_BTBReplaceWay(v_BTBSetIndex) <= '1';
                    else
                        s_BTBReplaceWay(v_BTBSetIndex) <= '0';
                    end if;

                else
                    -- invalid way or use replacement bit
                    if s_BTB(v_BTBSetIndex)(0).IsValid = '0' then
                        v_Victim := 0;
                    elsif s_BTB(v_BTBSetIndex)(1).IsValid = '0' then
                        v_Victim := 1;
                    else
                        v_Victim := 0;
                        if s_BTBReplaceWay(v_BTBSetIndex) = '1' then
                            v_Victim := 1;
                        end if;

                    end if;

                    s_BTB(v_BTBSetIndex)(v_Victim).IsValid        <= '1';
                    s_BTB(v_BTBSetIndex)(v_Victim).Tag            <= v_BTBTag;
                    s_BTB(v_BTBSetIndex)(v_Victim).TargetAddress  <= i_UpdateTarget;
                    s_BTB(v_BTBSetIndex)(v_Victim).BranchOperator <= i_UpdateOperator;

                    if v_Victim = 0 then
                        s_BTBReplaceWay(v_BTBSetIndex) <= '1';
                    else
                        s_BTBReplaceWay(v_BTBSetIndex) <= '0';
                    end if;

                end if;

            end if;

        end if;

    end process;


    -----------------------------------------------------
    -- Branch Decision Logic
    -----------------------------------------------------

    process(
        all
    )
        variable v_BranchTaken    : std_logic := '0';
        variable v_BranchNotTaken : std_logic := '0';

    begin

        v_BranchTaken    := '0';
        v_BranchNotTaken := '0';

        case i_BranchOperator is
            when BEQ_TYPE =>
                if unsigned(i_DS1) = unsigned(i_DS2) then
                    v_BranchTaken := '1';
                else
                    v_BranchNotTaken := '1';
                end if;

            when BNE_TYPE =>
                if unsigned(i_DS1) /= unsigned(i_DS2) then
                    v_BranchTaken := '1';
                else
                    v_BranchNotTaken := '1';
                end if;

            when BLT_TYPE =>
                if signed(i_DS1) < signed(i_DS2) then
                    v_BranchTaken := '1';
                else
                    v_BranchNotTaken := '1';
                end if;

            when BGE_TYPE =>
                if signed(i_DS1) >= signed(i_DS2) then
                    v_BranchTaken := '1';
                else
                    v_BranchNotTaken := '1';
                end if;

            when BLTU_TYPE =>
                if unsigned(i_DS1) < unsigned(i_DS2) then
                    v_BranchTaken := '1';
                else
                    v_BranchNotTaken := '1';
                end if;

            when BGEU_TYPE =>
                if unsigned(i_DS1) >= unsigned(i_DS2) then
                    v_BranchTaken := '1';
                else
                    v_BranchNotTaken := '1';
                end if;

            when JAL_TYPE =>
                v_BranchTaken := '1';

            when JALR_TYPE =>
                v_BranchTaken := '1';

            when others =>

        end case;

        o_BranchTaken    <= v_BranchTaken;
        o_BranchNotTaken <= v_BranchNotTaken;

    end process;

    -----------------------------------------------------
    
end implementation;
