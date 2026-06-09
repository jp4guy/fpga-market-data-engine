`timescale 1ns/1ps

import market_types_pkg::event_type_t;
import market_types_pkg::market_event_t;
import market_types_pkg::EVENT_ADD;
import market_types_pkg::EVENT_CANCEL;
import market_types_pkg::EVENT_EXECUTE;
import market_types_pkg::EVENT_INVALID;

module tb_event_market_data_engine_risk;

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

    event_market_data_engine #(
        .SPREAD_THRESHOLD(16'd100),
        .MAX_RISK_SPREAD(16'd10),
        .MAX_ORDER_QTY(16'd100)
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
                $display("FAIL: event engine stalled during risk test");
                errors++;
            end

            @(negedge clk);
            in_valid = 1'b0;
            in_packet = '0;
        end
    endtask

    task automatic wait_for_signal();
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
                $display("FAIL: timed out waiting for risk test signal");
                errors++;
            end
        end
    endtask

    task automatic check_risk_output(
        input logic [3:0]  expected_symbol,
        input logic [15:0] expected_spread,
        input logic        expected_risk_ok,
        input logic [2:0]  expected_reject_code,
        input logic        expected_trade_signal
    );
        begin
            wait_for_signal();

            if (signal_symbol !== expected_symbol) begin
                $display("FAIL: symbol expected %0d, got %0d",
                         expected_symbol, signal_symbol);
                errors++;
            end

            if (spread !== expected_spread) begin
                $display("FAIL: spread expected %0d, got %0d",
                         expected_spread, spread);
                errors++;
            end

            if (risk_ok !== expected_risk_ok) begin
                $display("FAIL: risk_ok expected %0b, got %0b",
                         expected_risk_ok, risk_ok);
                errors++;
            end

            if (risk_reject_code !== expected_reject_code) begin
                $display("FAIL: risk_reject_code expected %0d, got %0d",
                         expected_reject_code, risk_reject_code);
                errors++;
            end

            if (trade_signal !== expected_trade_signal) begin
                $display("FAIL: trade_signal expected %0b, got %0b",
                         expected_trade_signal, trade_signal);
                errors++;
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        send_packet(make_event_packet(EVENT_ADD, 4'd0, 1'b0, 16'd1, 16'd10010, 16'd50));
        send_packet(make_event_packet(EVENT_ADD, 4'd0, 1'b1, 16'd2, 16'd10015, 16'd50));
        check_risk_output(4'd0, 16'd5, 1'b1, 3'd0, 1'b1);

        send_packet(make_event_packet(EVENT_ADD, 4'd1, 1'b0, 16'd3, 16'd10010, 16'd50));
        send_packet(make_event_packet(EVENT_ADD, 4'd1, 1'b1, 16'd4, 16'd10030, 16'd50));
        check_risk_output(4'd1, 16'd20, 1'b0, 3'd2, 1'b0);

        send_packet(make_event_packet(EVENT_ADD, 4'd2, 1'b0, 16'd5, 16'd10010, 16'd101));
        send_packet(make_event_packet(EVENT_ADD, 4'd2, 1'b1, 16'd6, 16'd10015, 16'd50));
        check_risk_output(4'd2, 16'd5, 1'b0, 3'd3, 1'b0);

        if (errors == 0)
            $display("PASS: event market data engine risk test passed");
        else
            $display("FAIL: event market data engine risk test had %0d errors", errors);

        $finish;
    end

endmodule
