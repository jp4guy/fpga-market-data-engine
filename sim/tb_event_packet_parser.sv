`timescale 1ns/1ps

import market_types_pkg::event_type_t;
import market_types_pkg::market_event_t;
import market_types_pkg::EVENT_ADD;
import market_types_pkg::EVENT_CANCEL;
import market_types_pkg::EVENT_EXECUTE;
import market_types_pkg::EVENT_INVALID;

module tb_event_packet_parser;

    timeunit 1ns;
    timeprecision 1ps;

    logic          packet_valid;
    logic [63:0]   packet_data;
    logic          event_valid;
    market_event_t parsed_event;

    int errors = 0;

    event_packet_parser dut (
        .packet_valid(packet_valid),
        .packet_data(packet_data),
        .event_valid(event_valid),
        .parsed_event(parsed_event)
    );

    function automatic logic [63:0] make_event_packet(
        input event_type_t type_id,
        input logic [3:0]  symbol_id,
        input logic        side,
        input logic [15:0] order_id,
        input logic [15:0] price,
        input logic [15:0] quantity
    );
        make_event_packet = {type_id, symbol_id, side, order_id, price, quantity, 9'b0};
    endfunction

    task automatic check_event_packet(
        input logic [63:0] pkt,
        input logic        valid,
        input logic        expected_event_valid,
        input event_type_t expected_type,
        input logic [3:0]  expected_symbol,
        input logic        expected_side,
        input logic [15:0] expected_order_id,
        input logic [15:0] expected_price,
        input logic [15:0] expected_quantity
    );
        begin
            packet_data = pkt;
            packet_valid = valid;
            #1;

            if (event_valid !== expected_event_valid) begin
                $display("FAIL: event_valid expected %0b, got %0b",
                         expected_event_valid, event_valid);
                errors++;
            end

            if (parsed_event.type_id !== expected_type) begin
                $display("FAIL: type expected %0d, got %0d",
                         expected_type, parsed_event.type_id);
                errors++;
            end

            if (parsed_event.symbol_id !== expected_symbol) begin
                $display("FAIL: symbol expected %0d, got %0d",
                         expected_symbol, parsed_event.symbol_id);
                errors++;
            end

            if (parsed_event.side !== expected_side) begin
                $display("FAIL: side expected %0b, got %0b",
                         expected_side, parsed_event.side);
                errors++;
            end

            if (parsed_event.order_id !== expected_order_id) begin
                $display("FAIL: order_id expected %0d, got %0d",
                         expected_order_id, parsed_event.order_id);
                errors++;
            end

            if (parsed_event.price !== expected_price) begin
                $display("FAIL: price expected %0d, got %0d",
                         expected_price, parsed_event.price);
                errors++;
            end

            if (parsed_event.quantity !== expected_quantity) begin
                $display("FAIL: quantity expected %0d, got %0d",
                         expected_quantity, parsed_event.quantity);
                errors++;
            end
        end
    endtask

    initial begin
        packet_valid = 1'b0;
        packet_data = '0;
        #1;

        check_event_packet(
            make_event_packet(EVENT_ADD, 4'd2, 1'b0, 16'd17, 16'd10025, 16'd40),
            1'b1,
            1'b1,
            EVENT_ADD,
            4'd2,
            1'b0,
            16'd17,
            16'd10025,
            16'd40
        );

        check_event_packet(
            make_event_packet(EVENT_CANCEL, 4'd1, 1'b1, 16'd22, 16'd10100, 16'd10),
            1'b1,
            1'b1,
            EVENT_CANCEL,
            4'd1,
            1'b1,
            16'd22,
            16'd10100,
            16'd10
        );

        check_event_packet(
            make_event_packet(EVENT_EXECUTE, 4'd3, 1'b0, 16'd7, 16'd9900, 16'd5),
            1'b1,
            1'b1,
            EVENT_EXECUTE,
            4'd3,
            1'b0,
            16'd7,
            16'd9900,
            16'd5
        );

        check_event_packet(
            make_event_packet(EVENT_INVALID, 4'd0, 1'b1, 16'd99, 16'd0, 16'd0),
            1'b1,
            1'b1,
            EVENT_INVALID,
            4'd0,
            1'b1,
            16'd99,
            16'd0,
            16'd0
        );

        check_event_packet(
            make_event_packet(EVENT_ADD, 4'd2, 1'b0, 16'd17, 16'd10025, 16'd40),
            1'b0,
            1'b0,
            EVENT_ADD,
            4'd2,
            1'b0,
            16'd17,
            16'd10025,
            16'd40
        );

        if (errors == 0)
            $display("PASS: event packet parser test passed");
        else
            $display("FAIL: event packet parser test had %0d errors", errors);

        $finish;
    end

endmodule
