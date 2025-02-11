library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity apb_wb_bridge is
    generic (
        HOST_ADDR_WIDTH : integer := 32;
        SLAVE_DATA_WIDTH : integer := 8;
        HOST_DATA_WIDTH : integer := 32;
        SLAVE_ADDR_WIDTH : integer := 5;
        ADDRESSING_MODE : string := "byte" -- byte addressing, 16-bit lword, or 32-bit int
    );
    port (
        -- System CLK/RST
        apb_pclk_i     : in  std_logic;
        apb_resetn_i   : in  std_logic;
        -- APB Signals
        apb_addr_i     : in  std_logic_vector(HOST_ADDR_WIDTH-1 downto 0);
        apb_pselx_i    : in  std_logic;
        apb_penable_i  : in  std_logic;
        apb_pwrite_i   : in  std_logic;
        apb_pwdata_i   : in  std_logic_vector(HOST_DATA_WIDTH-1 downto 0);
        apb_pready_o   : out std_logic;
        apb_prdata_o   : out std_logic_vector(HOST_DATA_WIDTH-1 downto 0);
        apb_pslverr_o  : out std_logic;

        -- Wishbone Signals
        wb_clk_o    : out std_logic;
        wb_rst_o    : out std_logic;
        wb_cyc_o    : out std_logic;
        wb_stb_o    : out std_logic;
        wb_we_o     : out std_logic;
        wb_adr_o    : out std_logic_vector(SLAVE_ADDR_WIDTH-1 downto 0);
        wb_dat_o    : out std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
        wb_dat_i    : in  std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
        wb_ack_i    : in  std_logic;
        
        -- Interrupts
        apb_int_o   : out std_logic;
        wb_int_i    : in std_logic
    );
end apb_wb_bridge;

architecture Behavioral of apb_wb_bridge is

begin
    -- Connect APB clock and reset to Wishbone clock and reset
    wb_clk_o <= apb_pclk_i;
    wb_rst_o <= not apb_resetn_i;

    -- Map APB address to Wishbone address
    byte_addressing: if ADDRESSING_MODE = "byte" generate
        wb_adr_o <= apb_addr_i(SLAVE_ADDR_WIDTH+1 downto 2);
    end generate byte_addressing;
    
    short_addressing: if ADDRESSING_MODE = "lword" generate
        wb_adr_o <= apb_addr_i(SLAVE_ADDR_WIDTH downto 1);
    end generate short_addressing;
    
    int_addressing: if ADDRESSING_MODE = "int" generate
        wb_adr_o <= apb_addr_i(SLAVE_ADDR_WIDTH-1 downto 0);
    end generate int_addressing;
    
    -- Map APB select and enable to Wishbone strobe and cycle
    wb_stb_o <= apb_pselx_i;
    wb_cyc_o <= apb_pselx_i;

    -- Map APB write enable to Wishbone write enable
    wb_we_o <= apb_pwrite_i;

    -- Map APB write data to Wishbone data (only least significant byte)
    wb_dat_o(SLAVE_DATA_WIDTH-1 downto 0) <= apb_pwdata_i(SLAVE_DATA_WIDTH-1 downto 0);

    -- Map Wishbone acknowledge to APB ready signal
    apb_pready_o <= wb_ack_i and apb_penable_i;

    -- Map Wishbone read data to APB read data (extend LSB to 32-bit, upper bytes zeroed)
    apb_prdata_o(SLAVE_DATA_WIDTH-1 downto 0) <= wb_dat_i(SLAVE_DATA_WIDTH-1 downto 0);
    apb_prdata_o(HOST_DATA_WIDTH-1 downto SLAVE_DATA_WIDTH) <= (others => '0');

    -- APB slave error fixed to 0
    apb_pslverr_o <= '0';

end Behavioral;

