-- Horizon: vga_blitter.vhd
-- (c) 2026 Connor J. Link. All Rights Reserved.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.types.all;

entity vga_blitter is
    port(
        i_Clock              : in  std_logic;
        i_Reset              : in  std_logic;
        i_Command            : in  BlitterCommandType;
        i_TextureSlot        : in  TextureSlotType;
        i_FramebufferSlot    : in  FramebufferSlotType;
        -- clipping rect for drawing area
        i_RectangleX         : in  unsigned(9 downto 0);
        i_RectangleY         : in  unsigned(9 downto 0);
        i_RectangleWidth     : in  signed(9 downto 0);
        i_RectangleHeight    : in  signed(9 downto 0);
        -- clipping rect for texture atlas access
        i_TextureX           : in  unsigned(7 downto 0);
        i_TextureY           : in  unsigned(7 downto 0);
        i_TextureWidth       : in  signed(7 downto 0);
        i_TextureHeight      : in  signed(7 downto 0);
        -- graphics card either writes generates a color or texture sample
        -- if color, address points to the MMIO register of the color, else the texture sample address
        o_TextureAddress     : out std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
        o_FramebufferAddress : out std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
        o_WriteEnable        : out std_logic;
        o_Busy               : out std_logic
    );
end vga_blitter;

architecture implementation of vga_blitter is

    constant BYTES_PER_PIXEL         : natural := COLOR_DEPTH / 8;
    constant FRAMEBUFFER_STRIDE_BYTE : natural := FRAMEBUFFER_WIDTH * FRAMEBUFFER_HEIGHT * BYTES_PER_PIXEL;

    signal s_Busy             : std_logic := '0';
    signal s_Command          : BlitterCommandType := COMMAND_NONE;
    signal s_RectangleX       : integer range -2048 to 2047 := 0;
    signal s_RectangleY       : integer range -2048 to 2047 := 0;
    signal s_AbsoluteWidth    : natural range 0 to 1024 := 0;
    signal s_AbsoluteHeight   : natural range 0 to 1024 := 0;
    signal s_XIndex           : natural range 0 to 1023 := 0;
    signal s_YIndex           : natural range 0 to 1023 := 0;
    signal s_WidthIsNegative  : std_logic := '0';
    signal s_HeightIsNegative : std_logic := '0';
    signal s_FramebufferSlot  : FramebufferSlotType := 0;

