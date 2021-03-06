---------------------------------------------------------------------------------------
-- Title          : Wishbone slave core for MultiBoot controller
---------------------------------------------------------------------------------------
-- File           : multiboot_regs.vhd
-- Author         : auto-generated by wbgen2 from multiboot_regs.wb
-- Created        : Thu Feb 13 18:39:52 2014
-- Standard       : VHDL'87
---------------------------------------------------------------------------------------
-- THIS FILE WAS GENERATED BY wbgen2 FROM SOURCE FILE multiboot_regs.wb
-- DO NOT HAND-EDIT UNLESS IT'S ABSOLUTELY NECESSARY!
---------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity multiboot_regs is
  port (
    rst_n_i                                  : in     std_logic;
    clk_sys_i                                : in     std_logic;
    wb_adr_i                                 : in     std_logic_vector(2 downto 0);
    wb_dat_i                                 : in     std_logic_vector(31 downto 0);
    wb_dat_o                                 : out    std_logic_vector(31 downto 0);
    wb_cyc_i                                 : in     std_logic;
    wb_sel_i                                 : in     std_logic_vector(3 downto 0);
    wb_stb_i                                 : in     std_logic;
    wb_we_i                                  : in     std_logic;
    wb_ack_o                                 : out    std_logic;
    wb_stall_o                               : out    std_logic;
-- Port for std_logic_vector field: 'Configuration register address' in reg: 'CR'
    reg_cr_cfgregadr_o                       : out    std_logic_vector(5 downto 0);
-- Port for MONOSTABLE field: 'Read FPGA configuration register' in reg: 'CR'
    reg_cr_rdcfgreg_o                        : out    std_logic;
-- Ports for BIT field: 'Unlock bit for the IPROG command' in reg: 'CR'
    reg_cr_iprog_unlock_o                    : out    std_logic;
    reg_cr_iprog_unlock_i                    : in     std_logic;
    reg_cr_iprog_unlock_load_o               : out    std_logic;
-- Ports for BIT field: 'Start IPROG sequence' in reg: 'CR'
    reg_cr_iprog_o                           : out    std_logic;
    reg_cr_iprog_i                           : in     std_logic;
    reg_cr_iprog_load_o                      : out    std_logic;
-- Port for std_logic_vector field: 'Configuration register image' in reg: 'SR'
    reg_sr_cfgregimg_i                       : in     std_logic_vector(15 downto 0);
-- Port for BIT field: 'Configuration register image valid' in reg: 'SR'
    reg_sr_imgvalid_i                        : in     std_logic;
-- Ports for BIT field: 'MultiBoot FSM stalled at one point and was reset by FSM watchdog' in reg: 'SR'
    reg_sr_wdto_o                            : out    std_logic;
    reg_sr_wdto_i                            : in     std_logic;
    reg_sr_wdto_load_o                       : out    std_logic;
-- Port for std_logic_vector field: 'Bits of GBBAR register' in reg: 'GBBAR'
    reg_gbbar_bits_o                         : out    std_logic_vector(31 downto 0);
-- Port for std_logic_vector field: 'Bits of MBBAR register' in reg: 'MBBAR'
    reg_mbbar_bits_o                         : out    std_logic_vector(31 downto 0);
-- Port for std_logic_vector field: 'Flash data field' in reg: 'FAR'
    reg_far_data_o                           : out    std_logic_vector(23 downto 0);
    reg_far_data_i                           : in     std_logic_vector(23 downto 0);
    reg_far_data_load_o                      : out    std_logic;
-- Port for std_logic_vector field: 'Number of DATA fields to send and receive in one transfer:' in reg: 'FAR'
    reg_far_nbytes_o                         : out    std_logic_vector(1 downto 0);
-- Port for MONOSTABLE field: 'Start transfer to and from flash' in reg: 'FAR'
    reg_far_xfer_o                           : out    std_logic;
-- Port for BIT field: 'Chip select bit' in reg: 'FAR'
    reg_far_cs_o                             : out    std_logic;
-- Port for BIT field: 'Flash access ready' in reg: 'FAR'
    reg_far_ready_i                          : in     std_logic
  );
end multiboot_regs;

architecture syn of multiboot_regs is

