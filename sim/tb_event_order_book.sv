`timescale 1ns/1ps

import market_types_pkg::event_type_t;
import market_types_pkg::market_event_t;
import market_types_pkg::EVENT_ADD;
import market_types_pkg::EVENT_CANCEL;
import market_types_pkg::EVENT_EXECUTE;
import market_types_pkg::EVENT_INVALID;

module tb_event_order_book;

    timeunit 1ns;
    timeprecision 1ps;

    logic clk = 0;
    logic rst = 1;

    logic          event_valid = 0;
    market_event_t market_event = '0;

    logic        book_valid;
    logic [3:0]  book_symbol;
    logic [15:0] best_bid;
    logic [15:0] best_ask;
    logic [15:0] best_bid_qty;
    logic [15:0] best_ask_qty;

    int errors = 0;

    event_order_book dut (
        .clk(clk),
        .rst(rst),
        .event_valid(event_valid),
        .market_event(market_event),
        .book_valid(book_valid),
        .book_symbol(book_symbol),
        .best_bid(best_bid),
        .best_ask(best_ask),
        .best_bid_qty(best_bid_qty),
        .best_ask_qty(best_ask_qty)
    );

    always #5 clk = ~clk;

    function automatic market_event_t make_event(
        input event_type_t type_id,
        input logic [3:0]  symbol_id,
        input logic        side,
        input logic [15:0] order_id,
        input logic [15:0] price,
        input logic [15:0] quantity
    );
        market_event_t result;
        begin
            result.type_id   = type_id;
            result.symbol_id = symbol_id;
            result.side      = side;
            result.order_id  = order_id;
            result.price     = price;
            result.quantity  = quantity;
            make_event = result;
        end
    endfunction

    task automatic send_event(
        input market_event_t in_event,
        input logic [15:0]   expected_bid,
        input logic [15:0]   expected_ask,
        input logic [15:0]   expected_bid_qty,
        input logic [15:0]   expected_ask_qty
    );
        begin
            @(negedge clk);
            market_event = in_event;
            event_valid = 1'b1;

            @(posedge clk);
            #1;

            if (book_valid !== 1'b1) begin
                $display("FAIL: expected book_valid after event");
                errors++;
            end

            if (book_symbol !== in_event.symbol_id) begin
                $display("FAIL: book_symbol expected %0d, got %0d",
                         in_event.symbol_id, book_symbol);
                errors++;
            end

            if (best_bid !== expected_bid) begin
                $display("FAIL: best_bid expected %0d, got %0d",
                         expected_bid, best_bid);
                errors++;
            end

            if (best_ask !== expected_ask) begin
                $display("FAIL: best_ask expected %0d, got %0d",
                         expected_ask, best_ask);
                errors++;
            end

            if (best_bid_qty !== expected_bid_qty) begin
                $display("FAIL: best_bid_qty expected %0d, got %0d",
                         expected_bid_qty, best_bid_qty);
                errors++;
            end

            if (best_ask_qty !== expected_ask_qty) begin
                $display("FAIL: best_ask_qty expected %0d, got %0d",
                         expected_ask_qty, best_ask_qty);
                errors++;
            end

            @(negedge clk);
            event_valid = 1'b0;
            market_event = '0;
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        send_event(make_event(EVENT_ADD, 4'd0, 1'b0, 16'd1, 16'd10010, 16'd50),
                   16'd10010, 16'd0, 16'd50, 16'd0);

        send_event(make_event(EVENT_ADD, 4'd0, 1'b0, 16'd2, 16'd10012, 16'd20),
                   16'd10012, 16'd0, 16'd20, 16'd0);

        send_event(make_event(EVENT_ADD, 4'd0, 1'b1, 16'd3, 16'd10020, 16'd30),
                   16'd10012, 16'd10020, 16'd20, 16'd30);

        send_event(make_event(EVENT_ADD, 4'd0, 1'b1, 16'd4, 16'd10018, 16'd15),
                   16'd10012, 16'd10018, 16'd20, 16'd15);

        send_event(make_event(EVENT_EXECUTE, 4'd0, 1'b0, 16'd2, 16'd0, 16'd5),
                   16'd10012, 16'd10018, 16'd15, 16'd15);

        send_event(make_event(EVENT_EXECUTE, 4'd0, 1'b0, 16'd2, 16'd0, 16'd20),
                   16'd10010, 16'd10018, 16'd50, 16'd15);

        send_event(make_event(EVENT_CANCEL, 4'd0, 1'b1, 16'd4, 16'd0, 16'd0),
                   16'd10010, 16'd10020, 16'd50, 16'd30);

        send_event(make_event(EVENT_CANCEL, 4'd0, 1'b1, 16'd99, 16'd0, 16'd0),
                   16'd10010, 16'd10020, 16'd50, 16'd30);

        send_event(make_event(EVENT_INVALID, 4'd0, 1'b0, 16'd0, 16'd0, 16'd0),
                   16'd10010, 16'd10020, 16'd50, 16'd30);

        send_event(make_event(EVENT_ADD, 4'd1, 1'b0, 16'd5, 16'd10005, 16'd12),
                   16'd10005, 16'd0, 16'd12, 16'd0);

        if (errors == 0)
            $display("PASS: event order book test passed");
        else
            $display("FAIL: event order book test had %0d errors", errors);

        $finish;
    end

endmodule
