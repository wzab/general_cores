-------------------------------------------------------------------------------
-- Title      : An MxS Wishbone crossbar switch
-- Project    : General Cores Library (gencores)
-------------------------------------------------------------------------------
-- File       : xwb_crossbar.vhd
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

entity xwb_crossbar is
  generic(
    g_num_masters : integer := 2;
    g_num_slaves  : integer := 1;
    g_registered  : boolean := false;
                                        -- Address of the slaves connected
    g_address     : t_wishbone_address_array;
    g_mask        : t_wishbone_address_array);
  port(
    clk_sys_i : in  std_logic;
    rst_n_i   : in  std_logic;
                                        -- Master connections (INTERCON is a slave)
    slave_i   : in  t_wishbone_slave_in_array(g_num_masters-1 downto 0);
    slave_o   : out t_wishbone_slave_out_array(g_num_masters-1 downto 0);
                                        -- Slave connections (INTERCON is a master)
    master_i  : in  t_wishbone_master_in_array(g_num_slaves-1 downto 0);
    master_o  : out t_wishbone_master_out_array(g_num_slaves-1 downto 0);
                                        -- Master granted access to SDB for use by MSI crossbar (please ignore it)
    sdb_sel_o : out std_logic_vector(g_num_masters-1 downto 0));
end xwb_crossbar;

architecture rtl of xwb_crossbar is
  alias c_address : t_wishbone_address_array(g_num_slaves-1 downto 0) is g_address;
  alias c_mask    : t_wishbone_address_array(g_num_slaves-1 downto 0) is g_mask;

                                                -- Confirm that no address ranges overlap
  function f_ranges_ok
    return boolean
  is
    constant zero  : t_wishbone_address                                              := (others => '0');
    constant align : std_logic_vector(f_ceil_log2(c_wishbone_data_width)-4 downto 0) := (others => '0');
  begin
                                        -- all (i,j) with 0 <= i < j < n
    if g_num_slaves > 1 then
      for i in 0 to g_num_slaves-2 loop
        for j in i+1 to g_num_slaves-1 loop
          assert not (((c_mask(i) and c_mask(j)) and (c_address(i) xor c_address(j))) = zero) or
            ((c_mask(i) or not c_address(i)) = zero) or  -- disconnected slave?
            ((c_mask(j) or not c_address(j)) = zero)     -- disconnected slave?
            report "Address ranges must be distinct (slaves " &
            integer'image(i) & "[" & f_bits2string(c_address(i)) & "/" &
            f_bits2string(c_mask(i)) & "] & " &
            integer'image(j) & "[" & f_bits2string(c_address(j)) & "/" &
            f_bits2string(c_mask(j)) & "])"
            severity failure;
        end loop;
      end loop;
    end if;
    for i in 0 to g_num_slaves-1 loop
      assert (c_address(i) and not c_mask(i)) = zero or  -- at least 1 bit outside mask
        (not c_address(i) or c_mask(i)) = zero  -- all bits outside mask (= disconnected)
        report "Address bits not in mask; slave #" &
        integer'image(i) & "[" & f_bits2string(c_address(i)) & "/" &
        f_bits2string(c_mask(i)) & "]"
        severity failure;

      assert c_mask(i)(align'range) = align
        report "Address space smaller than a wishbone register; slave #" &
        integer'image(i) & "[" & f_bits2string(c_address(i)) & "/" &
        f_bits2string(c_mask(i)) & "]"
        severity failure;

                                        -- Working case
      report "Mapping slave #" &
        integer'image(i) & "[" & f_bits2string(c_address(i)) & "/" &
        f_bits2string(c_mask(i)) & "]"
        severity note;
    end loop;
    return true;
  end f_ranges_ok;
  constant c_ok : boolean := f_ranges_ok;

                                        -- Crossbar connection matrix
  subtype matrix is t_matrix (g_num_masters-1 downto 0, g_num_slaves downto 0);

                                        -- Add an 'error' device to the list of slaves
  signal master_ie   : t_wishbone_master_in_array(g_num_slaves downto 0);
  signal master_oe   : t_wishbone_master_out_array(g_num_slaves downto 0);
  signal virtual_ERR : std_logic;

  signal matrix_old : matrix;           -- Registered connection matrix
  signal matrix_new : matrix;           -- The new values of the matrix

                                        -- Either matrix_old or matrix_new, depending on g_registered
  signal granted : matrix;

begin
                                        -- The virtual error slave is pretty straight-forward:
  master_o                           <= master_oe(g_num_slaves-1 downto 0);
  master_ie(g_num_slaves-1 downto 0) <= master_i;

  master_ie(g_num_slaves) <= (
    ACK   => '0',
    ERR   => virtual_ERR,
    RTY   => '0',
    STALL => '0',
    DAT   => (others => '0'),
    INT   => '0');
  virtual_error_slave : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      virtual_ERR <= master_oe(g_num_slaves).CYC and master_oe(g_num_slaves).STB;
    end if;
  end process virtual_error_slave;

-- Update the matrix
  cb_matrix_logic_1 : entity work.cb_matrix_logic
    generic map (
      g_num_masters => g_num_masters,
      g_num_slaves  => g_num_slaves,
      g_address     => g_address,
      g_mask        => g_mask)
    port map (
      slave_i      => slave_i,
      matrix_old_i => matrix_old,
      matrix_new_o => matrix_new);

  main : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        matrix_old <= (others => (others => '0'));
      else
        matrix_old <= matrix_new;
      end if;
    end if;
  end process main;

                                        -- Is the crossbar combinatorial or registered
  granted <= matrix_old when g_registered else matrix_new;

                                        -- Make the slave connections
  slave_matrixs : for slave in g_num_slaves downto 0 generate

    cb_slave_logic_1 : entity work.cb_slave_logic
      generic map (
        g_num_masters => g_num_masters,
        g_num_slaves  => g_num_slaves,
        g_slave       => slave)
      port map (
        out_o     => master_oe(slave),
        granted_i => granted,
        slave_i   => slave_i);


  end generate;

                                        -- Make the master connections
  master_matrixs : for master in g_num_masters-1 downto 0 generate

    cb_master_logic_1 : entity work.cb_master_logic
      generic map (
        g_num_masters => g_num_masters,
        g_num_slaves  => g_num_slaves,
        g_master      => master)
      port map (
        out_o     => slave_o(master),
        granted_i => granted,
        master_i  => master_ie);

  end generate;

                                        -- Tell SDB which master is accessing it (SDB is last slave)
  sdb_masters : for master in g_num_masters-1 downto 0 generate
    sdb_sel_o(master) <= granted(master, g_num_slaves-1);
  end generate;

end rtl;
