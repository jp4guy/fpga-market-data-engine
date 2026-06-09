`timescale 1ns/1ps

module tb_market_data_engine;

    localparam int FIFO_DEPTH = 4;
    localparam int NUM_SYMBOLS = 4;

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

    int errors = 0;

    market_data_engine #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .NUM_SYMBOLS(NUM_SYMBOLS),
        .SPREAD_THRESHOLD(23'd10)
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

    task automatic send_packet(input logic [31:0] pkt);
        begin
            @(negedge clk);

            if (!in_ready) begin
                $display("FAIL: engine not ready when sending packet");
                errors++;
            end

            in_packet = pkt;
            in_valid = 1'b1;

            @(negedge clk);
            in_valid = 1'b0;
            in_packet = '0;
        end
    endtask

    task automatic wait_for_signal_and_check(
        input logic [3:0]  expected_symbol,
        input logic [22:0] expected_spread,
        input logic        expected_trade_signal
    );
        int wait_cycles;
        begin
            wait_cycles = 0;

            while (!signal_valid && wait_cycles < 20) begin
                @(posedge clk);
                #1;
                wait_cycles++;
            end

            if (!signal_valid) begin
                $display("FAIL: timed out waiting for signal_valid");
                errors++;
            end else begin
                if (signal_symbol !== expected_symbol) begin
                    $display("FAIL: expected signal_symbol %0d, got %0d", expected_symbol, signal_symbol);
                    errors++;
                end

                if (spread !== expected_spread) begin
                    $display("FAIL: expected spread %0d, got %0d", expected_spread, spread);
                    errors++;
                end

                if (trade_signal !== expected_trade_signal) begin
                    $display("FAIL: expected trade_signal %0b, got %0b", expected_trade_signal, trade_signal);
                    errors++;
                end
            end
        end
    endtask

    task automatic wait_no_signal(input int cycles);
        begin
            repeat (cycles) begin
                @(posedge clk);
                #1;

                if (signal_valid) begin
                    $display("FAIL: signal_valid went high when no full bid/ask pair existed");
                    errors++;
                end
            end
        end
    endtask

    initial begin
        $dumpfile("engine_trace.vcd");
        $dumpvars(0, tb_market_data_engine);

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;

        // Symbol 0 bid = $100.05
        send_packet(make_packet(4'h1, 4'd0, 1'b0, 23'd10005));

        // Only bid exists, no ask yet, so there should be no signal
        wait_no_signal(6);

        // Symbol 0 ask = $100.10
        // Spread = 5 cents, threshold = 10 cents, should trigger trade_signal = 1
        send_packet(make_packet(4'h1, 4'd0, 1'b1, 23'd10010));
        wait_for_signal_and_check(4'd0, 23'd5, 1'b1);

        // Symbol 1 bid = $250.25
        send_packet(make_packet(4'h1, 4'd1, 1'b0, 23'd25025));
        wait_no_signal(6);

        // Symbol 1 ask = $250.50
        // Spread = 25 cents, threshold = 10 cents, should output valid but trade_signal = 0
        send_packet(make_packet(4'h1, 4'd1, 1'b1, 23'd25050));
        wait_for_signal_and_check(4'd1, 23'd25, 1'b0);

        if (errors == 0)
            $display("PASS: full market data engine test passed");
        else
            $display("FAIL: full market data engine test had %0d errors", errors);

        $finish;
    end

endmodule
