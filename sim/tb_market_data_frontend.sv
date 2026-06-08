`timescale 1ns/1ps

module tb_market_data_frontend;

    localparam int DATA_WIDTH = 32;
    localparam int FIFO_DEPTH = 4;

    logic clk = 0;
    logic rst = 1;

    logic in_valid = 0;
    logic [DATA_WIDTH-1:0] in_packet = '0;
    logic in_ready;

    logic update_valid;
    logic [3:0] message_type;
    logic [3:0] symbol_id;
    logic side;
    logic [22:0] price;

    logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_count;

    int errors = 0;

    market_data_frontend #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
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

    always #5 clk = ~clk;

    function automatic logic [31:0] make_packet(
        input logic [3:0]  msg_type,
        input logic [3:0]  sym,
        input logic        bid_or_ask,
        input logic [22:0] px
    );
        make_packet = {msg_type, sym, bid_or_ask, px};
    endfunction

    task automatic send_packet(input logic [31:0] pkt);
        begin
            @(negedge clk);

            if (!in_ready) begin
                $display("FAIL: Tried to send while frontend not ready");
                errors++;
            end

            in_packet = pkt;
            in_valid = 1'b1;

            @(negedge clk);
            in_valid = 1'b0;
            in_packet = '0;
        end
    endtask

    task automatic expect_update(
        input logic [3:0] expected_msg_type,
        input logic [3:0] expected_symbol,
        input logic       expected_side,
        input logic [22:0] expected_price
    );
        int wait_cycles;
        begin
            wait_cycles = 0;

            while (!update_valid && wait_cycles < 10) begin
                @(posedge clk);
                #1;
                wait_cycles++;
            end

            if (!update_valid) begin
                $display("FAIL: Timed out waiting for update_valid");
                errors++;
            end else begin
                if (message_type !== expected_msg_type) begin
                    $display("FAIL: message_type expected %0h, got %0h", expected_msg_type, message_type);
                    errors++;
                end

                if (symbol_id !== expected_symbol) begin
                    $display("FAIL: symbol_id expected %0h, got %0h", expected_symbol, symbol_id);
                    errors++;
                end

                if (side !== expected_side) begin
                    $display("FAIL: side expected %0b, got %0b", expected_side, side);
                    errors++;
                end

                if (price !== expected_price) begin
                    $display("FAIL: price expected %0d, got %0d", expected_price, price);
                    errors++;
                end
            end
        end
    endtask

    initial begin
        $dumpfile("frontend_trace.vcd");
        $dumpvars(0, tb_market_data_frontend);

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;

        // Packet 1: symbol 0, bid, price 10005 = $100.05
        send_packet(make_packet(4'h1, 4'h0, 1'b0, 23'd10005));
        expect_update(4'h1, 4'h0, 1'b0, 23'd10005);

        // Packet 2: symbol 1, ask, price 25025 = $250.25
        send_packet(make_packet(4'h1, 4'h1, 1'b1, 23'd25025));
        expect_update(4'h1, 4'h1, 1'b1, 23'd25025);

        if (fifo_count > FIFO_DEPTH[$bits(fifo_count)-1:0]) begin
            $display("FAIL: fifo_count somehow exceeded FIFO_DEPTH");
            errors++;
        end

        if (errors == 0)
            $display("PASS: market data frontend test passed");
        else
            $display("FAIL: frontend test had %0d errors", errors);

        $finish;
    end

endmodule
