`timescale 1ns / 1ps

module tb_rv32i ();

    logic clk, rst;
    logic [7:0] gpi, gpo;
    wire  [15:0] gpio;
    logic [ 3:0] fnd_digit;
    logic [ 7:0] fnd_data;
    logic uart_rx, uart_tx;

    rv32i_mcu dut (.*);

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
         @(negedge clk);
         @(negedge clk);
        rst = 0;
        repeat (300) @(negedge clk);
        $stop;
    end
endmodule
