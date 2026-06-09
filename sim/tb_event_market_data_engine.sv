`timescale 1ns/1ps

import market_types_pkg::event_type_t;
import market_types_pkg::EVENT_ADD;
import market_types_pkg::EVENT_CANCEL;
import market_types_pkg::EVENT_EXECUTE;

module tb_event_market_data_engine;

    timeunit 1ns;
    timeprecision 1ps;

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

    event_market_data_engine dut (
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

    task automatic send_packet(input logic [63:0] pkt);
        begin
            @(negedge clk);
            in_valid = 1'b1;
            in_packet = pkt;

            @(posedge clk);
            #1;

            if (!in_ready) begin
                $display("FAIL: input stalled during deterministic engine test");
                errors++;
            end

            @(negedge clk);
            in_valid = 1'b0;
            in_packet = '0;
        end
    endtask

    task automatic expect_next_signal(
        input logic [3:0]  expected_symbol,
        input logic [15:0] expected_bid,
        input logic [15:0] expected_ask,
        input logic [15:0] expected_bid_qty,
        input logic [15:0] expected_ask_qty,
        input logic        expected_trade
    );
        int wait_cycles;
        begin
            wait_cycles = 0;
            while (signal_valid && (wait_cycles < 12)) begin
                @(posedge clk);
                #1;
                wait_cycles++;
            end

            wait_cycles = 0;
            while (!signal_valid && (wait_cycles < 12)) begin
                @(posedge clk);
                #1;
                wait_cycles++;
            end

            if (!signal_valid) begin
                $display("FAIL: timed out waiting for signal output");
                errors++;
            end else begin
                if (signal_symbol !== expected_symbol) begin
                    $display("FAIL: signal_symbol expected %0d, got %0d",
                             expected_symbol, signal_symbol);
                    errors++;
                end

                if (signal_bid !== expected_bid) begin
                    $display("FAIL: signal_bid expected %0d, got %0d",
                             expected_bid, signal_bid);
                    errors++;
                end

                if (signal_ask !== expected_ask) begin
                    $display("FAIL: signal_ask expected %0d, got %0d",
                             expected_ask, signal_ask);
                    errors++;
                end

                if (signal_bid_qty !== expected_bid_qty) begin
                    $display("FAIL: signal_bid_qty expected %0d, got %0d",
                             expected_bid_qty, signal_bid_qty);
                    errors++;
                end

                if (signal_ask_qty !== expected_ask_qty) begin
                    $display("FAIL: signal_ask_qty expected %0d, got %0d",
                             expected_ask_qty, signal_ask_qty);
                    errors++;
                end

                if (spread !== (expected_ask - expected_bid)) begin
                    $display("FAIL: spread expected %0d, got %0d",
                             expected_ask - expected_bid, spread);
                    errors++;
                end

                if (trade_signal !== expected_trade) begin
                    $display("FAIL: trade_signal expected %0b, got %0b",
                             expected_trade, trade_signal);
                    errors++;
                end

                if (risk_ok !== 1'b1) begin
                    $display("FAIL: risk_ok expected 1, got %0b", risk_ok);
                    errors++;
                end

                if (risk_reject_code !== 3'd0) begin
                    $display("FAIL: risk_reject_code expected 0, got %0d", risk_reject_code);
                    errors++;
                end
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        send_packet(make_event_packet(EVENT_ADD, 4'd0, 1'b0, 16'd1, 16'd10010, 16'd50));
        repeat (6) @(posedge clk);

        if (signal_valid) begin
            $display("FAIL: one-sided book should not produce a trade signal");
            errors++;
        end

        send_packet(make_event_packet(EVENT_ADD, 4'd0, 1'b1, 16'd2, 16'd10015, 16'd25));
        expect_next_signal(4'd0, 16'd10010, 16'd10015, 16'd50, 16'd25, 1'b1);

        send_packet(make_event_packet(EVENT_EXECUTE, 4'd0, 1'b0, 16'd1, 16'd0, 16'd20));
        expect_next_signal(4'd0, 16'd10010, 16'd10015, 16'd30, 16'd25, 1'b1);

        send_packet(make_event_packet(EVENT_ADD, 4'd0, 1'b0, 16'd3, 16'd10012, 16'd10));
        expect_next_signal(4'd0, 16'd10012, 16'd10015, 16'd10, 16'd25, 1'b1);

        send_packet(make_event_packet(EVENT_CANCEL, 4'd0, 1'b0, 16'd3, 16'd0, 16'd0));
        expect_next_signal(4'd0, 16'd10010, 16'd10015, 16'd30, 16'd25, 1'b1);

        if (errors == 0)
            $display("PASS: event market data engine test passed");
        else
            $display("FAIL: event market data engine test had %0d errors", errors);

        $finish;
    end

endmodule
