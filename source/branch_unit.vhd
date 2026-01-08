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
        o_BranchNotTaken : out std_logic
        -- TODO: prediction results here
    );
end branch_unit;

architecture implementation of branch_unit is
begin 

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

        -- TODO: predict conditional forward branch not taken (used for `if` conditions), backward branch taken (used for loops) -- should save about .5 cycles per branch I estimate

        o_BranchTaken    <= v_BranchTaken;
        o_BranchNotTaken <= v_BranchNotTaken;

    end process;
    
end implementation;
