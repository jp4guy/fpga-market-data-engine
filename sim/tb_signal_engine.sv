`timescale 1ns/1ps

module tb_signal_engine;

    logic clk = 0;
    logic rst = 1;

    logic book_valid = 0;
    logic [3:0] book_symbol = '0;
    logic [22:0] best_bid = '0;
    logic [22:0] best_ask = '0;

    logic signal_valid;
    logic [3:0] signal_symbol;
    logic [22:0] spread;
    logic trade_signal;

    int errors = 0;

    signal_engine #(
        .SPREAD_THRESHOLD(23'd10)
    ) dut (
        .clk(clk),
        .rst(rst),
        .book_valid(book_valid),
        .book_symbol(book_symbol),
        .best_bid(best_bid),
        .best_ask(best_ask),
        .signal_valid(signal_valid),
        .signal_symbol(signal_symbol),
        .spread(spread),
        .trade_signal(trade_signal)
    );

    always #5 clk = ~clk;

    task automatic send_book_and_check(
        input logic [3:0]  sym,
        input logic [22:0] bid,
        input logic [22:0] ask,
        input logic        expected_valid,
        input logic [22:0] expected_spread,
        input logic        expected_trade_signal
    );
        begin
            @(negedge clk);
            book_symbol = sym;
            best_bid = bid;
            best_ask = ask;
            book_valid = 1'b1;

            @(posedge clk);
            #1;

            if (signal_valid !== expected_valid) begin
                $display("FAIL: signal_valid expected %0b, got %0b", expected_valid, signal_valid);
                errors++;
            end

            if (expected_valid) begin
                if (signal_symbol !== sym) begin
                    $display("FAIL: signal_symbol expected %0d, got %0d", sym, signal_symbol);
                    errors++;
                end

                if (spread !== expected_spread) begin
                    $display("FAIL: spread expected %0d, got %0d", expected_spread, spread);
                    errors++;
                end

                if (trade_signal !== expected_trade_signal) begin
                    $display("FAIL: trade_signal expected %0b, got %0b", expected_trade_signal, trade_signal);
                    errors++;
                end
            end

            @(negedge clk);
            book_valid = 1'b0;
            book_symbol = '0;
            best_bid = '0;
            best_ask = '0;
        end
    endtask

    initial begin
        $dumpfile("signal_engine_trace.vcd");
        $dumpvars(0, tb_signal_engine);

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;

        // Spread = 5 cents, threshold = 10 cents, should trigger
        send_book_and_check(
            4'd0,
            23'd10005,
            23'd10010,
            1'b1,
            23'd5,
            1'b1
        );

        // Spread = 25 cents, threshold = 10 cents, should not trigger
        send_book_and_check(
            4'd1,
            23'd25025,
            23'd25050,
            1'b1,
            23'd25,
            1'b0
        );

        // Missing ask price, should not create valid signal
        send_book_and_check(
            4'd2,
            23'd15000,
            23'd0,
            1'b0,
            23'd0,
            1'b0
        );

        // Invalid crossed/bad state: ask < bid, should not create valid signal
        send_book_and_check(
            4'd3,
            23'd30000,
            23'd29990,
            1'b0,
            23'd0,
            1'b0
        );

        if (errors == 0)
            $display("PASS: signal engine test passed");
        else
            $display("FAIL: signal engine test had %0d errors", errors);

        $finish;
    end

endmodule
