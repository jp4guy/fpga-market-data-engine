`timescale 1ns/1ps

module tb_event_packet_parser;

    import market_types_pkg::market_event_t;
    import market_types_pkg::event_type_t;
    import market_types_pkg::EVENT_ADD;
    import market_types_pkg::EVENT_CANCEL;
    import market_types_pkg::EVENT_EXECUTE;
    import market_types_pkg::EVENT_INVALID;

    logic packet_valid;
    logic [63:0] packet_data;

    logic event_valid;
    market_event_t parsed_event;

    int errors = 0;
    int tests_run = 0;

    event_packet_parser dut (
        .packet_valid(packet_valid),
        .packet_data(packet_data),
        .event_valid(event_valid),
        .parsed_event(parsed_event)
    );

    function automatic logic [63:0] make_packet(
        input event_type_t event_type,
        input logic [3:0]  symbol_id,
        input logic        side,
        input logic [15:0] order_id,
        input logic [15:0] price,
        input logic [15:0] quantity
    );
        make_packet = {
            event_type,
            symbol_id,
            side,
            order_id,
            price,
            quantity,
            9'd0
        };
    endfunction

    task automatic check_event(
        input logic [63:0] pkt,
        input logic        pkt_valid,
        input logic        expected_valid,
        input event_type_t expected_type,
        input logic [3:0]  expected_symbol,
        input logic        expected_side,
        input logic [15:0] expected_order_id,
        input logic [15:0] expected_price,
        input logic [15:0] expected_quantity
    );
        begin
            packet_data  = pkt;
            packet_valid = pkt_valid;
            #1;

            if (event_valid !== expected_valid) begin
                $display("FAIL test %0d: event_valid expected %0b, got %0b",
                         tests_run, expected_valid, event_valid);
                errors++;
            end

            if (expected_valid) begin
                if (parsed_event.event_type !== expected_type) begin
                    $display("FAIL test %0d: event_type mismatch", tests_run);
                    errors++;
                end

                if (parsed_event.symbol_id !== expected_symbol) begin
                    $display("FAIL test %0d: symbol expected %0d, got %0d",
                             tests_run, expected_symbol, parsed_event.symbol_id);
                    errors++;
                end

                if (parsed_event.side !== expected_side) begin
                    $display("FAIL test %0d: side expected %0b, got %0b",
                             tests_run, expected_side, parsed_event.side);
                    errors++;
                end

                if (parsed_event.order_id !== expected_order_id) begin
                    $display("FAIL test %0d: order_id expected %0d, got %0d",
                             tests_run, expected_order_id, parsed_event.order_id);
                    errors++;
                end

                if (parsed_event.price !== expected_price) begin
                    $display("FAIL test %0d: price expected %0d, got %0d",
                             tests_run, expected_price, parsed_event.price);
                    errors++;
                end

                if (parsed_event.quantity !== expected_quantity) begin
                    $display("FAIL test %0d: quantity expected %0d, got %0d",
                             tests_run, expected_quantity, parsed_event.quantity);
                    errors++;
                end
            end

            tests_run++;
        end
    endtask

    initial begin
        $dumpfile("event_parser_trace.vcd");
        $dumpvars(0, tb_event_packet_parser);

        check_event(
            make_packet(EVENT_ADD, 4'd2, 1'b0, 16'd100, 16'd25000, 16'd10),
            1'b1,
            1'b1,
            EVENT_ADD,
            4'd2,
            1'b0,
            16'd100,
            16'd25000,
            16'd10
        );

        check_event(
            make_packet(EVENT_CANCEL, 4'd2, 1'b0, 16'd100, 16'd0, 16'd0),
            1'b1,
            1'b1,
            EVENT_CANCEL,
            4'd2,
            1'b0,
            16'd100,
            16'd0,
            16'd0
        );

        check_event(
            make_packet(EVENT_EXECUTE, 4'd3, 1'b1, 16'd201, 16'd0, 16'd5),
            1'b1,
            1'b1,
            EVENT_EXECUTE,
            4'd3,
            1'b1,
            16'd201,
            16'd0,
            16'd5
        );

        check_event(
            make_packet(EVENT_INVALID, 4'd1, 1'b1, 16'd7, 16'd12345, 16'd99),
            1'b1,
            1'b0,
            EVENT_INVALID,
            4'd1,
            1'b1,
            16'd7,
            16'd12345,
            16'd99
        );

        check_event(
            make_packet(EVENT_ADD, 4'd0, 1'b0, 16'd1, 16'd10000, 16'd1),
            1'b0,
            1'b0,
            EVENT_ADD,
            4'd0,
            1'b0,
            16'd1,
            16'd10000,
            16'd1
        );

        $display("----------------------------------------");
        $display("Event parser test summary");
        $display("Tests run: %0d", tests_run);
        $display("Errors:    %0d", errors);
        $display("----------------------------------------");

        if (errors == 0)
            $display("PASS: event packet parser test passed");
        else
            $display("FAIL: event packet parser test had %0d errors", errors);

        $finish;
    end

endmodule
