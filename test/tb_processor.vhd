-- Horizon: tb_processor.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
use IEEE.numeric_std.all;
library std;
use std.env.all;
use std.textio.all;
library work;
use work.types.all;

entity tb_processor is
    generic(
        constant CLOCK_HALF_PERIOD : time    := 10 ns;
        constant DATA_WIDTH        : integer := 32;
        constant IS_DEBUG          : boolean := false;
        constant BINARY_DIRECTORY  : string;
        constant TRACE_DIRECTORY   : string;
        constant TEST_FILE         : string;
        constant HEX_FILE          : string  := BINARY_DIRECTORY & TEST_FILE;
        constant TRACE_FILE        : string  := TRACE_DIRECTORY & TEST_FILE & ".ghdl.trace";
        constant DATA_FILE         : string  := HEX_FILE & "_d.hex";
        constant INSTRUCTION_FILE  : string  := HEX_FILE & "_i.hex"
    );
end tb_processor;

architecture implementation of tb_processor is

constant CLOCK_PERIOD : time := CLOCK_HALF_PERIOD * 2;

-- Testbench signals
signal s_Clock, s_Reset : std_logic := '0';
signal s_TraceEnable    : std_logic := '0';

-- Stimulus signals
signal s_iInstructionLoad     : std_logic := '0';
signal s_iInstructionAddress  : std_logic_vector(31 downto 0) := (others => '0');
signal s_iInstructionExternal : std_logic_vector(31 downto 0) := (others => '0');
signal s_iDataLoad            : std_logic := '0';
signal s_iDataAddress         : std_logic_vector(31 downto 0) := (others => '0');
signal s_iDataExternal        : std_logic_vector(31 downto 0) := (others => '0');
signal s_oALUOutput           : std_logic_vector(31 downto 0);
signal s_oHalt                : std_logic;

procedure LoadInstructionMemory(
    signal   i_Clock               : in  std_logic;
    signal   o_InstructionLoad     : out std_logic;
    signal   o_InstructionAddress  : out std_logic_vector(31 downto 0);
    signal   o_InstructionExternal : out std_logic_vector(31 downto 0);
    constant FileName              : in  string;
    constant BaseAddress           : in  std_logic_vector(31 downto 0)
) is
    file f_File : text open read_mode is FileName;
    variable v_Line    : line;
    variable v_Word    : std_logic_vector(31 downto 0);
    variable v_Address : unsigned(31 downto 0);
begin

    v_Address := unsigned(BaseAddress);

    o_InstructionLoad <= '1';

    while not endfile(f_File) loop
        readline(f_File, v_Line);

        -- Skip empty lines
        if v_Line'length = 0 then
            next;
        end if;

        hread(v_Line, v_Word);

        o_InstructionAddress  <= std_logic_vector(v_Address);
        o_InstructionExternal <= v_Word;

        -- Instruction memory writes on clock rising edge
        wait until rising_edge(i_Clock);
        if IS_DEBUG then
            report "Loaded instruction memory word " & to_hstring(v_Word) & " at address " & to_hstring(std_logic_vector(v_Address)) severity note;
        end if;
        v_Address := v_Address + 4;

    end loop;

    o_InstructionLoad     <= '0';
    o_InstructionAddress  <= (others => '0');
    o_InstructionExternal <= (others => '0');

end procedure;

procedure LoadDataMemory(
    signal   i_Clock       : in  std_logic;
    signal   o_DataLoad    : out std_logic;
    signal   o_DataAddress : out std_logic_vector(31 downto 0);
    signal   o_DataExternal: out std_logic_vector(31 downto 0);
    constant FileName      : in  string;
    constant BaseAddress   : in  std_logic_vector(31 downto 0)
) is
    file f_File : text open read_mode is FileName;
    variable v_Line    : line;
    variable v_Word    : std_logic_vector(31 downto 0);
    variable v_Address : unsigned(31 downto 0);
begin

    v_Address := unsigned(BaseAddress);

    o_DataLoad <= '1';

    while not endfile(f_File) loop
        readline(f_File, v_Line);

        -- Skip empty lines
        if v_Line'length = 0 then
            next;
        end if;

        hread(v_Line, v_Word);

        o_DataAddress  <= std_logic_vector(v_Address);
        o_DataExternal <= v_Word;

        -- Data memory writes on clock rising edge
        wait until rising_edge(i_Clock);
        if IS_DEBUG then
            report "Loaded data memory word " & to_hstring(v_Word) & " at address " & to_hstring(std_logic_vector(v_Address)) severity note;
        end if;
        v_Address := v_Address + 4;

    end loop;

    o_DataLoad     <= '0';
    o_DataAddress  <= (others => '0');
    o_DataExternal <= (others => '0');

end procedure;


