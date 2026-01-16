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
        i_DS1            : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        i_DS2            : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        i_BranchOperator : in  branch_operator_t;
        o_BranchTaken    : out std_logic;
        o_BranchNotTaken : out std_logic;
        o_Prediction     : out std_logic
    );
end branch_unit;

architecture implementation of branch_unit is

-- TODO: 128 sets x 2-way set associative branch target buffer
-- BTB should store the predicted target address and the branch type (branch_operator_t)

-- default LSB for branch addresses is half-word aligned (compressed instructions)
constant BRANCH_LSB : natural := 1;

constant BTB_SETS       : natural := 128;
constant BTB_WAYS       : natural := 2;
constant BTB_INDEX_BITS : natural := clog2(BTB_SETS);
constant BTB_INDEX_LSB  : natural := BRANCH_LSB;
constant BTB_INDEX_MSB  : natural := BTB_INDEX_LSB + BTB_INDEX_BITS;
constant BTB_TAG_LSB    : natural := BTB_INDEX_MSB + 1;
constant BTB_TAG_MSB    : natural := DATA_WIDTH - 1;
constant BTB_TAG_BITS   : natural := BTB_TAG_MSB - BTB_TAG_LSB + 1;

record btb_entry_t is
    signal IsValid        : std_logic;
    signal Tag            : std_logic_vector(BTB_TAG_BITS-1 downto 0);
    signal TargetAddress  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal BranchOperator : branch_operator_t;
end record;

-- PHT should be 256 entries, directly mapped
constant PHT_ENTRIES : natural := 256;
constant PHT_INDEX_BITS : natural := clog2(PHT_ENTRIES);
constant PHT_INDEX_LSB : natural := BRANCH_LSB;
constant PHT_INDEX_MSB : natural := PHT_INDEX_LSB + PHT_INDEX_BITS - 1;

begin 

    -- If branch not already in buffer, predict not taken for forward branches, taken for backward branches

    -----------------------------------------------------
    -- Pattern History Table
    -----------------------------------------------------

    g_PatternHistoryTable: for i in 0 to PHT_ENTRIES-1 generate
    
        -- 2-bit counter: 00 = strongly not taken, 01 = weakly not taken, 10 = weakly taken, 11 = strongly taken
        e_SaturatingCounter: entity work.saturating_counter
            generic map(
                N => 2
            )
            port map(
                i_Clock       => i_Clock,
                i_Enable      => '0',  -- TODO: enable when accessing branch buffer
                i_IsIncrement => '0',  -- TODO: set based on actual branch outcome
                o_Counter     => open
            );

    end generate g_PatternHistoryTable;

    -----------------------------------------------------


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
