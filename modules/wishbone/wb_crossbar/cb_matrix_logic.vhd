-------------------------------------------------------------------------------
-- Title      : An MxS Wishbone crossbar switch
-- Project    : General Cores Library (gencores)
-------------------------------------------------------------------------------
-- File       : cb_matrix_logic.vhd
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

entity cb_matrix_logic is

  generic (
    g_num_masters : integer;
    g_num_slaves  : integer;
    --g_master      : integer;
    g_address     : t_wishbone_address_array;
    g_mask        : t_wishbone_address_array);

  port (
    slave_i      :     t_wishbone_slave_in_array(g_num_masters-1 downto 0);
    matrix_old_i : in  t_matrix(g_num_masters-1 downto 0, g_num_slaves downto 0);
    matrix_new_o : out t_matrix(g_num_masters-1 downto 0, g_num_slaves downto 0)
    );

end entity;

architecture rtl of cb_matrix_logic is
  alias c_address : t_wishbone_address_array(g_num_slaves-1 downto 0) is g_address;
  alias c_mask    : t_wishbone_address_array(g_num_slaves-1 downto 0) is g_mask;

  subtype row is std_logic_vector(g_num_masters-1 downto 0);
  subtype column is std_logic_vector(g_num_slaves downto 0);

  type slave_matrix is array(g_num_masters-1 downto 0) of column;
  type master_matrix is array(g_num_slaves downto 0) of row;

  signal slave_req   : master_matrix;
  signal master_busy : slave_matrix;

  signal sbusy             : column;
  signal mbusy_pre, mbusy  : row;
  signal addr_match        : slave_matrix;
  signal no_match_n        : row;
  signal request, selected : master_matrix;

begin



  -- A slave is busy iff it services an in-progress cycle
  g1 : for slave in g_num_slaves downto 0 generate
    g2 : for master in g_num_masters-1 downto 0 generate
      slave_req(slave)(master) <= matrix_old_i(master, slave) and slave_i(master).CYC;
    end generate;

    cb_vector_or_7 : entity work.cb_vector_or
      generic map (
        g_width => g_num_masters)
      port map (
        d_i => slave_req(slave),
        q_o => sbusy(slave));

  end generate;

  -- A master is busy iff it services an in-progress cycle
  g3 : for master in g_num_masters-1 downto 0 generate
    g4 : for slave in g_num_slaves downto 0 generate
      master_busy(master)(slave) <= matrix_old_i(master, slave);
    end generate;

    cb_vector_or_8 : entity work.cb_vector_or
      generic map (
        g_width => g_num_slaves + 1)
      port map (
        d_i => master_busy(master),
        q_o => mbusy_pre(master));

    mbusy(master) <= mbusy_pre(master) and slave_i(master).CYC;
  end generate;

  -- Decode the request address to see if master wants access
  g5 : for master in g_num_masters-1 downto 0 generate
    g6 : for slave in g_num_slaves-1 downto 0 generate

      process(slave_i)
      begin
        if (slave_i(master).adr and c_mask(slave)) = c_address(slave) then
          addr_match(master)(slave) <= '1';
        else
          addr_match(master)(slave) <= '0';
        end if;
      end process;

      request(slave)(master) <= slave_i(master).CYC and slave_i(master).STB and addr_match(master)(slave);

    end generate;

    addr_match(master)(g_num_slaves) <= '0';

    -- If no slaves match request, bind to 'error device'
    cb_vector_or_9 : entity work.cb_vector_or
      generic map (
        g_width => g_num_slaves + 1)
      port map (
        d_i => addr_match(master),
        q_o => no_match_n(master));

    request(g_num_slaves)(master) <= slave_i(master).CYC and slave_i(master).STB and not no_match_n(master);
  end generate;

  -- Arbitrate among the requesting masters
  -- Policy: lowest numbered master first
  g7 : for slave in g_num_slaves downto 0 generate

    selected(slave)(0) <= request(slave)(0);  -- master 0 always wins
    g8 : if g_num_masters > 1 generate
      g9 : for master in 1 to g_num_masters-1 generate
        process(request)
        begin
          if unsigned(request(slave)(master-1 downto 0)) = 0 then
            selected(slave)(master) <= request(slave)(master);
          else
            selected(slave)(master) <= '0';
          end if;
        end process;
      end generate;
    end generate;
  end generate;

-- Determine the master granted access
-- Policy: if cycle still in progress, preserve the previous choice

  g10 : for slave in g_num_slaves downto 0 generate
    g11 : for master in g_num_masters-1 downto 0 generate
      process(sbusy, mbusy, matrix_old_i, selected)
      begin
        if sbusy(slave) = '1' or mbusy(master) = '1' then
          matrix_new_o(master, slave) <= matrix_old_i(master, slave);
        else
          matrix_new_o(master, slave) <= selected(slave)(master);
        end if;
      end process;
    end generate;
  end generate;

end rtl;
