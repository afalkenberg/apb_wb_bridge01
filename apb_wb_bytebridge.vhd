-- AMBA APB to Wishbone Bridge - Byte Lane version
--
-- (C) 2025 B. Jordan
-- 
-- GNU GPL 3.0
-- 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity apb_wb_bytebridge is
    generic (
		APB_ENABLE : boolean := True;
		WB_ENABLE : boolean := True;
    );
    port (
        -- System CLK/RST
        apb_pclk_i     : in  std_logic;
        apb_resetn_i   : in  std_logic;
        -- APB Signals
        apb_addr_i     : in  std_logic_vector(31 downto 0);
        apb_pselx_i    : in  std_logic;
        apb_penable_i  : in  std_logic;
        apb_pwrite_i   : in  std_logic;
        apb_pwdata_i   : in  std_logic_vector(31 downto 0);
        apb_pready_o   : out std_logic;
        apb_prdata_o   : out std_logic_vector(31 downto 0);
        apb_pslverr_o  : out std_logic;

        -- Wishbone Signals
        wb_clk_o    : out std_logic;
        wb_rst_o    : out std_logic;
        wb_cyc_o    : out std_logic;
        wb_stb_o    : out std_logic;
        wb_we_o     : out std_logic;
        wb_adr_o    : out std_logic_vector(7 downto 0);
        wb_dat_o    : out std_logic_vector(7 downto 0);
        wb_dat_i    : in  std_logic_vector(7 downto 0);
        wb_ack_i    : in  std_logic
        
    );
end apb_wb_bytebridge;

architecture Behavioral of apb_wb_bridge is
	signal byte_enable 	: std_logic_vector(1 downto 0);
	signal out_word		: std_logic_vector(31 downto 0);
	signal wb_in_byte	: std_logic_vector(7 downto 0);
	signal apb_in_byte	: std_logic_vector(7 downto 0);

begin
    -- Connect APB clock and reset to Wishbone clock and reset
    wb_clk_o <= apb_pclk_i;
    wb_rst_o <= not apb_resetn_i;
	wb_in_byte <= wb_dat_i;
	byte_enable <= apb_addr_i(1 downto 0);
	
	-- Async Byte Enable 1-to-4 demux / mux
	byte_lane: process (byte_enable) is
		when "00" =>
			out_word(7 downto 0)  <= wb_in_byte;
			out_word(31 downto 8) <= (others => '0');
			apb_in_byte <= apb_pwdata_i(7 downto 0);
		when "01" =>
			out_word(15 downto 8)  <= wb_in_byte;
			out_word(31 downto 16) <= (others => '0');
			out_word(7 downto 0)   <= (others => '0');
			apb_in_byte <= apb_pwdata_i(15 downto 8);
		when "10" =>
			out_word(23 downto 16) 	<= wb_in_byte;
			out_word(31 downto 24) 	<= (others => '0');
			out_word(15 downto 8) 	<= (others => '0');
			apb_in_byte <= apb_pwdata_i(23 downto 16);
		when "11" =>
			out_word(31 downto 24) 	<= wb_in_byte;
			out_word(23 downto 0) 	<= (others => '0');
			apb_in_byte <= apb_pwdata_i(31 downto 24);
	end process byte_lane;

    -- Map APB select and enable to Wishbone strobe and cycle
    wb_stb_o <= apb_pselx_i;
    wb_cyc_o <= apb_pselx_i;

    -- Map APB write enable to Wishbone write enable
    wb_we_o <= apb_pwrite_i;

    -- Map Wishbone acknowledge to APB ready signal
    apb_pready_o <= wb_ack_i and apb_penable_i;

	-- 32-bit APB output from octale 1-to-4 demux
	apb_prdata_o <= out_word;
    -- Map byte-select mux from APB to Wishbone data
    wb_dat_o <= apb_in_byte;

    -- APB slave error fixed to 0
    apb_pslverr_o <= '0';
	
end Behavioral;

