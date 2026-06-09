import market_types_pkg::market_event_t;

module event_market_data_engine #(
    parameter int FIFO_DEPTH   = 4,
    parameter int NUM_SYMBOLS  = 4,
    parameter int MAX_ORDERS   = 128,
    parameter int PRICE_LEVELS = 64,
    parameter int BASE_PRICE   = 10000,
    parameter logic [15:0] SPREAD_THRESHOLD = 16'd10,
    parameter logic [15:0] MAX_RISK_SPREAD = 16'd100,
    parameter logic [15:0] MAX_ORDER_QTY   = 16'd1000
) (
    input  logic        clk,
    input  logic        rst,

    input  logic        in_valid,
    input  logic [63:0] in_packet,
    output logic        in_ready,

    output logic        signal_valid,
    output logic [3:0]  signal_symbol,
    output logic [15:0] signal_bid,
    output logic [15:0] signal_ask,
    output logic [15:0] signal_bid_qty,
    output logic [15:0] signal_ask_qty,
    output logic [15:0] spread,
    output logic        trade_signal,
    output logic        risk_ok,
    output logic [2:0]  risk_reject_code
);

    timeunit 1ns;
    timeprecision 1ps;

    logic        fifo_wr_en;
    logic        fifo_rd_en;
    logic [63:0] fifo_rd_data;
    logic        fifo_full;
    logic        fifo_empty;
    logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_count;

    logic          parser_valid;
    logic          parsed_event_valid;
    market_event_t parsed_event;

    logic        book_valid;
    logic [3:0]  book_symbol;
    logic [15:0] best_bid;
    logic [15:0] best_ask;
    logic [15:0] best_bid_qty;
    logic [15:0] best_ask_qty;
    logic        strategy_trade_signal;

    assign in_ready   = !fifo_full;
    assign fifo_wr_en = in_valid && in_ready;
    assign fifo_rd_en = !fifo_empty;

    fifo #(
        .DATA_WIDTH(64),
        .DEPTH(FIFO_DEPTH)
    ) input_fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(fifo_wr_en),
        .wr_data(in_packet),
        .full(fifo_full),
        .rd_en(fifo_rd_en),
        .rd_data(fifo_rd_data),
        .empty(fifo_empty),
        .count(fifo_count)
    );

    always_ff @(posedge clk) begin
        if (rst)
            parser_valid <= 1'b0;
        else
            parser_valid <= fifo_rd_en;
    end

    event_packet_parser parser (
        .packet_valid(parser_valid),
        .packet_data(fifo_rd_data),
        .event_valid(parsed_event_valid),
        .parsed_event(parsed_event)
    );

    event_order_book #(
        .NUM_SYMBOLS(NUM_SYMBOLS),
        .MAX_ORDERS(MAX_ORDERS),
        .PRICE_LEVELS(PRICE_LEVELS),
        .BASE_PRICE(BASE_PRICE)
    ) book (
        .clk(clk),
        .rst(rst),
        .event_valid(parsed_event_valid),
        .market_event(parsed_event),
        .book_valid(book_valid),
        .book_symbol(book_symbol),
        .best_bid(best_bid),
        .best_ask(best_ask),
        .best_bid_qty(best_bid_qty),
        .best_ask_qty(best_ask_qty)
    );

    event_signal_engine #(
        .SPREAD_THRESHOLD(SPREAD_THRESHOLD)
    ) signals (
        .clk(clk),
        .rst(rst),
        .book_valid(book_valid),
        .book_symbol(book_symbol),
        .best_bid(best_bid),
        .best_ask(best_ask),
        .best_bid_qty(best_bid_qty),
        .best_ask_qty(best_ask_qty),
        .signal_valid(signal_valid),
        .signal_symbol(signal_symbol),
        .signal_bid(signal_bid),
        .signal_ask(signal_ask),
        .signal_bid_qty(signal_bid_qty),
        .signal_ask_qty(signal_ask_qty),
        .spread(spread),
        .trade_signal(strategy_trade_signal)
    );

    event_risk_engine #(
        .MAX_RISK_SPREAD(MAX_RISK_SPREAD),
        .MAX_ORDER_QTY(MAX_ORDER_QTY)
    ) risk (
        .signal_valid(signal_valid),
        .strategy_trade_signal(strategy_trade_signal),
        .spread(spread),
        .signal_bid_qty(signal_bid_qty),
        .signal_ask_qty(signal_ask_qty),
        .risk_ok(risk_ok),
        .risk_reject_code(risk_reject_code),
        .trade_signal(trade_signal)
    );

endmodule
