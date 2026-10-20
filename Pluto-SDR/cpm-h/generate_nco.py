"""Generate the fixed CPM-H I/Q lookup package."""
from pathlib import Path
import math

SIZE = 1024
AMPLITUDE = 16383
values = [round(AMPLITUDE * math.sin(2 * math.pi * n / SIZE)) for n in range(SIZE)]
entries = ',\n'.join(f'    {n} => {value}' for n, value in enumerate(values))
text = f'''library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package cpm_h_nco_pkg is
  constant NCO_ADDR_BITS : positive := 10;
  constant NCO_SIZE : positive := {SIZE};
  type sine_rom_t is array (0 to NCO_SIZE-1) of integer range -{AMPLITUDE} to {AMPLITUDE};
  constant SINE_ROM : sine_rom_t := (
{entries}
  );
end package;
'''
target = Path(__file__).resolve().parent / 'hdl' / 'cpm_h_nco_pkg.vhd'
target.write_text(text, encoding='ascii')
print(target)
