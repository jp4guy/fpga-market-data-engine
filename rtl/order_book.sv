`timescale 1ns/1ps

module order_book #(
    parameter int NUM_SYMBOLS = 4
) (
    input  logic        clk,
    input  logic        rst,

    input  logic        update_valid,
    input  logic [3:0]  symbol_id,
    input  logic        side,
    input  logic [22:0] price,

    output logic        book_valid,
    output logic [3:0]  book_symbol,
    output logic [22:0] best_bid,
    output logic [22:0] best_ask
);

    localparam int ADDR_WIDTH = $clog2(NUM_SYMBOLS);
    localparam logic [3:0] NUM_SYMBOLS_LIMIT = NUM_SYMBOLS[3:0];

    logic [22:0] bid_mem [0:NUM_SYMBOLS-1];
    logic [22:0] ask_mem [0:NUM_SYMBOLS-1];

    logic symbol_in_range;
    logic [ADDR_WIDTH-1:0] symbol_idx;

    assign symbol_in_range = (symbol_id < NUM_SYMBOLS_LIMIT);
    assign symbol_idx = symbol_id[ADDR_WIDTH-1:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            book_valid <= 1'b0;
            book_symbol <= '0;
            best_bid <= '0;
            best_ask <= '0;

            for (int i = 0; i < NUM_SYMBOLS; i++) begin
                bid_mem[i] <= '0;
                ask_mem[i] <= '0;
            end
        end else begin
            book_valid <= 1'b0;

            if (update_valid && symbol_in_range) begin
                book_valid <= 1'b1;
                book_symbol <= symbol_id;

                if (side == 1'b0) begin
                    // side 0 = bid
                    bid_mem[symbol_idx] <= price;
                    best_bid <= price;
                    best_ask <= ask_mem[symbol_idx];
                end else begin
                    // side 1 = ask
                    ask_mem[symbol_idx] <= price;
                    best_bid <= bid_mem[symbol_idx];
                    best_ask <= price;
                end
            end
        end
    end

endmodule
