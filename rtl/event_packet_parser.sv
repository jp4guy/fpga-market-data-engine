`timescale 1ns/1ps

import market_types_pkg::event_type_t;
import market_types_pkg::market_event_t;

module event_packet_parser (
    input  logic          packet_valid,
    input  logic [63:0]   packet_data,

    output logic          event_valid,
    output market_event_t parsed_event
);

    timeunit 1ns;
    timeprecision 1ps;

    assign event_valid = packet_valid;

    always_comb begin
        parsed_event.type_id   = event_type_t'(packet_data[63:62]);
        parsed_event.symbol_id = packet_data[61:58];
        parsed_event.side      = packet_data[57];
        parsed_event.order_id  = packet_data[56:41];
        parsed_event.price     = packet_data[40:25];
        parsed_event.quantity  = packet_data[24:9];
    end

endmodule
