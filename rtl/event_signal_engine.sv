`timescale 1ns/1ps

module event_signal_engine #(
    parameter logic [15:0] SPREAD_THRESHOLD = 16'd10
) (
    input  logic        clk,
    input  logic        rst,

    input  logic        book_valid,
    input  logic [3:0]  book_symbol,
    input  logic [15:0] best_bid,
    input  logic [15:0] best_ask,
    input  logic [15:0] best_bid_qty,
    input  logic [15:0] best_ask_qty,

    output logic        signal_valid,
    output logic [3:0]  signal_symbol,
    output logic [15:0] signal_bid,
    output logic [15:0] signal_ask,
    output logic [15:0] signal_bid_qty,
    output logic [15:0] signal_ask_qty,
    output logic [15:0] spread,
    output logic        trade_signal
);

    timeunit 1ns;
    timeprecision 1ps;

    logic        has_two_sided_book;
    logic [15:0] spread_calc;

    assign has_two_sided_book = book_valid &&
                                (best_bid != 16'd0) &&
                                (best_ask != 16'd0) &&
                                (best_ask >= best_bid);
    assign spread_calc = best_ask - best_bid;

    always_ff @(posedge clk) begin
        if (rst) begin
            signal_valid   <= 1'b0;
            signal_symbol  <= '0;
            signal_bid     <= '0;
            signal_ask     <= '0;
            signal_bid_qty <= '0;
            signal_ask_qty <= '0;
            spread         <= '0;
            trade_signal   <= 1'b0;
        end else begin
            signal_valid   <= has_two_sided_book;
            signal_symbol  <= book_symbol;
            signal_bid     <= best_bid;
            signal_ask     <= best_ask;
            signal_bid_qty <= best_bid_qty;
            signal_ask_qty <= best_ask_qty;

            if (has_two_sided_book) begin
                spread       <= spread_calc;
                trade_signal <= (spread_calc <= SPREAD_THRESHOLD);
            end else begin
                spread       <= '0;
                trade_signal <= 1'b0;
            end

            if (signal_valid) begin
                assert (signal_bid != 16'd0)
                    else $error("event signal_valid asserted with zero bid");
                assert (signal_ask != 16'd0)
                    else $error("event signal_valid asserted with zero ask");
                assert (signal_bid_qty != 16'd0)
                    else $error("event signal_valid asserted with zero bid quantity");
                assert (signal_ask_qty != 16'd0)
                    else $error("event signal_valid asserted with zero ask quantity");
                assert (signal_ask >= signal_bid)
                    else $error("event signal_valid asserted with crossed bid/ask");
                assert (spread == (signal_ask - signal_bid))
                    else $error("event spread does not match signal ask minus bid");
            end
        end
    end

endmodule
