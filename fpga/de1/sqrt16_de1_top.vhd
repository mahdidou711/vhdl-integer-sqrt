library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sqrt16_de1_top is
    port (
        CLOCK_50 : in  std_logic;
        KEY0     : in  std_logic;
        SW       : in  std_logic_vector(9 downto 0);
        LEDR0    : out std_logic;
        HEX0     : out std_logic_vector(6 downto 0);
        HEX1     : out std_logic_vector(6 downto 0);
        HEX2     : out std_logic_vector(6 downto 0);
        HEX3     : out std_logic_vector(6 downto 0)
    );
end entity sqrt16_de1_top;

architecture rtl of sqrt16_de1_top is
    constant SEG_BLANK : std_logic_vector(6 downto 0) := "1111111";

    signal low_byte         : std_logic_vector(7 downto 0) := (others => '0');
    signal high_byte        : std_logic_vector(7 downto 0) := (others => '0');
    signal core_input       : std_logic_vector(15 downto 0);
    signal core_result      : std_logic_vector(7 downto 0);
    signal core_done        : std_logic;

    signal start_meta       : std_logic := '0';
    signal start_sync       : std_logic := '0';
    signal start_sync_delay : std_logic := '0';
    signal launch_pulse     : std_logic;

    signal busy             : std_logic := '0';
    signal completion_latch : std_logic := '0';
    signal result_value     : integer range 0 to 255;

    function to_7segment(digit : natural) return std_logic_vector is
        variable segments : std_logic_vector(6 downto 0);
    begin
        case digit is
            when 0      => segments := "1000000";
            when 1      => segments := "1111001";
            when 2      => segments := "0100100";
            when 3      => segments := "0110000";
            when 4      => segments := "0011001";
            when 5      => segments := "0010010";
            when 6      => segments := "0000010";
            when 7      => segments := "1111000";
            when 8      => segments := "0000000";
            when 9      => segments := "0010000";
            when others => segments := SEG_BLANK;
        end case;
        return segments;
    end function to_7segment;
begin
    -- Two flip-flops bring the mechanical switch into the clock domain. The
    -- delayed synchronized value turns one low-to-high transition into one pulse.
    synchronize_start : process(CLOCK_50, KEY0)
    begin
        if KEY0 = '0' then
            start_meta       <= '0';
            start_sync       <= '0';
            start_sync_delay <= '0';
        elsif rising_edge(CLOCK_50) then
            start_meta       <= SW(9);
            start_sync       <= start_meta;
            start_sync_delay <= start_sync;
        end if;
    end process synchronize_start;

    launch_pulse <= start_sync and not start_sync_delay and not busy;

    -- Operand bytes may be edited only while idle. A launch freezes the value
    -- presented to the core until its transaction completes.
    board_control : process(CLOCK_50, KEY0)
    begin
        if KEY0 = '0' then
            low_byte         <= (others => '0');
            high_byte        <= (others => '0');
            busy             <= '0';
            completion_latch <= '0';
        elsif rising_edge(CLOCK_50) then
            if busy = '0' and launch_pulse = '0' then
                if SW(8) = '0' then
                    low_byte <= SW(7 downto 0);
                else
                    high_byte <= SW(7 downto 0);
                end if;
            end if;

            if launch_pulse = '1' then
                busy             <= '1';
                completion_latch <= '0';
            elsif core_done = '1' then
                busy             <= '0';
                completion_latch <= '1';
            end if;
        end if;
    end process board_control;

    core_input <= high_byte & low_byte;

    square_root_core : entity work.sqrt16
        port map (
            clk   => CLOCK_50,
            reset => KEY0,
            start => launch_pulse,
            X_in  => core_input,
            R_out => core_result,
            done  => core_done
        );

    LEDR0 <= completion_latch;

    result_value <= 0 when KEY0 = '0' else to_integer(unsigned(core_result));
    HEX0 <= to_7segment(result_value mod 10);
    HEX1 <= to_7segment((result_value / 10) mod 10)
        when result_value >= 10 else SEG_BLANK;
    HEX2 <= to_7segment(result_value / 100)
        when result_value >= 100 else SEG_BLANK;
    HEX3 <= SEG_BLANK;
end architecture rtl;
