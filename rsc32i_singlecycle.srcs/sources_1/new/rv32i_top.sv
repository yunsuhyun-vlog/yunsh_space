`timescale 1ns / 1ps


module rv32i_top (
    input clk,
    input rst,
    output [31:0] dwdata
);
    logic [2:0] o_funct3;
    logic dwe;
    logic [31:0] instr_addr, instr_data, daddr, drdata;

    instruction_mem U_INSTRUCTION_MEM (.*);

    rv32ii_cpu U_RV32I_CPU (
        .*,
        .o_funct3(o_funct3)
    );

    data_mem U_DATA_MEM (
        .*,
        .i_funct3(o_funct3)
    );

endmodule
