library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpm_correlation_bank is
  generic(IQ_BITS:positive:=12; ACC_BITS:positive:=32; NORMALIZE_SHIFT:natural:=9);
  port(
    clk,reset:in std_logic;
    sample_valid:in std_logic; sample_ready:out std_logic;
    symbol_start,parity:in std_logic;
    rx_i,rx_q:in signed(IQ_BITS-1 downto 0);
    result_valid:out std_logic; result_index:out unsigned(5 downto 0);
    result_re,result_im:out signed(17 downto 0);
    result_last,overflow:out std_logic
  );
end entity;

architecture rtl of cpm_correlation_bank is
  type accum_array_t is array(0 to 63) of signed(ACC_BITS-1 downto 0);
  type result_array_t is array(0 to 63) of signed(17 downto 0);
  signal accum_re,accum_im:accum_array_t:=(others=>(others=>'0'));
  signal saved_re,saved_im:result_array_t:=(others=>(others=>'0'));
  signal rx_i_q,rx_q_q:signed(IQ_BITS-1 downto 0):=(others=>'0');
  signal parity_q:std_logic:='0';
  signal observation:natural range 0 to 15:=0;
  signal group_index:natural range 0 to 10:=0;
  signal processing,draining:std_logic:='0';
  signal drain_index:natural range 0 to 63:=0;
  signal rom_address:unsigned(8 downto 0):=(others=>'0');
  signal rom0,rom1,rom2,rom3,rom4,rom5:std_logic_vector(23 downto 0);
  signal rom_valid_q:std_logic:='0';
  signal rom_observation_q:natural range 0 to 15:=0;
  signal rom_group_q:natural range 0 to 10:=0;
begin
  sample_ready<=not processing;
  process(all)
    variable a:natural;
  begin
    a:=observation*11+group_index;
    if parity_q='1' then a:=a+176; end if;
    rom_address<=to_unsigned(a,9);
  end process;
  templates:entity work.cpm_template_rom6
    port map(clk,rom_address,rom0,rom1,rom2,rom3,rom4,rom5);

  process(clk)
    variable template_index:natural;
    variable packed_template:std_logic_vector(23 downto 0);
    variable ti,tq:signed(11 downto 0);
    variable ii,qq,qi,iq:signed(23 downto 0);
    variable term_re,term_im,total_re,total_im:signed(ACC_BITS-1 downto 0);
  begin
    if rising_edge(clk) then
      result_valid<='0'; result_last<='0'; overflow<='0'; rom_valid_q<=processing;
      if reset='1' then
        accum_re<=(others=>(others=>'0')); accum_im<=(others=>(others=>'0'));
        saved_re<=(others=>(others=>'0')); saved_im<=(others=>(others=>'0'));
        processing<='0'; draining<='0'; observation<=0; group_index<=0;
        drain_index<=0; parity_q<='0'; rom_valid_q<='0';
        result_index<=(others=>'0'); result_re<=(others=>'0'); result_im<=(others=>'0');
      else
        if draining='1' then
          result_valid<='1'; result_index<=to_unsigned(drain_index,6);
          result_re<=saved_re(drain_index); result_im<=saved_im(drain_index);
          if drain_index=63 then result_last<='1'; draining<='0'; drain_index<=0;
          else drain_index<=drain_index+1; end if;
        end if;

        if rom_valid_q='1' then
          for lane in 0 to 5 loop
            template_index:=rom_group_q*6+lane;
            if template_index<64 then
              case lane is
                when 0=>packed_template:=rom0; when 1=>packed_template:=rom1;
                when 2=>packed_template:=rom2; when 3=>packed_template:=rom3;
                when 4=>packed_template:=rom4; when others=>packed_template:=rom5;
              end case;
              ti:=signed(packed_template(23 downto 12));
              tq:=signed(packed_template(11 downto 0));
              ii:=rx_i_q*ti; qq:=rx_q_q*tq; qi:=rx_q_q*ti; iq:=rx_i_q*tq;
              term_re:=resize(ii,ACC_BITS)+resize(qq,ACC_BITS);
              term_im:=resize(qi,ACC_BITS)-resize(iq,ACC_BITS);
              if rom_observation_q=0 then total_re:=term_re; total_im:=term_im;
              else
                total_re:=accum_re(template_index)+term_re;
                total_im:=accum_im(template_index)+term_im;
              end if;
              accum_re(template_index)<=total_re; accum_im(template_index)<=total_im;
              if rom_observation_q=15 then
                saved_re(template_index)<=resize(shift_right(total_re,NORMALIZE_SHIFT),18);
                saved_im(template_index)<=resize(shift_right(total_im,NORMALIZE_SHIFT),18);
                if template_index=63 then
                  if draining='1' then overflow<='1'; end if;
                  draining<='1'; drain_index<=0;
                end if;
              end if;
            end if;
          end loop;
        end if;

        if sample_valid='1' and processing='0' then
          rx_i_q<=rx_i; rx_q_q<=rx_q; processing<='1'; group_index<=0;
          if symbol_start='1' then observation<=0; parity_q<=parity; end if;
        end if;
        if processing='1' then
          rom_observation_q<=observation; rom_group_q<=group_index;
          if group_index=10 then
            processing<='0'; group_index<=0;
            if observation=15 then observation<=0; else observation<=observation+1; end if;
          else group_index<=group_index+1; end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
