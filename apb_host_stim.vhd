library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--use work.io_utils;

entity apb_host_stim is
   generic
   (   HOST_ADDR_WIDTH : integer := 32;
       HOST_DATA_WIDTH : integer := 32;
       SLAVE_ADDR_WIDTH : integer := 8;
       SLAVE_DATA_WIDTH : integer := 8 );
   port (
       pclk_i    : in std_logic;
       presetn_i : in std_logic;
       pready_i  : in std_logic;
       test_adv  : in std_logic;
       paddr_o   : out std_logic_vector(HOST_ADDR_WIDTH-1 downto 0);
       pwdata_o  : out std_logic_vector(HOST_DATA_WIDTH-1 downto 0);
       pselx_o   : out std_logic;
       pwrite_o  : out std_logic;
       penable_o : out std_logic;
       ack_err_o : out std_logic;
       done_o    : out std_logic );
end entity apb_host_stim;

architecture behavioral of apb_host_stim is
-- Test vector data array
constant t_v_length : natural := 16;
type addr_count is range 1 to t_v_length;
type test_array is array(positive range 1 to t_v_length) of std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
constant data_bytes : test_array := (
         x"AA", -- i = 0
         x"55",
         x"01",
         x"03",
         x"07",
         x"0F",
         x"1E",
         x"3C",
         x"78",
         x"F0",
         x"E0",
         x"C0",
         x"80",
         x"55",
         x"AA",
         x"00"  -- i = 15
);

type tx_state is
   ( s_init,
     s_write,
     --s_wait,
     s_error,
     s_idle,
     s_read,
     s_done );

signal current_state, next_state, last_state: tx_state;
signal testvec : std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
signal testadr : std_logic_vector(SLAVE_ADDR_WIDTH-1 downto 0);
signal addr_c_en : std_logic; -- address counter clock enable
signal addr_c_dir : std_logic; -- address counter direction
signal addr_c_tcu : std_logic; -- terminal count up
signal addr_c_tcd : std_logic; -- teminal count down.
signal en_penable : std_logic;
signal pselx : std_logic;

begin
STREG: process(pclk_i, presetn_i)
   begin
       if rising_edge(pclk_i) and presetn_i = '0' then
           -- initialize state machine
           current_state <= s_init;
           --next_state <= s_init;
           --last_state <= s_init;
       elsif rising_edge(pclk_i) then
           current_state <= next_state;
           --last_state <= current_state;
       end if;
   end process;

STTRANS: process(current_state, test_adv, addr_c_tcu, addr_c_tcd, pready_i)
         --variable i : integer := 0;
         variable j : integer := 0;
         variable k : integer := 0;
         --variable en : bit;
         --variable addr : addr_count := 0;
   begin

       case current_state is

           when s_init =>
                ack_err_o <= '0';
                pselx <= '0';
                pwrite_o <= '0';
                en_penable <= '0';
                addr_c_en <= '0';
                addr_c_dir <= '0';
                done_o <= '0';
                j := 0; -- reset error counter.
                if test_adv = '1' then
                   next_state <= s_write;
                   last_state <= s_init;
                end if;

           when s_write =>
                done_o <= '0';
                pwrite_o <= '1';
                pselx <= '1';
                en_penable <= '1';
                addr_c_en <= '1';
                addr_c_dir <= '0'; -- counting up
                if (addr_c_tcu = '0') then
                   next_state <= s_write;
                   last_state <= s_write;
                else
                   next_state <= s_idle;
                   last_state <= s_write;
                end if;
                   -- if we get stuck 4 cycles with no ack
                   -- assume that the bus target has a problem
                   -- an assert an error condition .
                if pready_i = '0' then
                   j := j + 1;
                   if (j > 3) then
                      next_state <= s_error;
                      last_state <= s_write;
                   end if;
                else
                   j := 0;
                end if;

           when s_error =>
                en_penable <= '0';
                pselx <= '0';
                next_state <= s_error;
                ack_err_o <= '1';
                -- stay here until reset.

           when s_idle =>
                en_penable <= '0';
                done_o <= '0';
                pselx <= '0';
                addr_c_en <= '0';
                pwrite_o <= '0';
                last_state <= s_idle;
                if test_adv = '1' then
                   next_state <= s_read; -- wait 8 cycle clocks
                else
                   next_state <= s_idle;
                   j := 0; -- reset error counter.
                end if;

           when s_read =>
                done_o <= '0';
                pselx <= '1';
                en_penable <= '1';
                addr_c_en <= '1';
                pwrite_o <= '0'; -- reading time.
                addr_c_dir <= '1'; -- count downwards for reading.
                last_state <= s_read;
                if addr_c_tcd = '0' then
                   next_state <= s_read;
                else
                   next_state <= s_done;
                end if;
                -- if 4 periods have nACK then error:
                if pready_i = '0' then
                   j := j + 1;
                   if (j > 3) then
                      ack_err_o <= '1';
                      next_state <= s_error;
                   end if;
                else
                   j := 0;
                end if;

           when s_done =>
                en_penable <= '0';
                addr_c_en <= '0';
                pwrite_o <= '0';
                pselx <= '0';
                next_state <= s_done;
                done_o <= '1';

           when others => -- should never be reached.
                en_penable <= '0';
                addr_c_en <= '0';
                pwrite_o <= '0';
                pselx <= '0';
                next_state <= s_done;
                done_o <= '1';
       end case;
   end process;

   -- Address Generation
   ADRCNT : process(pclk_i, presetn_i, addr_c_en, test_adv)
          variable address : addr_count ;
   begin
       -- async reset
       if presetn_i = '0' then
          testadr <= (others => '0');
          testvec <= (others => '0');
          address := 1;
          addr_c_tcu <= '0';
          addr_c_tcd <= '0';
       else
          -- assign address to address register:
          testadr <= std_logic_vector(to_unsigned((address-1), testadr'length));
          --if (address >= 0) and (address < t_v_length) then
          testvec <= data_bytes(address);
          --end if;
          if rising_edge(pclk_i) and addr_c_en = '1' then
             if pready_i = '1' or test_adv = '1' then
                if addr_c_dir = '0' then -- count up
                   if (address < t_v_length) then
                      address := address + 1; -- terminal count at "15"
                      addr_c_tcu <= '0';
                   else
                      addr_c_tcu <= '1';
                   end if;
                else -- or count backwards
                   if (address > 1) then
                      address := address - 1; -- terminate downcount at zero.
                      addr_c_tcd <= '0';
                   else
                      addr_c_tcd <= '1';
                   end if;
                end if;
             end if;
          end if;
       end if;
   end process;

   P_ENABLE : process(pclk_i, presetn_i, pselx_o)
   begin
       if presetn_i = '0' or pselx = '0' then
          penable_o <= '0';
       else
          if rising_edge(pclk_i) then
            if en_penable = '1' then
               penable_o <= '1';
            else
               penable_o <= '0';
            end if;
          end if;
       end if;
   end process;

   pwdata_o(HOST_DATA_WIDTH-1 downto 8) <= (others => '0');
   pwdata_o(SLAVE_DATA_WIDTH-1 downto 0) <= testvec;
       -- <= data_bytes(to_integer(unsigned(testadr)));
   paddr_o(HOST_ADDR_WIDTH-1 downto SLAVE_ADDR_WIDTH+2) <= (others => '0');
   paddr_o(SLAVE_ADDR_WIDTH+1 downto 2) <= testadr(SLAVE_ADDR_WIDTH-1 downto 0);
   paddr_o(1 downto 0) <= (others => '0');
   pselx_o <= pselx;


end architecture;
