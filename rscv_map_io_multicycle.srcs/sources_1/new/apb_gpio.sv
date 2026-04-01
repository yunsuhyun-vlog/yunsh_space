`timescale 1ns / 1ps

module apb_gpio (
    input               pclk,
    input               prst,
    input        [31:0] paddr,
    input        [31:0] pwdata,
    input               pwrite,
    input               penable,
    input               psel,
    output logic        pready,
    output logic [31:0] prdata,
    //external port
    inout  wire [15:0] gpio
);

    localparam [11:0] gpio_ctl_addr = 12'h000;
    localparam [11:0] gpio_odata_addr = 12'h004;  //addr
    localparam [11:0] gpio_idata_addr = 12'h008;
    logic [15:0] gpio_odata_reg, gpio_ctl_reg;
    wire  [15:0] gpio_idata_reg;

    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    assign prdata = (paddr[11:0] == gpio_ctl_addr)? {16'h0000, gpio_ctl_reg}:
                    (paddr[11:0] == gpio_odata_addr)?{16'h0000,gpio_odata_reg}:
                    (paddr[11:0] == gpio_idata_addr)?{16'h0000,gpio_idata_reg}:32'hxxxx_xxxx;

    always_ff @(posedge pclk, posedge prst) begin
        if (prst) begin
            gpio_odata_reg <= 16'h0;
            gpio_ctl_reg   <= 16'h0;
            //gpio_idata_reg <= 16'h0;
        end else begin
            if (pready) begin
                if (pwrite) begin
                    case (paddr[11:0])
                        gpio_ctl_addr:   gpio_ctl_reg <= pwdata[15:0];
                        gpio_odata_addr: gpio_odata_reg <= pwdata[15:0];
                    endcase
                // end else begin
                //     prdata <= gpio_idata_reg;
                end
            end
        end
    end

    gpio U_GPIO (
        .ctl(gpio_ctl_reg),
        .o_data(gpio_odata_reg),
        .i_data(gpio_idata_reg),
        .gpio(gpio)
    );

endmodule

module gpio (
    input        [15:0] ctl,
    input        [15:0] o_data,
    output logic [15:0] i_data,
    inout  wire [15:0] gpio
);

    genvar i;
    generate
        for (i = 0; i < 16; i++) begin
            assign gpio[i]   = ctl[i] ? o_data[i] : 1'bz;
            assign i_data[i] = ~ctl[i] ? gpio[i] : 1'b0;
        end
    endgenerate


endmodule
