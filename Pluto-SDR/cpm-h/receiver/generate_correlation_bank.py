"""Generate the fixed CPM-H base-template ROM and bank verification vectors."""
from pathlib import Path
import sys
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from cpm_receiver_hardware import ALPHABET, SPS, phase_pulse

HW = HERE / "hardware"
SCALE = 2047
POSITIONS = np.arange(0, SPS, 2)
ALPHA = tuple(int(x) for x in ALPHABET)

def base_wave(parity, b, c, d):
    h = 4 + parity
    u = POSITIONS / SPS
    turns = ((9-h)*b/16*phase_pulse(u+1)
             + h*c/16*phase_pulse(u+2)
             + h*ALPHA[d]/16*phase_pulse(u))
    return np.exp(2j*np.pi*turns)

def build_rom():
    irom=[]; qrom=[]
    for parity in range(2):
        waves=[]
        for b in ALPHA:
            for c in ALPHA:
                for d in range(4):
                    waves.append(base_wave(parity,b,c,d))
        waves=np.asarray(waves)
        for obs in range(16):
            irom.extend(np.rint(waves[:,obs].real*SCALE).astype(int))
            qrom.extend(np.rint(waves[:,obs].imag*SCALE).astype(int))
    return irom,qrom

def emit_pkg(irom,qrom):
    lanes=[[] for _ in range(6)]
    for parity in range(2):
        for obs in range(16):
            for group in range(11):
                for lane in range(6):
                    idx=group*6+lane
                    if idx < 64:
                        old=parity*1024+obs*64+idx
                        iv=irom[old] & 0xfff; qv=qrom[old] & 0xfff
                    else:
                        iv=qv=0
                    lanes[lane].append((iv<<12)|qv)
    constants=[]
    for lane,values in enumerate(lanes):
        rows=[]
        for n in range(0,len(values),8):
            rows.append("    "+", ".join(f'x"{x:06X}"' for x in values[n:n+8]))
        constants.append(f"  constant ROM{lane} : rom_t := (\n"+",\n".join(rows)+"\n  );")
    text="""library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpm_template_rom6 is
  port(clk:in std_logic; address:in unsigned(8 downto 0);
       q0,q1,q2,q3,q4,q5:out std_logic_vector(23 downto 0));
end entity;
architecture rtl of cpm_template_rom6 is
  type rom_t is array(0 to 351) of std_logic_vector(23 downto 0);
%s
  attribute rom_style:string;
  attribute rom_style of ROM0,ROM1,ROM2,ROM3,ROM4,ROM5:constant is "block";
begin
  process(clk) begin
    if rising_edge(clk) then
      q0<=ROM0(to_integer(address)); q1<=ROM1(to_integer(address));
      q2<=ROM2(to_integer(address)); q3<=ROM3(to_integer(address));
      q4<=ROM4(to_integer(address)); q5<=ROM5(to_integer(address));
    end if;
  end process;
end architecture;
""" % "\n".join(constants)
    (HW/"cpm_template_rom6.vhd").write_text(text)

def emit_vectors():
    rng=np.random.default_rng(731)
    lines=[]
    for parity in (0,1):
        truth=int(rng.integers(64))
        w=np.asarray([base_wave(parity,ALPHA[(truth//16)%4],ALPHA[(truth//4)%4],truth%4)[n] for n in range(16)])
        z=w+0.04*(rng.normal(size=16)+1j*rng.normal(size=16))
        ri=np.clip(np.rint(z.real*SCALE),-2048,2047).astype(int)
        rq=np.clip(np.rint(z.imag*SCALE),-2048,2047).astype(int)
        lines.append(f"CASE {parity}")
        for a,b in zip(ri,rq): lines.append(f"S {a} {b}")
        for idx in range(64):
            b=ALPHA[(idx//16)%4]; c=ALPHA[(idx//4)%4]; d=idx%4
            t=base_wave(parity,b,c,d)
            ti=np.rint(t.real*SCALE).astype(np.int64)
            tq=np.rint(t.imag*SCALE).astype(np.int64)
            re=int(np.sum(ri*ti+rq*tq)) >> 9
            im=int(np.sum(rq*ti-ri*tq)) >> 9
            # Match signed-18 resize semantics.
            re=((re+(1<<17))%(1<<18))-(1<<17)
            im=((im+(1<<17))%(1<<18))-(1<<17)
            lines.append(f"R {idx} {re} {im}")
    (HW/"correlation_bank_vectors.txt").write_text("\n".join(lines)+"\n")

if __name__=="__main__":
    HW.mkdir(parents=True,exist_ok=True)
    emit_pkg(*build_rom())
    emit_vectors()
