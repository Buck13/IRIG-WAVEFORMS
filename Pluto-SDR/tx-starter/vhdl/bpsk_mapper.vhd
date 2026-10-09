-- SPDX-License-Identifier: GPL-3.0-or-later
library ieee;
use ieee.std_logic_1164.all;

entity bpsk_mapper is
  port (symbol_bit : in std_logic; iq : out std_logic_vector(31 downto 0));
end entity;

architecture rtl of bpsk_mapper is
begin
  -- Signed I = +/-16384, Q = 0; packed as {I[15:0], Q[15:0]}.
  iq <= x"40000000" when symbol_bit = '1' else x"C0000000";
end architecture;
