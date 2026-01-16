-- Horizon: instruction_predecoder.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity instruction_predecoder is
    port(
        i_Instruction    : in  std_logic_vector(31 downto 0);
        o_BranchOperator : out branch_operator_t;
    );
end instruction_predecoder;

architecture implementation of instruction_predecoder is
begin

    process(
        i_Instruction
    )

        variable v_IsCompressed : boolean := false;

    begin

        o_BranchOperator <= BRANCH_NONE;

        v_IsCompressed := IsCompressedInstruction(i_Instruction);

        if v_IsCompressed then


        else

            -- Opcode bits [6:0]
            case i_Instruction(6 downto 0) is

                when "1100011" =>

                    -- Func3 bits [14:12]
                    case i_Instruction(14 downto 12) is

                        when "000" =>
                            o_BranchOperator <= BEQ_TYPE;

                        when "001" =>
                            o_BranchOperator <= BNE_TYPE;

                        when "100" =>
                            o_BranchOperator <= BLT_TYPE;

                        when "101" =>
                            o_BranchOperator <= BGE_TYPE;

                        when "110" =>
                            o_BranchOperator <= BLTU_TYPE;

                        when "111" =>
                            o_BranchOperator <= BGEU_TYPE;

                        when others =>
                            o_BranchOperator <= BRANCH_NONE;

                    end case;

                when "1101111" =>
                    o_BranchOperator <= JAL_TYPE;

                when "1100111" =>
                    o_BranchOperator <= JALR_TYPE;

                when others =>
                    o_BranchOperator <= BRANCH_NONE;

            end case;

        end if;

    end process;

end implementation;