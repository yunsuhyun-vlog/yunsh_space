
`timescale 1ns / 1ps

module top_dht11(
    input clk,
    input rst,
    input btn_r,           
    input [3:0] sw,    
    inout dhtio,           
    output [7:0] fnd_data,
    output [3:0] fnd_digit,
    output [2:0] led       // 디버그(상태) 확인용 3비트 LED 출력 포트
);

    wire [15:0] w_humidity;
    wire [15:0] w_temperature;
    wire [15:0] w_display_data;
    
    wire w_dht11_done;
    wire w_dht11_valid;

    wire w_btn_r;

    // 스위치 3번(sw[3])의 상태에 따라 온/습도 데이터 선택
    assign w_display_data = (sw[3] == 1'b1) ? w_humidity : w_temperature;

    btn_debounce_dht11 U_DHT11_BTN_D (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_r),
        .o_btn(w_btn_r)
    );


    dht11_controller U_DHT11_CTRL (
        .clk        (clk),
        .rst        (rst),
        .start      (w_btn_r),           
        .humidity   (w_humidity),      
        .temperature(w_temperature),   
        .dht11_done (w_dht11_done),
        .dht11_valid(w_dht11_valid),
        .debug      (led),             // [수정됨] 내부 debug 출력을 Top 모듈의 led 포트로 바로 연결
        .dhtio      (dhtio)            
    );

    dht11_fnd U_DHT11_FND (
        .clk         (clk),
        .rst         (rst),
        .display_data(w_display_data), 
        .fnd_digit   (fnd_digit),
        .fnd_data    (fnd_data)
    );

endmodule

module dht11_controller (
    input clk,
    input rst,
    input start,
    output [15:0] humidity,  //습도
    output [15:0] temperature,  //온도
    output dht11_done,  //40비트 받음
    output dht11_valid,  //checksum과 모두 더한 값이 같은지 확인
    output [2:0] debug,  //상태를 알고싶을 때
    inout dhtio
);

    wire tick_10u;

    tick_gen_10u U_TICK_10U (
        .clk(clk),
        .rst(rst),
        .tick_10u(tick_10u)
    );

    ila_0 U_ILA0 (
        .clk   (clk),
        .probe0(dhtio),  //1bit
        .probe1(debug)   //3bit
    );

    parameter IDLE = 0, START = 1, WAIT =2, SYNC_L =3,  SYNC_H =4, DATA_SYNC =5, DATA_C=6 , STOP=7;
    reg [2:0] c_state, n_state;
    reg dhtio_reg, dhtio_next;
    reg io_sel_reg, io_sel_next;
    reg [5:0] bit_cnt_reg, bit_cnt_next;
    reg [39:0] buf_40bit_reg, buf_40bit_next;
    reg dht11_done_reg, dht11_done_next;
    reg dht11_valid_reg, dht11_valid_next;

    //syncronizer

    reg dhtio_sync1, dhtio_sync2;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            dhtio_sync1 <= 1;
            dhtio_sync2 <= 1;
        end else begin
            dhtio_sync1 <= dhtio;
            dhtio_sync2 <= dhtio_sync1;
        end
    end

    assign dht11_done = dht11_done_reg;
    assign dht11_valid = dht11_valid_reg;
    //assign humidity = buf_40bit_reg[39:24];
    // assign temperature = buf_40bit_reg[23:8];

   // 출력 포트를 지속적으로 유지하기 위한 레지스터 선언
    reg [15:0] humidity_reg;
    reg [15:0] temperature_reg;
    
    assign humidity = humidity_reg;
    assign temperature = temperature_reg;
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            humidity_reg <= 0;
            temperature_reg <= 0;
        end else if (c_state == STOP && tick_10u) begin
            if ( (((buf_40bit_reg[39:32] + buf_40bit_reg[31:24] + buf_40bit_reg[23:16] + buf_40bit_reg[15:8]) & 8'hff) == buf_40bit_reg[7:0]) ) begin
                humidity_reg <= buf_40bit_reg[39:24];
                temperature_reg <= buf_40bit_reg[23:8];
            end
        end
    end

    // 수신이 완전히 종료(STOP)되고, 체크섬이 일치(Valid)할 때만 디스플레이 값 업데이트

    //for 19msec count by 10usec tick
    reg [$clog2(1900)-1:0] tick_cnt_reg, tick_cnt_next;

    assign dhtio = (io_sel_reg) ? dhtio_reg : 1'bz;  //1이면 출력, 0이면 입력 high_z면 끊어진 상태 방향설정
    assign debug = c_state;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= 0;
            dhtio_reg       <= 1;
            tick_cnt_reg    <= 0;
            io_sel_reg      <= 1;
            buf_40bit_reg   <= 0;
            bit_cnt_reg     <= 0;
            dht11_done_reg  <= 0;
            dht11_valid_reg <= 0;
        end else begin
            c_state         <= n_state;
            dhtio_reg       <= dhtio_next;
            tick_cnt_reg    <= tick_cnt_next;
            io_sel_reg      <= io_sel_next;
            buf_40bit_reg   <= buf_40bit_next;
            bit_cnt_reg     <= bit_cnt_next;
            dht11_done_reg  <= dht11_done_next;
            dht11_valid_reg <= dht11_valid_next;
        end
    end

    always @(*) begin
        n_state          = c_state;
        tick_cnt_next    = tick_cnt_reg;
        dhtio_next       = dhtio_reg;
        io_sel_next      = io_sel_reg;
        bit_cnt_next     = bit_cnt_reg;
        buf_40bit_next   = buf_40bit_reg;
        dht11_done_next  = dht11_done_reg;
        dht11_valid_next = dht11_valid_reg;
        case (c_state)
            IDLE: begin
                dht11_valid_next = 0;
                if (start) begin
                    n_state = START;
                end
            end
            START: begin
                dhtio_next = 1'b0;
                if (tick_10u) begin
                    tick_cnt_next = tick_cnt_reg + 1;  //1800까지 세면 됨 
                    if (tick_cnt_reg == 1900) begin
                        tick_cnt_next = 0;
                        n_state = WAIT;
                    end
                end
            end
            WAIT: begin
                //dhtio_next  = 1;
                io_sel_next = 1'b0;
                if (tick_10u) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 3) begin
                        //for output to hifh_z
                        n_state = SYNC_L;
                        tick_cnt_next = 0;
                    end
                end
            end
            SYNC_L: begin
                if (tick_10u) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (dhtio_sync2 == 1) begin
                        n_state = SYNC_H;
                        tick_cnt_next = 0;
                    end
                end
            end
            SYNC_H: begin
                if (tick_10u) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (dhtio_sync2 == 0) begin
                        tick_cnt_next = 0;
                        n_state = DATA_SYNC;  //50us를 보장하는 것이 아니기 때문에 위험성이 있을 수 이을 수 있음
                    end
                end
            end
            DATA_SYNC: begin
                if (tick_10u) begin
                    if (dhtio_sync2 == 1) begin
                        n_state = DATA_C;
                    end
                end
            end
            DATA_C: begin
                if (tick_10u) begin //if문은 가장 바깥쪽에서부터 풀어져 나감
                    if (dhtio_sync2 == 1) begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end else begin
                        if (tick_cnt_reg < 5) begin
                            buf_40bit_next = {buf_40bit_reg[38:0], 1'b0};
                            tick_cnt_next  = 0;
                            bit_cnt_next   = bit_cnt_reg + 1;
                            if (bit_cnt_reg == 39) begin
                                bit_cnt_next = 0;
                                n_state = STOP;
                            end else begin
                                n_state = DATA_SYNC;
                            end
                        end else begin
                            buf_40bit_next = {buf_40bit_reg[38:0], 1'b1};
                            tick_cnt_next  = 0;
                            bit_cnt_next   = bit_cnt_reg + 1;
                            if (bit_cnt_reg == 39) begin
                                bit_cnt_next = 0;
                                n_state = STOP;
                            end else begin
                                n_state = DATA_SYNC;
                            end
                        end
                    end
                end
            end

            STOP: begin
                if (tick_10u) begin
                    dht11_valid_next = (
                    ((buf_40bit_reg[39:32] + buf_40bit_reg[31:24] + buf_40bit_reg [23:16] + buf_40bit_reg [15:8]) & 8'hff) == buf_40bit_reg [7:0]
                    ) ? 1'b1 : 1'b0;
                    dht11_done_next = 1;
                    if (tick_cnt_reg == 5) begin
                        //output mode
                        io_sel_next = 1'b1;
                        dhtio_next = 1'b1;
                        dht11_done_next = 0;
                        tick_cnt_next =0;
                        n_state = IDLE;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end

        endcase
    end
endmodule

module tick_gen_10u (
    input clk,
    input rst,
    output reg tick_10u
);

    parameter F_COUNT = 100_000_000 / 100_000;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            tick_10u <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                tick_10u <= 1'b1;
            end else begin
                tick_10u <= 0;
            end
        end
    end
endmodule

module dht11_fnd (
    input clk,
    input rst,
    input [15:0] display_data,  //습도 or 온도
    output [3:0] fnd_digit,  //자릿수(pnp)
    output [7:0] fnd_data  //숫자 모양
);
    wire [1:0] w_scan_sel;
    wire [3:0] w_bcd_num;
    wire w_dp;  // 소수점(DP) 제어 신호 추가

    tick_counter U_TICK (
        .clk        (clk),
        .reset      (rst),
        .o_1khz     (),
        .out_counter(w_scan_sel)
    );

    splitter_mux U_SPLITTER (
        .display_data(display_data),
        .sel         (w_scan_sel),
        .mux_out     (w_bcd_num),
        .dp_out      (w_dp)           // 소수점 활성화 신호 출력
    );

    bcd_fnd_digit U_DIGIT_DEC (
        .digit_sel(w_scan_sel),
        .fnd_digit(fnd_digit)
    );

    bcd_fnd_data U_DATA_DEC (
        .bcd     (w_bcd_num),
        .dp      (w_dp),       // 소수점 활성화 신호 입력
        .fnd_data(fnd_data)
    );

endmodule


//자릿수 분리해서 나갈 자릿수 선택
module splitter_mux (
    input [15:0] display_data,
    input [1:0] sel,
    output reg [3:0] mux_out,
    output reg dp_out  // 소수점 출력 포트 추가
);

    // DHT11 데이터 구조에 맞게 상위 8비트(정수)와 하위 8비트(소수) 분리
    wire [7:0] int_part = display_data[15:8];
    wire [7:0] dec_part = display_data[7:0];

    wire [3:0] digit_1;
    wire [3:0] digit_10;
    wire [3:0] digit_100;
    wire [3:0] digit_1000;

    // 8비트 단위로 나눗셈 연산 수행 (합성 부담 감소)
    assign digit_1000 = int_part / 10;  // 정수부 십의 자리
    assign digit_100  = int_part % 10; // 정수부 일의 자리 (여기에 소수점을 찍음)
    assign digit_10   = dec_part / 10; // 소수부 십의 자리 (소수 첫째 자리)
    assign digit_1    = dec_part % 10; // 소수부 일의 자리 (소수 둘째 자리)

    always @(*) begin
        case (sel)
            2'b00: begin
                mux_out = digit_1;
                dp_out  = 1'b0;
            end
            2'b01: begin
                mux_out = digit_10;
                dp_out  = 1'b0;
            end
            2'b10: begin
                mux_out = digit_100;
                dp_out  = 1'b1;
            end  // 100의 자리(정수부 일의 자리) 출력 시 소수점 ON
            2'b11: begin
                mux_out = digit_1000;
                dp_out  = 1'b0;
            end
            default: begin
                mux_out = 4'd0;
                dp_out  = 1'b0;
            end
        endcase
    end

endmodule

//나갈 타이밍(o_1khz)을 생성하고 나갈 순서 생성
module tick_counter (
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
module bcd_fnd_data (
    input [3:0] bcd,
    input dp,  // 소수점 입력 포트 추가
    output reg [7:0] fnd_data
);
    reg [7:0] seg_data;

    always @(*) begin
        case (bcd)
            4'h0: seg_data = 8'hc0;
            4'h1: seg_data = 8'hf9;
            4'h2: seg_data = 8'ha4;
            4'h3: seg_data = 8'hb0;
            4'h4: seg_data = 8'h99;
            4'h5: seg_data = 8'h92;
            4'h6: seg_data = 8'h82;
            4'h7: seg_data = 8'hf8;
            4'h8: seg_data = 8'h80;
            4'h9: seg_data = 8'h90;
            default: seg_data = 8'hff;  // off
        endcase

        // Active Low 방식이므로, dp가 1일 때 기존 값에서 최상위 비트를 0으로 만듦 (& 8'h7F)
        if (dp) begin
            fnd_data = seg_data & 8'h7F;
        end else begin
            fnd_data = seg_data;
        end
    end
endmodule

//나갈 자리 켜기(pnp)
module bcd_fnd_digit (
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

module btn_debounce_dht11 (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);

    // clock divider for debounce shift register
    // 100Mhz -> 100Khz
    // count 1000
    parameter CLK_DIV = 100_000;  // 100K
    parameter F_COUNT = 100_000_000 / CLK_DIV;  // 1000
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    reg clk_100khz_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            clk_100khz_reg <= 0;
        end else begin
            counter_reg <= counter_reg + 1'b1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                clk_100khz_reg <= 1'b1;
            end else begin
                clk_100khz_reg <= 1'b0;
            end
        end
    end

    // series 8 tab F/F (8bit Shift Register)
    reg [7:0] debounce_reg;
    wire w_debounce;

    // SL
    always @(posedge clk_100khz_reg, posedge reset) begin
        if (reset) begin
            debounce_reg <= 0;
        end else begin
            // Sequential In
            // Bit Shift
            debounce_reg <= {i_btn, debounce_reg[7:1]};
        end
    end

    // debounce, 8 input AND
    assign w_debounce = &debounce_reg;

    reg edge_reg;
    // edge detection
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            edge_reg <= 0;
        end else begin
            edge_reg <= w_debounce;
        end
    end
    assign o_btn = w_debounce & (~edge_reg);

endmodule
