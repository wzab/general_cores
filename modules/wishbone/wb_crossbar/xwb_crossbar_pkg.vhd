library ieee;
use ieee.std_logic_1164.all;

library work;

package xwb_crossbar_pkg is

  -- Crossbar connection matrix
  type t_matrix is array (integer range <>, integer range <>) of std_logic;

end package;

