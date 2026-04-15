-- Horizon: forwarding_unit.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity forwarding_unit is
    port(
        i_IFID_RS1        : in  std_logic_vector(4 downto 0);
        i_IFID_RS2        : in  std_logic_vector(4 downto 0);
        i_IFID_IsLoad     : in  std_logic;

        i_IDEX_RS1               : in  std_logic_vector(4 downto 0);
        i_IDEX_RS2               : in  std_logic_vector(4 downto 0);
        i_IDEX_MemoryWriteEnable : in  std_logic;
        i_IDEX_IsLoad            : in  std_logic;
        i_IDEX_ALUSource         : in  alu_source_t;
        
        i_EXMEM_RS1                 : in  std_logic_vector(4 downto 0);
        i_EXMEM_RS2                 : in  std_logic_vector(4 downto 0);
        i_EXMEM_RD                  : in  std_logic_vector(4 downto 0);
        i_EXMEM_RegisterFileWriteEnable : in  std_logic;
        i_EXMEM_MemoryWriteEnable   : in  std_logic;
        i_EXMEM_IsLoad              : in  std_logic;

        i_MEMWB_RD                  : in  std_logic_vector(4 downto 0);
        i_MEMWB_RegisterFileWriteEnable : in  std_logic;
        i_MEMWB_MemoryWriteEnable   : in  std_logic;
        i_MEMWB_IsLoad              : in  std_logic;

        i_BranchMode      : in  branch_mode_t;
        i_BranchTaken     : in  std_logic;
        i_IsBranch        : in  std_logic;
    
        o_ForwardALUOperand1 : out forwarding_path_t;
        o_ForwardALUOperand2 : out forwarding_path_t;
        o_ForwardBGUOperand1 : out forwarding_path_t;
        o_ForwardBGUOperand2 : out forwarding_path_t;
        o_ForwardMemData     : out forwarding_path_t
    );
end forwarding_unit;

