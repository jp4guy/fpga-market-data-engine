`timescale 1ns/1ps

import market_types_pkg::event_type_t;
import market_types_pkg::market_event_t;

module tb_event_order_book_randomized;

    timeunit 1ns;
    timeprecision 1ps;

    localparam string VECTOR_FILE = "sim/generated_event_order_book_vectors.txt";

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

    int vector_fd;
    int vector_count;
    int scan_count;
    int errors = 0;

    int type_i;
    int symbol_i;
    int side_i;
    int order_i;
    int price_i;
    int quantity_i;
    int expected_bid_i;
    int expected_ask_i;
    int expected_bid_qty_i;
    int expected_ask_qty_i;

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

    task automatic drive_and_check(input int vector_index);
        begin
            @(negedge clk);
            market_event.type_id   = event_type_t'(type_i[1:0]);
            market_event.symbol_id = symbol_i[3:0];
            market_event.side      = side_i[0];
            market_event.order_id  = order_i[15:0];
            market_event.price     = price_i[15:0];
            market_event.quantity  = quantity_i[15:0];
            event_valid = 1'b1;

            @(posedge clk);
            #1;

            if (book_valid !== 1'b1) begin
                $display("FAIL[%0d]: expected book_valid", vector_index);
                errors++;
            end

            if (book_symbol !== symbol_i[3:0]) begin
                $display("FAIL[%0d]: symbol expected %0d, got %0d",
                         vector_index, symbol_i, book_symbol);
                errors++;
            end

            if (best_bid !== expected_bid_i[15:0]) begin
                $display("FAIL[%0d]: bid expected %0d, got %0d",
                         vector_index, expected_bid_i, best_bid);
                errors++;
            end

            if (best_ask !== expected_ask_i[15:0]) begin
                $display("FAIL[%0d]: ask expected %0d, got %0d",
                         vector_index, expected_ask_i, best_ask);
                errors++;
            end

            if (best_bid_qty !== expected_bid_qty_i[15:0]) begin
                $display("FAIL[%0d]: bid_qty expected %0d, got %0d",
                         vector_index, expected_bid_qty_i, best_bid_qty);
                errors++;
            end

            if (best_ask_qty !== expected_ask_qty_i[15:0]) begin
                $display("FAIL[%0d]: ask_qty expected %0d, got %0d",
                         vector_index, expected_ask_qty_i, best_ask_qty);
                errors++;
            end

            @(negedge clk);
            event_valid = 1'b0;
            market_event = '0;
        end
    endtask

    initial begin
        vector_fd = $fopen(VECTOR_FILE, "r");
        if (vector_fd == 0) begin
            $display("FAIL: could not open %s", VECTOR_FILE);
            $finish;
        end

        scan_count = $fscanf(vector_fd, "%d\n", vector_count);
        if (scan_count != 1) begin
            $display("FAIL: could not read vector count from %s", VECTOR_FILE);
            $finish;
        end

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        for (int i = 0; i < vector_count; i++) begin
            scan_count = $fscanf(
                vector_fd,
                "%d %d %d %d %d %d %d %d %d %d\n",
                type_i,
                symbol_i,
                side_i,
                order_i,
                price_i,
                quantity_i,
                expected_bid_i,
                expected_ask_i,
                expected_bid_qty_i,
                expected_ask_qty_i
            );

            if (scan_count != 10) begin
                $display("FAIL: vector %0d is malformed", i);
                errors++;
            end else begin
                drive_and_check(i);
            end
        end

        $fclose(vector_fd);

        if (errors == 0)
            $display("PASS: randomized event order book test passed with %0d vectors", vector_count);
        else
            $display("FAIL: randomized event order book test had %0d errors", errors);

        $finish;
    end

endmodule
