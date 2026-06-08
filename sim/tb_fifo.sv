`timescale 1ns/1ps

module tb_fifo;

    localparam int DATA_WIDTH = 32;
    localparam int DEPTH = 4;

    logic clk = 0;
    logic rst = 1;

    logic wr_en = 0;
    logic [DATA_WIDTH-1:0] wr_data = '0;
    logic full;

    logic rd_en = 0;
    logic [DATA_WIDTH-1:0] rd_data;
    logic empty;

    logic [$clog2(DEPTH+1)-1:0] count;

    int errors = 0;
    logic [DATA_WIDTH-1:0] popped_data;

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .full(full),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .empty(empty),
        .count(count)
    );

    always #5 clk = ~clk;

    task automatic push(input logic [DATA_WIDTH-1:0] data);
        begin
            @(negedge clk);
            wr_data = data;
            wr_en = 1;
            rd_en = 0;

            @(negedge clk);
            wr_en = 0;
            wr_data = '0;
        end
    endtask

    task automatic pop(output logic [DATA_WIDTH-1:0] data);
        begin
            @(negedge clk);
            rd_en = 1;
            wr_en = 0;

            @(posedge clk);
            #1;
            data = rd_data;

            @(negedge clk);
            rd_en = 0;
        end
    endtask

    initial begin
        $dumpfile("fifo_trace.vcd");
        $dumpvars(0, tb_fifo);

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;

        #1;
        if (!empty) begin
            $display("FAIL: FIFO should be empty after reset");
            errors++;
        end

        push(32'hAAAA_0001);
        push(32'hBBBB_0002);

        #1;
        if (count != 2) begin
            $display("FAIL: count should be 2, got %0d", count);
            errors++;
        end

        pop(popped_data);
        if (popped_data != 32'hAAAA_0001) begin
            $display("FAIL: first pop expected AAAA_0001, got %h", popped_data);
            errors++;
        end

        pop(popped_data);
        if (popped_data != 32'hBBBB_0002) begin
            $display("FAIL: second pop expected BBBB_0002, got %h", popped_data);
            errors++;
        end

        #1;
        if (!empty) begin
            $display("FAIL: FIFO should be empty after two pops");
            errors++;
        end

        if (errors == 0)
            $display("PASS: FIFO test passed");
        else
            $display("FAIL: FIFO test had %0d errors", errors);

        $finish;
    end

endmodule
