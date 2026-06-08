`timescale 1ns/1ps

module tb_latency;

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

    logic [22:0] debug_best_bid;
    logic [22:0] debug_best_ask;

    int errors = 0;
    int cycle_count = 0;
    int ask_accept_cycle = 0;
    int signal_cycle = 0;
    int measured_latency = 0;
    int bid_accept_cycle = 0;

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

        .debug_best_bid(debug_best_bid),
        .debug_best_ask(debug_best_ask)
    );

    always #5 clk = ~clk;

    always_ff @(posedge clk) begin
        if (rst)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end

    function automatic logic [31:0] make_packet(
        input logic [3:0]  msg_type,
        input logic [3:0]  sym,
        input logic        bid_or_ask,
        input logic [22:0] px
    );
        make_packet = {msg_type, sym, bid_or_ask, px};
    endfunction

    task automatic send_packet(
        input logic [31:0] pkt,
        output int accepted_cycle
    );
        begin
            @(negedge clk);

            if (!in_ready) begin
                $display("FAIL: engine not ready when sending packet");
                errors++;
            end

            in_packet = pkt;
            in_valid = 1'b1;

            @(posedge clk);
            #1;

            if (in_valid && in_ready) begin
                accepted_cycle = cycle_count;
                $display("Packet accepted at cycle %0d", accepted_cycle);
            end else begin
                $display("FAIL: packet was not accepted");
                errors++;
                accepted_cycle = -1;
            end

            @(negedge clk);
            in_valid = 1'b0;
            in_packet = '0;
        end
    endtask

    task automatic wait_for_signal(output int seen_cycle);
        int wait_cycles;
        begin
            wait_cycles = 0;
            seen_cycle = -1;

            while (!signal_valid && wait_cycles < 20) begin
                @(posedge clk);
                #1;
                wait_cycles++;
            end

            if (signal_valid) begin
                seen_cycle = cycle_count;
                $display("signal_valid seen at cycle %0d", seen_cycle);
            end else begin
                $display("FAIL: timed out waiting for signal_valid");
                errors++;
            end
        end
    endtask

    initial begin
        $dumpfile("latency_trace.vcd");
        $dumpvars(0, tb_latency);

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;

        // First send bid. This creates best_bid, but no signal yet because best_ask is missing.
        send_packet(
            make_packet(4'h1, 4'd0, 1'b0, 23'd10005),
            bid_accept_cycle
        );

        repeat (6) @(posedge clk);

        if (signal_valid) begin
            $display("FAIL: signal_valid should not appear after bid-only packet");
            errors++;
        end

        // Now send ask. This should produce a valid signal after the pipeline delay.
        send_packet(
            make_packet(4'h1, 4'd0, 1'b1, 23'd10010),
            ask_accept_cycle
        );

        wait_for_signal(signal_cycle);

        measured_latency = signal_cycle - ask_accept_cycle;

        $display("----------------------------------------");
        $display("Latency measurement");
        $display("Ask accepted cycle: %0d", ask_accept_cycle);
        $display("Signal cycle:       %0d", signal_cycle);
        $display("Measured latency:   %0d cycles", measured_latency);
        $display("----------------------------------------");

        if (signal_symbol !== 4'd0) begin
            $display("FAIL: expected signal_symbol 0, got %0d", signal_symbol);
            errors++;
        end

        if (spread !== 23'd5) begin
            $display("FAIL: expected spread 5, got %0d", spread);
            errors++;
        end

        if (trade_signal !== 1'b1) begin
            $display("FAIL: expected trade_signal 1, got %0b", trade_signal);
            errors++;
        end

        // Current expected latency for this pipeline is 3 cycles:
        // cycle 0: packet accepted into FIFO
        // cycle 1: FIFO read
        // cycle 2: order book update
        // cycle 3: signal engine output
        if (measured_latency !== 3) begin
            $display("FAIL: expected latency 3 cycles, got %0d", measured_latency);
            errors++;
        end

        if (errors == 0)
            $display("PASS: latency test passed");
        else
            $display("FAIL: latency test had %0d errors", errors);

        $finish;
    end

endmodule
