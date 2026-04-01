`timescale 1ns / 1ps

module GPO (
    //bus signal
    input               pclk,
    input               prst,
    //apb interface signal
    input        [31:0] paddr,
    input        [31:0] pwdata,
    input               pwrite,
    input               penable,
    input               psel,
    output logic        pready,
    output logic [31:0] prdata,
    output logic [ 7:0] gpo_out
);
    localparam [11:0] gpo_ctl_addr = 12'h000;
    localparam [11:0] gpo_odata_addr = 12'h004;  //addr
    logic [7:0] gpo_odata_reg, gpo_ctl_reg;
    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    assign prdata = (paddr[11:0] == gpo_ctl_addr)? {24'h0000, gpo_ctl_reg}:
                    (paddr[11:0] == gpo_odata_addr)?{24'h0000,gpo_odata_reg}:32'hxxxx_xxxx;

    always_ff @(posedge pclk, posedge prst) begin
        if (prst) begin
            gpo_odata_reg <= 8'h0;
            gpo_ctl_reg   <= 8'h0;
        end else begin
            if (pready & pwrite) begin
                case (paddr[11:0])
                    gpo_ctl_addr:   gpo_ctl_reg <= pwdata[7:0];
                    gpo_odata_addr: gpo_odata_reg <= pwdata[7:0];
                endcase
            end
        end
    end

    //assign gpo_out = (gpi_ctl_reg)? gpi_idata_reg:16'hzzzz;
    genvar i;
    generate
        for (i = 0; i < 8; i++) begin
            assign gpo_out[i] = (gpo_ctl_reg[i] ? gpo_odata_reg[i] : 1'bz);
        end
    endgenerate
endmodule


module GPI (
    input               pclk,
    input               prst,
    input        [31:0] paddr,
    input        [31:0] pwdata,
    input               pwrite,
    input               penable,
    input               psel,
    input        [ 7:0] gpi,
    output logic        pready,
    output logic [31:0] prdata
);

    localparam [11:0] gpi_ctl_addr = 12'h000;
    localparam [11:0] gpi_idata_addr = 12'h004;  //addr
    logic [7:0] gpi_idata_reg, gpi_ctl_reg;

    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    assign prdata = (paddr[11:0] == gpi_ctl_addr)? {24'h0000, gpi_ctl_reg}:
                    (paddr[11:0] == gpi_idata_addr)?{24'h0000,gpi_idata_reg}:32'hxxxx_xxxx;

    always_ff @(posedge pclk, posedge prst) begin
        if (prst) begin
            // gpi_idata_reg <= 16'h0;
            gpi_ctl_reg <= 8'h0;
        end else begin
            if (pready & pwrite) begin
                case (paddr[11:0])
                    gpi_ctl_addr: gpi_ctl_reg <= pwdata[7:0];
                    //gpo_odata_addr: gpi_idata_reg <= pwdata[15:0];
                endcase
            end
        end
    end

    //assign gpo_out = (gpi_ctl_reg)? gpi_idata_reg:16'hzzzz;
    genvar j;
    generate
        for (j = 0; j < 8; j++) begin
            assign gpi_idata_reg[j] = (gpi_ctl_reg[j] ? gpi[j] : 1'b0);
        end
    endgenerate
endmodule
