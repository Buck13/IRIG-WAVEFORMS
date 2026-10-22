library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
package cpm_receiver_pkg is
  type signed18_array4_t is array(0 to 3) of signed(17 downto 0);
  type signed48_array4_t is array(0 to 3) of signed(47 downto 0);
  type phase_array4_t is array(0 to 3) of unsigned(4 downto 0);
  type unsigned8_array4_t is array(0 to 3) of unsigned(7 downto 0);
  type trig_rom_t is array(0 to 31) of integer range -32767 to 32767;
  constant COS_Q15:trig_rom_t := (32767,32137,30273,27245,23170,18204,12539,6393,0,-6393,-12539,-18204,-23170,-27245,-30273,-32137,-32767,-32137,-30273,-27245,-23170,-18204,-12539,-6393,0,6393,12539,18204,23170,27245,30273,32137);
  constant SIN_Q15:trig_rom_t := (0,6393,12539,18204,23170,27245,30273,32137,32767,32137,30273,27245,23170,18204,12539,6393,0,-6393,-12539,-18204,-23170,-27245,-30273,-32137,-32767,-32137,-30273,-27245,-23170,-18204,-12539,-6393);
end package;
