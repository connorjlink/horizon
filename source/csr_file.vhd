-- Horizon: csr_file.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity csr_file is
    port(
        i_Clock                  : in  std_logic;
        i_Reset                  : in  std_logic;

        i_CSR_ReadAddress        : in  csr_address_vector_t;
        i_CSRWriteAddress        : in  csr_address_vector_t;
        i_CSRWriteData           : in  data_vector_t;
        i_CSR_WriteEnable        : in  std_logic;
        i_CSR_InstructionRetired : in  std_logic;
        i_TrapTaken              : in  std_logic;
        i_TrapReturn             : in  std_logic; -- for MRET instruction only
        -- TODO: integrate SRET and URET privilege level transitions from returns
        i_ExceptionIP            : in  address_vector_t;
        i_FaultValue             : in  address_vector_t;
        i_MCAUSE                 : in  std_logic_vector(3 downto 0);

        o_CSRReadData            : out data_vector_t;
        o_MTVEC_Base             : out address_vector_t;
        o_MEPC                   : out address_vector_t;
        o_PrivilegeLevel         : out privilege_level_t
    );
end csr_file;

architecture implementation of csr_file is

    -- CSR address constants
    constant CSR_MSTATUS   : csr_address_vector_t := x"300";
    constant CSR_MTVEC     : csr_address_vector_t := x"305";
    constant CSR_MSCRATCH  : csr_address_vector_t := x"340";
    constant CSR_MEPC      : csr_address_vector_t := x"341";
    constant CSR_MCAUSE    : csr_address_vector_t := x"342";
    constant CSR_MTVAL     : csr_address_vector_t := x"343";
    constant CSR_MCYCLE    : csr_address_vector_t := x"B00";
    constant CSR_MCYCLEH   : csr_address_vector_t := x"B80";
    constant CSR_MINSTRET  : csr_address_vector_t := x"B02";
    constant CSR_MINSTRETH : csr_address_vector_t := x"B82";

    -- Signals for internal CSR state
    signal s_MSTATUSOutput  : data_vector_t;
    signal s_MEPCOutput     : data_vector_t;
    signal s_MCAUSEOutput   : data_vector_t;
    signal s_MTVALOutput    : data_vector_t;
    signal s_MTVECOutput    : data_vector_t;
    signal s_MSCRATCHOutput : data_vector_t;
    signal s_MCYCLEOutput   : wide_data_vector_t := (others => '0');
    signal s_MINSTRETOutput : wide_data_vector_t := (others => '0');

    -- Signals to hold data inputs
    signal s_MEPCData     : data_vector_t;
    signal s_MCAUSEData   : data_vector_t;
    signal s_MTVALData    : data_vector_t;
    signal s_MCYCLEData   : wide_data_vector_t;
    signal s_MINSTRETData : wide_data_vector_t;

    -- Signals to hold write-enable logic
    signal s_MSTATUSWriteEnable  : std_logic;
    signal s_MEPCWriteEnable     : std_logic;
    signal s_MCAUSEWriteEnable   : std_logic;
    signal s_MTVALWriteEnable    : std_logic;
    signal s_MTVECWriteEnable    : std_logic;
    signal s_MSCRATCHWriteEnable : std_logic;
    signal s_MCYCLEWriteEnable   : std_logic;
    signal s_MINSTRETWriteEnable : std_logic;

    -- Privilege level tracking
    signal s_PrivilegeLevel : privilege_level_t := MACHINE_MODE;


    -----------------------------------------------------
    -- Helper functions for CSR write enablement
    -----------------------------------------------------

    function CSRWriteEnable(
        WriteEnable   : std_logic;
        WriteAddress  : csr_address_vector_t;
        TargetAddress : csr_address_vector_t
    ) return std_logic is
    begin
        if WriteEnable = '1' and WriteAddress = TargetAddress then
            return '1';
        else
            return '0';

        end if;

    end function;

    function CSRWriteEnableTrapPriority(
        TrapTaken     : std_logic;
        WriteEnable   : std_logic;
        WriteAddress  : csr_address_vector_t;
        TargetAddress : csr_address_vector_t
    ) return std_logic is
    begin
        if TrapTaken = '1' and WriteEnable = '1' and WriteAddress = TargetAddress then
            return '1';
        else
            return '0';

        end if;

    end function;

    -----------------------------------------------------

