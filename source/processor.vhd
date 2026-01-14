-- Horizon: processor.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity processor is
    generic(
        constant N : integer := DATA_WIDTH
    );
    port(
        i_Clock               : in  std_logic;
        i_Reset               : in  std_logic;
        i_InstructionLoad     : in  std_logic;
        i_InstructionAddress  : in  std_logic_vector(N-1 downto 0);
        i_InstructionExternal : in  std_logic_vector(N-1 downto 0);
        i_DataLoad            : in  std_logic;
        i_DataAddress         : in  std_logic_vector(N-1 downto 0);
        i_DataExternal        : in  std_logic_vector(N-1 downto 0);
        o_ALUOutput           : out std_logic_vector(N-1 downto 0);
        o_Halt                : out std_logic
    ); 
end processor;

architecture implementation of processor is

signal s_DataMemoryWriteEnable : std_logic;                      -- data memory write enable signal (active high)
signal s_DataMemoryAddress     : std_logic_vector(N-1 downto 0); -- data memory address input
signal s_DataMemoryData        : std_logic_vector(N-1 downto 0); -- data memory data input
signal s_DataMemoryOutput      : std_logic_vector(N-1 downto 0); -- data memory output
 
signal s_RegisterFileWriteEnable : std_logic;                      -- register file write enable signal (active high)
signal s_RegisterFileSelect      : std_logic_vector(4 downto 0);   -- destination register address input
signal s_RegisterFileData        : std_logic_vector(N-1 downto 0); -- data memory data input

signal s_InstructionMemoryAddress : std_logic_vector(N-1 downto 0); -- instruction memory address input
signal s_NextInstructionAddress   : std_logic_vector(N-1 downto 0); -- instruction pointer + stride
signal s_Instruction              : std_logic_vector(N-1 downto 0); -- instruction memory output (fetched)


-- Signals to hold the intermediate outputs from the register file
signal s_RS1Data : std_logic_vector(31 downto 0);
signal s_RS2Data : std_logic_vector(31 downto 0);

-- Signal to hold the ALU inputs and outputs
signal s_ALUOperand1     : std_logic_vector(31 downto 0);
signal s_RealALUOperand1 : std_logic_vector(31 downto 0);
signal s_ALUOperand2     : std_logic_vector(31 downto 0);
signal s_RealALUOperand2 : std_logic_vector(31 downto 0);
signal s_ALUDone         : std_logic;
signal s_ALUBusy         : std_logic;

-- Signals to handle the intputs/outputs of the branch unit
signal s_BranchOperand1 : std_logic_vector(31 downto 0);
signal s_BranchOperand2 : std_logic_vector(31 downto 0);
signal s_BranchTaken    : std_logic;
signal s_BranchNotTaken : std_logic;
signal s_BranchLoad     : std_logic := '0';

-- Signal to hold the modified clock
signal n_Clock  : std_logic;

-- Signals to hold the computed memory instruction address input to the IP
signal s_BranchAddress : std_logic_vector(31 downto 0);

-- Signal to output the contents of the instruction pointer
signal s_IPAddress : std_logic_vector(31 downto 0);
signal s_IPBreak   : std_logic;

-- Signals to drive the hazard detection and correction logic
signal s_IFID_IsLoad  : std_logic;
signal s_IDEX_IsLoad  : std_logic;
signal s_EXMEM_IsLoad : std_logic;
signal s_MEMWB_IsLoad : std_logic;


signal s_ForwardedDMemData : std_logic_vector(31 downto 0);
signal s_DataMemoryBuffer  : std_logic_vector(31 downto 0);

signal s_MemALUOperand1 : std_logic_vector(31 downto 0) := (others => '0');
signal s_MemALUOperand2 : std_logic_vector(31 downto 0) := (others => '0');
----------------------------------------------------------------------------------
---- Pipeline Data Signals
---- NOTE: the two identifiers are not the source and destination connections
---- The first is the source of the pipeline register, and the second is the stage
---- operating the pool of signals at hand.
----
---- Thus, EXMEM_IF_raw are the `input` signals to the pipeline register after the ALU
---- stage driven by the instruction register (so IPAddress, Instruction, etc.)
----------------------------------------------------------------------------------
signal IFID_IF_raw,   IFID_IF_buf   : IF_record_t;

