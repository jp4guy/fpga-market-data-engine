`timescale 1ns/1ps

module tb_order_book;

    localparam int NUM_SYMBOLS = 4;

    logic clk = 0;
    logic rst = 1;

    logic update_valid = 0;
    logic [3:0] symbol_id = '0;
    logic side = 0;
    logic [22:0] price = '0;

    logic book_valid;
    logic [3:0] book_symbol;
    logic [22:0] best_bid;
    logic [22:0] best_ask;

    int errors = 0;

    order_book #(
        .NUM_SYMBOLS(NUM_SYMBOLS)
    ) dut (
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

    always #5 clk = ~clk;

    task automatic send_update_and_check(
        input logic [3:0] expected_symbol,
        input logic       bid_or_ask,
        input logic [22:0] px,
        input logic [22:0] expected_bid,
        input logic [22:0] expected_ask
    );
        begin
            @(negedge clk);
            symbol_id = expected_symbol;
            side = bid_or_ask;
            price = px;
            update_valid = 1'b1;

            @(posedge clk);
            #1;

            if (!book_valid) begin
                $display("FAIL: expected book_valid = 1");
                errors++;
            end

            if (book_symbol !== expected_symbol) begin
                $display("FAIL: expected symbol %0d, got %0d", expected_symbol, book_symbol);
                errors++;
            end

            if (best_bid !== expected_bid) begin
                $display("FAIL: expected best_bid %0d, got %0d", expected_bid, best_bid);
                errors++;
            end

            if (best_ask !== expected_ask) begin
                $display("FAIL: expected best_ask %0d, got %0d", expected_ask, best_ask);
                errors++;
            end

            @(negedge clk);
            update_valid = 1'b0;
            symbol_id = '0;
            side = 1'b0;
            price = '0;
        end
    endtask

    initial begin
        $dumpfile("order_book_trace.vcd");
        $dumpvars(0, tb_order_book);

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;

        // Symbol 0 bid = $100.05
        send_update_and_check(4'd0, 1'b0, 23'd10005, 23'd10005, 23'd0);

        // Symbol 0 ask = $100.10
        send_update_and_check(4'd0, 1'b1, 23'd10010, 23'd10005, 23'd10010);

        // Symbol 1 bid = $250.25
        send_update_and_check(4'd1, 1'b0, 23'd25025, 23'd25025, 23'd0);

        // Symbol 1 ask = $250.40
        send_update_and_check(4'd1, 1'b1, 23'd25040, 23'd25025, 23'd25040);

        if (errors == 0)
            $display("PASS: order book test passed");
        else
            $display("FAIL: order book test had %0d errors", errors);

        $finish;
    end

endmodule
