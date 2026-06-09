`timescale 1ns/1ps

module tb_streaming_stress;

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

    int cycle_count = 0;
    int num_packets = 100000;
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
        input logic        side,
        input logic [22:0] px
    );
        make_packet = {msg_type, sym, side, px};
    endfunction

    function automatic logic [31:0] make_stream_packet(input int packet_index);
        int sym_i;
        int round_i;
        logic [3:0] sym;
        logic side;
        logic [22:0] px;

        begin
            // Two packets per symbol:
            // even = bid, odd = ask
            sym_i = (packet_index / 2) % NUM_SYMBOLS;
            round_i = packet_index / (2 * NUM_SYMBOLS);

            sym = sym_i[3:0];
            side = packet_index[0];

            if (side == 1'b0)
                px = 23'(10000 + (sym_i * 1000) + (round_i % 50));
            else
                px = 23'(10005 + (sym_i * 1000) + (round_i % 50));

            make_stream_packet = make_packet(4'h1, sym, side, px);
        end
    endfunction

    always @(posedge clk) begin
        #1;

        if (!rst && signal_valid) begin
            signal_count++;

            if (signal_count <= 10) begin
                $display(
                    "Signal %0d at cycle %0d: symbol=%0d bid=%0d ask=%0d spread=%0d trade_signal=%0b",
                    signal_count,
                    cycle_count,
                    signal_symbol,
                    signal_bid,
                    signal_ask,
                    spread,
                    trade_signal
                );
            end

            if (signal_ask < signal_bid) begin
                $display("FAIL: signal ask below bid");
                errors++;
            end

            if (spread !== (signal_ask - signal_bid)) begin
                $display("FAIL: spread mismatch. bid=%0d ask=%0d spread=%0d",
                         signal_bid, signal_ask, spread);
                errors++;
            end
        end
    end

    task automatic drive_stream();
        int packet_index;
        begin
            packet_index = 0;

            while (packet_index < num_packets) begin
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
                        $display("Accepted packet %0d at cycle %0d: 0x%08h",
                                 accepted_count, cycle_count, in_packet);
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
        if ($value$plusargs("NUM_PACKETS=%d", num_packets)) begin
            $display("NUM_PACKETS set to %0d", num_packets);
        end else begin
            $display("NUM_PACKETS defaulting to %0d", num_packets);
        end

        if ($test$plusargs("TRACE")) begin
            $display("TRACE enabled: writing streaming_stress_trace.vcd");
            $dumpfile("streaming_stress_trace.vcd");
            $dumpvars(0, tb_streaming_stress);
        end else begin
            $display("TRACE disabled for faster benchmark");
        end

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;

        drive_stream();

        repeat (50) @(posedge clk);
        #1;

        measurement_cycles = last_accept_cycle - first_accept_cycle + 1;

        if (accepted_count != num_packets) begin
            $display("FAIL: expected %0d accepted packets, got %0d",
                     num_packets, accepted_count);
            errors++;
        end

        if (stall_count != 0) begin
            $display("FAIL: expected 0 stalls, got %0d", stall_count);
            errors++;
        end

        if (signal_count == 0) begin
            $display("FAIL: expected signal outputs, got 0");
            errors++;
        end

        $display("----------------------------------------");
        $display("Streaming stress benchmark summary");
        $display("Packets requested:        %0d", num_packets);
        $display("Packets accepted:         %0d", accepted_count);
        $display("Signal outputs observed:  %0d", signal_count);
        $display("Input stall cycles:       %0d", stall_count);
        $display("First accept cycle:       %0d", first_accept_cycle);
        $display("Last accept cycle:        %0d", last_accept_cycle);
        $display("Measurement cycles:       %0d", measurement_cycles);

        if (measurement_cycles > 0) begin
            $display("Throughput target:        1 packet/cycle");
            $display("Measured accept rate:     %0d packets / %0d cycles",
                     accepted_count, measurement_cycles);
        end

        $display("Errors:                   %0d", errors);
        $display("----------------------------------------");

        if (errors == 0)
            $display("PASS: streaming stress benchmark passed");
        else
            $display("FAIL: streaming stress benchmark had %0d errors", errors);

        $finish;
    end

endmodule
