`timescale 1ns/1ps

import market_types_pkg::event_type_t;
import market_types_pkg::EVENT_ADD;

module tb_event_streaming_stress;

    timeunit 1ns;
    timeprecision 1ps;

    localparam int FIFO_DEPTH = 4;
    localparam int NUM_SYMBOLS = 4;

    logic clk = 0;
    logic rst = 1;

    logic        in_valid = 0;
    logic [63:0] in_packet = '0;
    logic        in_ready;

    logic        signal_valid;
    logic [3:0]  signal_symbol;
    logic [15:0] signal_bid;
    logic [15:0] signal_ask;
    logic [15:0] signal_bid_qty;
    logic [15:0] signal_ask_qty;
    logic [15:0] spread;
    logic        trade_signal;
    logic        risk_ok;
    logic [2:0]  risk_reject_code;

    int cycle_count = 0;
    int num_events = 100000;
    int accepted_count = 0;
    int stall_count = 0;
    int signal_count = 0;
    int errors = 0;

    int first_accept_cycle = -1;
    int last_accept_cycle = -1;
    int measurement_cycles = 0;

    event_market_data_engine #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .NUM_SYMBOLS(NUM_SYMBOLS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_packet(in_packet),
        .in_ready(in_ready),
        .signal_valid(signal_valid),
        .signal_symbol(signal_symbol),
        .signal_bid(signal_bid),
        .signal_ask(signal_ask),
        .signal_bid_qty(signal_bid_qty),
        .signal_ask_qty(signal_ask_qty),
        .spread(spread),
        .trade_signal(trade_signal),
        .risk_ok(risk_ok),
        .risk_reject_code(risk_reject_code)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (rst)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end

    function automatic logic [63:0] make_event_packet(
        input event_type_t type_id,
        input logic [3:0]  symbol_id,
        input logic        side,
        input logic [15:0] order_id,
        input logic [15:0] price,
        input logic [15:0] quantity
    );
        make_event_packet = {type_id, symbol_id, side, order_id, price, quantity, 9'b0};
    endfunction

    function automatic logic [63:0] make_stream_event(input int event_index);
        int sym_i;
        int round_i;
        int order_i;
        logic [3:0] sym;
        logic side;
        logic [15:0] px;
        logic [15:0] qty;
        begin
            sym_i = (event_index / 2) % NUM_SYMBOLS;
            round_i = event_index / (2 * NUM_SYMBOLS);
            order_i = event_index % 128;
            sym = sym_i[3:0];
            side = event_index[0];
            qty = 16'd10 + 16'(round_i % 20);

            if (side == 1'b0)
                px = 16'(10000 + (sym_i * 8) + (round_i % 4));
            else
                px = 16'(10004 + (sym_i * 8) + (round_i % 4));

            make_stream_event = make_event_packet(EVENT_ADD, sym, side, order_i[15:0], px, qty);
        end
    endfunction

    always @(posedge clk) begin
        #1;

        if (!rst && signal_valid) begin
            signal_count++;

            if (signal_count <= 10) begin
                $display(
                    "Signal %0d at cycle %0d: symbol=%0d bid=%0d ask=%0d bid_qty=%0d ask_qty=%0d spread=%0d trade=%0b",
                    signal_count,
                    cycle_count,
                    signal_symbol,
                    signal_bid,
                    signal_ask,
                    signal_bid_qty,
                    signal_ask_qty,
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

            if (!risk_ok || (risk_reject_code != 3'd0)) begin
                $display("FAIL: unexpected event risk rejection code=%0d", risk_reject_code);
                errors++;
            end
        end
    end

    task automatic drive_stream();
        int event_index;
        begin
            event_index = 0;

            while (event_index < num_events) begin
                @(negedge clk);
                in_valid = 1'b1;
                in_packet = make_stream_event(event_index);

                @(posedge clk);
                #1;

                if (in_valid && in_ready) begin
                    if (accepted_count == 0)
                        first_accept_cycle = cycle_count;

                    last_accept_cycle = cycle_count;
                    accepted_count++;
                    event_index++;

                    if (accepted_count <= 10) begin
                        $display("Accepted event %0d at cycle %0d: 0x%016h",
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
        if ($value$plusargs("NUM_EVENTS=%d", num_events))
            $display("NUM_EVENTS set to %0d", num_events);
        else
            $display("NUM_EVENTS defaulting to %0d", num_events);

        if ($test$plusargs("TRACE")) begin
            $display("TRACE enabled: writing event_streaming_stress_trace.vcd");
            $dumpfile("event_streaming_stress_trace.vcd");
            $dumpvars(0, tb_event_streaming_stress);
        end else begin
            $display("TRACE disabled for faster event benchmark");
        end

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        drive_stream();

        repeat (50) @(posedge clk);
        #1;

        measurement_cycles = last_accept_cycle - first_accept_cycle + 1;

        if (accepted_count != num_events) begin
            $display("FAIL: expected %0d accepted events, got %0d",
                     num_events, accepted_count);
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
        $display("Event streaming stress benchmark summary");
        $display("Events requested:         %0d", num_events);
        $display("Events accepted:          %0d", accepted_count);
        $display("Signal outputs observed:  %0d", signal_count);
        $display("Input stall cycles:       %0d", stall_count);
        $display("First accept cycle:       %0d", first_accept_cycle);
        $display("Last accept cycle:        %0d", last_accept_cycle);
        $display("Measurement cycles:       %0d", measurement_cycles);

        if (measurement_cycles > 0) begin
            $display("Throughput target:        1 event/cycle");
            $display("Measured accept rate:     %0d events / %0d cycles",
                     accepted_count, measurement_cycles);
        end

        $display("Errors:                   %0d", errors);
        $display("----------------------------------------");

        if (errors == 0)
            $display("PASS: event streaming stress benchmark passed");
        else
            $display("FAIL: event streaming stress benchmark had %0d errors", errors);

        $finish;
    end

endmodule
