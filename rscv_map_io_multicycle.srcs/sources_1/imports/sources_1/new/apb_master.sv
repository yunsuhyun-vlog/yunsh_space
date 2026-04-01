`timescale 1ns / 1ps

module apb_master (
    input pclk,
    input prst,

    //soc internal signal with cpu
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic        wreq,   //signal cpu:dwe
    input  logic        rreq,   //signal cpu:dre 
    //output logic        slverr,
    output logic [31:0] rdata,
    output logic        ready,

    //apb interface signal
    output logic [31:0] paddr,
    output logic [31:0] pwdata,
    output logic        psel0,    //ram
    output logic        psel1,    //gpo
    output logic        psel2,    //gpi
    output logic        psel3,    //gpio
    output logic        psel4,    //fnd
    output logic        psel5,    //uart
    output logic        penable,
    output logic        pwrite,
    input        [31:0] prdata0,
    input        [31:0] prdata1,
    input        [31:0] prdata2,
    input        [31:0] prdata3,
    input        [31:0] prdata4,
    input        [31:0] prdata5,
    input               pready0,
    input               pready1,
    input               pready2,
    input               pready3,
    input               pready4,
    input               pready5
);
    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        ACCESS
    } apb_state_e;

    apb_state_e c_state, n_state;
    logic [31:0] paddr_next, pwdata_next;  //유지 목적
    logic decode_en, pwrite_next;

    always_ff @(posedge pclk, posedge prst) begin
        if (prst) begin
            c_state <= IDLE;
            paddr   <= 32'b0;
            pwdata  <= 32'b0;
            pwrite  <= 0;
        end else begin
            c_state <= n_state;
            paddr   <= paddr_next;
            pwdata  <= pwdata_next;
            pwrite  <= pwrite_next;
        end
    end

    always_comb begin
        decode_en   = 0;  //latch 방지
        penable     = 0;
        paddr_next  = paddr;
        pwdata_next = pwdata;
        pwrite_next = pwrite;
        n_state     = c_state;
        case (c_state)
            IDLE: begin
                decode_en = 0;
                penable = 0;
                paddr_next = 32'b0;
                pwdata_next = 0;
                pwrite_next = 1'b0;
                if (wreq | rreq) begin
                    paddr_next  = addr;
                    pwdata_next = wdata;
                    if (wreq) begin
                        pwrite_next = 1;
                    end else begin
                        pwrite_next = 0;
                    end
                    n_state = SETUP;
                end
            end
            SETUP: begin             
                decode_en = 1;
                penable   = 0;
                n_state   = ACCESS;
            end
            ACCESS: begin
                decode_en = 1;     
                penable   = 1;
                if (ready) begin
                    n_state = IDLE;
                end
            end
        endcase
    end

    apb_master_decoder U_APB_DECODER (
        .en(decode_en),
        .addr(paddr),
        .psel0(psel0),
        .psel1(psel1),
        .psel2(psel2),
        .psel3(psel3),
        .psel4(psel4),
        .psel5(psel5)

    );

    apb_slave_in_mux U_APB_MUX (
        .prdata0(prdata0),
        .prdata1(prdata1),
        .prdata2(prdata2),
        .prdata3(prdata3),
        .prdata4(prdata4),
        .prdata5(prdata5),
        .pready0(pready0),
        .pready1(pready1),
        .pready2(pready2),
        .pready3(pready3),
        .pready4(pready4),
        .pready5(pready5),
        .sel(paddr),
        .rdata(rdata),
        .ready(ready)
    );


endmodule


module apb_master_decoder (
    input               en,
    input        [31:0] addr,
    output logic        psel0,
    output logic        psel1,
    output logic        psel2,
    output logic        psel3,
    output logic        psel4,
    output logic        psel5
    //output logic psel6
);
    always_comb begin
        psel0 = 0;  //idle에서 0 유지
        psel1 = 0;
        psel2 = 0;
        psel3 = 0;
        psel4 = 0;
        psel5 = 0;
        // psel6 = 0;
        if (en) begin
            case (addr[31:28])  // casex -> error 검출하기 힘듬 !주의해서 사용
                4'h1: psel0 = 1;
                4'h2: begin
                    case (addr[15:12])
                        4'h0: psel1 = 1;
                        4'h1: psel2 = 1;
                        4'h2: psel3 = 1;
                        4'h3: psel4 = 1;
                        4'h4: psel5 = 1;
                    endcase
                end
            endcase
        end
    end
endmodule

module apb_slave_in_mux (
    input        [31:0] prdata0,
    input        [31:0] prdata1,
    input        [31:0] prdata2,
    input        [31:0] prdata3,
    input        [31:0] prdata4,
    input        [31:0] prdata5,
    input               pready0,
    input               pready1,
    input               pready2,
    input               pready3,
    input               pready4,
    input               pready5,
    input        [31:0] sel,
    output logic [31:0] rdata,
    output logic        ready
);

    always_comb begin
        rdata = 32'h0000_0000;
        ready = 1'b0;
        case (sel[31:28])
            4'h1: begin
                rdata = prdata0;
                ready = pready0;
            end
            4'h2: begin
                case (sel[15:12])
                    4'h0: begin
                        rdata = prdata1;
                        ready = pready1;
                    end
                    4'h1: begin
                        rdata = prdata2;
                        ready = pready2;
                    end
                    4'h2: begin
                        rdata = prdata3;
                        ready = pready3;
                    end
                    4'h3: begin
                        rdata = prdata4;
                        ready = pready4;
                    end
                    4'h4: begin
                        rdata = prdata5;
                        ready = pready5;
                    end
                endcase
            end
        endcase

    end
endmodule



// `timescale 1ns / 1ps

