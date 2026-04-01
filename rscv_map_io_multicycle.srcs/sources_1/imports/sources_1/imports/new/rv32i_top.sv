`timescale 1ns / 1ps


module rv32i_mcu (
    input               clk,
    input               rst,
    input        [ 7:0] gpi,
    output logic [ 7:0] gpo,
    inout  wire  [15:0] gpio,
    output logic [ 3:0] fnd_digit,
    output logic [ 7:0] fnd_data,
    input  logic        uart_rx,
    output logic        uart_tx
);
    logic [2:0] o_funct3;
    logic bus_wreq, bus_rreq, bus_ready;
    logic [31:0] instr_addr, instr_data, bus_addr, bus_rdata, bus_wdata;
    logic psel0, psel1, psel2, psel3, psel4, psel5;
    logic [31:0] prdata0, prdata1, prdata2, prdata3, prdata4, prdata5;
    logic pready0, pready1, pready2, pready3, pready4, pready5;
    logic [31:0] paddr, pwdata;
    logic penable, pwrite;

    instruction_mem U_INSTRUCTION_MEM (.*);

    rv32ii_cpu U_RV32I_CPU (
        .*,
        .o_funct3(o_funct3)
    );

    // data_mem U_DATA_MEM (
    //     .*,
    //     .i_funct3(o_funct3)
    // );

    apb_master U_APB_MASTER (
        .pclk(clk),
        .prst(rst),
        .addr(bus_addr),
        .wdata(bus_wdata),
        .wreq(bus_wreq),  //signal cpu:dwe
        .rreq(bus_rreq),  //signal cpu:dr
        .rdata(bus_rdata),
        .ready(bus_ready),
        //to apb slave
        .paddr(paddr),
        .pwdata(pwdata),
        .penable(penable),
        .pwrite(pwrite),
        //from apb slave
        .psel0(psel0),  //ram
        .psel1(psel1),  //gpo
        .psel2(psel2),  //gpi
        .psel3(psel3),  //gpio
        .psel4(psel4),  //fnd
        .psel5(psel5),  //uart
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
        .pready5(pready5)
    );

    slave_ram U_BMEM (
        .*,
        .pclk  (clk),
        .psel  (psel0),
        .prdata(prdata0),
        .pready(pready0)
    );

    GPO U_APB_GPO (
        .pclk(clk),
        .prst(rst),
        .paddr(paddr),
        .pwdata(pwdata),
        .pwrite(pwrite),
        .penable(penable),
        .psel(psel1),
        .pready(pready1),
        .prdata(prdata1),
        .gpo_out(gpo)
    );

    GPI U_APB_GPI (
        .pclk(clk),
        .prst(rst),
        .paddr(paddr),
        .pwdata(pwdata),
        .pwrite(pwrite),
        .penable(penable),
        .psel(psel2),
        .gpi(gpi),
        .pready(pready2),
        .prdata(prdata2)
    );

    apb_gpio U_APB_GPIO (
        .pclk(clk),
        .prst(rst),
        .paddr(paddr),
        .pwdata(pwdata),
        .pwrite(pwrite),
        .penable(penable),
        .psel(psel3),
        .pready(pready3),
        .prdata(prdata3),
        .gpio(gpio)
    );

    apb_fnd U_APB_FND (
        .pclk(clk),
        .prst(rst),
        .paddr(paddr),
        .pwdata(pwdata),
        .pwrite(pwrite),
        .penable(penable),
        .psel(psel4),
        .pready(pready4),
        .prdata(prdata4),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

    apb_uart U_APB_UART (
        .pclk(clk),
        .prst(rst),
        .paddr(paddr),
        .pwdata(pwdata),  //tx_data_reg
        .psel(psel5),
        .penable(penable),
        .pwrite(pwrite),
        .prdata(prdata5),  //rx_data_reg
        .pready(pready5),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx)
    );
endmodule
