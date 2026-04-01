`timescale 1ns / 1ps
`include "define.vh"


module rv32ii_cpu (
    input               clk,
    input               rst,
    output logic [31:0] instr_addr,
    input  logic [31:0] bus_rdata,
    input  logic [31:0] instr_data,
    input  logic        bus_ready,
    output logic        bus_wreq,
    output logic        bus_rreq,
    output logic [31:0] bus_addr,
    output logic [31:0] bus_wdata,
    output logic [ 2:0] o_funct3
);
    logic rf_we, alu_src, branch, jal, jalr, pc_en;
    logic [2:0] rfwd_src;
    logic [3:0] alu_control;

    control_unit U_CONTROL_UNIT (
        .clk        (clk),
        .rst        (rst),
        .funct7     (instr_data[31:25]),
        .funct3     (instr_data[14:12]),
        .opcode     (instr_data[6:0]),
        .ready      (bus_ready),
        .rf_we      (rf_we),
        .alu_src    (alu_src),
        .alu_control(alu_control),
        .rfwd_src   (rfwd_src),
        .o_funct3   (o_funct3),
        .branch     (branch),
        .jal        (jal),
        .jalr       (jalr),
        .pc_en      (pc_en),
        .dwe        (bus_wreq),
        .dre        (bus_rreq)
    );

    rv32i_datapath U_DATAPATH (.*);

endmodule



