-------------------------------------------------------------------------------
-- Title      : An MxS Wishbone crossbar switch
-- Project    : General Cores Library (gencores)
-------------------------------------------------------------------------------
-- File       : cb_vector_or.vhd
-- Author     : Tomasz Wlostowski
-- Company    : GSI
-- Created    : 2011-06-08
-- Last update: 2018-01-23
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description:
--
-- Ors all bits in a vector together
-------------------------------------------------------------------------------
-- Copyright (c) 2017 CERN, licensed under LGPL v2.1
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

entity cb_vector_or is
  generic(
    g_width : integer);
  port(
    d_i : in  std_logic_vector(g_width-1 downto 0);
    q_o : out std_logic
    );
end entity;

architecture rtl of cb_vector_or is

  signal tmp : std_logic_vector(g_width -1 downto 0);
begin

  g1 : for i in 0 to g_width-1 generate
    tmp(i) <= '1' when d_i(i) = '1' or d_i(i) = 'H' else '0';
  end generate;

  q_o <= '1' when unsigned(tmp) /= 0 else '0';
end rtl;
