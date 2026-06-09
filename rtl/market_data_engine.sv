module market_data_engine #(
    parameter int FIFO_DEPTH = 4,
    parameter int NUM_SYMBOLS = 4,
    parameter logic [22:0] SPREAD_THRESHOLD = 23'd10
) (
    input  logic        clk,
    input  logic        rst,

    input  logic        in_valid,
    input  logic [31:0] in_packet,
    output logic        in_ready,

    output logic        signal_valid,
    output logic [3:0]  signal_symbol,
    output logic [22:0] spread,
    output logic        trade_signal,

    output logic [22:0] signal_bid,
    output logic [22:0] signal_ask,

    output logic [22:0] debug_best_bid,
    output logic [22:0] debug_best_ask
);

    logic        update_valid;
    logic [3:0]  message_type;
    logic [3:0]  symbol_id;
    logic        side;
    logic [22:0] price;

    logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_count;

    logic        book_valid;
    logic [3:0]  book_symbol;
    logic [22:0] best_bid;
    logic [22:0] best_ask;

    market_data_frontend #(
        .FIFO_DEPTH(FIFO_DEPTH)
    ) frontend (
        .clk(clk),
        .rst(rst),

        .in_valid(in_valid),
        .in_packet(in_packet),
        .in_ready(in_ready),

        .update_valid(update_valid),
        .message_type(message_type),
        .symbol_id(symbol_id),
        .side(side),
        .price(price),

        .fifo_count(fifo_count)
    );

    order_book #(
        .NUM_SYMBOLS(NUM_SYMBOLS)
    ) book (
        .clk(clk),
        .rst(rst),

        .update_valid(update_valid),
        .symbol_id(symbol_id),
        .side(side),
        .price(price),

        .book_valid(book_valid),
        .book_symbol(book_symbol),
        .best_bid(best_bid),
        .best_ask(best_ask)
    );

    signal_engine #(
        .SPREAD_THRESHOLD(SPREAD_THRESHOLD)
    ) signals (
        .clk(clk),
        .rst(rst),

        .book_valid(book_valid),
        .book_symbol(book_symbol),
        .best_bid(best_bid),
        .best_ask(best_ask),

        .signal_valid(signal_valid),
        .signal_symbol(signal_symbol),
        .spread(spread),
        .trade_signal(trade_signal),

        .signal_bid(signal_bid),
        .signal_ask(signal_ask)
    );

    assign debug_best_bid = best_bid;
    assign debug_best_ask = best_ask;

endmodule