signal IDEX_IF_raw,   IDEX_IF_buf   : IF_record_t;
signal IDEX_ID_raw,   IDEX_ID_buf   : ID_record_t;

signal EXMEM_IF_raw,  EXMEM_IF_buf  : IF_record_t;
signal EXMEM_ID_raw,  EXMEM_ID_buf  : ID_record_t;
signal EXMEM_EX_raw,  EXMEM_EX_buf  : EX_record_t;

signal MEMWB_IF_raw,  MEMWB_IF_buf  : IF_record_t;
signal MEMWB_ID_raw,  MEMWB_ID_buf  : ID_record_t;
signal MEMWB_EX_raw,  MEMWB_EX_buf  : EX_record_t;
signal MEMWB_MEM_raw, MEMWB_MEM_buf : MEM_record_t;

signal WB_WB_raw,     WB_WB_buf     : WB_record_t;

signal s_IFID_Stall,  s_IFID_Flush  : std_logic := '0';
signal s_IDEX_Stall,  s_IDEX_Flush  : std_logic := '0';
signal s_EXMEM_Stall, s_EXMEM_Flush : std_logic := '0';

signal s_EXMEM_MemoryWriteEnable : std_logic := '0';
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
---- Data Forwarding Signals
----------------------------------------------------------------------------------
signal s_ForwardALUOperand1 : forwarding_path_t := FORWARDING_NONE;
signal s_ForwardALUOperand2 : forwarding_path_t := FORWARDING_NONE;
signal s_ForwardBGUOperand1 : forwarding_path_t := FORWARDING_NONE;
signal s_ForwardBGUOperand2 : forwarding_path_t := FORWARDING_NONE;
signal s_ForwardMemData     : forwarding_path_t := FORWARDING_NONE;
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
---- Multithreading Support Signals
----------------------------------------------------------------------------------
signal s_StallThread : std_logic_vector(THREAD_COUNT-1 downto 0) := (others => '0');
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
---- Helper Function for Load/Store Data Size Extension
----------------------------------------------------------------------------------

function ExtendMemoryData(
    Data             : std_logic_vector(31 downto 0);
    MemoryWidth      : data_width_t;
    IsSignExtend     : std_logic;
    DestinationWidth : natural
) return std_logic_vector is
    variable Result : std_logic_vector(DestinationWidth - 1 downto 0);
