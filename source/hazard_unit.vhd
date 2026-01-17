-- Horizon: hazard_unit.vhd
-- (c) 2026 Connor J. Link. All rights reserved.


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity hazard_unit is
    generic(
        constant IS_DEBUG : boolean := false
    );
    port(
        i_IFID_RS1               : in  std_logic_vector(4 downto 0);
        i_IFID_RS2               : in  std_logic_vector(4 downto 0);
        i_IFID_IsLoad            : in  std_logic;
        i_IFID_MemoryWriteEnable : in  std_logic;

        i_IDEX_RD        : in  std_logic_vector(4 downto 0);
        i_IDEX_RS1       : in  std_logic_vector(4 downto 0);
        i_IDEX_RS2       : in  std_logic_vector(4 downto 0);
        i_IDEX_IsLoad    : in  std_logic;

        i_EXMEM_RS1                 : in  std_logic_vector(4 downto 0);
        i_EXMEM_RS2                 : in  std_logic_vector(4 downto 0);
        i_EXMEM_RD                  : in  std_logic_vector(4 downto 0);
        i_EXMEM_IsLoad              : in  std_logic;
        i_EXMEM_RegisterFileWriteEnable : in  std_logic;

        i_MEMWB_RD       : in  std_logic_vector(4 downto 0);
        i_MEMWB_IsLoad   : in  std_logic;

        i_BranchMode     : in  branch_mode_t;
        i_BranchTaken    : in  std_logic;

        -- Branch prediction (for avoiding unnecessary flushes on correct predictions)
        i_IsPredictionUsed  : in  std_logic := '0';
        i_IsMispredict   : in  std_logic := '0';
        
        i_IDEX_IsBranch  : in  std_logic;
        i_MEMWB_IsBranch : in  std_logic;

        o_Break          : out std_logic;

        o_IFID_Flush     : out std_logic;
        o_IFID_Stall     : out std_logic;

        o_IDEX_Flush     : out std_logic;
        o_IDEX_Stall     : out std_logic;

        o_EXMEM_Flush    : out std_logic;
        o_EXMEM_Stall    : out std_logic
    );
end hazard_unit;