// module apb_master_control_unit (
//     input               pclk,
//     input               prst,

//     //soc internal signal with cpu
//     input  logic [31:0] addr,
//     input  logic [31:0] wdata,
//     input  logic        wreq,
//     input  logic        rreq,
//     input  logic        pslverr0,
//     input  logic [31:0] prdata0,
//     input  logic        pready0,

//     //apb interface signal
//     output logic [31:0] paddr,
//     output logic [31:0] pwdata,
//     output logic        pselx,
//     output logic        penable,
//     output logic        pwrite,
//     output logic        slerr,
//     output logic [31:0] rdata,
//     output logic        ready
// );

//     logic [31:0] paddr_c, paddr_n;
//     logic [31:0] pwdata_c, pwdata_n;
//     logic pselx_c, pselx_n;
//     logic penable_c, penable_n;
//     logic pwrite_c, pwrite_n;
//     logic slerr_c, slerr_n;
//     logic [31:0] rdata_c, rdata_n;
//     logic ready_c, ready_n;

//     assign paddr   = paddr_c;
//     assign pwdata  = pwdata_c;
//     assign pselx   = pselx_c;
//     assign penable = penable_c;
//     assign pwrite  = pwrite_c;
//     assign slerr   = slerr_c;
//     assign rdata   = rdata_c;
//     assign ready   = ready_c;

//     typedef enum logic [1:0] {
//         IDLE,
//         SETUP,
//         ACCESS
//     } state_e;
//     state_e c_state, n_state;

//     always_ff @(posedge pclk, posedge prst) begin
//         if (prst) begin
//             c_state   <= IDLE;
//             paddr_c   <= 0;
//             pwdata_c  <= 0;
//             pselx_c   <= 0;
//             penable_c <= 0;
//             pwrite_c  <= 0;
//             slerr_c   <= 0;
//             rdata_c   <= 0;
//             ready_c   <= 0;
//         end else begin
//             c_state   <= n_state;
//             paddr_c   <= paddr_n;
//             pwdata_c  <= pwdata_n;
//             pselx_c   <= pselx_n;
//             penable_c <= penable_n;
//             pwrite_c  <= pwrite_n;
//             slerr_c   <= slerr_n;
//             rdata_c   <= rdata_n;
//             ready_c   <= ready_n;
//         end
//     end


//     always_comb begin
//         n_state   = c_state;
//         paddr_n   = paddr_c;
//         pwdata_n  = pwdata_c;
//         pselx_n   = pselx_c;
//         penable_n = penable_c;
//         pwrite_n  = pwrite_c;
//         slerr_n   = 0;
//         rdata_n   = 0;
//         ready_n   = 0;
//         case (c_state)
//             IDLE: begin
//                 pselx_n = 0;
//                 if (wreq | rreq) n_state = SETUP;
//             end
//             SETUP: begin
//                 pselx_n   = 1;
//                 penable_n = 0;
//                 if (wreq) begin
//                     paddr_n  = addr;
//                     pwrite_n = 1;
//                     pwdata_n = wdata;
//                     ready_n  = 0;
//                     n_state  = ACCESS;
//                 end else begin
//                     paddr_n  = addr;
//                     pwrite_n = 0;
//                     ready_n  = 0;
//                     n_state  = ACCESS;
//                 end
//             end
//             ACCESS: begin
//                 penable_n = 1;
//                 pselx_n   = 1;
//                 if (pready0) begin
//                     ready_n = pready0;
//                     rdata_n = prdata0;
//                     if (pslverr0) begin
//                         slerr_n = 1;
//                     end
//                     n_state = IDLE;
//                 end
//             end
//         endcase
//     end
// endmodule


// module apb_master_decoder (
//     input [31:0] addr,
//     output logic psel0,
//     output logic psel1,
//     output logic psel2,
//     output logic psel3,
//     output logic psel4,
//     output logic psel5,
//     output logic psel6
// );


//     always_comb begin
//         psel0 = 0;
//         psel1 = 0;
//         psel2 = 0;
//         psel3 = 0;
//         psel4 = 0;
//         psel5 = 0;
//         psel6 = 0;
//         if (addr => 32'h0000_0000 && addr <= 32'h0000_0fff) psel0 = 1;
//         if (addr => 32'h0000_0000 && addr <= 32'h0000_0fff) psel0 = 1;
//         if (addr => 32'h0000_0000 && addr <= 32'h0000_0fff) psel0 = 1;
//         if (addr => 32'h0000_0000 && addr <= 32'h0000_0fff) psel0 = 1;
//         if (addr => 32'h0000_0000 && addr <= 32'h0000_0fff) psel0 = 1;
//         if (addr => 32'h0000_0000 && addr <= 32'h0000_0fff) psel0 = 1;
//         if (addr => 32'h0000_0000 && addr <= 32'h0000_0fff) psel0 = 1;
//     end
// endmodule

// module slave_in_mux (
//     input [31:0] in0,
//     input [31:0] in1,
//     input [31:0] in2,
//     input [31:0] in3,
//     input [31:0] in4,
//     input [31:0] in5,
//     input [31:0] in6,
//     input [2:0] sel,
//     output logic [31:0] rdata
// );

//     always_comb begin
//         case (sel)
//             3'b000: begin
//                 rdata = in0;
//             end
//             3'b001: begin
//                 rdata = in1;
//             end
//             3'b010: begin
//                 rdata = in2;
//             end
//             3'b011: begin
//                 rdata = in3;
//             end
//             3'b100: begin
//                 rdata = in4;
//             end
//             3'b101: begin
//                 rdata = in5;
//             end
//             3'b110: begin
//                 rdata = in6;
//             end
//             default: rdata = 0;
//         endcase
//     end
// endmodule
