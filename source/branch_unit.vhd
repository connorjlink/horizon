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
        i_DS1            : in  std_logic_vector(31 downto 0);
        i_DS2            : in  std_logic_vector(31 downto 0);
        i_BranchOperator : in  branch_operator_t;
        o_BranchTaken    : out std_logic;
        o_BranchNotTaken : out std_logic;
        o_Prediction     : out std_logic
    );
end branch_unit;

architecture implementation of branch_unit is

-- TODO: 256x2-way set associative branch buffer for branch prediction results
-- store Address(1) as offset (diffentiates C and non-C instructions)
-- store Address(9 downto 2) as index
-- store Address(31 downto 10) as tag
-- Prediction intermediate: saturating 2-bit counter per entry: 00 = strongly not taken, 01 = weakly not taken, 10 = weakly taken, 11 = strongly taken

begin 

    -- If branch not already in buffer, predict not taken for forward branches, taken for backward branches

    -----------------------------------------------------
    -- Branch Buffer Generation
    -----------------------------------------------------

    g_BranchBuffer: for i in 0 to 255 generate
    
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

    end generate g_BranchBuffer;

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
