`timescale 1ns / 1ps
`include "define.vh"

module rv32i_datapath (
    input               clk,
    input               rst,
    input               rf_we,
    input               alu_src,
    input        [ 3:0] alu_control,
    input        [31:0] instr_data,
    input        [31:0] drdata,
    input        [ 2:0] rfwd_src,
    input               branch,
    input               jal,
    input               jalr,
    output       [31:0] instr_addr,
    output logic [31:0] daddr,
    output logic [31:0] dwdata
);
    logic btaken;
    logic [31:0] rd1, rd2, alu_result, imm_data, alusrc2_data;
    logic [31:0] rfwb_data;
    logic [31:0] auipc, jal_jalr;


    assign daddr  = alu_result;
    assign dwdata = rd2;

    program_counter U_PC (
        .clk(clk),
        .rst(rst),
        .program_counter(instr_addr),
        .pc_next_sel(btaken & branch),
        .jal(jal),
        .jalr(jalr),
        .rd1(rd1),
        .imm_data(imm_data),
        .pc_4_out(jal_jalr),
        .imm_out(auipc)
    );

    register_file U_REG_FILE (
        .clk(clk),
        .rst(rst),
        .ra1(instr_data[19:15]),
        .ra2(instr_data[24:20]),
        .wa(instr_data[11:7]),
        .rf_we(rf_we),
        .wdata(rfwb_data),
        .rd1(rd1),
        .rd2(rd2)
    );

    imm_extender U_IMM_EXTENDER (
        .instr_data(instr_data),
        .imm_data  (imm_data)
    );

    mux_2x1 U_MUX_ALUSRC_RS2 (
        .in0(rd2),  //sel 0
        .in1(imm_data),  //sel 1
        .mux_sel(alu_src),
        .out_mux(alusrc2_data)
    );

    alu U_ALU (
        .rd1(rd1),
        .rd2(alusrc2_data),
        .alu_control(alu_control),
        .alu_result(alu_result),
        .btaken(btaken)
    );

    mux_5X1 U_MUX_RFWD_SEL (
        .in0(alu_result),
        .in1(drdata),
        .in2(imm_data),
        .in3(auipc),
        .in4(jal_jalr),
        .mux_sel(rfwd_src),
        .out_mux(rfwb_data)
    );

endmodule


module mux_5X1 (
    input        [31:0] in0,
    input        [31:0] in1,
    input        [31:0] in2,
    input        [31:0] in3,
    input        [31:0] in4,
    input        [ 2:0] mux_sel,
    output logic [31:0] out_mux
);

    always_comb begin
        case (mux_sel)
            3'b000: begin
                out_mux = in0;
            end
            3'b001: begin
                out_mux = in1;
            end
            3'b010: begin
                out_mux = in2;
            end
            3'b011: begin
                out_mux = in3;
            end
            3'b100: begin
                out_mux = in4;
            end
            default: out_mux = in0;
        endcase
    end
endmodule

module mux_2x1 (
    input        [31:0] in0,      //sel 0
    input        [31:0] in1,      //sel 1
    input               mux_sel,
    output logic [31:0] out_mux
);

    assign out_mux = mux_sel ? in1 : in0;
endmodule

module imm_extender (
    input        [31:0] instr_data,
    output logic [31:0] imm_data
);

    always_comb begin
        imm_data = 32'd0;
        case (instr_data[6:0])
            `S_TYPE: begin
                imm_data = {
                    {20{instr_data[31]}}, instr_data[31:25], instr_data[11:7]
                };
            end
            `I_TYPE, `IL_TYPE, `JALR: begin
                imm_data = {{20{instr_data[31]}}, instr_data[31:20]};
            end
            `B_TYPE: begin
                imm_data = {
                    {20{instr_data[31]}},
                    instr_data[7],
                    instr_data[30:25],
                    instr_data[11:8],
                    1'b0
                };
            end
            `LUI, `AUIPC: begin
                imm_data = {instr_data[31:12], {12'b0}};
            end
            `JAL: begin
                imm_data = {
                    {12{instr_data[31]}},
                    instr_data[19:12],
                    instr_data[20],
                    instr_data[30:21],
                    1'b0
                };
            end
        endcase
    end
endmodule

