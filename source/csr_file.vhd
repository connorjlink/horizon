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
        i_CSR_WriteAddress       : in  csr_address_vector_t;
        i_CSR_WriteData          : in  data_vector_t;
        i_CSR_WriteEnable        : in  std_logic;
        i_CSR_InstructionRetired : in  std_logic;
        i_TrapTaken              : in  std_logic;
        i_TrapReturn             : in  std_logic; -- for MRET instruction only
        -- TODO: integrate SRET and URET privilege level transitions from returns
        i_ExceptionIP            : in  address_vector_t;
        i_FaultValue             : in  address_vector_t;
        i_MCause                 : in  std_logic_vector(3 downto 0);

        o_CSR_ReadData           : out data_vector_t;
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
    signal s_MSTATUS_Q   : data_vector_t;
    signal s_MEPC_Q      : data_vector_t;
    signal s_MCAUSE_Q    : data_vector_t;
    signal s_MTVAL_Q     : data_vector_t;
    signal s_MTVEC_Q     : data_vector_t;
    signal s_MSCRATCH_Q  : data_vector_t;
    -- Signals to hold data inputs
    signal s_D_MSTATUS   : data_vector_t;
    signal s_D_MEPC      : data_vector_t;
    signal s_D_MCAUSE    : data_vector_t;
    signal s_D_MTVAL     : data_vector_t;

    -- Signals to hold write-enable logic
    signal s_WE_MSTATUS  : std_logic;
    signal s_WE_MEPC     : std_logic;
    signal s_WE_MCAUSE   : std_logic;
    signal s_WE_MTVAL    : std_logic;
    signal s_WE_MTVEC    : std_logic;
    signal s_WE_MSCRATCH : std_logic;
    signal s_WE_MCYCLE   : std_logic;
    signal s_WE_MINSTRET : std_logic;

    -- Signals to hold performance counter values
    -- TODO: update using custom generic adder
    signal s_MCYCLE_Q    : wide_data_vector_t := (others => '0');
    signal s_MCYCLE_D    : wide_data_vector_t;
    signal s_MINSTRET_Q  : wide_data_vector_t := (others => '0');
    signal s_MINSTRET_D  : wide_data_vector_t;

    -- Privilege level tracking
    signal s_PrivilegeLevel : privilege_level_t := MACHINE_MODE;

