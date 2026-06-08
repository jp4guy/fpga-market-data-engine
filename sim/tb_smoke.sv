`timescale 1ns/1ps

module tb_smoke;

    logic clk = 0;
    logic rst = 1;
    logic [3:0] count;

    smoke_counter dut (
        .clk(clk),
        .rst(rst),
        .count(count)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim_trace.vcd");
        $dumpvars(0, tb_smoke);

        // Hold reset active for a bit
        repeat (2) @(posedge clk);

        // Release reset on a falling edge so it is stable before next rising edge
        @(negedge clk);
        rst = 0;

        // Count 10 rising clock edges
        repeat (10) @(posedge clk);
        #1;

        if (count == 4'd10)
            $display("PASS: count = %0d", count);
        else
            $display("FAIL: count = %0d", count);

        $finish;
    end

endmodule