begin
    case MemoryWidth is
        when BYTE_TYPE =>
            if IsSignExtend = '0' then
                Result := std_logic_vector(resize(unsigned(Data(7 downto 0)), DestinationWidth));
            else
                Result := std_logic_vector(resize(signed(Data(7 downto 0)), DestinationWidth));
            end if;

        when HALF_TYPE =>
            if IsSignExtend = '0' then
                Result := std_logic_vector(resize(unsigned(Data(15 downto 0)), DestinationWidth));
            else
                Result := std_logic_vector(resize(signed(Data(15 downto 0)), DestinationWidth));
            end if;

        when WORD_TYPE =>
            if IsSignExtend = '0' then
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

    -- NOTE: This is probably not the best way to detect a halt condition, but it will at least trap execution when two consecutive illegal instructions retire.
    o_Halt <= (MEMWB_ID_buf.Break and EXMEM_ID_buf.Break);

    n_Clock <= not i_Clock;

    with i_InstructionLoad select
        s_InstructionMemoryAddress <= 
            s_IPAddress          when '0',
            i_InstructionAddress when others;

    -----------------------------------------------------
    ---- Memory Subsystem
    -----------------------------------------------------

    e_InstructionMemory: entity work.memory
        generic map(
            ADDRESS_WIDTH => ADDRESS_WIDTH,
            DATA_WIDTH => N
        )
        port map(
            i_Clock       => i_Clock,
            i_Address     => s_InstructionMemoryAddress(11 downto 2),
            i_Data        => i_InstructionExternal,
            i_WriteEnable => i_InstructionLoad,
            o_Data        => s_Instruction
        );
  
    e_DataMemory: entity work.memory
        generic map(
            ADDRESS_WIDTH => ADDRESS_WIDTH,
            DATA_WIDTH => N
        )
        port map(
            i_Clock       => n_Clock, -- i_Clock
            i_Address     => s_DataMemoryAddress(11 downto 2),
            i_Data        => s_DataMemoryData,
            i_WriteEnable => s_DataMemoryWriteEnable,
            o_Data        => s_DataMemoryOutput
        );

    MEMWB_MEM_raw.Data <= ExtendMemoryData(s_DataMemoryOutput, MEMWB_ID_raw.MemoryWidth, '1', 32);
    IDEX_ID_raw.Data <= ExtendMemoryData(s_DataMemoryOutput, IDEX_ID_raw.MemoryWidth, '1', 32);

    -----------------------------------------------------


    -----------------------------------------------------
    ---- Instruction -> Control Unit stage register(s)
    -----------------------------------------------------

    e_IFID_RegisterIF: entity work.register_IF
        port map(
            i_Clock   => i_Clock,
            i_Reset   => i_Reset,
            i_Stall   => s_IFID_Stall or s_ALUBusy,
            i_Flush   => s_IFID_Flush,
            i_Signals => IFID_IF_raw,
            o_Signals => IFID_IF_buf
        );

    IDEX_IF_raw <= IFID_IF_buf;
        
    -----------------------------------------------------


    -----------------------------------------------------
    ---- Control Unit -> Arithmetic Logic Unit stage register(s)
    -----------------------------------------------------

    e_IDEX_RegisterIF: entity work.register_IF
        port map(
            i_Clock   => i_Clock,
            i_Reset   => i_Reset,
            i_Stall   => s_IDEX_Stall or s_ALUBusy,
            i_Flush   => s_IDEX_Flush,
            i_Signals => IDEX_IF_raw,
            o_Signals => IDEX_IF_buf
        );

    e_IDEX_Register_ID: entity work.register_ID
        port map(
            i_Clock   => i_Clock,
            i_Reset   => i_Reset,
            i_Stall   => s_IDEX_Stall or s_ALUBusy,
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

    e_EXMEM_RegisterIF: entity work.register_IF
        port map(
            i_Clock   => i_Clock,
            i_Reset   => i_Reset,
            i_Stall   => s_EXMEM_Stall or s_ALUBusy,
            i_Flush   => s_EXMEM_Flush,
            i_Signals => EXMEM_IF_raw,
            o_Signals => EXMEM_IF_buf
        );

    e_EXMEM_Register_ID: entity work.register_ID
        port map(
            i_Clock   => i_Clock,
            i_Reset   => i_Reset,
            i_Stall   => s_EXMEM_Stall or s_ALUBusy,
            i_Flush   => s_EXMEM_Flush,
            i_Signals => EXMEM_ID_raw,
            o_Signals => EXMEM_ID_buf
        );

    e_EXMEM_Register_EX: entity work.register_EX
        port map(
            i_Clock   => i_Clock,
            i_Reset   => i_Reset,
            i_Stall   => s_EXMEM_Stall or s_ALUBusy,
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

    e_MEMWB_Register_IF: entity work.register_IF
        port map(
            i_Clock   => i_Clock,
            i_Reset   => i_Reset,
            i_Stall   => s_ALUBusy,
            i_Flush   => '0',
            i_Signals => MEMWB_IF_raw,
            o_Signals => MEMWB_IF_buf
        );

    e_MEMWB_Register_ID: entity work.register_ID
        port map(
            i_Clock   => i_Clock,
            i_Reset   => i_Reset,
            i_Stall   => s_ALUBusy,
            i_Flush   => '0',
            i_Signals => MEMWB_ID_raw,
            o_Signals => MEMWB_ID_buf
        );

    e_MEMWB_RegisterEX: entity work.register_EX
        port map(
            i_Clock   => i_Clock,
            i_Reset   => i_Reset,
            i_Stall   => s_ALUBusy,
            i_Flush   => '0',
            i_Signals => MEMWB_EX_raw,
            o_Signals => MEMWB_EX_buf
        ); 
    

    e_MEMWB_RegisterMEM: entity work.register_MEM
        port map(
            i_Clock   => i_Clock,
            i_Reset   => i_Reset,
            i_Stall   => s_ALUBusy,
            i_Flush   => '0',
            i_Signals => MEMWB_MEM_raw,
            o_Signals => MEMWB_MEM_buf
        );

    -----------------------------------------------------


    -----------------------------------------------------
    ---- Register File -> x stage register(s)
    -----------------------------------------------------

    WB_WB_raw.Result      <= MEMWB_EX_buf.Result;
    WB_WB_raw.Data        <= MEMWB_MEM_buf.Data;
    WB_WB_raw.Forward     <= s_ForwardMemData;
    WB_WB_raw.MemoryWidth <= MEMWB_ID_buf.MemoryWidth;

    e_WBWB_RegisterWB: entity work.register_WB
        port map(
            i_Clock   => i_Clock,
            i_Reset   => i_Reset,
            i_Stall   => s_ALUBusy,
            i_Flush   => '0',
            i_Signals => WB_WB_raw,
            o_Signals => WB_WB_buf
        );

    -----------------------------------------------------



    -----------------------------------------------------
    ---- Instruction Pointer Unit
    -----------------------------------------------------

    s_BranchAddress <= std_logic_vector(signed(IDEX_IF_buf.InstructionAddress) + signed(IDEX_ID_buf.Immediate)) when (IDEX_ID_buf.BranchMode = BRANCHMODE_JAL_OR_BCC) else
                       std_logic_vector(signed(IDEX_ID_buf.DS1)                + signed(IDEX_ID_buf.Immediate)) when (IDEX_ID_buf.BranchMode = BRANCHMODE_JALR) else 
                       (others => '0');

    s_BranchLoad <=
        '1' when (IDEX_ID_buf.BranchMode = BRANCHMODE_JALR) else
        '1' when (IDEX_ID_buf.BranchMode = BRANCHMODE_JAL_OR_BCC and IDEX_ID_buf.IsBranch = '0') else
        (s_BranchTaken and IDEX_ID_buf.IsBranch);

    e_InstructionPointer: entity work.instruction_pointer
        generic map(
            ResetAddress => 32x"00400000"
        )
        port map(
            i_Clock       => i_Clock,
            i_Reset       => i_Reset,
            i_Stall       => s_IPBreak or s_BranchLoad or s_ALUBusy,
            i_Load        => s_BranchLoad,
            i_LoadAddress => s_BranchAddress,
            i_Stride      => '1', -- IDEX_ID_buf.IsStride4, -- NOTE: This might be 1 pipeline stage too late to increment the correct corresponding amount. But, resolving this requires instruction pre-decoding to compute length, so just assume 4-byte instructions for now
            o_Address     => s_IPAddress,
            o_LinkAddress => s_NextInstructionAddress
        );

    IFID_IF_raw.InstructionAddress <= s_IPAddress;
    IFID_IF_raw.LinkAddress        <= s_NextInstructionAddress;
    IFID_IF_raw.Instruction        <= s_Instruction;

    -----------------------------------------------------


    -----------------------------------------------------
    ---- Branch Generation Unit
    -----------------------------------------------------

    with s_ForwardBGUOperand1 select
        s_BranchOperand1 <=
            EXMEM_EX_buf.Result when FORWARDING_FROMEXMEM_ALU,
            MEMWB_EX_buf.Result when FORWARDING_FROMMEMWB_ALU,
            MEMWB_MEM_buf.Data  when FORWARDING_FROMMEM,
            IDEX_ID_buf.DS1     when others;

    with s_ForwardBGUOperand2 select
        s_BranchOperand2 <= 
            EXMEM_EX_buf.Result when FORWARDING_FROMEXMEM_ALU,
            MEMWB_EX_buf.Result when FORWARDING_FROMMEMWB_ALU,
            MEMWB_MEM_buf.Data  when FORWARDING_FROMMEM,
            IDEX_ID_buf.DS2     when others;

    e_BranchUnit: entity work.branch_unit
        port map(
            i_Clock          => i_Clock,
            i_DS1            => s_BranchOperand1,
            i_DS2            => s_BranchOperand2,
            i_BranchOperator => IDEX_ID_buf.BranchOperator,
            o_BranchTaken    => s_BranchTaken,
            o_BranchNotTaken => s_BranchNotTaken
        );

    -----------------------------------------------------


    -----------------------------------------------------
    ---- Processor Control Unit
    -----------------------------------------------------

    e_ControlUnit: entity work.control_unit
        port map(
            i_Clock                   => i_Clock,
            i_Reset                   => i_Reset,
            i_Instruction             => IDEX_IF_raw.Instruction,
            i_ThreadId                => IDEX_IF_raw.ThreadId,
            o_MemoryWriteEnable       => IDEX_ID_raw.MemoryWriteEnable,
            o_RegisterFileWriteEnable => IDEX_ID_raw.RegisterFileWriteEnable,
            o_RegisterSource          => IDEX_ID_raw.RegisterSource,
            o_ALUSource               => IDEX_ID_raw.ALUSource,
            o_ALUOperator             => IDEX_ID_raw.ALUOperator,
            o_BranchOperator          => IDEX_ID_raw.BranchOperator,
            o_MemoryWidth             => IDEX_ID_raw.MemoryWidth,
            o_BranchMode              => IDEX_ID_raw.BranchMode,
            o_RD                      => IDEX_ID_raw.RD,
            o_RS1                     => IDEX_ID_raw.RS1,
            o_RS2                     => IDEX_ID_raw.RS2,
            o_Immediate               => IDEX_ID_raw.Immediate,
            o_Break                   => IDEX_ID_raw.Break,
            o_IsBranch                => IDEX_ID_raw.IsBranch,
            o_IPToALU                 => IDEX_ID_raw.IPToALU,
            o_IsStride4               => IDEX_ID_raw.IsStride4,
            o_IsSignExtend            => IDEX_ID_raw.IsSignExtend,
            o_StallThread             => s_StallThread
        );

    IDEX_ID_raw.DS1 <= s_RS1Data;
    IDEX_ID_raw.DS2 <= s_RS2Data;

    -----------------------------------------------------


    -----------------------------------------------------
    ---- Register File Subsystem
    -----------------------------------------------------

    with MEMWB_ID_buf.RegisterSource select
        s_RegisterFileData <=
            MEMWB_MEM_buf.Data       when RFSOURCE_FROMRAM,
            MEMWB_EX_buf.Result      when RFSOURCE_FROMALU,
            MEMWB_IF_buf.LinkAddress when RFSOURCE_FROMNEXTIP,
            MEMWB_ID_buf.Immediate   when RFSOURCE_FROMIMMEDIATE,
            (others => '0')          when others;


    s_RegisterFileWriteEnable <= MEMWB_ID_buf.RegisterFileWriteEnable and not s_ALUBusy;
    s_RegisterFileSelect <= MEMWB_ID_buf.RD;

    e_RegisterFile: entity work.register_file
        port map(
            i_Clock       => n_Clock,
            i_Reset       => i_Reset,
            i_RS1         => IDEX_ID_raw.RS1, -- NOTE: registers reads occur in the decode stage unless forwarding
            i_RS2         => IDEX_ID_raw.RS2,
            i_RD          => s_RegisterFileSelect,
            i_WriteEnable => s_RegisterFileWriteEnable,
            i_D           => s_RegisterFileData,
            o_DS1         => s_RS1Data,
            o_DS2         => s_RS2Data
        );

    -----------------------------------------------------


    -----------------------------------------------------
    ---- Arithmetic Logic Unit
    -----------------------------------------------------

    s_MemALUOperand1 <= MEMWB_MEM_buf.Data when (MEMWB_ID_buf.MemoryWidth /= NONE_TYPE) else
                        MEMWB_EX_buf.Result;

    s_MemALUOperand2 <= MEMWB_MEM_buf.Data when (MEMWB_ID_buf.MemoryWidth /= NONE_TYPE) else
                        MEMWB_EX_buf.Result;

    with s_ForwardALUOperand1 select
        s_ALUOperand1 <=
            EXMEM_EX_buf.Result when FORWARDING_FROMEX,
            s_MemALUOperand1    when FORWARDING_FROMMEM,
            MEMWB_EX_buf.Result when FORWARDING_FROMMEMWB_ALU,
            IDEX_ID_buf.DS1     when others;

    with s_ForwardALUOperand2 select
        s_RealALUOperand2 <=
            EXMEM_EX_buf.Result when FORWARDING_FROMEX,
            MEMWB_EX_buf.Result when FORWARDING_FROMMEMWB_ALU,
            s_MemALUOperand2    when FORWARDING_FROMMEM,
            s_ALUOperand2       when others;

    -- NOTE: only the first operand is backwards here because IPToALU (for `auipc`) must take precedence over any potential data forwarding
    s_RealALUOperand1 <= (others => '0')                when (IDEX_ID_buf.ALUSource  = ALUSOURCE_BIGIMMEDIATE) else
                         IDEX_IF_buf.InstructionAddress when (IDEX_ID_buf.IPToALU = '1') else
                         s_ALUOperand1                  when (IDEX_ID_buf.IPToALU = '0') else
                         (others => '0');

    s_ALUOperand2 <= IDEX_ID_buf.Immediate when (IDEX_ID_buf.ALUSource = ALUSOURCE_IMMEDIATE) else
                     IDEX_ID_buf.Immediate when (IDEX_ID_buf.ALUSource = ALUSOURCE_BIGIMMEDIATE) else
                     IDEX_ID_buf.DS2       when (IDEX_ID_buf.ALUSource = ALUSOURCE_REGISTER) else
                     (others => '0');

    e_ArithmeticLogicUnit: entity work.arithmetic_logic_unit
        port map(
            i_Clock    => i_Clock,
            i_Reset    => i_Reset,
            i_A        => s_RealALUOperand1,
            i_B        => s_RealALUOperand2,
            i_Operator => EXMEM_ID_raw.ALUOperator,
            o_F        => EXMEM_EX_raw.Result,
            o_Carry    => EXMEM_EX_raw.CarryOut,
            o_Done     => s_ALUDone
        );

    s_ALUBusy <= '1' when IsMulticycleALUOperator(IDEX_ID_buf.ALUOperator) and (s_ALUDone = '0') else 
                 '0';

    o_ALUOutput <= EXMEM_EX_raw.Result;

    -----------------------------------------------------

        
    -----------------------------------------------------
    ---- Data Memory Subsystem
    -----------------------------------------------------

    with i_DataLoad select
        s_DataMemoryAddress <= 
            i_DataAddress       when '1',
            EXMEM_EX_buf.Result when others;

    with i_DataLoad select
        s_DataMemoryData <= 
            i_DataExternal     when '1',
            s_DataMemoryBuffer when others;

    s_EXMEM_MemoryWriteEnable <= EXMEM_ID_buf.MemoryWriteEnable and not s_ALUBusy;

    with i_DataLoad select
        s_DataMemoryWriteEnable <= 
            '1'                       when '1',
            s_EXMEM_MemoryWriteEnable when others;

    with WB_WB_buf.Forward select 
        s_ForwardedDMemData <= 
            ExtendMemoryData(WB_WB_buf.Data,      WB_WB_buf.MemoryWidth,    '1', 32) when FORWARDING_FROMMEM,
            ExtendMemoryData(MEMWB_EX_buf.Result, MEMWB_ID_buf.MemoryWidth, '1', 32) when FORWARDING_FROMEXMEM_ALU,
            ExtendMemoryData(WB_WB_buf.Result,    WB_WB_buf.MemoryWidth,    '1', 32) when FORWARDING_FROMMEMWB_ALU,
            (others => '0')   when others;

    s_DataMemoryBuffer <= s_ForwardedDMemData when (WB_WB_buf.Forward /= FORWARDING_NONE) else
        std_logic_vector(resize(unsigned(EXMEM_ID_buf.DS2(7  downto 0)), s_DataMemoryBuffer'length)) when (EXMEM_ID_buf.MemoryWidth = BYTE_TYPE) else
        std_logic_vector(resize(unsigned(EXMEM_ID_buf.DS2(15 downto 0)), s_DataMemoryBuffer'length)) when (EXMEM_ID_buf.MemoryWidth = HALF_TYPE) else
        std_logic_vector(resize(unsigned(EXMEM_ID_buf.DS2(31 downto 0)), s_DataMemoryBuffer'length)) when (EXMEM_ID_buf.MemoryWidth = WORD_TYPE) else
        (others => '0');

    -----------------------------------------------------


    -----------------------------------------------------
    ---- Hardware Pipeline Scheduling
    -----------------------------------------------------
        
    -- NOTE: IsLoad is simply set when the instruction is a load or store instruction.
    -- Hence, any hazard checks will need to also inspect for memory or register write 
    -- to determine to which case a particular hazard corresponds.

    s_IFID_IsLoad  <= '1' when (IDEX_ID_raw.MemoryWidth  /= NONE_TYPE) else '0';
    s_IDEX_IsLoad  <= '1' when (IDEX_ID_buf.MemoryWidth  /= NONE_TYPE) else '0';
    s_EXMEM_IsLoad <= '1' when (EXMEM_ID_buf.MemoryWidth /= NONE_TYPE) else '0';
    s_MEMWB_IsLoad <= '1' when (MEMWB_ID_buf.MemoryWidth /= NONE_TYPE) else '0';
    
    e_HazardUnit: entity work.hazard_unit
        port map(
            i_IFID_RS1               => IDEX_ID_raw.RS1,
            i_IFID_RS2               => IDEX_ID_raw.RS2,
            i_IFID_IsLoad            => s_IFID_IsLoad,
            i_IFID_MemoryWriteEnable => IDEX_ID_raw.MemoryWriteEnable,

            i_IDEX_RS1       => IDEX_ID_buf.RS1,
            i_IDEX_RS2       => IDEX_ID_buf.RS2,
            i_IDEX_RD        => IDEX_ID_buf.RD,
            i_IDEX_IsLoad    => s_IDEX_IsLoad,

            i_EXMEM_RS1                     => EXMEM_ID_buf.RS1,
            i_EXMEM_RS2                     => EXMEM_ID_buf.RS2,
            i_EXMEM_RD                      => EXMEM_ID_buf.RD,
            i_EXMEM_IsLoad                  => s_EXMEM_IsLoad,
            i_EXMEM_RegisterFileWriteEnable => EXMEM_ID_buf.RegisterFileWriteEnable,

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

    e_ForwardingUnit: entity work.forwarding_unit
        port map(
            i_IFID_RS1              => IDEX_ID_raw.RS1,
            i_IFID_RS2              => IDEX_ID_raw.RS2,
            i_IFID_IsLoad           => s_IFID_IsLoad,

            i_IDEX_RS1               => IDEX_ID_buf.RS1,
            i_IDEX_RS2               => IDEX_ID_buf.RS2,
            i_IDEX_MemoryWriteEnable => IDEX_ID_buf.MemoryWriteEnable,
            i_IDEX_IsLoad            => s_IDEX_IsLoad,
            i_IDEX_ALUSource         => IDEX_ID_buf.ALUSource,

            i_EXMEM_RS1                     => EXMEM_ID_buf.RS1,
            i_EXMEM_RS2                     => EXMEM_ID_buf.RS2,
            i_EXMEM_RD                      => EXMEM_ID_buf.RD,
            i_EXMEM_RegisterFileWriteEnable => EXMEM_ID_buf.RegisterFileWriteEnable,
            i_EXMEM_MemoryWriteEnable       => s_EXMEM_MemoryWriteEnable,
            i_EXMEM_IsLoad                  => s_EXMEM_IsLoad,

            i_MEMWB_RD                      => MEMWB_ID_buf.RD,
            i_MEMWB_RegisterFileWriteEnable => MEMWB_ID_buf.RegisterFileWriteEnable,
            i_MEMWB_MemoryWriteEnable       => MEMWB_ID_buf.MemoryWriteEnable,
            i_MEMWB_IsLoad                  => s_MEMWB_IsLoad,

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

end implementation;
