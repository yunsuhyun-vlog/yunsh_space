`timescale 1ns / 1ps

module sr04_top (
    input clk,
    input rst,
    input echo,
    input btn_r,
    output trigger,
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);
    wire [15:0] w_s_dist;
    wire w_s_tick;
    wire w_start;

    sr04_fnd_sr U_BD_FND (
        .clk(clk),
        .rst(rst),
        .s_dist(w_s_dist),     //거리 값 (cm)
        .fnd_disit(fnd_digit),  //자릿수(pnp)
        .fnd_data(fnd_data)   //숫자 모양
    );

    btn_debounce_sr U_BD_BTN_R (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_r),
        .o_btn(w_start)
    );


    tick_gen_sr U_BD_TICK (
        .clk(clk),
        .rst(rst),
        .s_tick(w_s_tick)
    );

    sr04_controller_sr U_BD_SR04CONTROLLER (
        .clk(clk),
        .rst(rst),
        .s_tick(w_s_tick),
        .start(w_start),
        .echo(echo),
        .trigger(trigger),
        .s_dist(w_s_dist)
    );

endmodule


module sr04_controller_sr (
    input clk,
    input rst,
    input s_tick,
    input start,
    input echo,
    output reg trigger,
    output [15:0] s_dist
);

    parameter F_COUNT = 400 * 58;
    parameter IDLE = 2'b00, START = 2'b01, WAIT = 2'b10, DISTANCE = 2'b11;

    reg [1:0] c_state, n_state;
    reg [3:0] trigger_cnt_c, trigger_cnt_n;
    reg [$clog2(F_COUNT)-1:0] echo_cnt_c, echo_cnt_n;
    reg [$clog2(F_COUNT)-1:0] buf_echo_cnt_c, buf_echo_cnt_n;
    reg [15:0] s_dist_c, s_dist_n;
    reg echo_reg;

    assign s_dist = s_dist_c;

    always @(posedge clk) begin
        echo_reg <= echo;
    end

    wire echo_negedge_flag = (echo_reg == 1 && echo == 0);


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            trigger_cnt_c <= 0;
            echo_cnt_c <= 0;
            s_dist_c <= 0;
            buf_echo_cnt_c <= 0;
        end else begin
            c_state <= n_state;
            trigger_cnt_c <= trigger_cnt_n;
            echo_cnt_c <= echo_cnt_n;
            s_dist_c <= s_dist_n;
            buf_echo_cnt_c <= buf_echo_cnt_n;
        end
    end

    always @(*) begin
        n_state = c_state;
        trigger_cnt_n = trigger_cnt_c;
        echo_cnt_n = echo_cnt_c;
        s_dist_n = s_dist_c;
        buf_echo_cnt_n = buf_echo_cnt_c;
        trigger = 0;
        case (c_state)
            IDLE: begin
                trigger_cnt_n = 0;
                echo_cnt_n = 0;
                // s_dist_n = 0;
                buf_echo_cnt_n = 0;
                if (start == 1) begin
                    n_state = START;
                end
            end
            START: begin
                trigger = 1'b1;
                if (s_tick == 1) begin
                    if (trigger_cnt_c == 13) begin
                        n_state = WAIT;
                        trigger_cnt_n = 0;
                    end else begin
                        trigger_cnt_n = trigger_cnt_c + 1;
                    end
                end
            end
            WAIT: begin
                if (echo == 1) begin
                    if (s_tick) begin
                        echo_cnt_n = echo_cnt_c + 1;
                    end
                end else if (echo_negedge_flag) begin
                    buf_echo_cnt_n = echo_cnt_c;
                    n_state = DISTANCE;
                end
            end
            DISTANCE: begin
                if (s_tick) begin
                    s_dist_n = buf_echo_cnt_c/58; //나누기는 슬랙타임 계산 필수
                    n_state = IDLE;
                end
            end
            default: n_state = IDLE;
        endcase
    end


endmodule


//need 1us_tick
module tick_gen_sr (
    input clk,
    input rst,
    output reg s_tick
);

    reg [$clog2(100)-1:0] tick_cnt;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            tick_cnt <= 0;
            s_tick   <= 0;
        end else begin
            if (tick_cnt == 99) begin
                s_tick   <= 1;
                tick_cnt <= 0;
            end else begin
                tick_cnt <= tick_cnt + 1;
                s_tick   <= 0;
            end
        end
    end

endmodule


module sr04_fnd_sr (
    input clk,
    input rst,
    input [15:0]s_dist,     //거리 값 (cm)
    output [3:0]fnd_disit,  //자릿수(pnp)
    output [7:0]fnd_data   //숫자 모양
);
    // 내부 연결을 위한 전선(Wire) 선언
    wire [1:0] w_scan_sel;  // 카운터에서 나온 순서 신호 (00, 01, 10, 11)
    wire [3:0] w_bcd_num;  // MUX에서 선택된 한 자리 숫자 (0~9)
    wire w_1khz;            // (선택사항) 1khz 틱 신호, 여기선 연결 안 해도 됨

    // 1. 타이밍 생성 모듈 (순서 00->01->10->11 생성)
    tick_counter U_TICK (
        .clk        (clk),
        .reset      (rst),
        .o_1khz     (w_1khz),     // 안 쓰면 비워둬도 됨
        .out_counter(w_scan_sel)  // [중요] 이 신호가 지휘자 역할
    );

    // 2. 자릿수 분리 및 선택 (MUX)
    splitter_mux U_SPLITTER (
        .s_dist(s_dist),
        .sel(w_scan_sel),     // 지휘자의 신호에 따라
        .mux_out(w_bcd_num)   // 해당 자릿수의 숫자 하나를 꺼냄
    );

    // 3. 자릿수 켜기 (Digit Decoder)
    bcd_fnd_digit U_DIGIT_DEC (
        .digit_sel(w_scan_sel),  // 지휘자의 신호에 따라
        .fnd_digit(fnd_disit)    // 실제 FND 자리를 켬 (출력 연결)
    );

    // 4. 숫자 모양 만들기 (Segment Decoder)
    bcd_fnd_data U_DATA_DEC (
        .bcd     (w_bcd_num),  // 골라진 숫자를 받아서
        .fnd_data(fnd_data)    // FND 모양으로 변환 (출력 연결)
    );


endmodule

//자릿수 분리해서 나갈 자릿수 선택
module splitter_mux_sr (
    input [15:0] s_dist,
    input [1:0] sel,
    output reg [3:0] mux_out
);

    // 1. [중요] 내부에서 쓸 신호(wire)를 먼저 선언해야 함
    wire [3:0] digit_1;
    wire [3:0] digit_10;
    wire [3:0] digit_100;
    wire [3:0] digit_1000;

    assign digit_1    = s_dist % 10;
    assign digit_10   = (s_dist / 10) % 10;
    assign digit_100  = (s_dist / 100) % 10;
    assign digit_1000 = (s_dist / 1000) % 10;

    always @(*) begin
        case (sel)
            2'b00:   mux_out = digit_1;
            2'b01:   mux_out = digit_10;
            2'b10:   mux_out = digit_100;
            2'b11:   mux_out = digit_1000;
            default: mux_out = 4'd0;
        endcase
    end

endmodule

//나갈 타이밍(o_1khz)을 생성하고 나갈 순서 생성
module tick_counter_sr (
    input clk,
    input reset,
    output reg o_1khz,
    output reg [1:0] out_counter
);
    reg [16:0] counter_r;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_r <= 0;
            o_1khz <= 0;
            out_counter <= 0;
        end else begin
            if (counter_r == 99999) begin
                counter_r <= 0;
                o_1khz <= 1'b1;
                out_counter <= out_counter + 1;
            end else begin
                counter_r <= counter_r + 1;
                o_1khz <= 1'b0;
                //out_counter <= 0; 값을 유지해야 하므로 
            end
        end
    end
endmodule

//나갈 모양 만들기
module bcd_fnd_data_sr (
    input [3:0] bcd,
    output reg [7:0] fnd_data
);
    always @(*) begin
        case (bcd)
            4'h0: fnd_data = 8'hc0;
            4'h1: fnd_data = 8'hf9;
            4'h2: fnd_data = 8'ha4;
            4'h3: fnd_data = 8'hb0;
            4'h4: fnd_data = 8'h99;
            4'h5: fnd_data = 8'h92;
            4'h6: fnd_data = 8'h82;
            4'h7: fnd_data = 8'hf8;
            4'h8: fnd_data = 8'h80;
            4'h9: fnd_data = 8'h90;
            default: fnd_data = 8'hff;  // off
        endcase
    end
endmodule

//나갈 자리 켜기(pnp)
module bcd_fnd_digit_sr (
    input [1:0] digit_sel,
    output reg [3:0] fnd_digit
);

    always @(*) begin
        case (digit_sel)
            2'b00:   fnd_digit = 4'b1110;
            2'b01:   fnd_digit = 4'b1101;
            2'b10:   fnd_digit = 4'b1011;
            2'b11:   fnd_digit = 4'b0111;
            default: fnd_digit = 4'b1111;
        endcase
    end
endmodule