architecture implementation of hazard_unit is
begin
    
    process(
        all
    )
        variable v_IP_Stall    : std_logic := '0';
        variable v_IFID_Flush  : std_logic := '0';
        variable v_IFID_Stall  : std_logic := '0';
        variable v_IDEX_Flush  : std_logic := '0';
        variable v_IDEX_Stall  : std_logic := '0';
        variable v_EXMEM_Flush : std_logic := '0';
        variable v_EXMEM_Stall : std_logic := '0';

    begin
        v_IP_Stall    := '0';
        v_IFID_Flush  := '0';
        v_IFID_Stall  := '0';
        v_IDEX_Flush  := '0';
        v_IDEX_Stall  := '0';
        v_EXMEM_Flush := '0';
        v_EXMEM_Stall := '0';


        -- Detect jal/j, which doesn't rely on any external data to execute.
        -- If the fetch unit already redirected via a correct prediction, avoid inserting bubbles.
        if i_BranchMode = BRANCHMODE_JAL_OR_BCC and i_IDEX_IsBranch = '0' then
            if (i_IsPredictionUsed = '0') or (i_IsMispredict = '1') then
                v_IFID_Flush := '1';
                v_IDEX_Flush := '1';
            end if;
            if IS_DEBUG then
                report "NON-HAZARD BRANCH DETECTED: jal" severity note;
            end if;


        -- Detect jalr/jr, which relies on the source register for the branch target
        elsif (i_BranchMode = BRANCHMODE_JALR) or
              (i_BranchMode = BRANCHMODE_JAL_OR_BCC and i_IDEX_IsBranch = '1') then

            -- If jalr/jr was already redirected by a correct prediction, no hazard
            if (i_BranchMode = BRANCHMODE_JALR) and (i_IsPredictionUsed = '1') and (i_IsMispredict = '0') then
                null;

            else

                -- NOTE: if jr, then the link register is x0 which will never cause a hazard
                if (i_IDEX_RD = i_IFID_RS1 and i_IDEX_RD /= 5x"0") or
                (i_IDEX_RD = i_IFID_RS2 and i_IDEX_RD /= 5x"0") then 

                    v_IP_Stall := '1';
                    v_IFID_Stall := '1';
                    v_IDEX_Flush := '1';
                    if IS_DEBUG then
                        report "HAZARD DETECTED: bcc/jalr" severity note;
                    end if;

            else
                -- Detect Bcc conditions taken/not taken
                if i_IDEX_IsBranch = '1' then 
                    if i_BranchTaken = '1' then
                        -- If the fetch unit already redirected via a correct prediction, avoid bubbles.
                        if (i_IsPredictionUsed = '0') or (i_IsMispredict = '1') then
                            v_IFID_Flush := '1';
                            v_IDEX_Flush := '1';
                        end if;
                        if IS_DEBUG then
                            report "BRANCH TAKEN: bcc" severity note;
                        end if;

                    else
                        if IS_DEBUG then
                            report "BRANCH NOT TAKEN: bcc" severity note;
                        end if;

                    end if;

                -- When non-hazard jalr/jr
                else
                    v_IP_Stall := '1';
                    v_IFID_Stall := '1';
                    v_IFID_Flush := '1';
                    v_IDEX_Flush := '1';
                    if IS_DEBUG then
                        report "NON-HAZARD BRANCH: jalr" severity note;
                    end if;

                end if;

            end if;

            end if;

        end if;

        
        -- Fixes triplet instruction sequences like:
        --   addi t2, t2, 4
        --   ...
        --   sw t2, 0(t3)
        if i_EXMEM_RegisterFileWriteEnable = '1' and i_IFID_IsLoad = '1' and i_IFID_MemoryWriteEnable = '1' and (i_EXMEM_RD = i_IFID_RS1 or i_EXMEM_RD = i_IFID_RS2) and i_EXMEM_RD /= 5x"0" then
            v_IP_Stall := '1';
            v_IFID_Stall := '1';
            v_IDEX_Flush := '1';
            if IS_DEBUG then
                report "HAZARD DETECTED: compute-store" severity note;
            end if;

        
        -- Fixes triplet instruction sequences like:
        --   lw t2, 0(t3)
        --   ...
        --   lw t3, 0(t2)
        elsif i_EXMEM_RegisterFileWriteEnable = '1' and i_EXMEM_IsLoad = '1' and i_IDEX_IsLoad = '1' and (i_EXMEM_RD = i_IDEX_RS1 or i_EXMEM_RD = i_IDEX_RS2) and i_EXMEM_RD /= 5x"0" then
            v_IP_Stall := '1';
            v_IFID_Stall := '1';
            v_IDEX_Stall := '1';
            v_EXMEM_Flush := '1';
            if IS_DEBUG then
                report "HAZARD DETECTED: load-load" severity note;
            end if;


        -- Fixes triplet instruction sequences like (which will have been already partially expanded):
        --   addi t2, t2, 1
        --   addi t3, t3, 1
        --   add  t4, t2, t3
        elsif i_EXMEM_RegisterFileWriteEnable = '1' and i_EXMEM_RD /= 5x"0" and i_EXMEM_RD = i_IFID_RS2 and i_IFID_IsLoad = '0' then
            v_IP_Stall := '1';
            v_IFID_Stall := '1';
            v_IDEX_Flush := '1';
            if IS_DEBUG then
                report "HAZARD DETECTED: compute-use" severity note;
            end if;


        -- Fixes duplet instruction sequences like:
        --   lw t2, 0(t3)
        --   addi t2, t2, 1
        elsif (i_IDEX_IsLoad = '0' and i_IFID_IsLoad = '1' and (i_IDEX_RD = i_IFID_RS1 or i_IDEX_RD = i_IFID_RS2) and i_IDEX_RD /= 5x"0") or
              (i_IDEX_IsLoad = '1' and i_IFID_IsLoad = '0' and (i_IDEX_RD = i_IFID_RS1 or i_IDEX_RD = i_IFID_RS2) and i_IDEX_RD /= 5x"0") then
            v_IP_Stall := '1';
            v_IFID_Stall := '1';
            v_IDEX_Flush := '1';
            if IS_DEBUG then
                report "HAZARD DETECTED: load-use" severity note;
            end if;


        -- NOTE: functionally correct without these cases
        -- NOTE: only be RS2 because the `sw` instruction only uses RS2 for its source operand
        -- elsif (i_EXMEM_IsLoad = '1' and i_IDEX_IsLoad = '1' and (i_EXMEM_RD = i_IDEX_RS2) and i_EXMEM_RD /= 5x"0") then 
        --     v_IP_Stall := '1';
        --     v_IFID_Stall := '1';
        --     v_IDEX_Stall := '1';
        --     v_EXMEM_Flush := '1';
        --     report "HAZARD DETECTED: load-store hazard" severity note;

        -- NOTE: only be RS1 because the `lw` instruction only uses RS1 for its base address operand
        -- elsif (i_EXMEM_IsLoad = '1' and i_IDEX_IsLoad = '1' and (i_EXMEM_RD = i_IDEX_RS1) and i_EXMEM_RD /= 5x"0") then
        --     v_IP_Stall := '1';
        --     v_IFID_Stall := '1';
        --     v_IDEX_Stall := '1';
        --     v_EXMEM_Flush := '1';
        --     report "HAZARD DETECTED: load-load address hazard" severity note;

        end if;

        o_Break       <= v_IP_Stall;
        o_IFID_Flush  <= v_IFID_Flush;
        o_IFID_Stall  <= v_IFID_Stall;
        o_IDEX_Flush  <= v_IDEX_Flush;
        o_IDEX_Stall  <= v_IDEX_Stall;
        o_EXMEM_Flush <= v_EXMEM_Flush;
        o_EXMEM_Stall <= v_EXMEM_Stall;

    end process;

end implementation;
