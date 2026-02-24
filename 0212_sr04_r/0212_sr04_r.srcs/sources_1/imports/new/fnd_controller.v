`timescale 1ns / 1ps

module fnd_controller (   //내꺼
    input clk,
    input reset,
    input sel_display,
    input [23:0] fnd_in_data,
    output [3:0] fnd_digit,  //세크먼트의 오른쪽만 켜겠다
    output [7:0] fnd_data
);
    wire [3:0] w_digit_msec_1, w_digit_msec_10; //wire의 정보전달을 위해 4비트 사용
    wire [3:0] w_digit_sec_1, w_digit_sec_10;
    wire [3:0] w_digit_min_1, w_digit_min_10;
    wire [3:0] w_digit_hour_1, w_digit_hour_10;
    wire [3:0] w_mux_hour_min_out, w_mux_sec_msec_out;
    wire [3:0] w_mux_2x1_out;
    wire [2:0] w_digit_sel;
    wire w_1khz;
    wire w_dot_onoff;

    //hour
    digit_splitter #(
        .BIT_WIDTH(5)
    ) hour_splitter (
        .in_data (fnd_in_data[23:19]),
        .digit_1 (w_digit_hour_1),
        .digit_10(w_digit_hour_10)
    );
    //min
    digit_splitter #(
        .BIT_WIDTH(6)
    ) min_splitter (
        .in_data (fnd_in_data[18:13]),
        .digit_1 (w_digit_min_1),
        .digit_10(w_digit_min_10)
    );
    //sec
    digit_splitter #(
        .BIT_WIDTH(6)
    ) sec_splitter (
        .in_data (fnd_in_data[12:7]),
        .digit_1 (w_digit_sec_1),
        .digit_10(w_digit_sec_10)
    );

    //msec
    digit_splitter #(
        .BIT_WIDTH(7)
    ) msec_splitter (
        .in_data (fnd_in_data[6:0]),
        .digit_1 (w_digit_msec_1),
        .digit_10(w_digit_msec_10)
    );

    dot_onoff_comp u_dot_comp (
        .msec(fnd_in_data[6:0]),
        .dot_onoff(w_dot_onoff)
    );

    mux_8x1 mux_hour_min (
        .sel(w_digit_sel),
        .digit_1(w_digit_min_1),
        .digit_10(w_digit_min_10),
        .digit_100(w_digit_hour_1),
        .digit_1000(w_digit_hour_10),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100({3'b111, w_dot_onoff}),
        .digit_dot_1000(4'hf),
        .mux_out(w_mux_hour_min_out)
    );

    mux_8x1 mux_sec_msec (
        .sel(w_digit_sel),
        .digit_1(w_digit_msec_1),
        .digit_10(w_digit_msec_10),
        .digit_100(w_digit_sec_1),
        .digit_1000(w_digit_sec_10),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100({3'b111, w_dot_onoff}),
        .digit_dot_1000(4'hf),
        .mux_out(w_mux_sec_msec_out)
    );

    mux_2x1 mux_2x1 (
        .sel(sel_display),
        .i_sel0(w_mux_sec_msec_out),
        .i_sel1(w_mux_hour_min_out),
        .o_mux(w_mux_2x1_out)
    );

    clk_div clk_div (
        .clk(clk),
        .reset(reset),
        .o_1khz(w_1khz)
    );

    counter_8 counter_8 (
        .clk(w_1khz),
        .reset(reset),
        .digit_sel(w_digit_sel)
    );


    decoder_2X4 decoder_2X4 (
        .digit_sel(w_digit_sel[1:0]),
        .fnd_digit(fnd_digit)
    );

    bcd U_BCD (
        .bcd(w_mux_2x1_out), //mux와 bcd를 연결해주기 위해 mux_out이름과 bcd입력 ()안의 이름을 같게!
        .fnd_data(fnd_data)
    );

endmodule

//도트 점멸
module dot_onoff_comp (

    input [6:0] msec,
    output dot_onoff
);

    assign dot_onoff = (msec < 50);
endmodule


//분초, 시간분 출력
module mux_2x1 (
    input sel,
    input [3:0] i_sel0,
    input [3:0] i_sel1,
    output [3:0] o_mux
);

    assign o_mux = (sel) ? i_sel1 : i_sel0;

endmodule

//1khz에서 동작하는 틱생성
module clk_div (
    input clk,
    input reset,
    output reg o_1khz  //출력
);

    reg [$clog2(100_000)-1:0] counter_r;  //reg [17:0] counter_r; 와 같은 말

    always @(posedge clk, posedge reset) begin
        if(reset)begin   //reset으로 초기화 하는 이유는 작동시키기 위래
            counter_r <= 0;
            o_1khz <= 1'b0;
        end else begin
            if (counter_r == 99999) begin
                counter_r <= 0;
                o_1khz <= 1'b1;
            end else begin
                counter_r <= counter_r + 1;
                o_1khz <= 1'b0;
            end
        end
    end

endmodule

//자리이동
module counter_8 (
    input clk,
    input reset,
    output [2:0] digit_sel
);

    reg [2:0] counter_r;  //4진 카운터를 만들기 위해 2비트
    assign digit_sel = counter_r;

    always @(posedge clk, posedge reset) begin
        if (reset) begin  //reset이 1이면 카운터를 0으로 초기화
            counter_r <= 0;  //always는 non_blocking
        end else begin
            counter_r <= counter_r + 1;  //즉 clk 신호에 맞춰 01->02->03->00 순서로 반복돠며 세그먼트 켜짐
        end
    end
endmodule


module decoder_2X4 (
    input [1:0] digit_sel,
    output reg [3:0] fnd_digit
);
    always @(*) begin
        case (digit_sel)
            2'b00: fnd_digit = 4'b1110;
            2'b01: fnd_digit = 4'b1101;
            2'b10: fnd_digit = 4'b1011;
            2'b11: fnd_digit = 4'b0111;
        endcase
    end
endmodule

//현재 출력할 자리 선택
module mux_8x1 (
    input [2:0] sel,

    input [3:0] digit_1,
    input [3:0] digit_10,
    input [3:0] digit_100,
    input [3:0] digit_1000,
    input [3:0] digit_dot_1,
    input [3:0] digit_dot_10,
    input [3:0] digit_dot_100,
    input [3:0] digit_dot_1000,
    output reg [3:0] mux_out  //always의 출력이니까 reg 사용
    //reg mux_out_o 와 wire mux_out = mux_out_o 은 같다
);


    always @(*) begin
        case (sel)
            3'b000: mux_out = digit_1;
            3'b001: mux_out = digit_10;
            3'b010: mux_out = digit_100;
            3'b011: mux_out = digit_1000;
            3'b100: mux_out = digit_dot_1;
            3'b101: mux_out = digit_dot_10;
            3'b110: mux_out = digit_dot_100;
            3'b111: mux_out = digit_dot_1000;
        endcase
    end
endmodule

//자리분리
module digit_splitter #(
    parameter BIT_WIDTH = 7
) (
    input [BIT_WIDTH-1:0] in_data,
    output [3:0] digit_1,
    output [3:0] digit_10

);

    assign digit_1  = in_data % 10;
    assign digit_10 = (in_data / 10) % 10;

endmodule

//7세그먼트 자리 출력
module bcd (
    input [3:0] bcd,
    output reg [7:0] fnd_data
);
    //always문의 출력은 항상 reg(저장)이다
    always @(bcd) begin    //bcd의 값에 변화가 있으면 begin~end를 절차적(순서)로 실행해라
        case (bcd)  //조건문 case들의 경우의 수 나열
            4'd0: fnd_data = 8'hc0;
            4'd1: fnd_data = 8'hf9;
            4'd2: fnd_data = 8'ha4;
            4'd3: fnd_data = 8'hb0;
            4'd4: fnd_data = 8'h99;
            4'd5: fnd_data = 8'h92;
            4'd6: fnd_data = 8'h82;
            4'd7: fnd_data = 8'hf8;
            4'd8: fnd_data = 8'h80;
            4'd9: fnd_data = 8'h90;
            4'd10: fnd_data = 8'hff;
            4'd11: fnd_data = 8'hff;
            4'd12: fnd_data = 8'hff;
            4'd13: fnd_data = 8'hff;  
            4'd14: fnd_data = 8'h7f;
            4'd15: fnd_data = 8'hff;
            default: fnd_data = 8'hff;
        endcase

    end
endmodule



