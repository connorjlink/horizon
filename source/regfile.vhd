-------------------------------------------------------------------------
-- Connor Link
-- Iowa State University
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- regfile.vhd
-- DESCRIPTION: This file contains an implementation of a RISC-V register file.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.RISCV_types.all;

entity regfile is
    port(i_Clock : in  std_logic;
         i_Reset : in  std_logic;
         i_RS1 : in  std_logic_vector(4 downto 0);
         i_RS2 : in  std_logic_vector(4 downto 0);
         i_RD  : in  std_logic_vector(4 downto 0);
         i_WE  : in  std_logic;
         i_D   : in  std_logic_vector(31 downto 0);
         o_DS1 : out std_logic_vector(31 downto 0);
         o_DS2 : out std_logic_vector(31 downto 0));
end regfile;

architecture mixed of regfile is

component dec5t32 is
    port(i_S : in  std_logic_vector(4 downto 0);
         o_Q : out std_logic_vector(31 downto 0));
end component;

component mux32t1 is
    port(i_S : in  std_logic_vector(4 downto 0);
         i_D : in  array_t(0 to 31);
         o_Q : out std_logic_vector(31 downto 0));
end component;

component register_N is
    generic(N : integer := 32);
    port(i_Clock : in  std_logic;                       -- Clock input
         i_Reset : in  std_logic;                       -- Reset input
         i_WE  : in  std_logic;                       -- Write enable input
         i_D   : in  std_logic_vector(N-1 downto 0);  -- Data value input
         o_Q   : out std_logic_vector(N-1 downto 0)); -- Data value output
end component;

-- Signals to hold the decoded write enable signals
signal s_WEx : std_logic_vector(31 downto 0);
signal s_WEm : std_logic_vector(31 downto 0);

-- Signal to hold all of the register output values
signal s_Rx : array_t(0 to 31);

-- Signal for dedicated zero register x0
signal s_X0 : std_logic_vector(31 downto 0) := x"00000000";

begin

    -- Decode the write enable signals to branch out
    g_Decoder: dec5t32
        port map(i_S => i_RD,
                 o_Q => s_WEx);

    s_WEm <= s_WEx and 32x"FFFFFFFF" when i_WE = '1' else 32x"0";

    -- Register stack structure
    g_Registers: for i in 1 to 31
    generate
        REGISTERI: register_N
            generic map(N => 32)
            port map(i_Clock => i_Clock,
                     i_Reset => i_Reset,
                     i_WE  => s_WEm(i),
                     i_D   => i_D,
                     o_Q   => s_Rx(i));
    end generate g_Registers;

    -- Dedicated hardwired zero register x0
    s_Rx(0) <= s_X0;

    -- Multiplex the outputs twice over for the two read ports
    g_Multiplexer1: mux32t1
        port map(i_S => i_RS1,
                 i_D => s_Rx,
                 o_Q => o_DS1);

    g_Multiplexer2: mux32t1
        port map(i_S => i_RS2,
                 i_D => s_Rx,
                 o_Q => o_DS2);

end mixed;
