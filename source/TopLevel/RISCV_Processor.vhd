-------------------------------------------------------------------------
-- Henry Duwe
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- RISCV_Processor.vhd
-- DESCRIPTION: This file contains a skeleton of a software-scheduled 
-- pipelined RISCV_Processor implementation.

-- 01.29.2019 by H3::Design created.
-- 02.11.2025 by Connor J. Link authored RISC-V implementation.
-- 02.16.2025 by Connor J. Link authored 5-stage pipeline upgrade.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.RISCV_types.all;

entity RISCV_Processor is
    generic(
        N : integer := work.RISCV_types.DATA_WIDTH
    );
    port(
        i_Clock      : in  std_logic;
        i_Reset      : in  std_logic;
        iInstLd   : in  std_logic;
        iInstAddr : in  std_logic_vector(N-1 downto 0);
        iInstExt  : in  std_logic_vector(N-1 downto 0);
        oALUOut   : out std_logic_vector(N-1 downto 0) 
    ); 
end RISCV_Processor;

architecture structure of RISCV_Processor is

-- Required data memory signals
signal s_DMemWr       : std_logic;                      -- use this signal as the final active high data memory write enable signal
signal s_DMemAddr     : std_logic_vector(N-1 downto 0); -- use this signal as the final data memory address input
signal s_DMemData     : std_logic_vector(N-1 downto 0); -- use this signal as the final data memory data input
signal s_DMemOut      : std_logic_vector(N-1 downto 0); -- use this signal as the data memory output
 
-- Required register file signals 
signal s_RegWr        : std_logic;                      -- use this signal as the final active high write enable input to the register file
signal s_RegWrAddr    : std_logic_vector(4 downto 0);   -- use this signal as the final destination register address input
signal s_RegWrData    : std_logic_vector(N-1 downto 0); -- use this signal as the final data memory data input

-- Required instruction memory signals
signal s_IMemAddr     : std_logic_vector(N-1 downto 0); -- Do not assign this signal, assign to s_NextInstAddr instead
signal s_NextInstAddr : std_logic_vector(N-1 downto 0); -- use this signal as your intended final instruction memory address input.
signal s_Inst         : std_logic_vector(N-1 downto 0); -- use this signal as the instruction signal 

-- Required halt signal -- for simulation
signal s_Halt         : std_logic;  -- this signal indicates to the simulation that intended program execution has completed.

-- Required overflow signal -- for overflow exception detection
signal s_Ovfl         : std_logic;

component mem is
    generic(
        ADDR_WIDTH : integer;
        DATA_WIDTH : integer
    );
    port(
        clk  : in  std_logic;
        addr : in  std_logic_vector((ADDR_WIDTH-1) downto 0);
        data : in  std_logic_vector((DATA_WIDTH-1) downto 0);
        we   : in  std_logic := '1';
        q    : out std_logic_vector((DATA_WIDTH -1) downto 0)
    );
end component;

-- Signals to hold the intermediate outputs from the register file
signal s_RS1Data : std_logic_vector(31 downto 0);
signal s_RS2Data : std_logic_vector(31 downto 0);

-- Signal to hold the ALU inputs and outputs
signal s_ALUOperand1 : std_logic_vector(31 downto 0);
signal s_RealALUOperand1 : std_logic_vector(31 downto 0);
signal s_ALUOperand2 : std_logic_vector(31 downto 0);
signal s_RealALUOperand2 : std_logic_vector(31 downto 0);

-- Signals to handle the intputs/outputs of the BGU
signal s_BGUOperand1 : std_logic_vector(31 downto 0);
signal s_BGUOperand2 : std_logic_vector(31 downto 0);
signal s_BranchTaken : std_logic;
signal s_BranchNotTaken : std_logic;

-- Signal to hold the modified clock
signal nCLK  : std_logic;

-- Signals to hold the computed memory instruction address input to the IP
signal s_BranchAddr : std_logic_vector(31 downto 0);

-- Signal to output the contents of the instruction pointer
signal s_IPAddr : std_logic_vector(31 downto 0);
signal s_IPBreak : std_logic;

-- Signals to drive the hazard detection and correction logic
signal s_IFID_IsLoad  : std_logic;
signal s_IDEX_IsLoad  : std_logic;
signal s_EXMEM_IsLoad : std_logic;
signal s_MEMWB_IsLoad : std_logic;