signal reg_cr_cfgregadr_int                     : std_logic_vector(5 downto 0);
signal reg_cr_rdcfgreg_dly0                     : std_logic      ;
signal reg_cr_rdcfgreg_int                      : std_logic      ;
signal reg_gbbar_bits_int                       : std_logic_vector(31 downto 0);
signal reg_mbbar_bits_int                       : std_logic_vector(31 downto 0);
signal reg_far_nbytes_int                       : std_logic_vector(1 downto 0);
signal reg_far_xfer_dly0                        : std_logic      ;
signal reg_far_xfer_int                         : std_logic      ;
signal reg_far_cs_int                           : std_logic      ;
signal ack_sreg                                 : std_logic_vector(9 downto 0);
signal rddata_reg                               : std_logic_vector(31 downto 0);
signal wrdata_reg                               : std_logic_vector(31 downto 0);
signal bwsel_reg                                : std_logic_vector(3 downto 0);
signal rwaddr_reg                               : std_logic_vector(2 downto 0);
signal ack_in_progress                          : std_logic      ;
signal wr_int                                   : std_logic      ;
signal rd_int                                   : std_logic      ;
signal allones                                  : std_logic_vector(31 downto 0);
signal allzeros                                 : std_logic_vector(31 downto 0);

begin
-- Some internal signals assignments. For (foreseen) compatibility with other bus standards.
  wrdata_reg <= wb_dat_i;
  bwsel_reg <= wb_sel_i;
  rd_int <= wb_cyc_i and (wb_stb_i and (not wb_we_i));
  wr_int <= wb_cyc_i and (wb_stb_i and wb_we_i);
  allones <= (others => '1');
  allzeros <= (others => '0');
-- 
-- Main register bank access process.
  process (clk_sys_i, rst_n_i)
  begin
    if (rst_n_i = '0') then 
      ack_sreg <= "0000000000";
      ack_in_progress <= '0';
      rddata_reg <= "00000000000000000000000000000000";
      reg_cr_cfgregadr_int <= "000000";
      reg_cr_rdcfgreg_int <= '0';
      reg_cr_iprog_unlock_load_o <= '0';
      reg_cr_iprog_load_o <= '0';
      reg_sr_wdto_load_o <= '0';
      reg_gbbar_bits_int <= "00000000000000000000000000000000";
      reg_mbbar_bits_int <= "00000000000000000000000000000000";
      reg_far_data_load_o <= '0';
      reg_far_nbytes_int <= "00";
      reg_far_xfer_int <= '0';
      reg_far_cs_int <= '0';
    elsif rising_edge(clk_sys_i) then
-- advance the ACK generator shift register
      ack_sreg(8 downto 0) <= ack_sreg(9 downto 1);
      ack_sreg(9) <= '0';
      if (ack_in_progress = '1') then
        if (ack_sreg(0) = '1') then
          reg_cr_rdcfgreg_int <= '0';
          reg_cr_iprog_unlock_load_o <= '0';
          reg_cr_iprog_load_o <= '0';
          reg_sr_wdto_load_o <= '0';
          reg_far_data_load_o <= '0';
          reg_far_xfer_int <= '0';
          ack_in_progress <= '0';
        else
          reg_cr_iprog_unlock_load_o <= '0';
          reg_cr_iprog_load_o <= '0';
          reg_sr_wdto_load_o <= '0';
          reg_far_data_load_o <= '0';
        end if;
      else
        if ((wb_cyc_i = '1') and (wb_stb_i = '1')) then
          case rwaddr_reg(2 downto 0) is
          when "000" => 
            if (wb_we_i = '1') then
              reg_cr_cfgregadr_int <= wrdata_reg(5 downto 0);
              reg_cr_rdcfgreg_int <= wrdata_reg(6);
              reg_cr_iprog_unlock_load_o <= '1';
              reg_cr_iprog_load_o <= '1';
            end if;
            rddata_reg(5 downto 0) <= reg_cr_cfgregadr_int;
            rddata_reg(6) <= '0';
            rddata_reg(16) <= reg_cr_iprog_unlock_i;
            rddata_reg(17) <= reg_cr_iprog_i;
            rddata_reg(7) <= 'X';
            rddata_reg(8) <= 'X';
            rddata_reg(9) <= 'X';
            rddata_reg(10) <= 'X';
            rddata_reg(11) <= 'X';
            rddata_reg(12) <= 'X';
            rddata_reg(13) <= 'X';
            rddata_reg(14) <= 'X';
            rddata_reg(15) <= 'X';
            rddata_reg(18) <= 'X';
            rddata_reg(19) <= 'X';
            rddata_reg(20) <= 'X';
            rddata_reg(21) <= 'X';
            rddata_reg(22) <= 'X';
            rddata_reg(23) <= 'X';
            rddata_reg(24) <= 'X';
            rddata_reg(25) <= 'X';
            rddata_reg(26) <= 'X';
            rddata_reg(27) <= 'X';
            rddata_reg(28) <= 'X';
            rddata_reg(29) <= 'X';
            rddata_reg(30) <= 'X';
            rddata_reg(31) <= 'X';
            ack_sreg(2) <= '1';
            ack_in_progress <= '1';
          when "001" => 
            if (wb_we_i = '1') then
              reg_sr_wdto_load_o <= '1';
            end if;
            rddata_reg(15 downto 0) <= reg_sr_cfgregimg_i;
            rddata_reg(16) <= reg_sr_imgvalid_i;
            rddata_reg(17) <= reg_sr_wdto_i;
            rddata_reg(18) <= 'X';
            rddata_reg(19) <= 'X';
            rddata_reg(20) <= 'X';
            rddata_reg(21) <= 'X';
            rddata_reg(22) <= 'X';
            rddata_reg(23) <= 'X';
            rddata_reg(24) <= 'X';
            rddata_reg(25) <= 'X';
            rddata_reg(26) <= 'X';
            rddata_reg(27) <= 'X';
            rddata_reg(28) <= 'X';
            rddata_reg(29) <= 'X';
            rddata_reg(30) <= 'X';
            rddata_reg(31) <= 'X';
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "010" => 
            if (wb_we_i = '1') then
              reg_gbbar_bits_int <= wrdata_reg(31 downto 0);
            end if;
            rddata_reg(31 downto 0) <= reg_gbbar_bits_int;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "011" => 
            if (wb_we_i = '1') then
              reg_mbbar_bits_int <= wrdata_reg(31 downto 0);
            end if;
            rddata_reg(31 downto 0) <= reg_mbbar_bits_int;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "100" => 
            if (wb_we_i = '1') then
              reg_far_data_load_o <= '1';
              reg_far_nbytes_int <= wrdata_reg(25 downto 24);
              reg_far_xfer_int <= wrdata_reg(26);
              reg_far_cs_int <= wrdata_reg(27);
            end if;
            rddata_reg(23 downto 0) <= reg_far_data_i;
            rddata_reg(25 downto 24) <= reg_far_nbytes_int;
            rddata_reg(26) <= '0';
            rddata_reg(27) <= reg_far_cs_int;
            rddata_reg(28) <= reg_far_ready_i;
            rddata_reg(29) <= 'X';
            rddata_reg(30) <= 'X';
            rddata_reg(31) <= 'X';
            ack_sreg(2) <= '1';
            ack_in_progress <= '1';
          when others =>