architecture implementation of forwarding_unit is
begin

    process(
        all
    )
        variable v_ForwardALUOperand1 : forwarding_path_t := FORWARDING_NONE;
        variable v_ForwardALUOperand2 : forwarding_path_t := FORWARDING_NONE;
        variable v_ForwardBGUOperand1 : forwarding_path_t := FORWARDING_NONE;
        variable v_ForwardBGUOperand2 : forwarding_path_t := FORWARDING_NONE;
        variable v_ForwardMemData     : forwarding_path_t := FORWARDING_NONE;

    begin

        v_ForwardALUOperand1 := FORWARDING_NONE;
        v_ForwardALUOperand2 := FORWARDING_NONE;
        v_ForwardBGUOperand1 := FORWARDING_NONE;
        v_ForwardBGUOperand2 := FORWARDING_NONE;
        v_ForwardMemData     := FORWARDING_NONE;

        -----------------------------------------------------
        ---- Arithmetic and memory access hazard resolution with forwarding
        -----------------------------------------------------
        if i_BranchMode = BRANCHMODE_NONE then

            -- Detect ALU operand dependence upon arithmetic result
            if i_EXMEM_RegisterFileWriteEnable = '1' and i_EXMEM_RD /= 5x"0" and i_EXMEM_RD = i_IDEX_RS1 then
                v_ForwardALUOperand1 := FORWARDING_FROMEX;
            
            -- Detect ALU operand dependence upon memory access or MEM-stage operand
            elsif i_MEMWB_RegisterFileWriteEnable = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS1 and not 
                 (i_EXMEM_RegisterFileWriteEnable = '1' and i_EXMEM_RD /= 5x"0" and i_EXMEM_RD = i_IDEX_RS1) then
                v_ForwardALUOperand1 := FORWARDING_FROMMEM;

            end if;

            
            -- Detect ALU operand dependence upon arithmetic result
            if i_EXMEM_RegisterFileWriteEnable = '1' and i_EXMEM_RD /= 5x"0" and i_EXMEM_RD = i_IDEX_RS2 and i_IDEX_ALUSource = ALUSOURCE_REGISTER then
                v_ForwardALUOperand2 := FORWARDING_FROMEX;

            -- Detect ALU operand dependence upon memory access or MEM-stage operand
            elsif i_MEMWB_RegisterFileWriteEnable = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS2 and not
                 (i_EXMEM_RegisterFileWriteEnable = '1' and i_EXMEM_RD /= 5x"0" and i_EXMEM_RD = i_IDEX_RS2) and i_EXMEM_IsLoad = '0' and i_IDEX_IsLoad = '0' and i_IDEX_ALUSource = ALUSOURCE_REGISTER then
                v_ForwardALUOperand2 := FORWARDING_FROMMEM;

            end if;


            -- Detect memory address or write data dependency upon spaced-out instruction
            if i_MEMWB_RegisterFileWriteEnable = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS2 then
                -- When the earlier instruction loads data needed later for store
                if i_MEMWB_IsLoad = '1' and i_IDEX_MemoryWriteEnable = '1' then
                    v_ForwardMemData := FORWARDING_FROMMEM;

                -- When the earlier instruction writes data needed later for store
                elsif i_IDEX_IsLoad = '1' and i_IDEX_MemoryWriteEnable = '1' then
                    v_ForwardMemData := FORWARDING_FROMMEMWB_ALU;

                end if;
                
            -- Detect memory write data dependence upon arithmetic result
            elsif i_EXMEM_RegisterFileWriteEnable = '1' and i_EXMEM_RD /= 5x"0" and i_EXMEM_RD = i_IDEX_RS2 and i_IDEX_IsLoad = '1' and i_EXMEM_IsLoad = '0' then
                v_ForwardMemData := FORWARDING_FROMEXMEM_ALU;

            -- Detect memory write data dependence upon retiring memory read
            elsif i_MEMWB_RegisterFileWriteEnable = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS2 and i_MEMWB_IsLoad = '1' then
                v_ForwardMemData := FORWARDING_FROMMEM;
            
            -- Detect memory write data dependence upon retiring arithmetic result
            elsif i_MEMWB_RegisterFileWriteEnable = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS2 and i_IDEX_IsLoad = '1' and i_MEMWB_IsLoad = '0' then
                v_ForwardMemData := FORWARDING_FROMMEMWB_ALU;

            end if;


            -- Detect address computation dependence upon arithmetic result
            if i_MEMWB_RegisterFileWriteEnable = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS1 then
                -- When the earlier instruction is load/store
                if i_IDEX_IsLoad = '0' and i_MEMWB_IsLoad = '1' then
                    v_ForwardALUOperand1 := FORWARDING_FROMMEM;

                -- When the later instruction is a load/store
                elsif i_IDEX_IsLoad = '1' and i_MEMWB_IsLoad = '0' then
                    v_ForwardALUOperand1 := FORWARDING_FROMMEMWB_ALU;

                -- When both instructions are load/store
                elsif i_IDEX_IsLoad = '1' and i_MEMWB_IsLoad = '1' then
                    v_ForwardALUOperand1 := FORWARDING_FROMMEM;

                end if;

            -- Detect address computation dependence upon retiring arithmetic result
            elsif i_MEMWB_RegisterFileWriteEnable = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS1 and i_IDEX_IsLoad = '1' then
                v_ForwardALUOperand2 := FORWARDING_FROMMEMWB_ALU;

            end if;

        
        -----------------------------------------------------
        ---- Branch hazard resolution with forwarding
        -----------------------------------------------------
        elsif i_BranchMode /= BRANCHMODE_NONE or i_IsBranch = '1' or i_BranchTaken = '1' then
            
            -- NOTE: the following two `if` statements are mirrored for each corresponding operand register

            -- Detect branch comparison operator dependence upon arithmetic result
            if i_EXMEM_RegisterFileWriteEnable = '1' and i_EXMEM_RD /= 5x"0" and i_EXMEM_RD = i_IDEX_RS1 then
                v_ForwardBGUOperand1 := FORWARDING_FROMEXMEM_ALU;

            elsif i_MEMWB_RegisterFileWriteEnable = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS1 then
                
                -- Detect branch comparison operator dependence upon memory access
                if i_MEMWB_IsLoad = '1' then
                    v_ForwardBGUOperand1 := FORWARDING_FROMMEM; 

                -- Detect branch comparison operator dependence upon retiring arithmetic result
                else 
                    v_ForwardBGUOperand1 := FORWARDING_FROMMEMWB_ALU;

                end if;

            end if;


            -- Detect branch comparison operator dependence upon arithmetic result
            if i_EXMEM_RegisterFileWriteEnable = '1' and i_EXMEM_RD /= 5x"0" and i_EXMEM_RD = i_IDEX_RS2 then
                v_ForwardBGUOperand2 := FORWARDING_FROMEXMEM_ALU;

            elsif i_MEMWB_RegisterFileWriteEnable = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS2 then
                
                -- Detect branch comparison operator dependence upon memory access
                if i_MEMWB_IsLoad = '1' then
                    v_ForwardBGUOperand2 := FORWARDING_FROMMEM;
                    
                -- Detect branch comparison operator dependence upon retiring arithmetic result
                else
                    v_ForwardBGUOperand2 := FORWARDING_FROMMEMWB_ALU;

                end if;

            end if;

        end if;

        o_ForwardALUOperand1 <= v_ForwardALUOperand1;
        o_ForwardALUOperand2 <= v_ForwardALUOperand2;
        o_ForwardBGUOperand1 <= v_ForwardBGUOperand1;
        o_ForwardBGUOperand2 <= v_ForwardBGUOperand2;
        o_ForwardMemData     <= v_ForwardMemData;

    end process;

end implementation;
   