signal s_ForwardedDMemData : std_logic_vector(31 downto 0);

signal s_MemALUOperand1 : std_logic_vector(31 downto 0) := (others => '0');
signal s_MemALUOperand2 : std_logic_vector(31 downto 0) := (others => '0');
----------------------------------------------------------------------------------
---- Pipeline Data Signals
---- NOTE: the two identifiers are not the source and destination connections
---- The first is the source of the pipeline register, and the second is the stage
---- operating the pool of signals at hand.
----
---- Thus, EXMEM_IF_raw are the `input` signals to the pipeline register after the ALU
---- stage driven by the instruction register (so IPAddr, Insn, etc.)
----------------------------------------------------------------------------------
signal IFID_IF_raw,   IFID_IF_buf   : work.RISCV_types.insn_record_t;

signal IDEX_IF_raw,   IDEX_IF_buf   : work.RISCV_types.insn_record_t;
signal IDEX_ID_raw,   IDEX_ID_buf   : work.RISCV_types.driver_record_t;

signal EXMEM_IF_raw,  EXMEM_IF_buf  : work.RISCV_types.insn_record_t;
signal EXMEM_ID_raw,  EXMEM_ID_buf  : work.RISCV_types.driver_record_t;
signal EXMEM_EX_raw,  EXMEM_EX_buf  : work.RISCV_types.alu_record_t;

signal MEMWB_IF_raw,  MEMWB_IF_buf  : work.RISCV_types.insn_record_t;
signal MEMWB_ID_raw,  MEMWB_ID_buf  : work.RISCV_types.driver_record_t;
signal MEMWB_EX_raw,  MEMWB_EX_buf  : work.RISCV_types.alu_record_t;
signal MEMWB_MEM_raw, MEMWB_MEM_buf : work.RISCV_types.mem_record_t;

signal WB_WB_raw,     WB_WB_buf     : work.RISCV_types.wb_record_t;

signal s_IFID_Stall,  s_IFID_Flush  : std_logic := '0';
signal s_IDEX_Stall,  s_IDEX_Flush  : std_logic := '0';
signal s_EXMEM_Stall, s_EXMEM_Flush : std_logic := '0';
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
---- Data Forwarding Signals
----------------------------------------------------------------------------------
signal s_ForwardALUOperand1 : natural := 0;
signal s_ForwardALUOperand2 : natural := 0;
signal s_ForwardBGUOperand1 : natural := 0;
signal s_ForwardBGUOperand2 : natural := 0;
signal s_ForwardMemData     : natural := 0;
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
---- Helper Function for Load/Store Data Size Extension
----------------------------------------------------------------------------------
function ExtendMemoryData(
    Data             : std_logic_vector(31 downto 0);
    LSWidth          : natural;
    SignExtend       : std_logic;
    DestinationWidth : natural
) return std_logic_vector is
    variable Result : std_logic_vector(DestinationWidth - 1 downto 0);
begin
    case LSWidth is
        when work.RISCV_types.BYTE =>
            if SignExtend = '0' then
                Result := std_logic_vector(resize(unsigned(Data(7 downto 0)), DestinationWidth));
            else
                Result := std_logic_vector(resize(signed(Data(7 downto 0)), DestinationWidth));
            end if;

        when work.RISCV_types.HALF =>
            if SignExtend = '0' then
                Result := std_logic_vector(resize(unsigned(Data(15 downto 0)), DestinationWidth));
            else
                Result := std_logic_vector(resize(signed(Data(15 downto 0)), DestinationWidth));
            end if;

        when work.RISCV_types.WORD =>
            if SignExtend = '0' then
                Result := std_logic_vector(resize(unsigned(Data(31 downto 0)), DestinationWidth));
            else
                Result := std_logic_vector(resize(signed(Data(31 downto 0)), DestinationWidth));
            end if;

        when others =>
            Result := (others => '0');

    end case;

    return Result;

end function;
----------------------------------------------------------------------------------





