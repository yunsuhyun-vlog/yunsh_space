
`timescale 1ns / 1ps

module fnd_controller (
    input clk,
    input reset,
    input sel_display,  // stopwatch hour/min vs sec/msec
    input [1:0] mux_sel,  // 00:스톱워치, 01:초음파, 10:온습도
    input [23:0] fnd_in_data_stopwatch,
    input [15:0] in_data_sr,
    input [15:0] in_data_dht,
    output [3:0] fnd_digit,
    output [7:0] fnd_data,
    output reg [15:0] o_bcd_16bit  // ASCII Sender로 보낼 통합 BCD 데이터
);

    wire w_1khz;
    wire [1:0] w_scan_sel;  // 4진 카운터 스캔 신호

    // --- 1. 4진 타이밍 카운터 인스턴스 ---
    tick_1khz_sel U_TICK_SCAN (
        .clk(clk),
        .rst(reset),
        .o_1khz(w_1khz),
        .counter(w_scan_sel)
    );

    // --- 2. 초음파 센서 (SR40) 스플리터 ---
    wire [3:0] w_sr_digit;
    wire [15:0] w_sr_bcd_16;
    digit_spliter_mux_sr40 U_SR_SPLIT (
        .in_data(in_data_sr),
        .sel(w_scan_sel),
        .out_data(w_sr_digit),
        .out_bcd_16(w_sr_bcd_16)
    );

    // --- 3. 온습도 센서 (DHT11) 스플리터 ---
    wire [3:0] w_dht_digit;
    wire w_dht_dp;
    wire [15:0] w_dht_bcd_16;
    digit_spliter_mux_dht0 U_DHT_SPLIT (
        .in_data(in_data_dht),
        .sel(w_scan_sel),
        .dp(w_dht_dp),
        .out_data(w_dht_digit),
        .out_bcd_16(w_dht_bcd_16)
    );

    // --- 4. 스톱워치 데이터 분리 및 MUX 로직 ---
    wire [3:0] w_digit_msec_1, w_digit_msec_10;
    wire [3:0] w_digit_sec_1, w_digit_sec_10;
    wire [3:0] w_digit_min_1, w_digit_min_10;
    wire [3:0] w_digit_hour_1, w_digit_hour_10;
    wire w_dot_onoff;

    digit_spliter_10 #(
        .BIT_WIDTH(5)
    ) hour_splitter (
        .in_data (fnd_in_data_stopwatch[23:19]),
        .digit_1 (w_digit_hour_1),
        .digit_10(w_digit_hour_10)
    );
    digit_spliter_10 #(
        .BIT_WIDTH(6)
    ) min_splitter (
        .in_data (fnd_in_data_stopwatch[18:13]),
        .digit_1 (w_digit_min_1),
        .digit_10(w_digit_min_10)
    );
    digit_spliter_10 #(
        .BIT_WIDTH(6)
    ) sec_splitter (
        .in_data (fnd_in_data_stopwatch[12:7]),
        .digit_1 (w_digit_sec_1),
        .digit_10(w_digit_sec_10)
    );
    digit_spliter_10 #(
        .BIT_WIDTH(7)
    ) msec_splitter (
        .in_data (fnd_in_data_stopwatch[6:0]),
        .digit_1 (w_digit_msec_1),
        .digit_10(w_digit_msec_10)
    );
    dot_onoff_comp u_dot_comp (
        .msec(fnd_in_data_stopwatch[6:0]),
        .dot_onoff(w_dot_onoff)
    );

    wire [3:0] w_sw_digit;
    wire w_sw_dp;
    wire [3:0] w_final_digit;
    wire w_final_dp;

    // --- 4. 스톱워치 데이터 분리 및 MUX 로직 (하위 모듈로 대체) ---
    mux_stopwatch_digit U_MUX_SW (
        .sel_display(sel_display),
        .scan_sel(w_scan_sel),
        .digit_hour_10(w_digit_hour_10),
        .digit_hour_1(w_digit_hour_1),
        .digit_min_10(w_digit_min_10),
        .digit_min_1(w_digit_min_1),
        .digit_sec_10(w_digit_sec_10),
        .digit_sec_1(w_digit_sec_1),
        .digit_msec_10(w_digit_msec_10),
        .digit_msec_1(w_digit_msec_1),
        .dot_onoff(w_dot_onoff),
        .sw_digit(w_sw_digit),
        .sw_dp(w_sw_dp)
    );

    // --- 5. 통합 MUX (하위 모듈로 대체) ---
    mux_final_fnd U_MUX_FINAL (
        .mux_sel    (mux_sel),
        .sw_digit   (w_sw_digit),
        .sw_dp      (w_sw_dp),
        .sr_digit   (w_sr_digit),     // SR40 스플리터에서 나온 wire
        .dht_digit  (w_dht_digit),    // DHT11 스플리터에서 나온 wire
        .dht_dp     (w_dht_dp),       // DHT11 스플리터에서 나온 wire
        .final_digit(w_final_digit),
        .final_dp   (w_final_dp)
    );

    // --- 6. 최종 출력 ---
    bcd_dp U_BCD_DP (
        .bcd     (w_final_digit),  // 변경됨
        .dp      (w_final_dp),     // 변경됨
        .fnd_data(fnd_data)
    );

    decoder_2X4 U_DEC_DIGIT (
        .digit_sel(w_scan_sel),
        .fnd_digit(fnd_digit)
    );

    always @(*) begin
        case (mux_sel)
            2'b00: begin // 스톱워치
                if (sel_display) 
                    o_bcd_16bit = {w_digit_hour_10, w_digit_hour_1, w_digit_min_10, w_digit_min_1};
                else 
                    o_bcd_16bit = {w_digit_min_10, w_digit_min_1, w_digit_sec_10, w_digit_sec_1};
            end
            2'b01: o_bcd_16bit = w_sr_bcd_16;   // 초음파
            2'b10: o_bcd_16bit = w_dht_bcd_16;  // 온습도
            default: o_bcd_16bit = 16'd0;
        endcase
    end

endmodule

// 1. 스톱워치 전용 자릿수 및 소수점 선택 MUX
module mux_stopwatch_digit (
    input sel_display,
    input [1:0] scan_sel,
    input [3:0] digit_hour_10,
    digit_hour_1,
    input [3:0] digit_min_10,
    digit_min_1,
    input [3:0] digit_sec_10,
    digit_sec_1,
    input [3:0] digit_msec_10,
    digit_msec_1,
    input dot_onoff,
    output reg [3:0] sw_digit,
    output sw_dp
);
    always @(*) begin
        if (sel_display == 1'b1) begin  // Hour/Min 모드
            case (scan_sel)
                2'b00: sw_digit = digit_min_1;
                2'b01: sw_digit = digit_min_10;
                2'b10: sw_digit = digit_hour_1;
                2'b11: sw_digit = digit_hour_10;
            endcase
        end else begin  // Sec/Msec 모드
            case (scan_sel)
                2'b00: sw_digit = digit_msec_1;
                2'b01: sw_digit = digit_msec_10;
                2'b10: sw_digit = digit_sec_1;
                2'b11: sw_digit = digit_sec_10;
            endcase
        end
    end

    // 100의 자리(2'b10)에서만 DP 점멸
    assign sw_dp = (scan_sel == 2'b10) ? dot_onoff : 1'b0;
endmodule

// 2. 최종 FND 출력 데이터 선택 MUX
module mux_final_fnd (
    input [1:0] mux_sel,
    input [3:0] sw_digit,
    input sw_dp,
    input [3:0] sr_digit,
    input [3:0] dht_digit,
    input dht_dp,
    output reg [3:0] final_digit,
    output reg final_dp
);
    always @(*) begin
        case (mux_sel)
            2'b00: begin  // 스톱워치
                final_digit = sw_digit;
                final_dp = sw_dp;
            end
            2'b01: begin  // 초음파 센서
                final_digit = sr_digit;
                final_dp = 1'b0;
            end
            2'b10: begin  // 온습도 센서
                final_digit = dht_digit;
                final_dp = dht_dp;
            end
            default: begin
                final_digit = 4'd0;
                final_dp = 1'b0;
            end
        endcase
    end
endmodule

module dot_onoff_comp (

    input [6:0] msec,
    output dot_onoff
);

    assign dot_onoff = (msec < 50);
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



module digit_spliter_10 #(
    parameter BIT_WIDTH = 7
) (
    input [BIT_WIDTH-1:0] in_data,
    output [3:0] digit_1,
    output [3:0] digit_10

);

    assign digit_1  = in_data % 10;
    assign digit_10 = (in_data / 10) % 10;

endmodule

module digit_spliter_mux_sr40 (
    input [15:0] in_data,
    input [1:0] sel,
    output reg [3:0] out_data,
    output [15:0] out_bcd_16//add
);

    wire [3:0] digit_1;
    wire [3:0] digit_10;
    wire [3:0] digit_100;
    wire [3:0] digit_1000;

    assign digit_1 = in_data % 10;
    assign digit_10 = (in_data / 10) % 10;
    assign digit_100 = (in_data / 100) % 10;
    assign digit_1000 = (in_data / 1000) % 10;

    assign out_bcd_16 = {digit_1000, digit_100, digit_10, digit_1};

    always @(*) begin
        case (sel)
            2'b00:   out_data = digit_1;
            2'b01:   out_data = digit_10;
            2'b10:   out_data = digit_100;
            2'b11:   out_data = digit_1000;
            default: out_data = 4'd0;
        endcase
    end
endmodule


module digit_spliter_mux_dht0 (
    input [15:0] in_data,
    input [1:0] sel,
    output reg dp,
    output reg [3:0] out_data
);

    wire [7:0] int_part = in_data[15:8];
    wire [7:0] dec_part = in_data[7:0];
//out_bcd_16
    assign out_bcd_16 = { (int_part/10)%10, int_part%10, (dec_part/10)%10, dec_part%10 };

    always @(*) begin
        case (sel)
            2'b00: begin
                out_data = dec_part % 10;
                dp = 0;
            end
            2'b01: begin
                out_data = (dec_part / 10) % 10;
                dp = 0;
            end
            2'b10: begin
                out_data = int_part % 10;
                dp = 1;
            end
            2'b11: begin
                out_data = (int_part / 10) % 10;
                dp = 0;
            end
            default: begin
                out_data = 4'd0;
                dp = 0;
            end

        endcase
    end
endmodule


module tick_1khz_sel (
    input clk,
    input rst,
    output reg o_1khz,
    output reg [1:0] counter
);

    reg [$clog2(100000-1):0] counter_r;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_r <= 0;
            o_1khz <= 0;
            counter <= 0;
        end else begin
            if (counter_r == 99999) begin
                counter_r <= 0;
                o_1khz <= 1;
                counter <= counter + 1;
            end else begin
                counter_r <= counter_r + 1;
                o_1khz <= 0;
                //counter <= 0; tick처럼 나가면 안됨
            end
        end
    end
endmodule

module bcd_dp (
    input [3:0] bcd,
    input dp,
    output reg [7:0] fnd_data
);
    //always문의 출력은 항상 reg(저장)이다
    always @(*) begin    //bcd의 값에 변화가 있으면 begin~end를 절차적(순서)로 실행해라
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
            default: fnd_data = 8'hff;
        endcase

        if (dp == 1) begin
            fnd_data = fnd_data & 8'b0111_1111;
        end else begin
            fnd_data = fnd_data;
        end

    end
endmodule


// module bcd (
//     input [3:0] bcd,
//     output reg [7:0] fnd_data
// );
//     //always문의 출력은 항상 reg(저장)이다
//     always @(bcd) begin    //bcd의 값에 변화가 있으면 begin~end를 절차적(순서)로 실행해라
//         case (bcd)  //조건문 case들의 경우의 수 나열
//             4'd0: fnd_data = 8'hc0;
//             4'd1: fnd_data = 8'hf9;
//             4'd2: fnd_data = 8'ha4;
//             4'd3: fnd_data = 8'hb0;
//             4'd4: fnd_data = 8'h99;
//             4'd5: fnd_data = 8'h92;
//             4'd6: fnd_data = 8'h82;
//             4'd7: fnd_data = 8'hf8;
//             4'd8: fnd_data = 8'h80;
//             4'd9: fnd_data = 8'h90;
//             4'd10: fnd_data = 8'hff;
//             4'd11: fnd_data = 8'hff;
//             4'd12: fnd_data = 8'hff;
//             4'd13: fnd_data = 8'hff;
//             4'd14: fnd_data = 8'h7f;
//             4'd15: fnd_data = 8'hff;
//             default: fnd_data = 8'hff;
//         endcase

//     end
// endmodule



// module mux_2x1 (
//     input sel,
//     input [3:0] i_sel0,
//     input [3:0] i_sel1,
//     output [3:0] o_mux
// );

//     assign o_mux = (sel) ? i_sel1 : i_sel0;

// endmodule

// module clk_div (
//     input clk,
//     input reset,
//     output reg o_1khz  //출력
// );

//     reg [$clog2(100_000)-1:0] counter_r;  //reg [17:0] counter_r; 와 같은 말

//     always @(posedge clk, posedge reset) begin
//         if(reset)begin   //reset으로 초기화 하는 이유는 작동시키기 위래
//             counter_r <= 0;
//             o_1khz <= 1'b0;
//         end else begin
//             if (counter_r == 99999) begin
//                 counter_r <= 0;
//                 o_1khz <= 1'b1;
//             end else begin
//                 counter_r <= counter_r + 1;
//                 o_1khz <= 1'b0;
//             end
//         end
//     end

// endmodule


// module counter_8 (
//     input clk,
//     input reset,
//     output [2:0] digit_sel
// );

//     reg [2:0] counter_r;  //8진 카운터를 만들기 위해 2비트
//     assign digit_sel = counter_r;

//     always @(posedge clk, posedge reset) begin
//         if (reset) begin  //reset이 1이면 카운터를 0으로 초기화
//             counter_r <= 0;  //always는 non_blocking
//         end else begin
//             counter_r <= counter_r + 1;  //즉 clk 신호에 맞춰 01->02->03->00 순서로 반복돠며 세그먼트 켜짐
//         end
//     end
// endmodule

// module mux_8x1 (
//     input [2:0] sel,

//     input [3:0] digit_1,
//     input [3:0] digit_10,
//     input [3:0] digit_100,
//     input [3:0] digit_1000,
//     input [3:0] digit_dot_1,
//     input [3:0] digit_dot_10,
//     input [3:0] digit_dot_100,
//     input [3:0] digit_dot_1000,
//     output reg [3:0] mux_out  //always의 출력이니까 reg 사용
//     //reg mux_out_o 와 wire mux_out = mux_out_o 은 같다
// );


//     always @(*) begin
//         case (sel)
//             3'b000: mux_out = digit_1;
//             3'b001: mux_out = digit_10;
//             3'b010: mux_out = digit_100;
//             3'b011: mux_out = digit_1000;
//             3'b100: mux_out = digit_dot_1;
//             3'b101: mux_out = digit_dot_10;
//             3'b110: mux_out = digit_dot_100;
//             3'b111: mux_out = digit_dot_1000;
//         endcase
//     end
// endmodule
