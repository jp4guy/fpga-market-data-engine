`timescale 1ns/1ps

module tb_throughput_engine;

    localparam int FIFO_DEPTH = 4;
    localparam int NUM_SYMBOLS = 4;
    localparam logic [22:0] SPREAD_THRESHOLD = 23'd10;

    localparam int NUM_PACKETS = 8;
    localparam int EXPECTED_SIGNALS = 4;

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

    logic [31:0] packets [0:NUM_PACKETS-1];

    logic [3:0]  expected_symbol [0:EXPECTED_SIGNALS-1];
    logic [22:0] expected_spread [0:EXPECTED_SIGNALS-1];
    logic        expected_trade_signal [0:EXPECTED_SIGNALS-1];

    int errors = 0;
    int accepted_count = 0;
    int signal_count = 0;

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

    // Monitor signal outputs continuously.
    always @(posedge clk) begin
        #1;

        if (!rst && signal_valid) begin
            if (signal_count >= EXPECTED_SIGNALS) begin
                $display("FAIL: unexpected extra signal output");
                errors++;
            end else begin
                if (signal_symbol !== expected_symbol[signal_count]) begin
                    $display("FAIL signal %0d: expected symbol %0d, got %0d",
                             signal_count, expected_symbol[signal_count], signal_symbol);
                    errors++;
                end

                if (spread !== expected_spread[signal_count]) begin
                    $display("FAIL signal %0d: expected spread %0d, got %0d",
                             signal_count, expected_spread[signal_count], spread);
                    errors++;
                end

                if (trade_signal !== expected_trade_signal[signal_count]) begin
                    $display("FAIL signal %0d: expected trade_signal %0b, got %0b",
                             signal_count, expected_trade_signal[signal_count], trade_signal);
                    errors++;
                end

                $display("Observed signal %0d: symbol=%0d spread=%0d trade_signal=%0b",
                         signal_count, signal_symbol, spread, trade_signal);
            end

            signal_count++;
        end
    end

    task automatic send_back_to_back_packets();
        int i;
        begin
            for (i = 0; i < NUM_PACKETS; i++) begin
                @(negedge clk);

                if (!in_ready) begin
                    $display("FAIL: engine not ready for packet %0d", i);
                    errors++;
                end

                in_packet = packets[i];
                in_valid = 1'b1;

                @(posedge clk);
                #1;

                if (in_ready) begin
                    accepted_count++;
                    $display("Accepted packet %0d: 0x%08h", i, packets[i]);
                end
            end

            @(negedge clk);
            in_valid = 1'b0;
            in_packet = '0;
        end
    endtask

    initial begin
        $dumpfile("throughput_engine_trace.vcd");
        $dumpvars(0, tb_throughput_engine);

        // Back-to-back packet burst:
        // symbol 0: spread 5, trade_signal 1
        packets[0] = make_packet(4'h1, 4'd0, 1'b0, 23'd10005);
        packets[1] = make_packet(4'h1, 4'd0, 1'b1, 23'd10010);

        // symbol 1: spread 25, trade_signal 0
        packets[2] = make_packet(4'h1, 4'd1, 1'b0, 23'd25025);
        packets[3] = make_packet(4'h1, 4'd1, 1'b1, 23'd25050);

        // symbol 2: spread 8, trade_signal 1
        packets[4] = make_packet(4'h1, 4'd2, 1'b0, 23'd15000);
        packets[5] = make_packet(4'h1, 4'd2, 1'b1, 23'd15008);

        // symbol 3: spread 20, trade_signal 0
        packets[6] = make_packet(4'h1, 4'd3, 1'b0, 23'd30000);
        packets[7] = make_packet(4'h1, 4'd3, 1'b1, 23'd30020);

        expected_symbol[0] = 4'd0;
        expected_spread[0] = 23'd5;
        expected_trade_signal[0] = 1'b1;

        expected_symbol[1] = 4'd1;
        expected_spread[1] = 23'd25;
        expected_trade_signal[1] = 1'b0;

        expected_symbol[2] = 4'd2;
        expected_spread[2] = 23'd8;
        expected_trade_signal[2] = 1'b1;

        expected_symbol[3] = 4'd3;
        expected_spread[3] = 23'd20;
        expected_trade_signal[3] = 1'b0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;

        send_back_to_back_packets();

        // Let pipeline flush.
        repeat (30) @(posedge clk);
        #1;

        if (accepted_count !== NUM_PACKETS) begin
            $display("FAIL: expected %0d accepted packets, got %0d",
                     NUM_PACKETS, accepted_count);
            errors++;
        end

        if (signal_count !== EXPECTED_SIGNALS) begin
            $display("FAIL: expected %0d signal outputs, got %0d",
                     EXPECTED_SIGNALS, signal_count);
            errors++;
        end

        $display("----------------------------------------");
        $display("Throughput test summary");
        $display("Packets sent back-to-back: %0d", NUM_PACKETS);
        $display("Packets accepted:          %0d", accepted_count);
        $display("Signals observed:          %0d", signal_count);
        $display("Errors:                    %0d", errors);
        $display("----------------------------------------");

        if (errors == 0)
            $display("PASS: throughput engine test passed");
        else
            $display("FAIL: throughput engine test had %0d errors", errors);

        $finish;
    end

endmodule