begin

    -- NOTE: RISC-V does not support overflow-checked arithmetic.
    s_Ovfl <= '0';
    -- NOTE: This is probably not the best way to detect a halt condition, but it will at least trap execution when two consecutive illegal instructions retire.
    s_Halt <= (MEMWB_ID_buf.Break and EXMEM_ID_buf.Break);

    
    nCLK <= not i_Clock;

    -- This is required to be your final input to your instruction memory. This provides a feasible method to externally load the memory module which means that the synthesis tool must assume it knows nothing about the values stored in the instruction memory. If this is not included, much, if not all of the design is optimized out because the synthesis tool will believe the memory to be all zeros.
    with iInstLd select
        s_IMemAddr <= s_NextInstAddr when '0',
                      iInstAddr      when others;

    IMem: mem
        generic map(
            ADDR_WIDTH => work.RISCV_types.ADDR_WIDTH,
            DATA_WIDTH => N
        )
        port map(
            clk  => i_Clock,
            addr => s_IPAddr(11 downto 2),
            data => iInstExt,
            we   => iInstLd,
            q    => s_Inst
        );
  
    DMem: mem
        generic map(
            ADDR_WIDTH => work.RISCV_types.ADDR_WIDTH,
            DATA_WIDTH => N
        )
        port map(
            clk  => nCLK, -- i_Clock
            addr => s_DMemAddr(11 downto 2),
            data => s_DMemData,
            we   => s_DMemWr,
            q    => s_DMemOut
        );

    MEMWB_MEM_raw.Data <= ExtendMemoryData(s_DMemOut, MEMWB_ID_raw.LSWidth, '1', 32);
    IDEX_ID_raw.Data <= ExtendMemoryData(s_DMemOut, IDEX_ID_raw.LSWidth, '1', 32);


    -----------------------------------------------------
    ---- Instruction -> Driver stage register(s)
    -----------------------------------------------------

    CPU_Insn_IR: entity work.reg_insn
        port map(
            i_Clock   => i_Clock,
            i_Reset   => i_Reset,
            i_Stall   => s_IFID_Stall,
            i_Flush   => s_IFID_Flush,
            i_Signals => IFID_IF_raw,
            o_Signals => IFID_IF_buf
        );

    IDEX_IF_raw <= IFID_IF_buf;
        
    -----------------------------------------------------


    -----------------------------------------------------
    ---- Driver -> ALU stage register(s)
    -----------------------------------------------------

    CPU_Driver_IR: entity work.reg_insn
        port map(
            i_Clock     => i_Clock,
            i_Reset     => i_Reset,
            i_Stall   => s_IDEX_Stall,
            i_Flush   => s_IDEX_Flush,
        
            i_Signals => IDEX_IF_raw,
            o_Signals => IDEX_IF_buf
        );

    CPU_Driver_DR: entity work.reg_driver
        port map(
            i_Clock     => i_Clock,
            i_Reset     => i_Reset,
            i_Stall   => s_IDEX_Stall,
            i_Flush   => s_IDEX_Flush,
        
            i_Signals => IDEX_ID_raw,
            o_Signals => IDEX_ID_buf
        );

    EXMEM_IF_raw <= IDEX_IF_buf;
    EXMEM_ID_raw <= IDEX_ID_buf;

    -----------------------------------------------------


    -----------------------------------------------------
    ---- ALU -> Memory stage register(s)
    -----------------------------------------------------

    CPU_ALU_IR: entity work.reg_insn
        port map(
            i_Clock     => i_Clock,
            i_Reset     => i_Reset,
            i_Stall   => s_EXMEM_Stall,
            i_Flush   => s_EXMEM_Flush,
        
            i_Signals => EXMEM_IF_raw,
            o_Signals => EXMEM_IF_buf
        );

    CPU_ALU_DR: entity work.reg_driver
        port map(
            i_Clock     => i_Clock,
            i_Reset     => i_Reset,
            i_Stall   => s_EXMEM_Stall,
            i_Flush   => s_EXMEM_Flush,
        
            i_Signals => EXMEM_ID_raw,
            o_Signals => EXMEM_ID_buf
        );

    CPU_ALU_AR: entity work.reg_alu
        port map(
            i_Clock     => i_Clock,
            i_Reset     => i_Reset,
            i_Stall   => s_EXMEM_Stall,
            i_Flush   => s_EXMEM_Flush,
        
            i_Signals => EXMEM_EX_raw,
            o_Signals => EXMEM_EX_buf
        );

    MEMWB_IF_raw <= EXMEM_IF_buf;
    MEMWB_ID_raw <= EXMEM_ID_buf;
    MEMWB_EX_raw <= EXMEM_EX_buf;

    -----------------------------------------------------


    -----------------------------------------------------
    ---- Memory -> Register File stage register(s)
    -----------------------------------------------------

    CPU_Mem_IR: entity work.reg_insn
        port map(
            i_Clock     => i_Clock,
            i_Reset     => i_Reset,
            i_Stall   => '0',
            i_Flush   => '0',
        
            i_Signals => MEMWB_IF_raw,
            o_Signals => MEMWB_IF_buf
        );

    CPU_Mem_DR: entity work.reg_driver
        port map(
            i_Clock     => i_Clock,
            i_Reset     => i_Reset,
            i_Stall   => '0',
            i_Flush   => '0',
        
            i_Signals => MEMWB_ID_raw,
            o_Signals => MEMWB_ID_buf
        );

    CPU_Mem_AR: entity work.reg_alu
        port map(
            i_Clock     => i_Clock,
            i_Reset     => i_Reset,
            i_Stall   => '0',
            i_Flush   => '0',
        
            i_Signals => MEMWB_EX_raw,
            o_Signals => MEMWB_EX_buf
        ); 
    

    CPU_Mem_MR: entity work.reg_mem
        port map(
            i_Clock     => i_Clock,
            i_Reset     => i_Reset,
            i_Stall   => '0',
            i_Flush   => '0',
        
            i_Signals => MEMWB_MEM_raw,
            o_Signals => MEMWB_MEM_buf
        );

    -----------------------------------------------------


    -----------------------------------------------------
    ---- Memory -> Register File stage register(s)
    -----------------------------------------------------

    WB_WB_raw.F       <= MEMWB_EX_buf.F;
    WB_WB_raw.Data    <= MEMWB_MEM_buf.Data;
    WB_WB_raw.Forward <= s_ForwardMemData;
    WB_WB_raw.LSWidth <= MEMWB_ID_buf.LSWidth;

    CPU_WB_WR: entity work.reg_wb
        port map(
            i_Clock     => i_Clock,
            i_Reset     => i_Reset,
            i_Stall   => '0',
            i_Flush   => '0',

            i_Signals => WB_WB_raw,
            o_Signals => WB_WB_buf
        );



    -----------------------------------------------------



    -----------------------------------------------------
    ---- Instruction Pointer Unit
    -----------------------------------------------------

    s_BranchAddr <= std_logic_vector(signed(IDEX_IF_buf.IPAddr) + signed(IDEX_ID_buf.Imm)) when (IDEX_ID_buf.BranchMode = work.RISCV_types.JAL_OR_BCC) else
                    std_logic_vector(signed(IDEX_ID_buf.DS1)    + signed(IDEX_ID_buf.Imm)) when (IDEX_ID_buf.BranchMode = work.RISCV_types.JALR)       else 
                    (others => '0');

    CPU_IP: entity work.ip
        generic map(
            ResetAddress => 32x"00400000"
        )
        port map(
            i_Clock        => i_Clock,
            i_Reset        => i_Reset,
            i_Stall      => s_IPBreak,
            i_Load       => s_BranchTaken,
            i_Addr       => s_BranchAddr,
            i_nInc2_Inc4 => '1', -- IDEX_ID_buf.IPStride, -- NOTE: This might be 1 pipeline stage too late to increment the correct corresponding amount. But, resolving this requires instruction pre-decoding to compute length, so just assume 4-byte instructions for now
            o_Addr       => s_IPAddr,
            o_LinkAddr   => s_NextInstAddr 
        );

    IFID_IF_raw.IPAddr   <= s_IPAddr;
    IFID_IF_raw.LinkAddr <= s_NextInstAddr;
    IFID_IF_raw.Insn     <= s_Inst;

    -----------------------------------------------------


    -----------------------------------------------------
    ---- Branch Generation Unit
    -----------------------------------------------------

    with s_ForwardBGUOperand1 select
        s_BGUOperand1 <=
            EXMEM_EX_buf.F     when work.RISCV_types.FROM_EXMEM_ALU,
            MEMWB_EX_buf.F     when work.RISCV_types.FROM_MEMWB_ALU,
            MEMWB_MEM_buf.Data when work.RISCV_types.FROM_MEM,
            IDEX_ID_buf.DS1    when others;

    with s_ForwardBGUOperand2 select
        s_BGUOperand2 <= 
            EXMEM_EX_buf.F     when work.RISCV_types.FROM_EXMEM_ALU,
            MEMWB_EX_buf.F     when work.RISCV_types.FROM_MEMWB_ALU,
            MEMWB_MEM_buf.Data when work.RISCV_types.FROM_MEM,
            IDEX_ID_buf.DS2    when others;

    CPU_BGU: entity work.bgu
        port map(
            i_Clock            => i_Clock,
            i_DS1            => s_BGUOperand1,
            i_DS2            => s_BGUOperand2,
            i_BGUOp          => IDEX_ID_buf.BGUOp,
            o_BranchTaken    => s_BranchTaken,
            o_BranchNotTaken => s_BranchNotTaken
        );

    -----------------------------------------------------


    -----------------------------------------------------
    ---- Processor Control Unit
    -----------------------------------------------------

    CPU_Driver: entity work.driver
        port map(
            i_Clock        => i_Clock,
            i_Reset        => i_Reset,
            i_Insn       => IDEX_IF_raw.Insn,    
            o_MemWrite   => IDEX_ID_raw.MemWrite,
            o_RegWrite   => IDEX_ID_raw.RegWrite,
            o_RFSrc      => IDEX_ID_raw.RFSrc,
            o_ALUSrc     => IDEX_ID_raw.ALUSrc,
            o_ALUOp      => IDEX_ID_raw.ALUOp,
            o_BGUOp      => IDEX_ID_raw.BGUOp,
            o_LSWidth    => IDEX_ID_raw.LSWidth,
            o_RD         => IDEX_ID_raw.RD,
            o_RS1        => IDEX_ID_raw.RS1,
            o_RS2        => IDEX_ID_raw.RS2, 
            o_Imm        => IDEX_ID_raw.Imm,
            o_BranchMode => IDEX_ID_raw.BranchMode,
            o_Break      => IDEX_ID_raw.Break,
            o_IsBranch   => IDEX_ID_raw.IsBranch,
            o_IPToALU    => IDEX_ID_raw.IPToALU,
            o_IPStride   => IDEX_ID_raw.IPStride,
            o_SignExtend => IDEX_ID_raw.SignExtend
        );

    IDEX_ID_raw.DS1 <= s_RS1Data;
    IDEX_ID_raw.DS2 <= s_RS2Data;

    -----------------------------------------------------


    -----------------------------------------------------
    ---- Register File Subsystem
    -----------------------------------------------------

    with MEMWB_ID_buf.RFSrc select
        s_RegWrData <=
            MEMWB_MEM_buf.Data    when work.RISCV_types.FROM_RAM,
            MEMWB_EX_buf.F        when work.RISCV_types.FROM_ALU,
            MEMWB_IF_buf.LinkAddr when work.RISCV_types.FROM_NEXTIP,
            MEMWB_ID_buf.Imm      when work.RISCV_types.FROM_IMM,
            (others => '0')       when others;


    s_RegWr <= MEMWB_ID_buf.RegWrite;
    s_RegWrAddr <= MEMWB_ID_buf.RD;

    CPU_RegisterFile: entity work.regfile
        port map(
            i_Clock => nCLK,
            i_Reset => i_Reset,
            i_RS1 => IDEX_ID_raw.RS1, -- NOTE: registers reads occur in the decode stage unless forwarding
            i_RS2 => IDEX_ID_raw.RS2,
            i_RD  => s_RegWrAddr,
            i_WE  => s_RegWr,
            i_D   => s_RegWrData,
            o_DS1 => s_RS1Data,
            o_DS2 => s_RS2Data
        );

    -----------------------------------------------------


    -----------------------------------------------------
    ---- Arithmetic Logic Unit
    -----------------------------------------------------

    s_MemALUOperand1 <= MEMWB_MEM_buf.Data when (MEMWB_ID_buf.LSWidth /= 0) else
                        MEMWB_EX_buf.F;

    s_MemALUOperand2 <= MEMWB_MEM_buf.Data when (MEMWB_ID_buf.LSWidth /= 0) else
                        MEMWB_EX_buf.F;      

    with s_ForwardALUOperand1 select
        s_ALUOperand1 <=
            EXMEM_EX_buf.F   when work.RISCV_types.FROM_EX,
            s_MemALUOperand1 when work.RISCV_types.FROM_MEM,
            MEMWB_EX_buf.F   when work.RISCV_types.FROM_MEMWB_ALU,
            IDEX_ID_buf.DS1  when others;

    with s_ForwardALUOperand2 select
        s_RealALUOperand2 <=
            EXMEM_EX_buf.F   when work.RISCV_types.FROM_EX,
            MEMWB_EX_buf.F   when work.RISCV_types.FROM_MEMWB_ALU,
            s_MemALUOperand2 when work.RISCV_types.FROM_MEM,
            s_ALUOperand2    when others;

    -- NOTE: only the first operand is backwards here because IPToALU (for `auipc`) must take precedence over any potential data forwarding
    s_RealALUOperand1 <= (others => '0')    when (IDEX_ID_buf.ALUSrc  = work.RISCV_types.ALUSRC_BIGIMM) else
                         IDEX_IF_buf.IPAddr when (IDEX_ID_buf.IPToALU = '1') else
                         s_ALUOperand1      when (IDEX_ID_buf.IPToALU = '0') else
                         (others => '0');

    s_ALUOperand2 <= IDEX_ID_buf.Imm when (IDEX_ID_buf.ALUSrc = work.RISCV_types.ALUSRC_IMM)    else
                     IDEX_ID_buf.Imm when (IDEX_ID_buf.ALUSrc = work.RISCV_types.ALUSRC_BIGIMM) else
                     IDEX_ID_buf.DS2 when (IDEX_ID_buf.ALUSrc = work.RISCV_types.ALUSRC_REG)    else
                     (others => '0');

    CPU_ALU: entity work.alu
        port map(
            i_A     => s_RealALUOperand1,
            i_B     => s_RealALUOperand2,
            i_ALUOp => EXMEM_ID_raw.ALUOp,
            o_F     => EXMEM_EX_raw.F,
            o_Co    => EXMEM_EX_raw.Co
        );

    oALUOut <= EXMEM_EX_raw.F;

    -----------------------------------------------------

        
    -----------------------------------------------------
    ---- Data Memory Subsystem
    -----------------------------------------------------

    s_DMemWr <= EXMEM_ID_buf.MemWrite;
    s_DMemAddr <= EXMEM_EX_buf.F;

    with WB_WB_buf.Forward select 
        s_ForwardedDMemData <= 
            ExtendMemoryData(WB_WB_buf.Data, WB_WB_buf.LSWidth,    '1', 32) when work.RISCV_types.FROM_MEM,
            ExtendMemoryData(MEMWB_EX_buf.F, MEMWB_ID_buf.LSWidth, '1', 32) when work.RISCV_types.FROM_EXMEM_ALU,
            ExtendMemoryData(WB_WB_buf.F,    WB_WB_buf.LSWidth,    '1', 32) when work.RISCV_types.FROM_MEMWB_ALU,     
            (others => '0')   when others;


    s_DMemData <= s_ForwardedDMemData when (WB_WB_buf.Forward /= 0) else
                  std_logic_vector(resize(unsigned(EXMEM_ID_buf.DS2(7  downto 0)), s_DMemData'length)) when (EXMEM_ID_buf.LSWidth = work.RISCV_types.BYTE) else
                  std_logic_vector(resize(unsigned(EXMEM_ID_buf.DS2(15 downto 0)), s_DMemData'length)) when (EXMEM_ID_buf.LSWidth = work.RISCV_types.HALF) else
                  std_logic_vector(resize(unsigned(EXMEM_ID_buf.DS2(31 downto 0)), s_DMemData'length)) when (EXMEM_ID_buf.LSWidth = work.RISCV_types.WORD) else
                  (others => '0');

    -----------------------------------------------------


    -----------------------------------------------------
    ---- Hardware Pipeline Scheduling
    -----------------------------------------------------
        
    -- NOTE: IsLoad is simply set when the instruction is a load or store instruction.
    -- Hence, any hazard checks will need to also inspect for memory or register write 
    -- to determine to which case a particular hazard corresponds.

    s_IFID_IsLoad  <= '1' when (IDEX_ID_raw.LSWidth  /= 0) else '0';
    s_IDEX_IsLoad  <= '1' when (IDEX_ID_buf.LSWidth  /= 0) else '0';
    s_EXMEM_IsLoad <= '1' when (EXMEM_ID_buf.LSWidth /= 0) else '0';
    s_MEMWB_IsLoad <= '1' when (MEMWB_ID_buf.LSWidth /= 0) else '0';
    
    CPU_HMU: entity work.hmu
        port map(
            i_IFID_RS1       => IDEX_ID_raw.RS1,
            i_IFID_RS2       => IDEX_ID_raw.RS2,
            i_IFID_IsLoad    => s_IFID_IsLoad,
            i_IFID_MemWrite  => IDEX_ID_raw.MemWrite,

            i_IDEX_RS1       => IDEX_ID_buf.RS1,
            i_IDEX_RS2       => IDEX_ID_buf.RS2,
            i_IDEX_RD        => IDEX_ID_buf.RD,
            i_IDEX_IsLoad    => s_IDEX_IsLoad,

            i_EXMEM_RS1      => EXMEM_ID_buf.RS1,
            i_EXMEM_RS2      => EXMEM_ID_buf.RS2,
            i_EXMEM_RD       => EXMEM_ID_buf.RD,
            i_EXMEM_IsLoad   => s_EXMEM_IsLoad,
            i_EXMEM_RegWrite => EXMEM_ID_buf.RegWrite,

            i_MEMWB_RD       => MEMWB_ID_buf.RD,
            i_MEMWB_IsLoad   => s_MEMWB_IsLoad,

            i_BranchMode     => IDEX_ID_buf.BranchMode,
            i_BranchTaken    => s_BranchTaken,

            i_IDEX_IsBranch  => IDEX_ID_buf.IsBranch,
            i_MEMWB_IsBranch => MEMWB_ID_buf.IsBranch,

            o_Break          => s_IPBreak,
            o_IFID_Flush     => s_IFID_Flush,
            o_IFID_Stall     => s_IFID_Stall,
            o_IDEX_Flush     => s_IDEX_Flush,
            o_IDEX_Stall     => s_IDEX_Stall,
            o_EXMEM_Flush    => s_EXMEM_Flush,
            o_EXMEM_Stall    => s_EXMEM_Stall
        );

    CPU_DFU: entity work.dfu
        port map(
            i_IFID_RS1              => IDEX_ID_raw.RS1,
            i_IFID_RS2              => IDEX_ID_raw.RS2,
            i_IFID_IsLoad           => s_IFID_IsLoad,

            i_IDEX_RS1              => IDEX_ID_buf.RS1,
            i_IDEX_RS2              => IDEX_ID_buf.RS2,
            i_IDEX_MemWrite         => IDEX_ID_buf.MemWrite,
            i_IDEX_IsLoad           => s_IDEX_IsLoad,
            i_IDEX_ALUSrc           => IDEX_ID_buf.ALUSrc,

            i_EXMEM_RS1             => EXMEM_ID_buf.RS1,
            i_EXMEM_RS2             => EXMEM_ID_buf.RS2,
            i_EXMEM_RD              => EXMEM_ID_buf.RD,
            i_EXMEM_RegWrite        => EXMEM_ID_buf.RegWrite,
            i_EXMEM_MemWrite        => EXMEM_ID_buf.MemWrite,
            i_EXMEM_IsLoad          => s_EXMEM_IsLoad,

            i_MEMWB_RD              => MEMWB_ID_buf.RD,
            i_MEMWB_RegWrite        => MEMWB_ID_buf.RegWrite,
            i_MEMWB_MemWrite        => MEMWB_ID_buf.MemWrite,
            i_MEMWB_IsLoad          => s_MEMWB_IsLoad,

            i_BranchMode            => IDEX_ID_buf.BranchMode,
            i_BranchTaken           => s_BranchTaken,
            i_IsBranch              => IDEX_ID_buf.Isbranch,

            o_ForwardALUOperand1    => s_ForwardALUOperand1,
            o_ForwardALUOperand2    => s_ForwardALUOperand2,
            o_ForwardBGUOperand1    => s_ForwardBGUOperand1,
            o_ForwardBGUOperand2    => s_ForwardBGUOperand2,
            o_ForwardMemData        => s_ForwardMemData
        );

    -----------------------------------------------------

end structure;

