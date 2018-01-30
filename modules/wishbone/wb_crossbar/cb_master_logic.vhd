-------------------------------------------------------------------------------
-- Title      : An MxS Wishbone crossbar switch
-- Project    : General Cores Library (gencores)
-------------------------------------------------------------------------------
-- File       : cb_master_logic.vhd
-- Author     : Wesley W. Terpstra
-- Company    : GSI
-- Created    : 2011-06-08
-- Last update: 2018-01-23
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description:
--
-- An MxS Wishbone crossbar switch
-- 
-- All masters, slaves, and the crossbar itself must share the same WB clock.
-- All participants must support the same data bus width. 
-- 
-- If a master raises STB_O with an address not mapped by the crossbar,
-- ERR_I will be raised. If two masters address the same slave
-- simultaneously, the lowest numbered master is granted access.
-- 
-- The implementation of this crossbar locks a master to a slave so long as
-- CYC_O is held high. 
-- 
-- Synthesis/timing relevant facts:
--   (m)asters, (s)laves, masked (a)ddress bits
--   
--   Area required       = O(ms log(ma))
--   Arbitration depth   = O(log(msa))
--   Master->Slave depth = O(log(m))
--   Slave->Master depth = O(log(s))
-- 
--   If g_registered = false, arbitration depth is added to M->S and S->M.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2011 GSI / Wesley W. Terpstra
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2012-03-05  3.0      wterpstra       made address generic and check overlap
-- 2011-11-04  2.0      wterpstra       timing improvements
-- 2011-06-08  1.0      wterpstra       import from SVN
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;
use work.xwb_crossbar_pkg.all;


entity cb_master_logic is
  generic (
    g_num_masters : integer;
    g_num_slaves  : integer;
    g_master      : integer);
  port (
    out_o     : out t_wishbone_slave_out;
    granted_i : in  t_matrix (g_num_masters-1 downto 0, g_num_slaves downto 0);
    master_i  :     t_wishbone_master_in_array(g_num_slaves downto 0));
end entity;

architecture rtl of cb_master_logic is

  subtype master_row is std_logic_vector(g_num_slaves downto 0);
  type master_matrix is array (natural range <>) of master_row;

  signal ACK_row    : master_row;
  signal ERR_row    : master_row;
  signal RTY_row    : master_row;
  signal STALL_row  : master_row;
  signal DAT_matrix : master_matrix(c_wishbone_data_width-1 downto 0);
  signal stall_n    : std_logic;
begin
-- We use inverted logic on STALL so that if no slave granted => stall

  g1 : for slave in g_num_slaves downto 0 generate
    ACK_row(slave)   <= master_i(slave).ACK and granted_i(g_master, slave);
    ERR_row(slave)   <= master_i(slave).ERR and granted_i(g_master, slave);
    RTY_row(slave)   <= master_i(slave).RTY and granted_i(g_master, slave);
    STALL_row(slave) <= not master_i(slave).STALL and granted_i(g_master, slave);

    g2 : for bit in c_wishbone_data_width-1 downto 0 generate
      DAT_matrix(bit)(slave) <= master_i(slave).DAT(bit) and granted_i(g_master, slave);
    end generate;
  end generate;

  cb_vector_or_1 : entity work.cb_vector_or
    generic map (
      g_width => g_num_slaves + 1)
    port map (
      d_i => ACK_row,
      q_o => out_o.ACK);

  cb_vector_or_2 : entity work.cb_vector_or
    generic map (
      g_width => g_num_slaves + 1)
    port map (
      d_i => ERR_row,
      q_o => out_o.ERR);

  cb_vector_or_3 : entity work.cb_vector_or
    generic map (
      g_width => g_num_slaves + 1)
    port map (
      d_i => RTY_row,
      q_o => out_o.RTY);

  cb_vector_or_4 : entity work.cb_vector_or
    generic map (
      g_width => g_num_slaves + 1)
    port map (
      d_i => STALL_row,
      q_o => stall_n);

  out_o.int   <= '0';
  out_o.stall <= not stall_n;

  g7 : for i in 0 to c_wishbone_data_width-1 generate
    cb_vector_or_6 : entity work.cb_vector_or
      generic map (
        g_width => g_num_slaves + 1)
      port map (
        d_i => DAT_matrix(i),
        q_o => out_o.DAT(i));
  end generate;


end rtl;
