-- Horizon: exception_handler.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity exception_handler is
    port(
        i_Clock              : in  std_logic;
        i_Reset              : in  std_logic;

        -- Fault Triggers
        i_Interrupt          : in  std_logic;
        i_MCause             : in  std_logic_vector(3 downto 0);
        i_ValidCommit        : in  std_logic;

        -- Fault Context
        i_ExceptionIP        : in  address_vector_t;
        i_FaultValue         : in  address_vector_t; -- faulting address or instruction
        i_MTVEC_Base         : in  address_vector_t;
        i_PrivilegeLevel     : in  privilege_level_t;

        -- Pipeline Control
        o_Flush              : out std_logic;
        o_TrapTaken          : out std_logic;
        o_TrapIP             : out address_vector_t;

        -- CSR Updates
        o_CSRWriteEnable     : out std_logic;
        o_MEPC               : out address_vector_t;
        o_MCauseUpdate       : out std_logic_vector(3 downto 0);
        o_MTVAL              : out address_vector_t
    );
end exception_handler;

architecture implementation of exception_handler is

    signal s_TakeTrap : std_logic;

begin

    -- A trap is taken on a valid commit cycle if an interrupt or exception is flagged
    s_TakeTrap <= i_ValidCommit and (i_Interrupt or i_ExceptionValid);

    -- Flush the pipeline stages and signal the trap transition to the control unit
    o_Flush     <= s_TakeTrap;
    o_TrapTaken <= s_TakeTrap;

    -- Load the instruction pointer with the trap vector base address
    -- Note: Vectored mode for interrupts would calculate an offset here (MTVEC_Base + 4 * MCause)
    o_TrapIP <= i_MTVEC_Base;

    -- Pass contextual data along to be written into the CSR file
    o_CSRWriteEnable <= s_TakeTrap;
    o_MEPC           <= i_ExceptionIP;
    o_MCauseUpdate   <= i_MCause;
    o_MTVAL          <= i_FaultValue;

    -----------------------------------------------------
    -- Notes on exception cause encodings
    -----------------------------------------------------

    -- Interrupt 0: exceptions
    -- Mcause == 0: Instruction address misaligned
    -- MCause == 1: Illegal instruction
    -- Mcause == 2: Illegal instruction
    -- Mcause == 3: Breakpoint
    -- Mcause == 4: Load address misaligned
    -- Mcause == 5: Load access fault
    -- Mcause == 6: Store/AMO address misaligned
    -- Mcause == 7: Store/AMO access fault
    -- Mcause == 8: Environment call from U-mode or VU-mode
    -- Mcause == 9: Environment call from HS-mode
    -- Mcause == 10: Environment call from VS-mode
    -- Mcause == 11: Environment call from M-mode
    -- Mcause == 12: Instruction page fault
    -- Mcause == 13: Load page fault
    -- Mcause == 14: reserved
    -- Mcause == 15: Store/AMO page fault
    -- Mcause == 16-19: reserved
    -- Mcause == 20: Instruction guest-page fault
    -- Mcause == 21: Load guest-page fault
    -- Mcause == 22: Store/AMO guest-page fault
    -- Mcause == 23-31: reserved

    -- Interrupt 1: interrupts
    -- Mcause == 0: reserved
    -- Mcause == 1: Supervisor software interrupt
    -- Mcause == 2: Virtual supervisor software interrupt
    -- Mcause == 3: Machine software interrupt
    -- Mcause == 4: reserved
    -- Mcause == 5: Supervisor timer interrupt
    -- Mcause == 6: Virtual supervisor timer interrupt
    -- Mcause == 7: Machine timer interrupt
    -- Mcause == 8: reserved
    -- Mcause == 9: Supervisor external interrupt
    -- Mcause == 10: Virtual supervisor external interrupt
    -- Mcause == 11: Machine external interrupt
    -- Mcause == 12: Supervisor guest external interrupt
    -- Mcause == 13-31: reserved

end implementation;
