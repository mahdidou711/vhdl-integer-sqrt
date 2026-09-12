library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sqrt16 is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;                    -- actif bas (KEY[0])
        start : in  std_logic;                    -- SW[9]
        X_in  : in  std_logic_vector(15 downto 0);
        R_out : out std_logic_vector(7 downto 0); -- résultat
        done  : out std_logic                     -- fin calcul
    );
end sqrt16;

architecture comportementale of sqrt16 is

    type etat_t is (IDLE, COMPUTE, FINISH);
    signal etat  : etat_t;

    signal X_reg : unsigned(16 downto 0); -- 17 bits pour éviter débordement
    signal Z_reg : unsigned(16 downto 0);
    signal V_reg : unsigned(16 downto 0);
    signal cpt   : integer range 0 to 7;

begin

    process(clk, reset)
        variable Z_tmp : unsigned(16 downto 0); -- valeur intermédiaire Z+V
    begin
        if reset = '0' then
            etat  <= IDLE;
            done  <= '0';
            R_out <= (others => '0');
            X_reg <= (others => '0');
            Z_reg <= (others => '0');
            V_reg <= (others => '0');
            cpt   <= 0;

        elsif rising_edge(clk) then
            case etat is

                when IDLE =>
                    done <= '0';
                    if start = '1' then
                        X_reg <= '0' & unsigned(X_in); -- X sur 17 bits
                        V_reg <= to_unsigned(16384, 17); -- 2^14
                        Z_reg <= (others => '0');
                        cpt   <= 0;
                        etat  <= COMPUTE;
                    end if;

                when COMPUTE =>
                    -- étape 1 : Z_tmp = Z + V (variable locale, pas de conflit)
                    Z_tmp := Z_reg + V_reg;

                    -- étape 2 : test X >= Z_tmp
                    if X_reg >= Z_tmp then
                        X_reg <= X_reg - Z_tmp;              -- X = X - Z
                        Z_reg <= shift_right(Z_tmp + V_reg, 1); -- Z = (Z+2V)/2
                    else
                        Z_reg <= shift_right(Z_tmp - V_reg, 1); -- Z = Z/2
                    end if;

                    -- étape 3 : V = V/4
                    V_reg <= shift_right(V_reg, 2);

                    -- compteur
                    if cpt = 7 then
                        etat <= FINISH;
                    else
                        cpt <= cpt + 1;
                    end if;

                when FINISH =>
                    R_out <= std_logic_vector(Z_reg(7 downto 0));
                    done  <= '1';
                    etat  <= IDLE;

            end case;
        end if;
    end process;

end comportementale;