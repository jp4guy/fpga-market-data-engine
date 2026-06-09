module event_risk_engine #(
    parameter logic [15:0] MAX_RISK_SPREAD = 16'd100,
    parameter logic [15:0] MAX_ORDER_QTY   = 16'd1000
) (
    input  logic        signal_valid,
    input  logic        strategy_trade_signal,
    input  logic [15:0] spread,
    input  logic [15:0] signal_bid_qty,
    input  logic [15:0] signal_ask_qty,

    output logic        risk_ok,
    output logic [2:0]  risk_reject_code,
    output logic        trade_signal
);

    timeunit 1ns;
    timeprecision 1ps;

    localparam logic [2:0] RISK_OK             = 3'd0;
    localparam logic [2:0] RISK_NO_SIGNAL      = 3'd1;
    localparam logic [2:0] RISK_SPREAD_TOO_WIDE = 3'd2;
    localparam logic [2:0] RISK_QTY_TOO_LARGE  = 3'd3;

    always_comb begin
        risk_ok = 1'b0;
        risk_reject_code = RISK_NO_SIGNAL;

        if (signal_valid) begin
            if (spread > MAX_RISK_SPREAD) begin
                risk_reject_code = RISK_SPREAD_TOO_WIDE;
            end else if ((signal_bid_qty > MAX_ORDER_QTY) ||
                         (signal_ask_qty > MAX_ORDER_QTY)) begin
                risk_reject_code = RISK_QTY_TOO_LARGE;
            end else begin
                risk_ok = 1'b1;
                risk_reject_code = RISK_OK;
            end
        end

        trade_signal = signal_valid && strategy_trade_signal && risk_ok;
    end

endmodule