begin

    -- Hardwired outputs
    o_MTVEC_Base     <= s_MTVEC_Q;
    o_MEPC           <= s_MEPC_Q;
    o_PrivilegeLevel <= s_PrivilegeLevel;

    -----------------------------------------------------
    -- CSR Read Logic
    -----------------------------------------------------

    process(
        all
    )
    begin
        case i_CSR_ReadAddress is
            when CSR_MSTATUS   => o_CSR_ReadData <= s_MSTATUS_Q;
            when CSR_MTVEC     => o_CSR_ReadData <= s_MTVEC_Q;
            when CSR_MSCRATCH  => o_CSR_ReadData <= s_MSCRATCH_Q;
            when CSR_MEPC      => o_CSR_ReadData <= s_MEPC_Q;
            when CSR_MCAUSE    => o_CSR_ReadData <= s_MCAUSE_Q;
            when CSR_MTVAL     => o_CSR_ReadData <= s_MTVAL_Q;
            when CSR_MCYCLE    => o_CSR_ReadData <= s_MCYCLE_Q(DATA_WIDTH-1 downto 0);
            when CSR_MCYCLEH   => o_CSR_ReadData <= s_MCYCLE_Q(63 downto DATA_WIDTH);
            when CSR_MINSTRET  => o_CSR_ReadData <= s_MINSTRET_Q(DATA_WIDTH-1 downto 0);
            when CSR_MINSTRETH => o_CSR_ReadData <= s_MINSTRET_Q(63 downto DATA_WIDTH);
            when others        => o_CSR_ReadData <= (others => '0');

        end case;

    end process;

    -----------------------------------------------------


    -----------------------------------------------------
    -- Write enable logic
    -----------------------------------------------------

    s_WE_MSTATUS  <= '1' when (i_CSR_WriteEnable = '1' and i_CSR_WriteAddress = CSR_MSTATUS) else '0'; 
    s_WE_MTVEC    <= '1' when (i_CSR_WriteEnable = '1' and i_CSR_WriteAddress = CSR_MTVEC) else '0';
    s_WE_MSCRATCH <= '1' when (i_CSR_WriteEnable = '1' and i_CSR_WriteAddress = CSR_MSCRATCH) else '0';
    
    -- Hardware traps take priority for architectural state changes
    s_WE_MEPC     <= '1' when i_TrapTaken = '1' else 
                     '1' when (i_CSR_WriteEnable = '1' and i_CSR_WriteAddress = CSR_MEPC) else 
                     '0';
    
    s_WE_MCAUSE   <= '1' when i_TrapTaken = '1' else 
                     '1' when (i_CSR_WriteEnable = '1' and i_CSR_WriteAddress = CSR_MCAUSE) else 
                     '0';
                     
    s_WE_MTVAL    <= '1' when i_TrapTaken = '1' else 
                     '1' when (i_CSR_WriteEnable = '1' and i_CSR_WriteAddress = CSR_MTVAL) else 
                     '0';

    s_D_MEPC      <= i_ExceptionIP when i_TrapTaken = '1' else i_CSR_WriteData;
    s_D_MCAUSE    <= x"0000000" & i_MCause when i_TrapTaken = '1' else i_CSR_WriteData;
    s_D_MTVAL     <= i_FaultValue when i_TrapTaken = '1' else i_CSR_WriteData;
    s_D_MSTATUS   <= i_CSR_WriteData;
    -- TODO: add hardware trap logic to set MPIE/MPP in MSTATUS here

    -----------------------------------------------------


    -----------------------------------------------------
    -- CSR register generation
    -----------------------------------------------------
    REG_MSTATUS  : entity work.register_N generic map(N => 32) port map(i_Clock => i_Clock, i_Reset => i_Reset, i_WriteEnable => s_WE_MSTATUS,  i_D => s_D_MSTATUS,     o_Q => s_MSTATUS_Q);
    REG_MTVEC    : entity work.register_N generic map(N => 32) port map(i_Clock => i_Clock, i_Reset => i_Reset, i_WriteEnable => s_WE_MTVEC,    i_D => i_CSR_WriteData, o_Q => s_MTVEC_Q);
    REG_MSCRATCH : entity work.register_N generic map(N => 32) port map(i_Clock => i_Clock, i_Reset => i_Reset, i_WriteEnable => s_WE_MSCRATCH, i_D => i_CSR_WriteData, o_Q => s_MSCRATCH_Q);
    REG_MEPC     : entity work.register_N generic map(N => 32) port map(i_Clock => i_Clock, i_Reset => i_Reset, i_WriteEnable => s_WE_MEPC,     i_D => s_D_MEPC,        o_Q => s_MEPC_Q);
    REG_MCAUSE   : entity work.register_N generic map(N => 32) port map(i_Clock => i_Clock, i_Reset => i_Reset, i_WriteEnable => s_WE_MCAUSE,   i_D => s_D_MCAUSE,      o_Q => s_MCAUSE_Q);
    REG_MTVAL    : entity work.register_N generic map(N => 32) port map(i_Clock => i_Clock, i_Reset => i_Reset, i_WriteEnable => s_WE_MTVAL,    i_D => s_D_MTVAL,       o_Q => s_MTVAL_Q);


    -----------------------------------------------------
    -- Zicntr performance counters
    -- TODO: accommodate 64-bit hardware adders
    -----------------------------------------------------
    s_MCYCLE_D   <= std_logic_vector(unsigned(s_MCYCLE_Q) + 1);
    s_MINSTRET_D <= std_logic_vector(unsigned(s_MINSTRET_Q) + 1);

    REG_MCYCLE_LOW: entity work.register_N generic map(N => 32) port map(i_Clock => i_Clock, i_Reset => i_Reset, i_WriteEnable => '1', i_D => s_MCYCLE_D(31 downto 0), o_Q => s_MCYCLE_Q(31 downto 0));
    REG_MCYCLE_HIGH : entity work.register_N generic map(N => 32) port map(i_Clock => i_Clock, i_Reset => i_Reset, i_WriteEnable => '1', i_D => s_MCYCLE_D(63 downto 32), o_Q => s_MCYCLE_Q(63 downto 32));

    REG_MINSTRET_LOW  : entity work.register_N generic map(N => 32) port map(i_Clock => i_Clock, i_Reset => i_Reset, i_WriteEnable => i_InstructionRetired, i_D => s_MINSTRET_D(31 downto 0), o_Q => s_MINSTRET_Q(31 downto 0));
    REG_MINSTRET_HIGH : entity work.register_N generic map(N => 32) port map(i_Clock => i_Clock, i_Reset => i_Reset, i_WriteEnable => i_InstructionRetired, i_D => s_MINSTRET_D(63 downto 32), o_Q => s_MINSTRET_Q(63 downto 32));

end implementation;