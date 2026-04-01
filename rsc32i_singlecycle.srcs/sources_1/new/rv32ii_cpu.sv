`timescale 1ns / 1ps
`include "define.vh"


module rv32ii_cpu (
    input         clk,
    input         rst,
    output [31:0] instr_addr,
    input  [31:0] drdata,
    input  [31:0] instr_data,
    output        dwe,
    output [31:0] daddr,
    output [31:0] dwdata,
    output [ 2:0] o_funct3
);
    logic rf_we, alu_src, branch, jal, jalr;
    logic [2:0] rfwd_src;
    logic [3:0] alu_control;

    control_unit U_CONTROL_UNIT (
        .funct7(instr_data[31:25]),
        .funct3(instr_data[14:12]),
        .opcode(instr_data[6:0]),
        .rf_we(rf_we),
        .alu_src(alu_src),
        .alu_control(alu_control),
        .dwe(dwe),
        .rfwd_src(rfwd_src),
        .o_funct3(o_funct3),
        .branch(branch),
        .jal(jal),
        .jalr(jalr)
    );

    rv32i_datapath U_DATAPATH (.*);
endmodule



module control_unit (
    //input              rst,
    input [6:0] funct7,
    input [2:0] funct3,
    input [6:0] opcode,
    output logic rf_we,  //register_file
    output logic alu_src,
    output logic [3:0] alu_control,
    output logic dwe,
    output logic [2:0] o_funct3,
    output logic [2:0] rfwd_src,  //0_alu, 1_memory, 2_lui, 3_auipc, 4_jal/jalr
    output logic branch,
    output logic jal,
    output logic jalr
);

    always_comb begin
        rf_we       = 1'b0;
        alu_src     = 1'b0;
        alu_control = 4'b0000;
        dwe         = 1'b0;
        rfwd_src    = 0;
        o_funct3    = 0;
        branch      = 0;
        jal         = 0;
        jalr        = 0;
        case (opcode)
            `R_TYPE: begin
                rf_we       = 1'b1;
                alu_src     = 1'b0;
                alu_control = {funct7[5], funct3};
                rfwd_src    = 0;
                o_funct3    = 0;
                dwe         = 1'b0;
                branch      = 0;
                jal         = 0;
                jalr        = 0;
            end
            `S_TYPE: begin
                rf_we       = 1'b0;
                alu_src     = 1'b1;
                alu_control = 4'b0000;
                rfwd_src    = 0;
                o_funct3    = funct3;
                dwe         = 1'b1;
                branch      = 0;
                jal         = 0;
                jalr        = 0;
            end
            `IL_TYPE: begin
                rf_we       = 1'b1;
                alu_src     = 1'b1;
                alu_control = 4'b0000;
                rfwd_src    = 1;
                o_funct3    = funct3;
                dwe         = 0;
                branch      = 0;
                jal         = 0;
                jalr        = 0;
            end  //BLUE
            `I_TYPE: begin
                rf_we   = 1'b1;
                alu_src = 1'b1;
                if (funct3 == 3'b101) alu_control = {funct7[5], funct3};
                else alu_control = {1'b0, funct3};
                rfwd_src = 0;
                o_funct3 = funct3;
                dwe      = 0;
                branch   = 0;
                jal      = 0;
                jalr     = 0;
            end
            `B_TYPE: begin
                rf_we       = 1'b0;
                alu_src     = 1'b0;
                alu_control = {1'b0, funct3};
                rfwd_src    = 0;
                o_funct3    = 0;
                dwe         = 0;
                branch      = 1;
                jal         = 0;
                jalr        = 0;
            end
            `LUI: begin
                rf_we       = 1'b1;
                alu_src     = 1'b0;
                alu_control = 0;
                rfwd_src    = 3'b010;
                o_funct3    = 0;
                dwe         = 0;
                branch      = 0;
                jal         = 0;
                jalr        = 0;
            end
            `AUIPC: begin
                rf_we       = 1'b1;
                alu_src     = 1'b0;
                alu_control = 0;
                rfwd_src    = 3'b011;
                o_funct3    = 0;
                dwe         = 0;
                branch      = 0;
                jal         = 0;
                jalr        = 0;
            end
            `JAL: begin
                rf_we       = 1'b1;
                alu_src     = 1'b0;
                alu_control = 0;
                rfwd_src    = 3'b100;
                o_funct3    = 0;
                dwe         = 0;
                branch      = 0;
                jal         = 1;
                jalr        = 0;
            end
            `JALR: begin
                rf_we       = 1'b1;
                alu_src     = 1'b0;
                alu_control = 0;
                rfwd_src    = 3'b100;
                o_funct3    = 0;
                dwe         = 0;
                branch      = 0;
                jal         = 1;
                jalr        = 1;
            end
        endcase
    end
endmodule