begin

    process(
        i_Clock, i_Reset
    )
        variable v_Width          : integer;
        variable v_Height         : integer;
        variable v_AbsoluteWidth  : natural;
        variable v_AbsoluteHeight : natural;
        variable v_FramebufferX   : integer;
        variable v_FramebufferY   : integer;
        variable v_IsBorder       : boolean;
        variable v_WriteEnable    : std_logic;
        variable v_Address        : unsigned(ADDRESS_WIDTH - 1 downto 0);

    begin
        if i_Reset = '1' then
            s_Busy              <= '0';
            s_Command           <= COMMAND_NONE;
            s_RectangleX        <= 0;
            s_RectangleY        <= 0;
            s_AbsoluteWidth     <= 0;
            s_AbsoluteHeight    <= 0;
            s_WidthIsNegative     <= '0';
            s_HeightIsNegative    <= '0';
            s_XIndex            <= 0;
            s_YIndex            <= 0;
            s_FramebufferSlot   <= 0;

            o_TextureAddress     <= (others => '0');
            o_FramebufferAddress <= (others => '0');
            o_WriteEnable        <= '0';
            o_Busy               <= '0';

        elsif rising_edge(i_Clock) then
            -- defaults each cycle
            o_TextureAddress     <= (others => '0');
            o_FramebufferAddress <= (others => '0');
            o_WriteEnable        <= '0';
            o_Busy               <= s_Busy;

            if s_Busy = '1' then
                -- current pixel within signed rectangle walk
                if s_WidthIsNegative = '1' then
                    v_FramebufferX := s_RectangleX - integer(s_XIndex);
                else
                    v_FramebufferX := s_RectangleX + integer(s_XIndex);
                end if;

                if s_HeightIsNegative = '1' then
                    v_FramebufferY := s_RectangleY - integer(s_YIndex);
                else
                    v_FramebufferY := s_RectangleY + integer(s_YIndex);
                end if;

                -- edge test for outline mode
                v_IsBorder :=
                    (s_XIndex = 0) or
                    (s_YIndex = 0) or
                    (s_XIndex = s_AbsoluteWidth - 1) or
                    (s_YIndex = s_AbsoluteHeight - 1);

                -- command-local write decision
                v_WriteEnable := '0';
                case s_Command is
                    when COMMAND_DRAW_SOLID_COLOR =>
                        v_WriteEnable := '1';
                        
                    when COMMAND_DRAW_OUTLINE_COLOR =>
                        if v_IsBorder then
                            v_WriteEnable := '1';
                        end if;

                    when others =>
                        v_WriteEnable := '0';

                end case;

                -- color draw reads from MMIO color register
                o_TextureAddress <= MMIO_COLOR;

                -- clip to framebuffer bounds
                if (v_FramebufferX >= 0) and (v_FramebufferX < FRAMEBUFFER_WIDTH) and
                   (v_FramebufferY >= 0) and (v_FramebufferY < FRAMEBUFFER_HEIGHT) and
                   (v_WriteEnable = '1') then

                    v_Address := unsigned(FRAMEBUFFER_BASE) + to_unsigned(
                        (s_FramebufferSlot * FRAMEBUFFER_STRIDE_BYTE) +
                        ((v_FramebufferY * FRAMEBUFFER_WIDTH + v_FramebufferX) * BYTES_PER_PIXEL),
                        ADDRESS_WIDTH
                    );

                    o_FramebufferAddress <= std_logic_vector(v_Address);
                    o_WriteEnable <= '1';
                else
                    o_WriteEnable <= '0';

                end if;

                -- advance raster cursor
                if (s_XIndex + 1) < s_AbsoluteWidth then
                    s_XIndex <= s_XIndex + 1;
                else
                    s_XIndex <= 0;
                    if (s_YIndex + 1) < s_AbsoluteHeight then
                        s_YIndex <= s_YIndex + 1;
                    else
                        -- done
                        s_Busy    <= '0';
                        s_Command <= COMMAND_NONE;
                    end if;

                end if;

            else
                -- idle: accept one command, ignore others while busy
                case i_Command is
                    when COMMAND_DRAW_SOLID_COLOR | COMMAND_DRAW_OUTLINE_COLOR =>
                        v_Width := to_integer(i_RectangleWidth);
                        v_Height := to_integer(i_RectangleHeight);

                        if v_Width < 0 then
                            s_WidthIsNegative <= '1';
                            v_AbsoluteWidth := natural(-v_Width);
                        else
                            s_WidthIsNegative <= '0';
                            v_AbsoluteWidth := natural(v_Width);
                        end if;

                        if v_Height < 0 then
                            s_HeightIsNegative <= '1';
                            v_AbsoluteHeight := natural(-v_Height);
                        else
                            s_HeightIsNegative <= '0';
                            v_AbsoluteHeight := natural(v_Height);
                        end if;

                        if (v_AbsoluteWidth /= 0) and (v_AbsoluteHeight /= 0) then
                            s_Command         <= i_Command;
                            s_Busy            <= '1';
                            s_RectangleX           <= to_integer(i_RectangleX);
                            s_RectangleY           <= to_integer(i_RectangleY);
                            s_AbsoluteWidth        <= v_AbsoluteWidth;
                            s_AbsoluteHeight       <= v_AbsoluteHeight;
                            s_XIndex          <= 0;
                            s_YIndex          <= 0;
                            s_FramebufferSlot <= to_integer(unsigned(i_FramebufferSlot));

                            o_Busy <= '1';

                        else
                            s_Busy    <= '0';
                            s_Command <= COMMAND_NONE;

                        end if;

                    when others =>
                        s_Busy    <= '0';
                        s_Command <= COMMAND_NONE;

                end case;

            end if;

        end if;

    end process;

end implementation;