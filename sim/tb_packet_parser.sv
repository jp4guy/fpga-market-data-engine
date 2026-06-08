`timescale 1ns/1ps

module tb_packet_parser;

    logic        packet_valid;
    logic [31:0] packet_data;

    logic        update_valid;
    logic [3:0]  message_type;
    logic [3:0]  symbol_id;
    logic        side;
    logic [22:0] price;

    int errors = 0;

    packet_parser dut (
        .packet_valid(packet_valid),
        .packet_data(packet_data),
        .update_valid(update_valid),
        .message_type(message_type),
        .symbol_id(symbol_id),
        .side(side),
        .price(price)
    );

    function automatic logic [31:0] make_packet(
        input logic [3:0]  msg_type,
        input logic [3:0]  sym,
        input logic        bid_or_ask,
        input logic [22:0] px
    );
        make_packet = {msg_type, sym, bid_or_ask, px};
    endfunction

    task automatic check_packet(
        input logic [31:0] pkt,
        input logic        valid,
        input logic        expected_update_valid,
        input logic [3:0]  expected_msg_type,
        input logic [3:0]  expected_symbol,
        input logic        expected_side,
        input logic [22:0] expected_price
    );
        begin
            packet_data = pkt;
            packet_valid = valid;
            #1;

            if (update_valid !== expected_update_valid) begin
                $display("FAIL: update_valid expected %0b, got %0b", expected_update_valid, update_valid);
                errors++;
            end

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
    endtask

    initial begin
        $dumpfile("parser_trace.vcd");
        $dumpvars(0, tb_packet_parser);

        packet_valid = 0;
        packet_data = '0;
        #1;

        // Valid bid update: symbol 0, bid, price 10005 = $100.05
        check_packet(
            make_packet(4'h1, 4'h0, 1'b0, 23'd10005),
            1'b1,
            1'b1,
            4'h1,
            4'h0,
            1'b0,
            23'd10005
        );

        // Valid ask update: symbol 1, ask, price 25025 = $250.25
        check_packet(
            make_packet(4'h1, 4'h1, 1'b1, 23'd25025),
            1'b1,
            1'b1,
            4'h1,
            4'h1,
            1'b1,
            23'd25025
        );

        // Invalid message type: parser should decode fields, but update_valid should be 0
        check_packet(
            make_packet(4'h2, 4'h3, 1'b0, 23'd5000),
            1'b1,
            1'b0,
            4'h2,
            4'h3,
            1'b0,
            23'd5000
        );

        // packet_valid = 0, so update_valid should be 0
        check_packet(
            make_packet(4'h1, 4'h2, 1'b1, 23'd12345),
            1'b0,
            1'b0,
            4'h1,
            4'h2,
            1'b1,
            23'd12345
        );

        if (errors == 0)
            $display("PASS: packet parser test passed");
        else
            $display("FAIL: packet parser test had %0d errors", errors);

        $finish;
    end

endmodule