begin

    -----------------------------------------------------
    -- CSR read logic
    -----------------------------------------------------

    -- Hardwired outputs
    o_MTVEC_Base     <= s_MTVECOutput;
    o_MEPC           <= s_MEPCOutput;
    o_PrivilegeLevel <= s_PrivilegeLevel;

    process(
        all
    )
    begin
        case i_CSR_ReadAddress is
            when CSR_MSTATUS   => o_CSRReadData <= s_MSTATUSOutput;
            when CSR_MTVEC     => o_CSRReadData <= s_MTVECOutput;
            when CSR_MSCRATCH  => o_CSRReadData <= s_MSCRATCHOutput;
            when CSR_MEPC      => o_CSRReadData <= s_MEPCOutput;
            when CSR_MCAUSE    => o_CSRReadData <= s_MCAUSEOutput;
            when CSR_MTVAL     => o_CSRReadData <= s_MTVALOutput;
            when CSR_MCYCLE    => o_CSRReadData <= s_MCYCLEOutput(DATA_WIDTH-1 downto 0);
            when CSR_MCYCLEH   => o_CSRReadData <= s_MCYCLEOutput(63 downto DATA_WIDTH);
            when CSR_MINSTRET  => o_CSRReadData <= s_MINSTRETOutput(DATA_WIDTH-1 downto 0);
            when CSR_MINSTRETH => o_CSRReadData <= s_MINSTRETOutput(63 downto DATA_WIDTH);
            when others        => o_CSRReadData <= (others => '0');

        end case;

    end process;

    -----------------------------------------------------


    -----------------------------------------------------
    -- CSR write logic
    -----------------------------------------------------

    s_MSTATUSWriteEnable  <= CSRWriteEnable(i_CSR_WriteEnable, i_CSRWriteAddress, CSR_MSTATUS);
    s_MTVECWriteEnable    <= CSRWriteEnable(i_CSR_WriteEnable, i_CSRWriteAddress, CSR_MTVEC);
    s_MSCRATCHWriteEnable <= CSRWriteEnable(i_CSR_WriteEnable, i_CSRWriteAddress, CSR_MSCRATCH);
    -- NOTE: Hardware traps take priority for architectural state changes
    s_MEPCWriteEnable   <= CSRWriteEnableTrapPriority(i_TrapTaken, i_CSR_WriteEnable, i_CSRWriteAddress, CSR_MEPC);
    s_MCAUSEWriteEnable <= CSRWriteEnableTrapPriority(i_TrapTaken, i_CSR_WriteEnable, i_CSRWriteAddress, CSR_MCAUSE);
    s_MTVALWriteEnable  <= CSRWriteEnableTrapPriority(i_TrapTaken, i_CSR_WriteEnable, i_CSRWriteAddress, CSR_MTVAL);

    s_MEPCData     <= i_ExceptionIP         when i_TrapTaken = '1' else i_CSRWriteData;
    s_MCAUSEData   <= x"0000000" & i_MCAUSE when i_TrapTaken = '1' else i_CSRWriteData;
    s_MTVALData    <= i_FaultValue          when i_TrapTaken = '1' else i_CSRWriteData;
    
    -- Zicsr/Zicntr performance counter registers
    -- TODO: use hardware adders instead of unsigned increment
    s_MCYCLEData   <= std_logic_vector(unsigned(s_MCYCLEOutput) + 1);
    s_MINSTRETData <= std_logic_vector(unsigned(s_MINSTRETOutput) + 1);


    -- TODO: add hardware trap logic to set MPIE/MPP in MSTATUS here

    -----------------------------------------------------


    -----------------------------------------------------
    -- CSR register generation
    -----------------------------------------------------

    e_MSTATUS: entity work.register_N 
        generic map(
            N => 32
        ) 
        port map(
            i_Clock       => i_Clock, 
            i_Reset       => i_Reset, 
            i_WriteEnable => s_MSTATUSWriteEnable,
            i_D           => i_CSRWriteData,
            o_Q           => s_MSTATUSOutput
        );

    e_MTVEC: entity work.register_N 
        generic map(
            N => 32
        ) 
        port map(
            i_Clock       => i_Clock, 
            i_Reset       => i_Reset, 
            i_WriteEnable => s_MTVECWriteEnable,    
            i_D           => i_CSRWriteData, 
            o_Q           => s_MTVECOutput
        );

    e_MSCRATCH: entity work.register_N
        generic map(
            N => 32
        ) 
        port map(
            i_Clock       => i_Clock, 
            i_Reset       => i_Reset, 
            i_WriteEnable => s_MSCRATCHWriteEnable, 
            i_D           => i_CSRWriteData, 
            o_Q           => s_MSCRATCHOutput
        );

    e_MEPC: entity work.register_N
        generic map(
            N => 32
        ) 
        port map(
            i_Clock       => i_Clock, 
            i_Reset       => i_Reset, 
            i_WriteEnable => s_MEPCWriteEnable, 
            i_D           => s_MEPCData, 
            o_Q           => s_MEPCOutput
        );

    e_MCAUSE: entity work.register_N 
        generic map(
            N => 32
        ) 
        port map(
            i_Clock       => i_Clock, 
            i_Reset       => i_Reset, 
            i_WriteEnable => s_MCAUSEWriteEnable, 
            i_D           => s_MCAUSEData, 
            o_Q           => s_MCAUSEOutput
        );
        
    e_MTVAL: entity work.register_N 
        generic map(
            N => 32
        ) 
        port map(
            i_Clock       => i_Clock, 
            i_Reset       => i_Reset, 
            i_WriteEnable => s_MTVALWriteEnable, 
            i_D           => s_MTVALData, 
            o_Q           => s_MTVALOutput
        );

    e_MCYCLELow: entity work.register_N 
        generic map(
            N => 32
        ) 
        port map(
            i_Clock       => i_Clock, 
            i_Reset       => i_Reset, 
            i_WriteEnable => '1', 
            i_D           => s_MCYCLEData(31 downto 0), 
            o_Q           => s_MCYCLEOutput(31 downto 0)
        );

    e_MCYCLEHigh: entity work.register_N 
        generic map(
            N => 32
        ) 
        port map(
            i_Clock       => i_Clock, 
            i_Reset       => i_Reset, 
            i_WriteEnable => '1', -- always write
            i_D           => s_MCYCLEData(63 downto 32), 
            o_Q           => s_MCYCLEOutput(63 downto 32)
        );

    e_MINSTRETLow: entity work.register_N 
        generic map(
            N => 32
        ) 
        port map(
            i_Clock       => i_Clock, 
            i_Reset       => i_Reset, 
            i_WriteEnable => i_InstructionRetired, 
            i_D           => s_MINSTRETData(31 downto 0), 
            o_Q           => s_MINSTRETOutput(31 downto 0)
        );
    e_MINSTRETHigh: entity work.register_N 
        generic map(
            N => 32
        ) 
        port map(
            i_Clock       => i_Clock, 
            i_Reset       => i_Reset, 
            i_WriteEnable => i_InstructionRetired, 
            i_D           => s_MINSTRETData(63 downto 32), 
            o_Q           => s_MINSTRETOutput(63 downto 32)
        );

    -----------------------------------------------------

end implementation;
