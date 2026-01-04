-- Horizon: extender_NtoM.vhd
-- (c) 2026 Connor J. Link. All rights reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.RISCV_types.all;

entity extender_NtoM is
    generic(
        N : integer := 12;
        M : integer := work.RISCV_types.DATA_WIDTH
    ); 
    port(
        i_D             : in  std_logic_vector(N-1 downto 0);
        i_ExtensionType : in  std_logic; -- 0: zero-extend, 1: sign-extend
        o_Q             : out std_logic_vector(M-1 downto 0)
    );
end extender_NtoM;

architecture implementation of extender_NtoM is

signal s_Rz : std_logic_vector(M-1 downto 0);
signal s_Rs : std_logic_vector(M-1 downto 0);

begin

    s_Rz <= std_logic_vector(resize(unsigned(i_D), M));
    s_Rs <= std_logic_vector(resize(signed(i_D), M));

    o_Q  <= s_Rz when i_ExtensionType = '0' else s_Rs;

end implementation;
