from pathlib import Path
import numpy as np
from soqpsk_full_trellis import templates

t=templates(8); q=np.clip(np.rint(np.real(t)*4096),-2048,2047).astype(int)
vals=q.reshape(-1).tolist(); entries=',\n'.join(f'    {i} => {v}' for i,v in enumerate(vals))
text='''library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
package soqpsk_template_pkg is
  constant STATES:positive:=256; constant BITS:positive:=2; constant SPS:positive:=8;
  type rom_t is array(0 to %d) of integer range -2048 to 2047;
  constant TEMPLATE:rom_t := (\n%s\n  );
  function template_index(state:integer; bit_value:integer; sample:integer; parity:integer) return integer;
end package;
package body soqpsk_template_pkg is
 function template_index(state:integer; bit_value:integer; sample:integer; parity:integer) return integer is
 begin return (((parity*STATES+state)*BITS+bit_value)*SPS+sample); end;
end package body;
'''%(len(vals)-1,entries)
Path('soqpsk_template_pkg.vhd').write_text(text,encoding='utf-8')
print('wrote soqpsk_template_pkg.vhd',len(vals),'coefficients')
