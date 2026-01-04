-- Horizon: forwarding_unit.vhd
-- (c) 2026 Connor J. Link. All rights reserved.


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.RISCV_types.all;

entity forwarding_unit is
    port(
        i_IFID_RS1        : in  std_logic_vector(4 downto 0);
        i_IFID_RS2        : in  std_logic_vector(4 downto 0);
        i_IFID_IsLoad     : in  std_logic;

        i_IDEX_RS1        : in  std_logic_vector(4 downto 0);
        i_IDEX_RS2        : in  std_logic_vector(4 downto 0);
        i_IDEX_MemWrite   : in  std_logic;
        i_IDEX_IsLoad     : in  std_logic;
        i_IDEX_ALUSrc     : in  natural;
        
        i_EXMEM_RS1       : in  std_logic_vector(4 downto 0);
        i_EXMEM_RS2       : in  std_logic_vector(4 downto 0);
        i_EXMEM_RD        : in  std_logic_vector(4 downto 0);
        i_EXMEM_RegWrite  : in  std_logic;
        i_EXMEM_MemWrite  : in  std_logic;
        i_EXMEM_IsLoad    : in  std_logic;

        i_MEMWB_RD        : in  std_logic_vector(4 downto 0);
        i_MEMWB_RegWrite  : in  std_logic;
        i_MEMWB_MemWrite  : in  std_logic;
        i_MEMWB_IsLoad    : in  std_logic;

        i_BranchMode      : in  natural;
        i_BranchTaken     : in  std_logic;
        i_IsBranch        : in  std_logic;
    
        o_ForwardALUOperand1    : out natural;
        o_ForwardALUOperand2    : out natural;
        o_ForwardBGUOperand1    : out natural;
        o_ForwardBGUOperand2    : out natural;
        o_ForwardMemData        : out natural
    );
end forwarding_unit;

