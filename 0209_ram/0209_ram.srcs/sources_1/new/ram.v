`timescale 1ns / 1ps

module ram(
    input clk,
    input we,
    input [9:0] addr,
    input [7:0] wdata,
    output [7:0] rdata
    );

    //ram space
    reg [7:0]ram[0:1023]; //8비트 낮은순서로 집어넣음?

    //to write ram
    always@(posedge clk)begin
        if(we)begin
            ram[addr] <= wdata; //램의 주소에 집어넣어라
        end //else begin
           // rdata <= ram[addr];
       // end
    end

    assign rdata = ram[addr];   


endmodule
