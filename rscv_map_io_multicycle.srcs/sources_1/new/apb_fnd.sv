`timescale 1ns / 1ps

module apb_fnd (
    input               pclk,
    input               prst,
    input        [31:0] paddr,
    input        [31:0] pwdata,
    input               pwrite,
    input               penable,
    input               psel,
    output logic        pready,
    output logic [31:0] prdata,
    output logic [ 3:0] fnd_digit,
    output logic [ 7:0] fnd_data
);

    localparam [11:0] fnd_ctl_addr = 12'h000;
    localparam [11:0] fnd_odata_addr = 12'h004;  //addr
    logic [15:0] fnd_odata_reg, fnd_ctl_reg;

    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    assign prdata = (paddr[11:0] == fnd_ctl_addr)? {16'h0000, fnd_ctl_reg}:
                    (paddr[11:0] == fnd_odata_addr)?{16'h0000,fnd_odata_reg}:32'hxxxx_xxxx;

    always_ff @(posedge pclk, posedge prst) begin
        if (prst) begin
            fnd_odata_reg <= 16'h0;
            fnd_ctl_reg   <= 16'h0;
        end else begin
            if (pready) begin
                if (pwrite) begin
                    case (paddr[11:0])
                        fnd_ctl_addr:   fnd_ctl_reg <= pwdata[15:0];
                        fnd_odata_addr: fnd_odata_reg <= pwdata[15:0];
                    endcase
                end
            end
        end
    end

    fnd_controller U_FND_CONTROLLER (
        .clk(pclk),
        .rst(prst),
        .fnd_in_data(fnd_odata_reg), // 스위치에서 들어온 16비트 원본 데이터
        .fnd_digit(fnd_digit),  // FND 자리수 선택 (Anode/Cathode)
        .fnd_data(fnd_data)  // 7-Segment 표시 데이터
    );

endmodule


module fnd_controller (
    input logic clk,
    input logic rst,
    input  logic [15:0] fnd_in_data, // 스위치에서 들어온 16비트 원본 데이터
    output logic [3:0] fnd_digit,  // FND 자리수 선택 (Anode/Cathode)
    output logic [7:0] fnd_data  // 7-Segment 표시 데이터
);

    logic       w_1khz;
    logic [1:0] w_digit_sel;  // 4자리 표시를 위한 2비트 선택 신호
    logic [3:0] w_mux_out;  // 선택된 1자리의 4비트(16진수) 데이터

    // 1. 클럭 분주기 (1kHz 생성)
    clk_div u_clk_div (
        .clk   (clk),
        .rst (rst),
        .o_1khz(w_1khz)
    );

    // 2. 2비트 카운터 (0 -> 1 -> 2 -> 3 반복)
    counter_4 u_counter (
        .clk      (clk),         // 메인 100MHz 클럭 연결
        .rst      (rst),
        .en       (w_1khz),      // 1kHz 펄스를 인에이블 핀에 연결
        .digit_sel(w_digit_sel)
    );

    // 3. 자리수 디코더 (어느 위치의 FND를 켤지 결정)
    decoder_2X4 u_decoder (
        .digit_sel(w_digit_sel),
        .fnd_digit(fnd_digit)
    );

    // 4. 4x1 먹스 (16비트 데이터를 4비트씩 4등분하여 순서대로 출력)
    mux_4x1 u_mux (
        .sel (w_digit_sel),
        .hex0(fnd_in_data[3:0]),    // 오른쪽 첫 번째 자리
        .hex1(fnd_in_data[7:4]),    // 오른쪽 두 번째 자리
        .hex2(fnd_in_data[11:8]),   // 오른쪽 세 번째 자리
        .hex3(fnd_in_data[15:12]),  // 오른쪽 네 번째 자리 (최상위)
        .dout(w_mux_out)
    );

    // 5. 16진수 -> 7-Segment 디코더
    hex_bcd u_bcd (
        .hex_in  (w_mux_out),
        .fnd_data(fnd_data)
    );

endmodule


module clk_div (
    input  logic clk,
    input  logic rst,
    output logic o_1khz
);
    logic [16:0] counter_r;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_r <= 0;
            o_1khz    <= 1'b0;
        end else begin
            if (counter_r == 99999) begin  // 100MHz 기준 1kHz 생성
                counter_r <= 0;
                o_1khz    <= 1'b1;
            end else begin
                counter_r <= counter_r + 1;
                o_1khz    <= 1'b0;
            end
        end
    end
endmodule

module counter_4 (
    input  logic       clk,       // w_1khz 대신 메인 clk 사용
    input  logic       rst,
    input  logic       en,        // 인에이블(Enable) 신호 추가
    output logic [1:0] digit_sel
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            digit_sel <= 2'b00;
        end else if (en) begin // en(1kHz 펄스)이 1일 때만 카운트 증가
            digit_sel <= digit_sel + 1;
        end
    end
endmodule

module decoder_2X4 (
    input  logic [1:0] digit_sel,
    output logic [3:0] fnd_digit
);
    always_comb begin
        case (digit_sel)
            2'b00: fnd_digit = 4'b1110;
            2'b01: fnd_digit = 4'b1101;
            2'b10: fnd_digit = 4'b1011;
            2'b11: fnd_digit = 4'b0111;
        endcase
    end
endmodule

module mux_4x1 (
    input  logic [1:0] sel,
    input  logic [3:0] hex0,
    input  logic [3:0] hex1,
    input  logic [3:0] hex2,
    input  logic [3:0] hex3,
    output logic [3:0] dout
);
    always_comb begin
        case (sel)
            2'b00: dout = hex0;
            2'b01: dout = hex1;
            2'b10: dout = hex2;
            2'b11: dout = hex3;
        endcase
    end
endmodule

module hex_bcd (
    input  logic [3:0] hex_in,
    output logic [7:0] fnd_data
);
    always_comb begin
        case (hex_in)
            4'h0: fnd_data = 8'hc0;  // 0
            4'h1: fnd_data = 8'hf9;  // 1
            4'h2: fnd_data = 8'ha4;  // 2
            4'h3: fnd_data = 8'hb0;  // 3
            4'h4: fnd_data = 8'h99;  // 4
            4'h5: fnd_data = 8'h92;  // 5
            4'h6: fnd_data = 8'h82;  // 6
            4'h7: fnd_data = 8'hf8;  // 7
            4'h8: fnd_data = 8'h80;  // 8
            4'h9: fnd_data = 8'h90;  // 9
            4'hA: fnd_data = 8'h88;  // A
            4'hB: fnd_data = 8'h83;  // b
            4'hC: fnd_data = 8'hc6;  // C
            4'hD: fnd_data = 8'ha1;  // d
            4'hE: fnd_data = 8'h86;  // E
            4'hF: fnd_data = 8'h8e;  // F
            default: fnd_data = 8'hff;
        endcase
    end
endmodule
