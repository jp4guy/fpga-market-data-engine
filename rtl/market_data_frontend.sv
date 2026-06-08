module market_data_frontend #(
    parameter int DATA_WIDTH = 32,
    parameter int FIFO_DEPTH = 4
) (
    input  logic                  clk,
    input  logic                  rst,

    input  logic                  in_valid,
    input  logic [DATA_WIDTH-1:0] in_packet,
    output logic                  in_ready,

    output logic                  update_valid,
    output logic [3:0]            message_type,
    output logic [3:0]            symbol_id,
    output logic                  side,
    output logic [22:0]           price,

    output logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_count
);

    logic                  fifo_wr_en;
    logic                  fifo_rd_en;
    logic [DATA_WIDTH-1:0] fifo_rd_data;
    logic                  fifo_full;
    logic                  fifo_empty;

    logic                  parser_valid;

    assign in_ready   = !fifo_full;
    assign fifo_wr_en = in_valid && in_ready;

    // For now, read whenever FIFO has data.
    assign fifo_rd_en = !fifo_empty;

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) input_fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(fifo_wr_en),
        .wr_data(in_packet),
        .full(fifo_full),
        .rd_en(fifo_rd_en),
        .rd_data(fifo_rd_data),
        .empty(fifo_empty),
        .count(fifo_count)
    );

    always_ff @(posedge clk) begin
        if (rst)
            parser_valid <= 1'b0;
        else
            parser_valid <= fifo_rd_en;
    end

    packet_parser parser (
        .packet_valid(parser_valid),
        .packet_data(fifo_rd_data),
        .update_valid(update_valid),
        .message_type(message_type),
        .symbol_id(symbol_id),
        .side(side),
        .price(price)
    );

endmodule