module register_file (
    input               clk,
    input               rst,
    input        [ 4:0] ra1,
    input        [ 4:0] ra2,
    input        [ 4:0] wa,
    input               rf_we,
    input        [31:0] wdata,
    output logic [31:0] rd1,
    output logic [31:0] rd2
);

    logic [31:0] register_file[0:31];


    // `ifdef SIMULATION
    //     initial begin
    //         // for (int i = 1; i < 32; i++) begin
    //         //     register_file[i] = i;
    //         // end
    //         // register_file[1] = 32'hFFFFFFFF; // x1 = -1
    //         // register_file[2] = 32'h00000001; // x2 = 1
    //         // register_file[3] = 32'hFFFFFFFE; // x3 = -2
    //         // register_file[1] = 32'h00000007;
    //         // register_file[1] = 32'h00000000; // x1 = 0
    //         // register_file[2] = 32'hFFFFFFFF; // x2 = ffffffff
    //         dmem[0] = 32'hFFFFFFFF;
    //         dmem[2] = 32'hFFFFFFFF;

    //     end
    // `endif

    //read
    always_comb begin
        rd1 = register_file[ra1];
        rd2 = register_file[ra2];
        if (ra1 == 5'd0) rd1 = 0;
        if (ra2 == 5'd0) rd2 = 0;
    end

    //write
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            register_file[0] <= 32'h0;
        end else begin
            if (rf_we) begin
                register_file[wa] <= wdata;
            end
        end
    end
endmodule

module alu (
    input        [31:0] rd1,          //base unsigned
    input        [31:0] rd2,
    input        [ 3:0] alu_control,  //func7[5],func3 ->4bit
    output logic [31:0] alu_result,
    output logic        btaken        //compare
);


    always_comb begin
        case (alu_control)
            `ADD: begin
                alu_result = rd1 + rd2;  //add
            end
            `SUB: begin
                alu_result = rd1 - rd2;  //sub
            end
            `SLL: begin
                alu_result = rd1 << rd2[4:0];  //sll
            end
            `SLT: begin
                alu_result = ($signed(rd1) < $signed(rd2)) ? 1 :
                    0;  //slt->signed처리
            end
            `SLTU: begin
                alu_result = (rd1 < rd2) ? 1 : 0;  //zero_extend sltu->unsigned처리
            end
            `XOR: begin
                alu_result = rd1 ^ rd2;  //xor
            end
            `SRL: begin
                alu_result = rd1 >> rd2[4:0];  //srl -> 빈공간 0
            end
            `SRA: begin
                alu_result = $signed(rd1) >>> rd2[4:0];  //msb_extension sra, arithmethic ->빈공간 rd1의 최상위 비트
            end
            `OR: begin
                alu_result = rd1 | rd2;  //or
            end
            `AND: begin
                alu_result = rd1 & rd2;  //and
            end
            default: alu_result = 0;
        endcase
    end

    always_comb begin
        btaken = 0;
        case (alu_control)
            `BEQ: begin
                if (rd1 == rd2) btaken = 1;
                else btaken = 0;
            end
            `BNE: begin
                if (rd1 != rd2) btaken = 1;
                else btaken = 0;
            end
            `BLT: begin
                if ($signed(rd1) < $signed(rd2)) btaken = 1;
                else btaken = 0;
            end
            `BGE: begin
                if ($signed(rd1) >= $signed(rd2)) btaken = 1;
                else btaken = 0;
            end
            `BLTU: begin
                if (rd1 < rd2) btaken = 1;
                else btaken = 0;
            end
            `BGEU: begin
                if (rd1 >= rd2) btaken = 1;
                else btaken = 0;
            end
        endcase
    end
endmodule

module program_counter (
    input               clk,
    input               rst,
    input               pc_next_sel,
    input        [31:0] imm_data,
    input               jal,
    input               jalr,
    input        [31:0] rd1,
    output logic [31:0] program_counter,
    output logic [31:0] pc_4_out,
    output logic [31:0] imm_out
);

    logic [31:0] pc_next, rs2_or_pc_out;
    logic pc_nn_sel;
    assign pc_nn_sel = (pc_next_sel | jal);

    mux_2x1 U_MUX_RS2_OR_PC (
        .in0    (program_counter),  //sel 0
        .in1    (rd1),              //sel 1
        .mux_sel(jalr),
        .out_mux(rs2_or_pc_out)
    );

    pc_alu U_ALU_IMM (
        .a(imm_data),
        .b(rs2_or_pc_out),
        .pc_alu_out(imm_out)
    );
    pc_alu U_ALU_PC_4 (
        .a(32'd4),
        .b(program_counter),
        .pc_alu_out(pc_4_out)
    );
    mux_2x1 U_MUX_PC_NEXT (
        .in0    (pc_4_out),   //sel 0
        .in1    (imm_out),    //sel 1
        .mux_sel(pc_nn_sel),
        .out_mux(pc_next)
    );

    register U_PC_REG (
        .clk(clk),
        .rst(rst),
        .data_in(pc_next),
        .data_out(program_counter)
    );

endmodule

module pc_alu (
    input  [31:0] a,
    input  [31:0] b,
    output [31:0] pc_alu_out
);

    assign pc_alu_out = a + b;
endmodule

module register (
    input         clk,
    input         rst,
    input  [31:0] data_in,
    output [31:0] data_out
);

    logic [31:0] register;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            register <= 0;
        end else begin
            register <= data_in;
        end
    end
    assign data_out = register;
endmodule

