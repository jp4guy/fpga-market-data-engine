module fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH = 4
) (
    input  logic                  clk,
    input  logic                  rst,

    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,

    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty,

    output logic [$clog2(DEPTH+1)-1:0] count
);

    localparam int ADDR_WIDTH = $clog2(DEPTH);
    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);

    localparam logic [COUNT_WIDTH-1:0] DEPTH_COUNT = DEPTH[COUNT_WIDTH-1:0];

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] wr_ptr;
    logic [ADDR_WIDTH-1:0] rd_ptr;

    logic do_write;
    logic do_read;

    assign full  = (count == DEPTH_COUNT);
    assign empty = (count == '0);

    assign do_write = wr_en && !full;
    assign do_read  = rd_en && !empty;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr  <= '0;
            rd_ptr  <= '0;
            rd_data <= '0;
            count   <= '0;
        end else begin
            assert (count <= DEPTH_COUNT)
                else $error("FIFO count exceeded depth");
            assert (!(wr_en && full))
                else $error("FIFO write requested while full");
            assert (!(rd_en && empty))
                else $error("FIFO read requested while empty");

            if (do_write) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;
            end

            if (do_read) begin
                rd_data <= mem[rd_ptr];
                rd_ptr <= rd_ptr + 1'b1;
            end

            case ({do_write, do_read})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule
