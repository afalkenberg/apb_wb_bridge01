library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity wb_target_mem is
   generic (
      SLAVE_ADDR_WIDTH : integer := 8;
      SLAVE_DATA_WIDTH : integer := 8
   );
   port (
      wb_clk_i : in std_logic;
      wb_rst_i : in std_logic;
      wb_cyc_i : in std_logic;
      wb_stb_i : in std_logic;
      wb_we_i  : in std_logic;
      wb_adr_i : in std_logic_vector(SLAVE_ADDR_WIDTH-1 downto 0);
      wb_dat_i : in std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0); -- Data from master (for writes)
      wb_dat_o : out std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0); -- Data to master (for reads)
      wb_ack_o : out std_logic;
      wb_int_o : out std_logic  -- Interrupt output
   );
end wb_target_mem;

architecture Behavioral of wb_target_mem is
    -- Memory array: 256 bytes
    type mem_array is array (0 to 2**SLAVE_ADDR_WIDTH-1) of std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
    signal mem : mem_array := (others => (others => '0'));

    signal transaction_count : integer := 0;
    signal ack_reg    : std_logic := '0';
    signal delay_ack  : std_logic := '0';
    signal int_reg    : std_logic := '0';
    signal read_data_reg : std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0) := (others => '0');
begin

    process(wb_clk_i)
    begin
       if rising_edge(wb_clk_i) then
           if wb_rst_i = '1' then
               mem <= (others => (others => '0'));
               transaction_count <= 0;
               ack_reg    <= '0';
               delay_ack  <= '0';
               int_reg    <= '0';
               read_data_reg <= (others => '0');
           else
               ack_reg <= '0';  -- default: deassert ack

               if (wb_cyc_i = '1' and wb_stb_i = '1') then
                   transaction_count <= transaction_count + 1;
                   -- Every 7th transaction delay the ack by one extra cycle.
                   if (transaction_count mod 7 = 6) then
                       if delay_ack = '0' then
                           delay_ack <= '1';  -- delay this cycle
                       else
                           ack_reg <= '1';
                           delay_ack <= '0';
                       end if;
                   else
                       ack_reg <= '1';
                   end if;
                   
                   if wb_we_i = '1' then
                       -- Write transaction: update memory at addressed location.
                       mem(to_integer(unsigned(wb_adr_i))) <= wb_dat_i;
                       -- Special interrupt handling:
                       if wb_adr_i = x"FE" then
                           int_reg <= '1';
                       elsif wb_adr_i = x"FF" then
                           int_reg <= '0';
                       end if;
                   else
                       -- Read transaction: capture the memory data.
                       read_data_reg <= mem(to_integer(unsigned(wb_adr_i)));
                   end if;
               end if;
           end if;
       end if;
    end process;
    
    wb_ack_o <= ack_reg;
    wb_int_o <= int_reg;
    wb_dat_o <= read_data_reg;
    
end Behavioral;