-- prevent the slave from hanging the bus on invalid address
            ack_in_progress <= '1';
            ack_sreg(0) <= '1';
          end case;
        end if;
      end if;
    end if;
  end process;
  
  
-- Drive the data output bus
  wb_dat_o <= rddata_reg;
-- Configuration register address
  reg_cr_cfgregadr_o <= reg_cr_cfgregadr_int;
-- Read FPGA configuration register
  process (clk_sys_i, rst_n_i)
  begin
    if (rst_n_i = '0') then 
      reg_cr_rdcfgreg_dly0 <= '0';
      reg_cr_rdcfgreg_o <= '0';
    elsif rising_edge(clk_sys_i) then
      reg_cr_rdcfgreg_dly0 <= reg_cr_rdcfgreg_int;
      reg_cr_rdcfgreg_o <= reg_cr_rdcfgreg_int and (not reg_cr_rdcfgreg_dly0);
    end if;
  end process;
  
  
-- Unlock bit for the IPROG command
  reg_cr_iprog_unlock_o <= wrdata_reg(16);
-- Start IPROG sequence
  reg_cr_iprog_o <= wrdata_reg(17);
-- Configuration register image
-- Configuration register image valid
-- MultiBoot FSM stalled at one point and was reset by FSM watchdog
  reg_sr_wdto_o <= wrdata_reg(17);
-- Bits of GBBAR register
  reg_gbbar_bits_o <= reg_gbbar_bits_int;
-- Bits of MBBAR register
  reg_mbbar_bits_o <= reg_mbbar_bits_int;
-- Flash data field
  reg_far_data_o <= wrdata_reg(23 downto 0);
-- Number of DATA fields to send and receive in one transfer:
  reg_far_nbytes_o <= reg_far_nbytes_int;
-- Start transfer to and from flash
  process (clk_sys_i, rst_n_i)
  begin
    if (rst_n_i = '0') then 
      reg_far_xfer_dly0 <= '0';
      reg_far_xfer_o <= '0';
    elsif rising_edge(clk_sys_i) then
      reg_far_xfer_dly0 <= reg_far_xfer_int;
      reg_far_xfer_o <= reg_far_xfer_int and (not reg_far_xfer_dly0);
    end if;
  end process;
  
  
-- Chip select bit
  reg_far_cs_o <= reg_far_cs_int;
-- Flash access ready
  rwaddr_reg <= wb_adr_i;
  wb_stall_o <= (not ack_sreg(0)) and (wb_stb_i and wb_cyc_i);
-- ACK signal generation. Just pass the LSB of ACK counter.
  wb_ack_o <= ack_sreg(0);
end syn;
