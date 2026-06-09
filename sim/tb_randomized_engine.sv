`timescale 1ns/1ps

module tb_randomized_engine;

    localparam int FIFO_DEPTH = 4;
    localparam int NUM_SYMBOLS = 4;
    localparam logic [22:0] SPREAD_THRESHOLD = 23'd10;

    logic clk = 0;
    logic rst = 1;

    logic in_valid = 0;
    logic [31:0] in_packet = '0;
    logic in_ready;

    logic signal_valid;
    logic [3:0] signal_symbol;
    logic [22:0] spread;
    logic trade_signal;

    logic [22:0] signal_bid;
    logic [22:0] signal_ask;

    logic [22:0] debug_best_bid;
    logic [22:0] debug_best_ask;

    logic [22:0] model_bid [0:NUM_SYMBOLS-1];
    logic [22:0] model_ask [0:NUM_SYMBOLS-1];

    int errors = 0;
    int tests_run = 0;

    market_data_engine #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .NUM_SYMBOLS(NUM_SYMBOLS),
        .SPREAD_THRESHOLD(SPREAD_THRESHOLD)
    ) dut (
        .clk(clk),
        .rst(rst),

        .in_valid(in_valid),
        .in_packet(in_packet),
        .in_ready(in_ready),

        .signal_valid(signal_valid),
        .signal_symbol(signal_symbol),
        .spread(spread),
        .trade_signal(trade_signal),
        .signal_bid(signal_bid),
        .signal_ask(signal_ask),

        .debug_best_bid(debug_best_bid),
        .debug_best_ask(debug_best_ask)
    );

    always #5 clk = ~clk;

    function automatic logic [31:0] make_packet(
        input logic [3:0]  msg_type,
        input logic [3:0]  sym,
        input logic        bid_or_ask,
        input logic [22:0] px
    );
        make_packet = {msg_type, sym, bid_or_ask, px};
    endfunction

    task automatic send_packet_and_check(
        input logic [31:0] pkt,
        input logic        expected_valid,
        input logic [3:0]  expected_symbol,
        input logic [22:0] expected_spread,
        input logic        expected_trade_signal
    );
        begin
            @(negedge clk);

            if (!in_ready) begin
                $display("FAIL: engine not ready before packet");
                errors++;
            end

            in_packet = pkt;
            in_valid = 1'b1;

            @(posedge clk);
            #1;

            if (!(in_valid && in_ready)) begin
                $display("FAIL: packet was not accepted");
                errors++;
            end

            @(negedge clk);
            in_valid = 1'b0;
            in_packet = '0;

            // Current known pipeline latency is 3 cycles from accepted packet to signal.
            repeat (3) @(posedge clk);
            #1;

            if (signal_valid !== expected_valid) begin
                $display("FAIL test %0d: signal_valid expected %0b, got %0b",
                         tests_run, expected_valid, signal_valid);
                $display("    packet = 0x%08h", pkt);
                errors++;
            end

            if (expected_valid) begin
                if (signal_symbol !== expected_symbol) begin
                    $display("FAIL test %0d: symbol expected %0d, got %0d",
                             tests_run, expected_symbol, signal_symbol);
                    errors++;
                end

                if (spread !== expected_spread) begin
                    $display("FAIL test %0d: spread expected %0d, got %0d",
                             tests_run, expected_spread, spread);
                    errors++;
                end

                if (trade_signal !== expected_trade_signal) begin
                    $display("FAIL test %0d: trade_signal expected %0b, got %0b",
                             tests_run, expected_trade_signal, trade_signal);
                    errors++;
                end
            end

            tests_run++;
        end
    endtask

    initial begin
        logic [3:0] msg_type;
        logic [3:0] sym;
        logic side;
        logic [22:0] px;
        logic [31:0] pkt;

        logic expected_valid;
        logic [22:0] expected_spread;
        logic expected_trade_signal;

        int unsigned r;
        int i;
        int sym_idx;

        $dumpfile("randomized_engine_trace.vcd");
        $dumpvars(0, tb_randomized_engine);

        for (i = 0; i < NUM_SYMBOLS; i++) begin
            model_bid[i] = '0;
            model_ask[i] = '0;
        end

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;

        // Deterministic seed for repeatable random tests.
        r = 32'hC0FFEE;

        for (i = 0; i < 100; i++) begin
            // 80% valid price updates, 20% invalid message types.
            r = $urandom(r);
            if ((r % 10) < 8)
                msg_type = 4'h1;
            else
                msg_type = 4'h2;

            r = $urandom(r);
            sym_idx = r % NUM_SYMBOLS;
            sym = sym_idx[3:0];

            r = $urandom(r);
            side = r[0];

            // Generate prices around each symbol's own range.
            r = $urandom(r);
            if (side == 1'b0) begin
                // bid
                px = 23'(10000 + (sym * 1000) + (r % 50));
            end else begin
                // ask
                px = 23'(10005 + (sym * 1000) + (r % 50));
            end

            pkt = make_packet(msg_type, sym, side, px);

            expected_valid = 1'b0;
            expected_spread = '0;
            expected_trade_signal = 1'b0;

            if (msg_type == 4'h1) begin
                if (side == 1'b0)
                    model_bid[sym_idx] = px;
                else
                    model_ask[sym_idx] = px;

                if ((model_bid[sym_idx] != 23'd0) &&
                    (model_ask[sym_idx] != 23'd0) &&
                    (model_ask[sym_idx] >= model_bid[sym_idx])) begin

                    expected_valid = 1'b1;
                    expected_spread = model_ask[sym_idx] - model_bid[sym_idx];
                    expected_trade_signal = (expected_spread <= SPREAD_THRESHOLD);
                end
            end

            send_packet_and_check(
                pkt,
                expected_valid,
                sym,
                expected_spread,
                expected_trade_signal
            );
        end

        $display("----------------------------------------");
        $display("Randomized engine test summary");
        $display("Tests run: %0d", tests_run);
        $display("Errors:    %0d", errors);
        $display("----------------------------------------");

        if (errors == 0)
            $display("PASS: randomized engine test passed");
        else
            $display("FAIL: randomized engine test had %0d errors", errors);

        $finish;
    end

endmodule
