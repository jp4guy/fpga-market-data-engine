`timescale 1ns/1ps

import market_types_pkg::event_type_t;
import market_types_pkg::EVENT_ADD;

module tb_event_latency;

    timeunit 1ns;
    timeprecision 1ps;

    localparam int FIFO_DEPTH = 4;
    localparam int NUM_SYMBOLS = 4;
    localparam int EXPECTED_LATENCY = 3;

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

    int errors = 0;
    int cycle_count = 0;
    int bid_accept_cycle = 0;
    int ask_accept_cycle = 0;
    int signal_cycle = 0;
    int measured_latency = 0;

    event_market_data_engine #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .NUM_SYMBOLS(NUM_SYMBOLS),
        .SPREAD_THRESHOLD(16'd10)
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

    always_ff @(posedge clk) begin
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

    task automatic send_packet(
        input logic [63:0] pkt,
        output int accepted_cycle
    );
        begin
            @(negedge clk);

            if (!in_ready) begin
                $display("FAIL: event engine not ready when sending packet");
                errors++;
            end

            in_packet = pkt;
            in_valid = 1'b1;

            @(posedge clk);
            #1;

            if (in_valid && in_ready) begin
                accepted_cycle = cycle_count;
                $display("Event packet accepted at cycle %0d", accepted_cycle);
            end else begin
                $display("FAIL: event packet was not accepted");
                errors++;
                accepted_cycle = -1;
            end

            @(negedge clk);
            in_valid = 1'b0;
            in_packet = '0;
        end
    endtask

    task automatic wait_no_signal(input int cycles);
        begin
            repeat (cycles) begin
                @(posedge clk);
                #1;

                if (signal_valid) begin
                    $display("FAIL: signal_valid went high with one-sided event book");
                    errors++;
                end
            end
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
                $display("event signal_valid seen at cycle %0d", seen_cycle);
            end else begin
                $display("FAIL: timed out waiting for event signal_valid");
                errors++;
            end
        end
    endtask

    initial begin
        $dumpfile("event_latency_trace.vcd");
        $dumpvars(0, tb_event_latency);

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        send_packet(
            make_event_packet(EVENT_ADD, 4'd0, 1'b0, 16'd1, 16'd10010, 16'd50),
            bid_accept_cycle
        );

        wait_no_signal(6);

        send_packet(
            make_event_packet(EVENT_ADD, 4'd0, 1'b1, 16'd2, 16'd10015, 16'd25),
            ask_accept_cycle
        );

        wait_for_signal(signal_cycle);
        measured_latency = signal_cycle - ask_accept_cycle;

        $display("----------------------------------------");
        $display("Event latency measurement");
        $display("Ask accepted cycle: %0d", ask_accept_cycle);
        $display("Signal cycle:       %0d", signal_cycle);
        $display("Measured latency:   %0d cycles", measured_latency);
        $display("----------------------------------------");

        if (signal_symbol !== 4'd0) begin
            $display("FAIL: expected signal_symbol 0, got %0d", signal_symbol);
            errors++;
        end

        if (signal_bid !== 16'd10010) begin
            $display("FAIL: expected signal_bid 10010, got %0d", signal_bid);
            errors++;
        end

        if (signal_ask !== 16'd10015) begin
            $display("FAIL: expected signal_ask 10015, got %0d", signal_ask);
            errors++;
        end

        if (signal_bid_qty !== 16'd50) begin
            $display("FAIL: expected signal_bid_qty 50, got %0d", signal_bid_qty);
            errors++;
        end

        if (signal_ask_qty !== 16'd25) begin
            $display("FAIL: expected signal_ask_qty 25, got %0d", signal_ask_qty);
            errors++;
        end

        if (spread !== 16'd5) begin
            $display("FAIL: expected spread 5, got %0d", spread);
            errors++;
        end

        if (trade_signal !== 1'b1) begin
            $display("FAIL: expected trade_signal 1, got %0b", trade_signal);
            errors++;
        end

        if (risk_ok !== 1'b1) begin
            $display("FAIL: expected risk_ok 1, got %0b", risk_ok);
            errors++;
        end

        if (risk_reject_code !== 3'd0) begin
            $display("FAIL: expected risk_reject_code 0, got %0d", risk_reject_code);
            errors++;
        end

        if (measured_latency !== EXPECTED_LATENCY) begin
            $display("FAIL: expected event latency %0d cycles, got %0d",
                     EXPECTED_LATENCY, measured_latency);
            errors++;
        end

        if (errors == 0)
            $display("PASS: event latency test passed");
        else
            $display("FAIL: event latency test had %0d errors", errors);

        $finish;
    end

endmodule
