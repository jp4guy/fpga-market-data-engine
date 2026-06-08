module packet_parser (
    input  logic        packet_valid,
    input  logic [31:0] packet_data,

    output logic        update_valid,
    output logic [3:0]  message_type,
    output logic [3:0]  symbol_id,
    output logic        side,
    output logic [22:0] price
);

    assign message_type = packet_data[31:28];
    assign symbol_id    = packet_data[27:24];
    assign side         = packet_data[23];
    assign price        = packet_data[22:0];

    assign update_valid = packet_valid && (packet_data[31:28] == 4'h1);

endmodule
