library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_sqrt16 is
end entity tb_sqrt16;

architecture test of tb_sqrt16 is
    constant CLK_PERIOD : time := 10 ns;

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '0';
    signal start    : std_logic := '0';
    signal x_in     : std_logic_vector(15 downto 0) := (others => '0');
    signal r_out    : std_logic_vector(7 downto 0);
    signal done     : std_logic;
    signal finished : boolean := false;
begin
    dut : entity work.sqrt16
        port map (
            clk   => clk,
            reset => reset,
            start => start,
            X_in  => x_in,
            R_out => r_out,
            done  => done
        );

    clock_generator : process
    begin
        while not finished loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process clock_generator;

    stimulus : process
        function is_binary(value : std_logic_vector) return boolean is
        begin
            for bit_index in value'range loop
                if value(bit_index) /= '0' and value(bit_index) /= '1' then
                    return false;
                end if;
            end loop;
            return true;
        end function is_binary;

        -- Independent reference model: monotonic binary search using integer
        -- multiplication. It does not reproduce the DUT's restoring recurrence.
        function integer_sqrt(value : natural) return natural is
            variable low_bound  : natural := 0;
            variable high_bound : natural := 256;
            variable candidate  : natural;
        begin
            while low_bound + 1 < high_bound loop
                candidate := (low_bound + high_bound) / 2;
                if candidate * candidate <= value then
                    low_bound := candidate;
                else
                    high_bound := candidate;
                end if;
            end loop;
            return low_bound;
        end function integer_sqrt;

        variable suite_mismatches      : natural := 0;
        variable exhaustive_checked    : natural := 0;
        variable exhaustive_mismatches : natural := 0;
        variable previous_result       : std_logic_vector(7 downto 0);

        procedure check_reset_outputs(constant test_name : in string) is
        begin
            assert done = '0'
                report test_name & ": done was not cleared"
                severity failure;
            assert is_binary(r_out)
                report test_name & ": R_out contains a meta-value"
                severity failure;
            assert r_out = "00000000"
                report test_name & ": R_out was not reset to zero"
                severity failure;
        end procedure check_reset_outputs;

        procedure check_result(
            constant test_name       : in string;
            constant expected        : in natural;
            constant exhaustive_case : in boolean;
            constant announce_pass   : in boolean
        ) is
            variable actual : natural;
        begin
            if not is_binary(r_out) then
                assert false
                    report test_name & ": R_out contains a meta-value"
                    severity failure;
            else
                actual := to_integer(unsigned(r_out));
                if exhaustive_case then
                    exhaustive_checked := exhaustive_checked + 1;
                end if;

                if actual /= expected then
                    suite_mismatches := suite_mismatches + 1;
                    if exhaustive_case then
                        exhaustive_mismatches := exhaustive_mismatches + 1;
                    end if;
                    report test_name & ": expected " &
                           integer'image(expected) & ", got " &
                           integer'image(actual)
                        severity warning;
                elsif announce_pass then
                    report test_name & " PASS" severity note;
                end if;
            end if;
        end procedure check_result;

        -- Called shortly after a falling edge. The next rising edge accepts start.
        procedure run_pulsed_transaction(
            constant test_name       : in string;
            constant operand         : in natural;
            constant expected        : in natural;
            constant exhaustive_case : in boolean;
            constant announce_pass   : in boolean
        ) is
            variable held_result : std_logic_vector(7 downto 0);
        begin
            assert is_binary(r_out)
                report test_name & ": previous R_out contains a meta-value"
                severity failure;
            held_result := r_out;

            x_in  <= std_logic_vector(to_unsigned(operand, x_in'length));
            start <= '1';

            -- Acceptance edge t0.
            wait until rising_edge(clk);
            wait for 1 ns;
            start <= '0';
            assert done = '0'
                report test_name & ": done high on acceptance edge"
                severity failure;
            assert is_binary(r_out)
                report test_name & ": R_out contains a meta-value on acceptance"
                severity failure;
            assert r_out = held_result
                report test_name & ": R_out changed on acceptance"
                severity failure;

            -- Eight COMPUTE edges. done must remain low and R_out unchanged.
            for compute_edge in 1 to 8 loop
                wait until rising_edge(clk);
                wait for 1 ns;
                assert done = '0'
                    report test_name & ": done asserted early at COMPUTE edge " &
                           integer'image(compute_edge)
                    severity failure;
                assert is_binary(r_out)
                    report test_name & ": R_out contains a meta-value during COMPUTE"
                    severity failure;
                assert r_out = held_result
                    report test_name & ": R_out changed before FINISH"
                    severity failure;
            end loop;

            -- FINISH edge at t0 + 9 periods.
            wait until rising_edge(clk);
            wait for 1 ns;
            assert done = '1'
                report test_name & ": done missing at t0 + 9 periods"
                severity failure;
            check_result(test_name, expected, exhaustive_case, announce_pass);

            -- done must still be high halfway through its one-cycle pulse.
            wait until falling_edge(clk);
            wait for 1 ns;
            assert done = '1'
                report test_name & ": done pulse shorter than one clock period"
                severity failure;
        end procedure run_pulsed_transaction;

    begin
        -- Initial asynchronous reset while idle.
        wait for 2 ns;
        check_reset_outputs("reset from idle at startup");
        reset <= '1';
        wait until falling_edge(clk);
        wait for 1 ns;

        -- Explicitly named boundary cases.
        run_pulsed_transaction("directed 0 to 0",         0,     0, false, true);
        run_pulsed_transaction("directed 1 to 1",         1,     1, false, true);
        run_pulsed_transaction("directed 2 to 1",         2,     1, false, true);
        run_pulsed_transaction("directed 3 to 1",         3,     1, false, true);
        run_pulsed_transaction("directed 4 to 2",         4,     2, false, true);
        run_pulsed_transaction("directed 8 to 2",         8,     2, false, true);
        run_pulsed_transaction("directed 9 to 3",         9,     3, false, true);
        run_pulsed_transaction("directed 10 to 3",       10,     3, false, true);
        run_pulsed_transaction("directed 15 to 3",       15,     3, false, true);
        run_pulsed_transaction("directed 16 to 4",       16,     4, false, true);
        run_pulsed_transaction("directed 17 to 4",       17,     4, false, true);
        run_pulsed_transaction("directed 24 to 4",       24,     4, false, true);
        run_pulsed_transaction("directed 25 to 5",       25,     5, false, true);
        run_pulsed_transaction("directed 26 to 5",       26,     5, false, true);
        run_pulsed_transaction("directed 65024 to 254", 65024, 254, false, true);
        run_pulsed_transaction("directed 65025 to 255", 65025, 255, false, true);
        run_pulsed_transaction("directed 65026 to 255", 65026, 255, false, true);
        run_pulsed_transaction("directed 65535 to 255", 65535, 255, false, true);

        assert suite_mismatches = 0
            report "DIRECTED TESTS FAILED"
            severity failure;
        report "DIRECTED TESTS PASS" severity note;

        -- With start low, done clears after one full cycle and R_out stays stable.
        previous_result := r_out;
        start <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert done = '0' severity failure;
        assert is_binary(r_out) and r_out = previous_result severity failure;
        wait until rising_edge(clk);
        wait for 1 ns;
        assert done = '0' severity failure;
        assert is_binary(r_out) and r_out = previous_result severity failure;
        report "done pulse and post-done output stability PASS" severity note;
        wait until falling_edge(clk);
        wait for 1 ns;

        -- Reset A: asynchronous reset from idle, followed by a valid transaction.
        reset <= '0';
        wait for 1 ns;
        check_reset_outputs("reset from idle");
        reset <= '1';
        wait until falling_edge(clk);
        wait for 1 ns;
        run_pulsed_transaction("transaction after idle reset", 36, 6, false, false);
        assert suite_mismatches = 0 severity failure;
        report "reset from idle PASS" severity note;

        -- Reset B: asynchronous reset during COMPUTE.
        previous_result := r_out;
        x_in  <= std_logic_vector(to_unsigned(400, x_in'length));
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        for compute_edge in 1 to 3 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert done = '0' and r_out = previous_result severity failure;
        end loop;
        wait for 2 ns;
        reset <= '0';
        wait for 1 ns;
        check_reset_outputs("reset during COMPUTE");
        reset <= '1';
        wait until falling_edge(clk);
        wait for 1 ns;
        run_pulsed_transaction("transaction after COMPUTE reset", 49, 7, false, false);
        assert suite_mismatches = 0 severity failure;
        report "reset during COMPUTE PASS" severity note;

        -- Reset C: asynchronous reset during the externally visible done pulse.
        run_pulsed_transaction("setup for reset during done", 64, 8, false, false);
        assert done = '1' severity failure;
        reset <= '0';
        wait for 1 ns;
        check_reset_outputs("reset during done");
        reset <= '1';
        wait until falling_edge(clk);
        wait for 1 ns;
        run_pulsed_transaction("transaction after done reset", 81, 9, false, false);
        assert suite_mismatches = 0 severity failure;
        report "reset during done PASS" severity note;

        -- Input capture: change X_in immediately after acceptance.
        previous_result := r_out;
        x_in  <= std_logic_vector(to_unsigned(144, x_in'length));
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        x_in  <= std_logic_vector(to_unsigned(65025, x_in'length));
        assert done = '0' and r_out = previous_result severity failure;
        for compute_edge in 1 to 8 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert done = '0' and r_out = previous_result severity failure;
        end loop;
        wait until rising_edge(clk);
        wait for 1 ns;
        assert done = '1' severity failure;
        check_result("input capture 144 despite live 65025", 12, false, false);
        wait until falling_edge(clk);
        wait for 1 ns;
        assert done = '1' severity failure;
        assert suite_mismatches = 0 severity failure;
        report "input capture PASS" severity note;

        -- A one-cycle start pulse during COMPUTE must be ignored.
        previous_result := r_out;
        x_in  <= std_logic_vector(to_unsigned(225, x_in'length));
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        for compute_edge in 1 to 8 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert done = '0' and r_out = previous_result severity failure;
            if compute_edge = 2 then
                x_in  <= std_logic_vector(to_unsigned(4096, x_in'length));
                start <= '1';
            elsif compute_edge = 3 then
                start <= '0';
            end if;
        end loop;
        wait until rising_edge(clk);
        wait for 1 ns;
        assert done = '1' severity failure;
        check_result("start pulse during COMPUTE", 15, false, false);
        wait until falling_edge(clk);
        wait for 1 ns;
        assert done = '1' severity failure;

        -- No delayed/queued transaction may result from that ignored pulse.
        start <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert done = '0' severity failure;
        for idle_edge in 1 to 10 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert done = '0' and r_out = std_logic_vector(to_unsigned(15, 8))
                report "busy start pulse was queued or output became unstable"
                severity failure;
        end loop;
        wait until falling_edge(clk);
        wait for 1 ns;
        assert suite_mismatches = 0 severity failure;
        report "start during COMPUTE PASS" severity note;

        -- Held-high start: second transaction is accepted one IDLE edge after done.
        previous_result := r_out;
        x_in  <= std_logic_vector(to_unsigned(100, x_in'length));
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert done = '0' and r_out = previous_result severity failure;
        for compute_edge in 1 to 8 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert done = '0' and r_out = previous_result severity failure;
        end loop;
        wait until rising_edge(clk);
        wait for 1 ns;
        assert done = '1' severity failure;
        check_result("held-high start first result", 10, false, false);
        x_in <= std_logic_vector(to_unsigned(121, x_in'length));
        wait until falling_edge(clk);
        wait for 1 ns;
        assert done = '1' severity failure;

        -- start is still high, so this IDLE edge accepts X=121 automatically.
        wait until rising_edge(clk);
        wait for 1 ns;
        assert done = '0' and r_out = std_logic_vector(to_unsigned(10, 8))
            severity failure;
        start <= '0';
        for compute_edge in 1 to 8 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert done = '0' and r_out = std_logic_vector(to_unsigned(10, 8))
                severity failure;
        end loop;
        wait until rising_edge(clk);
        wait for 1 ns;
        assert done = '1' severity failure;
        check_result("held-high start repeated result", 11, false, false);
        wait until falling_edge(clk);
        wait for 1 ns;
        assert done = '1' severity failure;
        assert suite_mismatches = 0 severity failure;
        report "held-high start characterization PASS" severity note;

        -- Successive pulsed transactions at the minimum acceptance spacing.
        run_pulsed_transaction("successive transaction A", 169, 13, false, false);
        run_pulsed_transaction("successive transaction B", 196, 14, false, false);
        assert suite_mismatches = 0 severity failure;
        report "successive pulsed transactions and output stability PASS"
            severity note;
        report "PROTOCOL TESTS PASS" severity note;

        -- Exhaustive arithmetic campaign. Latency, meta-values, done pulse and
        -- output stability are also checked for every accepted transaction.
        for operand in 0 to 65535 loop
            run_pulsed_transaction(
                "exhaustive X=" & integer'image(operand),
                operand,
                integer_sqrt(operand),
                true,
                false
            );
        end loop;

        -- Clear the final done pulse and prove the last result remains stable.
        previous_result := r_out;
        start <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert done = '0' severity failure;
        assert is_binary(r_out) and r_out = previous_result severity failure;
        for idle_edge in 1 to 2 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert done = '0' and r_out = previous_result severity failure;
        end loop;

        report integer'image(exhaustive_checked) & " inputs checked"
            severity note;
        report integer'image(exhaustive_mismatches) & " mismatches"
            severity note;
        assert exhaustive_checked = 65536
            report "exhaustive campaign did not check exactly 65536 inputs"
            severity failure;
        assert exhaustive_mismatches = 0
            report "EXHAUSTIVE TESTS FAILED"
            severity failure;
        assert suite_mismatches = 0
            report "TEST SUITE FAILED"
            severity failure;

        report "EXHAUSTIVE TESTS PASS" severity note;
        report "ALL TESTS PASS" severity note;
        finished <= true;
        wait;
    end process stimulus;
end architecture test;
