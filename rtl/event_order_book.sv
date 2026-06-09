`timescale 1ns/1ps

import market_types_pkg::event_type_t;
import market_types_pkg::market_event_t;
import market_types_pkg::EVENT_ADD;
import market_types_pkg::EVENT_CANCEL;
import market_types_pkg::EVENT_EXECUTE;

module event_order_book #(
    parameter int NUM_SYMBOLS  = 4,
    parameter int MAX_ORDERS   = 128,
    parameter int PRICE_LEVELS = 64,
    parameter int BASE_PRICE   = 10000
) (
    input  logic          clk,
    input  logic          rst,

    input  logic          event_valid,
    input  market_event_t market_event,

    output logic          book_valid,
    output logic [3:0]    book_symbol,
    output logic [15:0]   best_bid,
    output logic [15:0]   best_ask,
    output logic [15:0]   best_bid_qty,
    output logic [15:0]   best_ask_qty
);

    timeunit 1ns;
    timeprecision 1ps;

    localparam int SYMBOL_WIDTH = $clog2(NUM_SYMBOLS);
    localparam int ORDER_WIDTH  = $clog2(MAX_ORDERS);
    localparam int PRICE_WIDTH  = $clog2(PRICE_LEVELS);

    localparam logic [3:0]  NUM_SYMBOLS_LIMIT = NUM_SYMBOLS[3:0];
    localparam logic [15:0] MAX_ORDERS_LIMIT  = MAX_ORDERS[15:0];
    localparam logic [15:0] BASE_PRICE_U       = BASE_PRICE[15:0];
    localparam logic [15:0] PRICE_LIMIT_U      = 16'(BASE_PRICE + PRICE_LEVELS);

    logic order_active [0:MAX_ORDERS-1];
    logic [SYMBOL_WIDTH-1:0] order_symbol [0:MAX_ORDERS-1];
    logic order_side [0:MAX_ORDERS-1];
    logic [PRICE_WIDTH-1:0] order_price_idx [0:MAX_ORDERS-1];
    logic [15:0] order_quantity [0:MAX_ORDERS-1];

    logic [15:0] level_quantity [0:NUM_SYMBOLS-1][0:1][0:PRICE_LEVELS-1];

    logic symbol_in_range;
    logic order_in_range;
    logic price_in_range;
    logic [SYMBOL_WIDTH-1:0] event_symbol_idx;
    logic [ORDER_WIDTH-1:0] event_order_idx;
    logic [15:0] event_price_offset;
    logic [PRICE_WIDTH-1:0] event_price_idx;

    assign symbol_in_range  = (market_event.symbol_id < NUM_SYMBOLS_LIMIT);
    assign order_in_range   = (market_event.order_id < MAX_ORDERS_LIMIT);
    assign price_in_range   = (market_event.price >= BASE_PRICE_U) &&
                              (market_event.price < PRICE_LIMIT_U);
    assign event_symbol_idx = market_event.symbol_id[SYMBOL_WIDTH-1:0];
    assign event_order_idx  = market_event.order_id[ORDER_WIDTH-1:0];
    assign event_price_offset = market_event.price - BASE_PRICE_U;
    assign event_price_idx    = event_price_offset[PRICE_WIDTH-1:0];

    always_comb begin
        best_bid     = '0;
        best_ask     = '0;
        best_bid_qty = '0;
        best_ask_qty = '0;

        if (book_symbol < NUM_SYMBOLS_LIMIT) begin
            for (int i = 0; i < PRICE_LEVELS; i++) begin
                if (level_quantity[book_symbol[SYMBOL_WIDTH-1:0]][0][i] != 16'd0) begin
                    best_bid     = BASE_PRICE_U + 16'(i);
                    best_bid_qty = level_quantity[book_symbol[SYMBOL_WIDTH-1:0]][0][i];
                end
            end

            for (int i = 0; i < PRICE_LEVELS; i++) begin
                if ((best_ask == 16'd0) &&
                    (level_quantity[book_symbol[SYMBOL_WIDTH-1:0]][1][i] != 16'd0)) begin
                    best_ask     = BASE_PRICE_U + 16'(i);
                    best_ask_qty = level_quantity[book_symbol[SYMBOL_WIDTH-1:0]][1][i];
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            book_valid  <= 1'b0;
            book_symbol <= '0;

            for (int order_i = 0; order_i < MAX_ORDERS; order_i++) begin
                order_active[order_i]    <= 1'b0;
                order_symbol[order_i]    <= '0;
                order_side[order_i]      <= 1'b0;
                order_price_idx[order_i] <= '0;
                order_quantity[order_i]  <= '0;
            end

            for (int sym_i = 0; sym_i < NUM_SYMBOLS; sym_i++) begin
                for (int side_i = 0; side_i < 2; side_i++) begin
                    for (int price_i = 0; price_i < PRICE_LEVELS; price_i++) begin
                        level_quantity[sym_i][side_i][price_i] <= '0;
                    end
                end
            end
        end else begin
            book_valid <= 1'b0;

            if (event_valid && symbol_in_range) begin
                book_valid  <= 1'b1;
                book_symbol <= market_event.symbol_id;

                unique case (market_event.type_id)
                    EVENT_ADD: begin
                        if (order_in_range && price_in_range &&
                            (market_event.quantity != 16'd0) &&
                            !order_active[event_order_idx]) begin
                            order_active[event_order_idx]    <= 1'b1;
                            order_symbol[event_order_idx]    <= event_symbol_idx;
                            order_side[event_order_idx]      <= market_event.side;
                            order_price_idx[event_order_idx] <= event_price_idx;
                            order_quantity[event_order_idx]  <= market_event.quantity;

                            level_quantity[event_symbol_idx][market_event.side][event_price_idx]
                                <= level_quantity[event_symbol_idx][market_event.side][event_price_idx] +
                                   market_event.quantity;
                        end
                    end

                    EVENT_CANCEL: begin
                        if (order_in_range && order_active[event_order_idx]) begin
                            level_quantity[order_symbol[event_order_idx]]
                                          [order_side[event_order_idx]]
                                          [order_price_idx[event_order_idx]]
                                <= level_quantity[order_symbol[event_order_idx]]
                                                 [order_side[event_order_idx]]
                                                 [order_price_idx[event_order_idx]] -
                                   order_quantity[event_order_idx];

                            order_active[event_order_idx]   <= 1'b0;
                            order_quantity[event_order_idx] <= '0;
                        end
                    end

                    EVENT_EXECUTE: begin
                        if (order_in_range && order_active[event_order_idx]) begin
                            if (market_event.quantity >= order_quantity[event_order_idx]) begin
                                level_quantity[order_symbol[event_order_idx]]
                                              [order_side[event_order_idx]]
                                              [order_price_idx[event_order_idx]]
                                    <= level_quantity[order_symbol[event_order_idx]]
                                                     [order_side[event_order_idx]]
                                                     [order_price_idx[event_order_idx]] -
                                       order_quantity[event_order_idx];

                                order_active[event_order_idx]   <= 1'b0;
                                order_quantity[event_order_idx] <= '0;
                            end else begin
                                level_quantity[order_symbol[event_order_idx]]
                                              [order_side[event_order_idx]]
                                              [order_price_idx[event_order_idx]]
                                    <= level_quantity[order_symbol[event_order_idx]]
                                                     [order_side[event_order_idx]]
                                                     [order_price_idx[event_order_idx]] -
                                       market_event.quantity;

                                order_quantity[event_order_idx]
                                    <= order_quantity[event_order_idx] - market_event.quantity;
                            end
                        end
                    end

                    default: begin
                        // Invalid events produce a snapshot but do not mutate state.
                    end
                endcase
            end

            if (book_valid) begin
                assert (book_symbol < NUM_SYMBOLS_LIMIT)
                    else $error("event book produced an out-of-range symbol");
                if (best_bid != 16'd0) begin
                    assert (best_bid_qty != 16'd0)
                        else $error("event book produced a bid price with zero quantity");
                end
                if (best_ask != 16'd0) begin
                    assert (best_ask_qty != 16'd0)
                        else $error("event book produced an ask price with zero quantity");
                end
            end
        end
    end

endmodule
