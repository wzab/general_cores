-------------------------------------------------------------------------------
-- Title      : An MxS Wishbone crossbar switch
-- Project    : General Cores Library (gencores)
-------------------------------------------------------------------------------
-- File       : cb_slave_logic.vhd
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

entity cb_slave_logic is
  generic (
    g_num_masters : integer;
    g_num_slaves  : integer;
    g_slave       : integer);
  port (
    out_o     : out t_wishbone_master_out;
    granted_i : in  t_matrix (g_num_masters-1 downto 0, g_num_slaves downto 0);
    slave_i   :     t_wishbone_slave_in_array(g_num_masters-1 downto 0));
end entity;

architecture rtl of cb_slave_logic is

  subtype slave_row is std_logic_vector(g_num_masters-1 downto 0);
  type slave_matrix is array (natural range <>) of slave_row;

  signal CYC_row    : slave_row;
  signal STB_row    : slave_row;
  signal ADR_matrix : slave_matrix(c_wishbone_address_width-1 downto 0);
  signal SEL_matrix : slave_matrix((c_wishbone_address_width/8)-1 downto 0);
  signal WE_row     : slave_row;
  signal DAT_matrix : slave_matrix(c_wishbone_data_width-1 downto 0);

begin

  -- Rename all the signals ready for big_or
  g1 : for master in g_num_masters-1 downto 0 generate
    CYC_row(master) <= slave_i(master).CYC and granted_i(master, g_slave);
    STB_row(master) <= slave_i(master).STB and granted_i(master, g_slave);
    WE_row(master)  <= slave_i(master).WE and granted_i(master, g_slave);

    g2 : for bit in c_wishbone_address_width-1 downto 0 generate
      ADR_matrix(bit)(master) <= slave_i(master).ADR(bit) and granted_i(master, g_slave);
    end generate;

    g3 : for bit in (c_wishbone_address_width/8)-1 downto 0 generate
      SEL_matrix(bit)(master) <= slave_i(master).SEL(bit) and granted_i(master, g_slave);
    end generate;

    g4 : for bit in c_wishbone_data_width-1 downto 0 generate

      DAT_matrix(bit)(master) <= slave_i(master).DAT(bit) and granted_i(master, g_slave);
    end generate;

  end generate;


  cb_vector_or_1 : entity work.cb_vector_or
    generic map (
      g_width => g_num_masters)
    port map (
      d_i => CYC_row,
      q_o => out_o.CYC);


  cb_vector_or_2 : entity work.cb_vector_or
    generic map (
      g_width => g_num_masters)
    port map (
      d_i => STB_row,
      q_o => out_o.STB);


  cb_vector_or_3 : entity work.cb_vector_or
    generic map (
      g_width => g_num_masters)
    port map (
      d_i => WE_row,
      q_o => out_o.WE);

  g5 : for i in 0 to c_wishbone_address_width-1 generate
    cb_vector_or_4 : entity work.cb_vector_or
      generic map (
        g_width => g_num_masters)
      port map (
        d_i => ADR_matrix(i),
        q_o => out_o.ADR(i));
  end generate;

  g6 : for i in 0 to c_wishbone_data_width/8-1 generate
    cb_vector_or_5 : entity work.cb_vector_or
      generic map (
        g_width => g_num_masters)
      port map (
        d_i => SEL_matrix(i),
        q_o => out_o.SEL(i));
  end generate;


  g7 : for i in 0 to c_wishbone_data_width-1 generate
    cb_vector_or_6 : entity work.cb_vector_or
      generic map (
        g_width => g_num_masters)
      port map (
        d_i => DAT_matrix(i),
        q_o => out_o.DAT(i));
  end generate;

end rtl;
