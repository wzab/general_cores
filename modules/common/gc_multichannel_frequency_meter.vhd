-------------------------------------------------------------------------------
-- Title      : Frequency meter optimized for multiple channels
-- Project    : General Cores
-------------------------------------------------------------------------------
-- File       : gc_multichannel_frequency_meter.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN
-- Platform   : FPGA-generics
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Copyright (c) 2012-2015 CERN
--
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 0.51 (the “License”) (which enables you, at your option,
-- to treat this file as licensed under the Apache License 2.0); you may not
-- use this file except in compliance with the License. You may obtain a copy
-- of the License at http://solderpad.org/licenses/SHL-0.51.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
-------------------------------------------------------------------------------

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gencores_pkg.all;

entity gc_multichannel_frequency_meter is
  generic(
    g_with_internal_timebase : boolean := true;
    g_clk_sys_freq           : integer;
    g_counter_bits           : integer := 32;
    g_channels               : integer := 1);

  port(
    clk_sys_i     : in  std_logic;
    clk_in_i      : in  std_logic_vector(g_channels -1 downto 0);
    rst_n_i       : in  std_logic;
    pps_p1_i      : in  std_logic;
    channel_sel_i : in  std_logic_vector(3 downto 0);
    freq_o        : out std_logic_vector(g_counter_bits-1 downto 0);
    freq_valid_o  : out std_logic
    );

end gc_multichannel_frequency_meter;

architecture behavioral of gc_multichannel_frequency_meter is

  signal gate_pulse        : std_logic;
  signal gate_pulse_synced : std_logic_vector(g_channels-1 downto 0);

  signal cntr_gate : unsigned(g_counter_bits-1 downto 0);

  type t_channel_state is record
    cntr       : unsigned(g_counter_bits-1 downto 0);
    freq       : unsigned(g_counter_bits-1 downto 0);
    freq_valid : std_logic;
  end record;

  type t_channel_state_array is array(0 to g_channels-1) of t_channel_state;

  signal ch : t_channel_state_array;

begin

  gen_internal_timebase : if(g_with_internal_timebase = true) generate

    p_gate_counter : process(clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if rst_n_i = '0' then
          cntr_gate  <= (others => '0');
          gate_pulse <= '0';
        else
          if(cntr_gate = g_clk_sys_freq-1) then
            cntr_gate  <= (others => '0');
            gate_pulse <= '1';
          else
            cntr_gate  <= cntr_gate + 1;
            gate_pulse <= '0';
          end if;
        end if;
      end if;
    end process;


  end generate gen_internal_timebase;

  gen_external_timebase : if(g_with_internal_timebase = false) generate
    gate_pulse <= pps_p1_i;
  end generate gen_external_timebase;

  gen_channels : for i in 0 to g_channels-1 generate

    U_Sync_Gate : gc_pulse_synchronizer
      port map (
        clk_in_i  => clk_sys_i,
        clk_out_i => clk_in_i(i),
        rst_n_i   => rst_n_i,
        d_ready_o => open,
        d_p_i     => gate_pulse,
        q_p_o     => gate_pulse_synced(i));


    p_freq_counter : process (clk_in_i(i), rst_n_i)
    begin
      if rst_n_i = '0' then             -- asynchronous reset (active low)
        ch(i).cntr       <= (others => '0');
        ch(i).freq       <= (others => '0');
        ch(i).freq_valid <= '0';
      elsif rising_edge(clk_in_i(i)) then

        if(gate_pulse_synced(i) = '1') then
          ch(i).freq_valid <= '1';
          ch(i).freq <= ch(i).cntr;
          ch(i).cntr <= (others => '0');
        else
          ch(i).cntr <= ch(i).cntr + 1;
        end if;
      end if;
    end process p_freq_counter;

  end generate gen_channels;

  p_freq_output : process(clk_sys_i)
    variable idx : integer range 0 to g_channels-1;
  begin
    if rising_edge(clk_sys_i) then
      idx          := to_integer(unsigned(channel_sel_i));
      freq_o       <= std_logic_vector(ch(idx).freq);
      freq_valid_o <= ch(idx).freq_valid;
    end if;
  end process;


end behavioral;


