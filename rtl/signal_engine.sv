module signal_engine #(
    parameter logic [22:0] SPREAD_THRESHOLD = 23'd10
) (
    input  logic        clk,
    input  logic        rst,

    input  logic        book_valid,
    input  logic [3:0]  book_symbol,
    input  logic [22:0] best_bid,
    input  logic [22:0] best_ask,

    output logic        signal_valid,
    output logic [3:0]  signal_symbol,
    output logic [22:0] spread,
    output logic        trade_signal,

    output logic [22:0] signal_bid,
    output logic [22:0] signal_ask
);

    logic prices_valid;
    logic [22:0] spread_calc;

    assign prices_valid = (best_bid != 23'd0) && (best_ask != 23'd0);
    assign spread_calc  = best_ask - best_bid;

    always_ff @(posedge clk) begin
        if (rst) begin
            signal_valid  <= 1'b0;
            signal_symbol <= '0;
            spread        <= '0;
            trade_signal  <= 1'b0;
            signal_bid    <= '0;
            signal_ask    <= '0;
        end else begin
            signal_valid <= 1'b0;

            if (book_valid && prices_valid && (best_ask >= best_bid)) begin
                signal_valid  <= 1'b1;
                signal_symbol <= book_symbol;

                signal_bid    <= best_bid;
                signal_ask    <= best_ask;
                spread        <= spread_calc;

                trade_signal  <= (spread_calc <= SPREAD_THRESHOLD);
            end
        end
    end

endmodule
