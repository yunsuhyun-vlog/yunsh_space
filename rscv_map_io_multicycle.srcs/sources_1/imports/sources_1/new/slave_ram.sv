`timescale 1ns / 1ps

module slave_ram (
    input               pclk,
    // input prst,

    //apb interface signal
    input        [31:0] paddr,
    input        [31:0] pwdata,
    input               penable,
    input               pwrite,
    input               psel,     //ram
    output logic [31:0] prdata,
    output logic        pready
);

    //!!bmem!!
    logic [31:0] bmem[0:1024];

    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    always_ff @(posedge pclk) begin
        if (psel & penable & pwrite) begin
            bmem[paddr[11:2]] <= pwdata;
        end
    end

    assign prdata = bmem[paddr[11:2]];

    //         case (i_funct3)
    //             3'b000: begin  // SB
    //                 case (paddr[1:0])
    //                     2'b00: bmem[paddr[31:2]][7:0] <= pwdata[7:0];
    //                     2'b01: bmem[paddr[31:2]][15:8] <= pwdata[7:0];
    //                     2'b10: bmem[paddr[31:2]][23:16] <= pwdata[7:0];
    //                     2'b11: bmem[paddr[31:2]][31:24] <= pwdata[7:0];
    //                 endcase
    //             end
    //             3'b001: begin  // SH
    //                 case (paddr[1])
    //                     1'b0: bmem[paddr[31:2]][15:0] <= pwdata[15:0];
    //                     1'b1: bmem[paddr[31:2]][31:16] <= pwdata[15:0];
    //                 endcase
    //             end
    //             3'b010: begin  // SW
    //                 bmem[paddr[31:2]] <= pwdata;
    //             end
    //             default: bmem[paddr[31:2]] <= pwdata;
    //         endcase
    //     end
    // end


    // // (Load) 
    // always_comb begin
    //     prdata = 32'b0;
    //     case (i_funct3)
    //         3'b000: begin  // LB
    //             case (paddr[1:0])
    //                 2'b00:
    //                 prdata = {
    //                     {24{bmem[paddr[31:2]][7]}}, bmem[paddr[31:2]][7:0]
    //                 };
    //                 2'b01:
    //                 prdata = {
    //                     {24{bmem[paddr[31:2]][15]}}, bmem[paddr[31:2]][15:8]
    //                 };
    //                 2'b10:
    //                 prdata = {
    //                     {24{bmem[paddr[31:2]][23]}}, bmem[paddr[31:2]][23:16]
    //                 };
    //                 2'b11:
    //                 prdata = {
    //                     {24{bmem[paddr[31:2]][31]}}, bmem[paddr[31:2]][31:24]
    //                 };
    //             endcase
    //         end

    //         3'b001: begin  // LH 
    //             case (paddr[1])
    //                 1'b0:
    //                 prdata = {
    //                     {16{bmem[paddr[31:2]][15]}}, bmem[paddr[31:2]][15:0]
    //                 };
    //                 1'b1:
    //                 prdata = {
    //                     {16{bmem[paddr[31:2]][31]}}, bmem[paddr[31:2]][31:16]
    //                 };
    //             endcase
    //         end

    //         3'b010: begin  // LW 
    //             prdata = bmem[paddr[31:2]];
    //         end

    //         3'b100: begin  // LBU 
    //             case (paddr[1:0])
    //                 2'b00: prdata = {24'b0, bmem[paddr[31:2]][7:0]};
    //                 2'b01: prdata = {24'b0, bmem[paddr[31:2]][15:8]};
    //                 2'b10: prdata = {24'b0, bmem[paddr[31:2]][23:16]};
    //                 2'b11: prdata = {24'b0, bmem[paddr[31:2]][31:24]};
    //             endcase
    //         end

    //         3'b101: begin  // LHU 
    //             case (paddr[1])
    //                 1'b0: prdata = {16'b0, bmem[paddr[31:2]][15:0]};
    //                 1'b1: prdata = {16'b0, bmem[paddr[31:2]][31:16]};
    //             endcase
    //         end
    //         default: prdata = bmem[paddr[31:2]];
    //     endcase
    // end




    // logic [31:0] paddr, dwdata, dwe, dwe_n;

    // assign dwe = (pwrite | penable | psel);


    // typedef enum logic [1:0] {
    //     IDLE,
    //     IN_RDATA,
    //     RESPONSE
    // } slave_state;
    // slave_state c_state, n_state;

    // always_ff @(posedge pclk, posedge prst) begin
    //     if (prst) begin
    //         c_state <= IDLE;
    //         paddr <= 0;
    //         dwdata <= 0;
    //         dwe <= 0;
    //         prdata0 <= 0;
    //     end else begin
    //         c_state <= n_state;
    //         paddr <= paddr;
    //         dwdata <= pwdata;
    //         dwe <= dwe_n;
    //         prdata0 <= drdata0;
    //     end
    // end

    // always_comb begin
    //     n_state = c_state;
    //     paddr   = paddr;
    //     pwdata  = dwdata;
    //     dwe_n   = dwe;
    //     drdata0 = prdata0;
    //     drdata1 = prdata1;
    //     drdata2 = prdata2;
    //     drdata3 = prdata3;
    //     drdata4 = prdata4;
    //     drdata5 = prdata5;

    //     case (c_state)
    //         IDLE: begin

    //         end
    //         IN_RDATA: begin
    //         end
    //         RESPONSE: begin
    //         end
    //     endcase
    // end
endmodule
