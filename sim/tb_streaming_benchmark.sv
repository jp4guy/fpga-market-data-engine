`timescale 1ns/1ps

module tb_streaming_benchmark;

    localparam int FIFO_DEPTH = 4;
    localparam int NUM_SYMBOLS = 4;
    localparam logic [22:0] SPREAD_THRESHOLD = 23'd10;

    localparam int NUM_PACKETS = 2000;

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

    int cycle_count = 0;
    int accepted_count = 0;
    int stall_count = 0;
    int signal_count = 0;
    int errors = 0;

    int first_accept_cycle = -1;
    int last_accept_cycle = -1;
    int measurement_cycles = 0;

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

    always @(posedge clk) begin
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

    function automatic logic [31:0] make_stream_packet(input int packet_index);
        int sym_i;
        logic [3:0] sym;
        logic side;
        logic [22:0] px;
        begin
            // Every pair of packets belongs to the same symbol:
            // packet 0: symbol 0 bid
            // packet 1: symbol 0 ask
            // packet 2: symbol 1 bid
            // packet 3: symbol 1 ask
            sym_i = (packet_index / 2) % NUM_SYMBOLS;
            sym = sym_i[3:0];

            // Even packet = bid, odd packet = ask.
            side = packet_index[0];

            // Generate a stable price range per symbol.
            // Ask is always 5 cents above the matching bid.
            if (side == 1'b0) begin
                px = 23'(10000 + (sym_i * 1000) + ((packet_index / (2 * NUM_SYMBOLS)) % 20));
            end else begin
                px = 23'(10005 + (sym_i * 1000) + ((packet_index / (2 * NUM_SYMBOLS)) % 20));
            end

            make_stream_packet = make_packet(4'h1, sym, side, px);
        end
    endfunction

    always @(posedge clk) begin
        #1;

        if (!rst && signal_valid) begin
            signal_count++;

            if (signal_count <= 10) begin
                $display(
                    "Signal %0d at cycle %0d: symbol=%0d spread=%0d trade_signal=%0b bid=%0d ask=%0d",
                    signal_count,
                    cycle_count,
                    signal_symbol,
                    spread,
                    trade_signal,
                    signal_bid,
                    signal_ask
                );
            end
        end
    end

    task automatic drive_continuous_stream();
        int packet_index;
        begin
            packet_index = 0;

            while (packet_index < NUM_PACKETS) begin
                @(negedge clk);

                in_valid = 1'b1;
                in_packet = make_stream_packet(packet_index);

                @(posedge clk);
                #1;

                if (in_valid && in_ready) begin
                    if (accepted_count == 0)
                        first_accept_cycle = cycle_count;

                    last_accept_cycle = cycle_count;
                    accepted_count++;

                    packet_index++;

                    if (accepted_count <= 10) begin
                        $display(
                            "Accepted packet %0d at cycle %0d: 0x%08h",
                            accepted_count,
                            cycle_count,
                            in_packet
                        );
                    end
                end else begin
                    stall_count++;
                end
            end

            @(negedge clk);
            in_valid = 1'b0;
            in_packet = '0;
        end
    endtask

    initial begin
        $dumpfile("streaming_benchmark_trace.vcd");
        $dumpvars(0, tb_streaming_benchmark);

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;

        drive_continuous_stream();

        // Flush pipeline after the last packet.
        repeat (50) @(posedge clk);
        #1;

        if (accepted_count != NUM_PACKETS) begin
            $display("FAIL: expected %0d accepted packets, got %0d", NUM_PACKETS, accepted_count);
            errors++;
        end

        if (stall_count != 0) begin
            $display("WARNING: observed %0d stall cycles", stall_count);
        end

        if (signal_count == 0) begin
            $display("FAIL: expected some signal outputs, got 0");
            errors++;
        end

        measurement_cycles = last_accept_cycle - first_accept_cycle + 1;

        $display("----------------------------------------");
        $display("Continuous streaming benchmark summary");
        $display("Packets attempted:        %0d", NUM_PACKETS);
        $display("Packets accepted:         %0d", accepted_count);
        $display("Signal outputs observed:  %0d", signal_count);
        $display("Input stall cycles:       %0d", stall_count);
        $display("First accept cycle:       %0d", first_accept_cycle);
        $display("Last accept cycle:        %0d", last_accept_cycle);
        $display("Measurement cycles:       %0d", measurement_cycles);

        if (measurement_cycles > 0) begin
            $display("Ideal throughput target:  1 packet/cycle");
            $display("Measured accept rate:     %0d packets over %0d cycles", accepted_count, measurement_cycles);
        end

        $display("Errors:                   %0d", errors);
        $display("----------------------------------------");

        if (errors == 0)
            $display("PASS: continuous streaming benchmark passed");
        else
            $display("FAIL: continuous streaming benchmark had %0d errors", errors);

        $finish;
    end

endmodule
