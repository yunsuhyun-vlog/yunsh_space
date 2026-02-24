`timescale 1ns / 1ps


module register(
    input clk,
    input rst,
    input [31:0] d,
    output [31:0] q
    );

    reg [31:0] q_reg;

    assign q = q_reg;

    always@(posedge clk, posedge rst) begin
        if(rst) begin
            q_reg <= 32'd0;
        end else begin 
            q_reg <= d;
        end
        end
endmodule
