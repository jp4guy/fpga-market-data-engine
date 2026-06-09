`timescale 1ns/1ps

module event_packet_parser (
    input  logic                              packet_valid,
    input  logic [63:0]                       packet_data,

    output logic                              event_valid,
    output market_types_pkg::market_event_t  parsed_event
);

    logic [1:0] raw_event_type;

    assign raw_event_type = packet_data[63:62];

    always_comb begin
        parsed_event = '0;

        parsed_event.event_type = market_types_pkg::event_type_t'(raw_event_type);
        parsed_event.symbol_id  = packet_data[61:58];
        parsed_event.side       = packet_data[57];
        parsed_event.order_id   = packet_data[56:41];
        parsed_event.price      = packet_data[40:25];
        parsed_event.quantity   = packet_data[24:9];

        event_valid = packet_valid && (raw_event_type != 2'd3);
    end

endmodule