architecture implementation of forwarding_unit is
begin

    process(
        all
    )
        variable v_ForwardALUOperand1 : natural := 0;
        variable v_ForwardALUOperand2 : natural := 0;
        variable v_ForwardBGUOperand1 : natural := 0;
        variable v_ForwardBGUOperand2 : natural := 0;
        variable v_ForwardMemData     : natural := 0;

    begin

        v_ForwardALUOperand1    := 0;
        v_ForwardALUOperand2    := 0;
        v_ForwardBGUOperand1    := 0;
        v_ForwardBGUOperand2    := 0;
        v_ForwardMemData        := 0;

        -----------------------------------------------------
        ---- Arithmetic and memory access hazard resolution with forwarding
        -----------------------------------------------------
        if i_BranchMode = 0 then

            -- Detect ALU operand dependence upon arithmetic result
            if i_EXMEM_RegWrite = '1' and i_EXMEM_RD /= 5x"0" and i_EXMEM_RD = i_IDEX_RS1 then
                v_ForwardALUOperand1 := work.RISCV_types.FROM_EX;
            
            -- Detect ALU operand dependence upon memory access or MEM-stage operand
            elsif i_MEMWB_RegWrite = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS1 and not 
                 (i_EXMEM_RegWrite = '1' and i_EXMEM_RD /= 5x"0" and i_EXMEM_RD = i_IDEX_RS1) then
                v_ForwardALUOperand1 := work.RISCV_types.FROM_MEM;

            end if;

            
            -- Detect ALU operand dependence upon arithmetic result
            if i_EXMEM_RegWrite = '1' and i_EXMEM_RD /= 5x"0" and i_EXMEM_RD = i_IDEX_RS2 and i_IDEX_ALUSrc = work.RISCV_types.ALUSRC_REG then
                v_ForwardALUOperand2 := work.RISCV_types.FROM_EX;

            -- Detect ALU operand dependence upon memory access or MEM-stage operand
            elsif i_MEMWB_RegWrite = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS2 and not
                 (i_EXMEM_RegWrite = '1' and i_EXMEM_RD /= 5x"0" and i_EXMEM_RD = i_IDEX_RS2) and i_EXMEM_IsLoad = '0' and i_IDEX_IsLoad = '0' and i_IDEX_ALUSrc = work.RISCV_types.ALUSRC_REG then
                v_ForwardALUOperand2 := work.RISCV_types.FROM_MEM;

            end if;


            -- Detect memory address or write data dependency upon spaced-out instruction
            if i_MEMWB_RegWrite = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS2 then
                -- When the earlier instruction loads data needed later for store
                if i_MEMWB_IsLoad = '1' and i_IDEX_MemWrite = '1' then
                    v_ForwardMemData := work.RISCV_types.FROM_MEM;

                -- When the earlier instruction writes data needed later for store
                elsif i_IDEX_IsLoad = '1' and i_IDEX_MemWrite = '1' then
                    v_ForwardMemData := work.RISCV_types.FROM_MEMWB_ALU;

                end if;
                
            -- Detect memory write data dependence upon arithmetic result
            elsif i_EXMEM_RegWrite = '1' and i_EXMEM_RD /= 5x"0" and i_EXMEM_RD = i_IDEX_RS2 and i_IDEX_IsLoad = '1' and i_EXMEM_IsLoad = '0' then
                v_ForwardMemData := work.RISCV_types.FROM_EXMEM_ALU;

            -- Detect memory write data dependence upon retiring memory read
            elsif i_MEMWB_RegWrite = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS2 and i_MEMWB_IsLoad = '1' then
                v_ForwardMemData := work.RISCV_types.FROM_MEM;
            
            -- Detect memory write data dependence upon retiring arithmetic result
            elsif i_MEMWB_RegWrite = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS2 and i_IDEX_IsLoad = '1' and i_MEMWB_IsLoad = '0' then
                v_ForwardMemData := work.RISCV_types.FROM_MEMWB_ALU;

            end if;


            -- Detect address computation dependence upon arithmetic result
            if i_MEMWB_RegWrite = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS1 then
                -- When the earlier instruction is load/store
                if i_IDEX_IsLoad = '0' and i_MEMWB_IsLoad = '1' then
                    v_ForwardALUOperand1 := work.RISCV_types.FROM_MEM;

                -- When the later instruction is a load/store
                elsif i_IDEX_IsLoad = '1' and i_MEMWB_IsLoad = '0' then
                    v_ForwardALUOperand1 := work.RISCV_types.FROM_MEMWB_ALU;

                -- When both instructions are load/store
                elsif i_IDEX_IsLoad = '1' and i_MEMWB_IsLoad = '1' then
                    v_ForwardALUOperand1 := work.RISCV_types.FROM_MEM;

                end if;

            -- Detect address computation dependence upon retiring arithmetic result
            elsif i_MEMWB_RegWrite = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS1 and i_IDEX_IsLoad = '1' then
                v_ForwardALUOperand2 := work.RISCV_types.FROM_MEMWB_ALU;

            end if;

        
        -----------------------------------------------------
        ---- Branch hazard resolution with forwarding
        -----------------------------------------------------
        elsif i_BranchMode /= 0 or i_IsBranch = '1' or i_BranchTaken = '1' then
            
            -- NOTE: the following two `if` statements are mirrored for each corresponding operand register

            -- Detect branch comparison operator dependence upon arithmetic result
            if i_EXMEM_RegWrite = '1' and i_EXMEM_RD /= 5x"0" and i_EXMEM_RD = i_IDEX_RS1 then
                v_ForwardBGUOperand1 := work.RISCV_types.FROM_EXMEM_ALU;

            elsif i_MEMWB_RegWrite = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS1 then
                
                -- Detect branch comparison operator dependence upon memory access
                if i_MEMWB_IsLoad = '1' then
                    v_ForwardBGUOperand1 := work.RISCV_types.FROM_MEM; 

                -- Detect branch comparison operator dependence upon retiring arithmetic result
                else 
                    v_ForwardBGUOperand1 := work.RISCV_types.FROM_MEMWB_ALU;

                end if;

            end if;


            -- Detect branch comparison operator dependence upon arithmetic result
            if i_EXMEM_RegWrite = '1' and i_EXMEM_RD /= 5x"0" and i_EXMEM_RD = i_IDEX_RS2 then
                v_ForwardBGUOperand2 := work.RISCV_types.FROM_EXMEM_ALU;

            elsif i_MEMWB_RegWrite = '1' and i_MEMWB_RD /= 5x"0" and i_MEMWB_RD = i_IDEX_RS2 then
                
                -- Detect branch comparison operator dependence upon memory access
                if i_MEMWB_IsLoad = '1' then
                    v_ForwardBGUOperand2 := work.RISCV_types.FROM_MEM;
                    
                -- Detect branch comparison operator dependence upon retiring arithmetic result
                else
                    v_ForwardBGUOperand2 := work.RISCV_types.FROM_MEMWB_ALU;

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
   