module control_unit (
    input clk,
    input rst,
    input [6:0] funct7,
    input [2:0] funct3,
    input [6:0] opcode,
    input ready,
    output logic pc_en,
    output logic rf_we,  //register_file
    output logic alu_src,
    output logic [3:0] alu_control,
    output logic dwe,
    output logic [2:0] o_funct3,
    output logic [2:0] rfwd_src,  //0_alu, 1_memory, 2_lui, 3_auipc, 4_jal/jalr
    output logic branch,
    output logic jal,
    output logic jalr,
    output logic dre
);

    typedef enum logic [2:0] {
        FETCH,
        DECODE,
        EXECUTE,
        MEM,
        WB
    } state_e;
    state_e c_state, n_state;

    //sl
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= FETCH;
        end else begin
            c_state <= n_state;
        end
    end
    //cl-next_state
    always_comb begin
        n_state = c_state;
        case (c_state)
            FETCH: begin
                n_state = DECODE;
            end
            DECODE: begin
                n_state = EXECUTE;
            end
            EXECUTE: begin
                case (opcode)
                    `R_TYPE, `JAL, `JALR, `AUIPC, `LUI, `I_TYPE: begin
                        n_state = FETCH;
                    end
                    `B_TYPE: begin
                        n_state = FETCH;
                    end
                    `S_TYPE: begin
                        n_state = MEM;
                    end
                    `IL_TYPE: begin
                        n_state = MEM;
                    end
                endcase
            end
            MEM: begin
            //     if (ready) begin
            //         if (opcode == `IL_TYPE) n_state = WB;
            //         else n_state = FETCH;
            //     end
            // end
                case (opcode)
                    `S_TYPE: begin
                        if (ready) n_state = FETCH;
                    end
                    `IL_TYPE: n_state = WB;
                endcase
            end
            WB: begin
                if (ready) begin
                    n_state = FETCH;
                end
            end
        endcase
    end

    //OUTPUT_cl
    always_comb begin
        pc_en       = 0;
        rf_we       = 1'b0;
        alu_src     = 1'b0;
        alu_control = 4'b0000;
        dwe         = 1'b0;  //for s type
        rfwd_src    = 0;
        o_funct3    = 0;
        branch      = 0;
        jal         = 0;
        jalr        = 0;
        dre         = 1'b0;  //for il type
        case (c_state)
            FETCH: begin
                pc_en = 1;
            end
            DECODE: begin
            end
            EXECUTE: begin
                case (opcode)
                    `R_TYPE: begin
                        rf_we       = 1'b1;
                        alu_src     = 1'b0;
                        alu_control = {funct7[5], funct3};
                    end
                    `I_TYPE: begin
                        rf_we   = 1'b1;
                        alu_src = 1'b1;
                        if (funct3 == 3'b101) alu_control = {funct7[5], funct3};
                        else alu_control = {1'b0, funct3};
                    end
                    `B_TYPE: begin
                        alu_src     = 1'b0;
                        alu_control = {1'b0, funct3};
                        branch      = 1'b1;
                    end
                    `S_TYPE: begin
                        alu_src     = 1'b1;
                        alu_control = 4'b0000;
                    end
                    `IL_TYPE: begin
                        alu_src     = 1'b1;
                        alu_control = 4'b0000;
                    end
                    `LUI: begin
                        rf_we = 1'b1;
                        rfwd_src = 3'b010;
                    end
                    `AUIPC: begin
                        rf_we = 1'b1;
                        rfwd_src = 3'b011;
                    end
                    `JAL: begin
                        rf_we = 1'b1;
                        rfwd_src = 3'b100;
                        jal = 1;
                    end
                    `JALR: begin
                        rf_we = 1'b1;
                        rfwd_src = 3'b100;
                        jal = 1;
                        jalr = 1;
                    end
                endcase
            end
            MEM: begin
                o_funct3 = funct3;
                if (opcode == `S_TYPE) dwe = 1'b1;
                if (opcode == `IL_TYPE) dre = 1'b1;     //추가
            end
            WB: begin
                //IL_TYPE
                rf_we    = 1'b1;
                rfwd_src = 3'b001;
            end
        endcase
    end

endmodule


// `timescale 1ns / 1ps
// `include "define.vh"


// module rv32ii_cpu (
//     input         clk,
//     input         rst,
//     output [31:0] instr_addr,
//     input  [31:0] drdata,
//     input  [31:0] instr_data,
//     output        dwe,
//     output [31:0] daddr,
//     output [31:0] dwdata,
//     output [ 2:0] o_funct3
// );
//     logic rf_we, alu_src, branch, jal, jalr, pc_en;
//     logic [2:0] rfwd_src;
//     logic [3:0] alu_control;

//     control_unit U_CONTROL_UNIT (
//         .clk(clk),
//         .rst(rst),
//         .funct7(instr_data[31:25]),
//         .funct3(instr_data[14:12]),
//         .opcode(instr_data[6:0]),
//         .rf_we(rf_we),
//         .alu_src(alu_src),
//         .alu_control(alu_control),
//         .dwe(dwe),
//         .rfwd_src(rfwd_src),
//         .o_funct3(o_funct3),
//         .branch(branch),
//         .jal(jal),
//         .jalr(jalr),
//         .pc_en(pc_en)
//     );

//     rv32i_datapath U_DATAPATH (.*);
// endmodule



// module control_unit (
//     input clk,
//     input rst,
//     input [6:0] funct7,
//     input [2:0] funct3,
//     input [6:0] opcode,
//     output logic pc_en,
//     output logic rf_we,  //register_file
//     output logic alu_src,
//     output logic [3:0] alu_control,
//     output logic dwe,
//     output logic [2:0] o_funct3,
//     output logic [2:0] rfwd_src,  //0_alu, 1_memory, 2_lui, 3_auipc, 4_jal/jalr
//     output logic branch,
//     output logic jal,
//     output logic jalr
// );

//     typedef enum logic [2:0] {
//         FETCH,
//         DECODE,
//         EXECUTE,
//         MEM,
//         WB
//     } state_e;
//     state_e c_state, n_state;

//     //sl
//     always_ff @(posedge clk, posedge rst) begin
//         if (rst) begin
//             c_state <= FETCH;
//         end else begin
//             c_state <= n_state;
//         end
//     end

//     //cl
//     always_comb begin
//         pc_en       = 0;
//         rf_we       = 1'b0;
//         alu_src     = 1'b0;
//         alu_control = 4'b0000;
//         dwe         = 1'b0;
//         rfwd_src    = 0;
//         o_funct3    = 0;
//         branch      = 0;
//         jal         = 0;
//         jalr        = 0;
//         n_state     = c_state;
//         case (c_state)
//             FETCH: begin
//                 pc_en   = 1;
//                 n_state = DECODE;
//             end
//             DECODE: begin
//                 n_state = EXECUTE;
//             end
//             EXECUTE: begin
//                 case (opcode)
//                     `R_TYPE: begin
//                         alu_src     = 1'b0;
//                         alu_control = {funct7[5],funct3};
//                         n_state     = WB;
//                     end
//                     `I_TYPE: begin
//                         alu_src = 1'b1;
//                         if (funct3 == 3'b101) alu_control = {funct7[5], funct3};
//                         else alu_control = {1'b0, funct3};
//                         n_state = WB;
//                     end
//                     `B_TYPE: begin
//                         alu_src     = 1'b0;
//                         alu_control = {1'b0, funct3};
//                         branch      = 1'b1;
//                         pc_en       = 1;
//                         n_state     = FETCH;
//                     end
//                     `S_TYPE: begin
//                         alu_src     = 1'b1;
//                         alu_control = 4'b0000;
//                         n_state     = MEM;
//                     end
//                     `IL_TYPE: begin
//                         alu_src     = 1'b1;
//                         alu_control = 4'b0000;
//                         n_state     = MEM;
//                     end
//                     `LUI: begin
//                         alu_src     = 1'b0;
//                         alu_control = 0;
//                         n_state     = WB;
//                     end
//                     `AUIPC: begin
//                         alu_src     = 1'b0;
//                         alu_control = 0;
//                         n_state     = WB;
//                     end
//                     `JAL: begin
//                         alu_src     = 1'b0;
//                         alu_control = 0;
//                         jal         = 1;
//                         n_state     = WB;
//                     end
//                     `JALR: begin
//                         alu_src     = 1'b0;
//                         alu_control = 0;
//                         jal         = 1;
//                         jalr        = 1;
//                         n_state     = WB;
//                     end
//                 endcase
//             end
//             MEM: begin
//                 if (opcode == `S_TYPE) begin
//                     o_funct3 = funct3;
//                     dwe      = 1'b1;
//                     n_state  = FETCH;
//                 end else begin
//                     if (opcode == `IL_TYPE) begin
//                         o_funct3 = funct3;
//                         n_state  = WB;
//                     end
//                 end
//             end
//             default: n_state = FETCH;
//             WB: begin
//                 rf_we = 1'b1;
//                 case (opcode)
//                     `R_TYPE: begin
//                         rfwd_src = 0;
//                         n_state  = FETCH;
//                     end
//                     `I_TYPE: begin
//                         rfwd_src = 0;
//                         n_state  = FETCH;
//                     end
//                     `IL_TYPE: begin
//                         rfwd_src = 1;
//                         n_state  = FETCH;
//                     end
//                     `LUI: begin
//                         rfwd_src = 3'b010;
//                         n_state  = FETCH;
//                     end
//                     `AUIPC: begin
//                         rfwd_src = 3'b011;
//                         n_state  = FETCH;
//                     end
//                     `JAL: begin
//                         rfwd_src = 3'b100;
//                         jal      = 1'b1;
//                         n_state  = FETCH;
//                     end
//                     `JALR: begin
//                         rfwd_src = 3'b100;
//                         jal      = 1'b1; 
//                         jalr     = 1'b1;
//                         n_state  = FETCH;
//                     end
//                 endcase
//             end
//         endcase
//     end

// endmodule