begin

    -- Design-under-test instantiation
    DUT: entity work.processor
        port map(
            i_Clock               => s_Clock,
            i_Reset               => s_Reset,
            i_InstructionLoad     => s_iInstructionLoad,
            i_InstructionAddress  => s_iInstructionAddress,
            i_InstructionExternal => s_iInstructionExternal,
            i_DataLoad            => s_iDataLoad,
            i_DataAddress         => s_iDataAddress,
            i_DataExternal        => s_iDataExternal,
            o_ALUOutput           => s_oALUOutput,
            o_Halt                => s_oHalt
        );


    p_Clock: process
    begin
        s_Clock <= '1';
        wait for CLOCK_HALF_PERIOD;
        s_Clock <= '0';
        wait for CLOCK_HALF_PERIOD;
    end process;

    p_Reset: process
    begin
        s_Reset <= '0';
        wait for CLOCK_HALF_PERIOD / 2;
        s_Reset <= '1';
        wait for CLOCK_PERIOD;
        s_Reset <= '0';
        wait;
    end process;

    p_Trace: process
        file f_Trace      : text open write_mode is TRACE_FILE;
        variable v_Line   : line;
        variable v_Cycles : integer := 0;

        alias a_DataMemoryWriteEnable is <<signal DUT.s_DataMemoryWriteEnable : std_logic>>;
        alias a_DataMemoryAddress     is <<signal DUT.s_DataMemoryAddress     : std_logic_vector(31 downto 0)>>;
        alias a_DataMemoryData        is <<signal DUT.s_DataMemoryData        : std_logic_vector(DATA_WIDTH-1 downto 0)>>;

        alias a_RegisterFileWriteEnable is <<signal DUT.s_RegisterFileWriteEnable : std_logic>>;
        alias a_RegisterFileSelect      is <<signal DUT.s_RegisterFileSelect      : std_logic_vector(4 downto 0)>>;
        alias a_RegisterFileData        is <<signal DUT.s_RegisterFileData        : std_logic_vector(DATA_WIDTH-1 downto 0)>>;

        alias a_InstructionPointer is <<signal DUT.s_IPAddress : std_logic_vector(31 downto 0)>>;

    begin

        wait until rising_edge(s_Clock);

        loop
            wait until rising_edge(s_Clock);

            if (s_Reset = '0') and (s_TraceEnable = '1') then
                write(v_Line, string'("Instruction Pointer: 0x"));
                hwrite(v_Line, a_InstructionPointer);
                writeline(f_Trace, v_Line);

                if (a_RegisterFileWriteEnable = '1') then
                    write(v_Line, string'("In clock cycle: "));
                    write(v_Line, v_Cycles);
                    writeline(f_Trace, v_Line);

                    write(v_Line, string'("Register Write to Reg: 0x"));
                    hwrite(v_Line, a_RegisterFileSelect);
                    write(v_Line, string'(" Val: 0x"));
                    hwrite(v_Line, a_RegisterFileData);
                    writeline(f_Trace, v_Line);
                end if;

                if (a_DataMemoryWriteEnable = '1') then
                    write(v_Line, string'("In clock cycle: "));
                    write(v_Line, v_Cycles);
                    writeline(f_Trace, v_Line);

                    write(v_Line, string'("Memory Write to Addr: 0x"));
                    hwrite(v_Line, a_DataMemoryAddress);
                    write(v_Line, string'(" Val: 0x"));
                    hwrite(v_Line, a_DataMemoryData);
                    writeline(f_Trace, v_Line);
                end if;

                if (s_oHalt = '1') then
                    write(v_Line, string'("Execution stopped at cycle "));
                    write(v_Line, v_Cycles);
                    writeline(f_Trace, v_Line);
                    file_close(f_Trace);
                    finish;
                end if;

                v_Cycles := v_Cycles + 1;

            end if;

        end loop;

    end process;

    p_Stimulus: process
        constant c_MaximumCycles : integer := 5000;
        variable v_Cycles        : integer := 0;
    begin
        -- Await reset and stabilization; trigger off-edge
        wait for CLOCK_HALF_PERIOD;
        wait for CLOCK_HALF_PERIOD / 2;

        -- Load processor instruction and data memories with target program
        LoadInstructionMemory(
            s_Clock,
            s_iInstructionLoad,
            s_iInstructionAddress,
            s_iInstructionExternal,
            INSTRUCTION_FILE ,
            x"00400000"
        );

        LoadDataMemory(
            s_Clock,
            s_iDataLoad,
            s_iDataAddress,
            s_iDataExternal,
            DATA_FILE ,
            x"10010000"
        );

        s_TraceEnable <= '1';

        report to_string(s_oHalt) & " - Beginning program execution." severity note;

        while s_oHalt = '0' loop
            wait until rising_edge(s_Clock);
            v_Cycles := v_Cycles + 1;

            if v_Cycles mod 1000 = 0 then
                report "Simulation running... (cycle count: " & integer'image(v_Cycles) & ")" severity note;
            end if;

            assert v_Cycles < c_MaximumCycles
                report "Maximum cycle count (" & integer'image(c_MaximumCycles) & ") exceeded; simulation stopped." severity failure;

        end loop;

        s_TraceEnable <= '0';

        finish;

    end process;

end implementation;
