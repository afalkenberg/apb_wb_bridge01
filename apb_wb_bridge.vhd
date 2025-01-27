library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity apb_wb_bridge is
    generic (
        ADDR_WIDTH : integer := 32;
        SLAVE_DATA_WIDTH : integer := 8;
        HOST_DATA_WIDTH : integer := 32
    );
    port (
        -- APB Signals
        apb_pclk     : in  std_logic;
        apb_resetn   : in  std_logic;
        apb_addr     : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        apb_pselx    : in  std_logic;
        apb_penable  : in  std_logic;
        apb_pwrite   : in  std_logic;
        apb_pwdata   : in  std_logic_vector(HOST_DATA_WIDTH-1 downto 0);
        apb_pready   : out std_logic;
        apb_prdata   : out std_logic_vector(HOST_DATA_WIDTH-1 downto 0);
        apb_pslverr  : out std_logic;

        -- Wishbone Signals
        wb_clk_o    : out std_logic;
        wb_rst_o    : out std_logic;
        wb_cyc_o    : out std_logic;
        wb_stb_o    : out std_logic;
        wb_we_o     : out std_logic;
        wb_adr_o    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        wb_dat_o    : out std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
        wb_dat_i    : in  std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
        wb_ack_i    : in  std_logic
    );
end apb_wb_bridge;

architecture Behavioral of apb_wb_bridge is
begin
    assert (SLAVE_DATA_WIDTH <= HOST_DATA_WIDTH) report "Error: SLAVE bus width exceeds HOST." severity Failure;
    -- Connect APB clock and reset to Wishbone clock and reset
    wb_clk_o <= apb_pclk;
    wb_rst_o <= not apb_resetn;

    -- Map APB address to Wishbone address
    wb_adr_o <= apb_addr;

    -- Map APB select and enable to Wishbone strobe and cycle
    wb_stb_o <= apb_pselx;
    wb_cyc_o <= apb_pselx;

    -- Map APB write enable to Wishbone write enable
    wb_we_o <= apb_pwrite;

    -- Map APB write data to Wishbone data (only least significant byte)
    wb_dat_o <= apb_pwdata(SLAVE_DATA_WIDTH-1 downto 0);

    -- Map Wishbone acknowledge to APB ready signal
    apb_pready <= wb_ack_i and apb_penable;

    -- Map Wishbone read data to APB read data (extend LSB to 32-bit, upper bytes zeroed)
    apb_prdata(SLAVE_DATA_WIDTH-1 downto 0) <= wb_dat_i;
    apb_prdata <= (others => '0');

    -- APB slave error fixed to 0
    apb_pslverr <= '0';

end Behavioral;

