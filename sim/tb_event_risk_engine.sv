`timescale 1ns/1ps

module tb_event_risk_engine;

    logic        signal_valid;
    logic        strategy_trade_signal;
    logic [15:0] spread;
    logic [15:0] signal_bid_qty;
    logic [15:0] signal_ask_qty;

    logic        risk_ok;
    logic [2:0]  risk_reject_code;
    logic        trade_signal;

    int errors = 0;

    event_risk_engine #(
        .MAX_RISK_SPREAD(16'd20),
        .MAX_ORDER_QTY(16'd100)
    ) dut (
        .signal_valid(signal_valid),
        .strategy_trade_signal(strategy_trade_signal),
        .spread(spread),
        .signal_bid_qty(signal_bid_qty),
        .signal_ask_qty(signal_ask_qty),
        .risk_ok(risk_ok),
        .risk_reject_code(risk_reject_code),
        .trade_signal(trade_signal)
    );

    task automatic check_risk(
        input logic        valid,
        input logic        strategy_trade,
        input logic [15:0] in_spread,
        input logic [15:0] bid_qty,
        input logic [15:0] ask_qty,
        input logic        expected_risk_ok,
        input logic [2:0]  expected_reject_code,
        input logic        expected_trade
    );
        begin
            signal_valid = valid;
            strategy_trade_signal = strategy_trade;
            spread = in_spread;
            signal_bid_qty = bid_qty;
            signal_ask_qty = ask_qty;
            #1;

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

            if (trade_signal !== expected_trade) begin
                $display("FAIL: trade_signal expected %0b, got %0b",
                         expected_trade, trade_signal);
                errors++;
            end
        end
    endtask

    initial begin
        check_risk(1'b0, 1'b1, 16'd5, 16'd10, 16'd10, 1'b0, 3'd1, 1'b0);
        check_risk(1'b1, 1'b1, 16'd5, 16'd10, 16'd10, 1'b1, 3'd0, 1'b1);
        check_risk(1'b1, 1'b0, 16'd5, 16'd10, 16'd10, 1'b1, 3'd0, 1'b0);
        check_risk(1'b1, 1'b1, 16'd25, 16'd10, 16'd10, 1'b0, 3'd2, 1'b0);
        check_risk(1'b1, 1'b1, 16'd5, 16'd101, 16'd10, 1'b0, 3'd3, 1'b0);
        check_risk(1'b1, 1'b1, 16'd5, 16'd10, 16'd101, 1'b0, 3'd3, 1'b0);

        if (errors == 0)
            $display("PASS: event risk engine test passed");
        else
            $display("FAIL: event risk engine test had %0d errors", errors);

        $finish;
    end

endmodule
