
`timescale 1ns / 1ps

module top_stopwatch (  //내꺼
    input clk,
    input reset,
    input  [2:0] sw,         // sw[0]:stopwatch down/up mode, sw[1]:watch/stopwatch select, sw[2]:hour min/sec msec
    input btn_r,  // (sec/run_stop)
    input btn_l,  // (hour/clear)
    input btn_u,  //(min)
    input btn_d,
    input [3:0] uart_btn,
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);

    wire o_btn_l, o_btn_u, o_btn_r, o_btn_d;  //디바운스된 버튼 신호
    wire w_run_stop, w_clear, w_mode;  //control_unit -> stopwatch datapath
    wire w_sw_run_stop, w_sw_clear;  //stopwatch용 입력
    wire w_wa_btn_h, w_wa_btn_m, w_wa_btn_s;  //watch용 입력
    wire [23:0] w_stopwatch_time, w_watch_time, w_fnd_input;

    btn_debounce U_BD_L (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_l),
        .o_btn(o_btn_l)
    );

    btn_debounce U_BD_U (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_u),
        .o_btn(o_btn_u)
    );

    btn_debounce U_BD_R (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_r),
        .o_btn(o_btn_r)
    );

    btn_debounce U_BD_D (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_d),
        .o_btn(o_btn_d)
    );

    assign w_sw_run_stop = (sw[1] == 1'b0) ? (o_btn_r | uart_btn[0]) : 1'b0;
    assign w_sw_clear = (sw[1] == 1'b0) ? (o_btn_l | uart_btn[1]) : 1'b0;
    assign w_wa_btn_h = (sw[1] == 1'b1) ? (o_btn_l | uart_btn[1]): 1'b0;
    assign w_wa_btn_m = (sw[1] == 1'b1) ? (o_btn_u | uart_btn[2]) : 1'b0;
    assign w_wa_btn_s = (sw[1] == 1'b1) ? (o_btn_r | uart_btn[0]) : 1'b0;


    control_unit U_CONTROL_UNIT (
        .clk(clk),
        .reset(reset),
        .i_mode(sw[0]),
        .i_run_stop(w_sw_run_stop),
        .i_clear(w_sw_clear),
        .o_mode(w_mode),
        .o_run_stop(w_run_stop),
        .o_clear(w_clear)
    );
    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk     (clk),
        .reset   (reset),
        .mode    (w_mode),
        .clear   (w_clear),
        .run_stop(w_run_stop),
        .msec    (w_stopwatch_time[6:0]),    //7bit
        .sec     (w_stopwatch_time[12:7]),   //6
        .min     (w_stopwatch_time[18:13]),  //6
        .hour    (w_stopwatch_time[23:19])   //5
    );

    watch_datapath U_WATCH_DATAPATH (
        .clk(clk),
        .reset(reset),
        .btn_h(w_wa_btn_h),
        .btn_m(w_wa_btn_m),
        .btn_s(w_wa_btn_s),
        .o_watch_time(w_watch_time)
    );

    assign w_fnd_input = (sw[1] == 0) ? w_stopwatch_time : w_watch_time;

    fnd_controller U_FND_CNTL (
        .clk(clk),
        .reset(reset),
        .sel_display(sw[2]),
        .fnd_in_data(w_fnd_input),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

endmodule


module stopwatch_datapath (
    input clk,
    input reset,
    input mode,
    input clear,
    input run_stop,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);

    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;

    tick_counter #(
        .BIT_WIDTH(5),  //파라미터 재사용
        .TIMES    (24)
    ) hour_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_hour_tick),
        .o_tick(),
        .mode(mode),
        .clear(clear),
        .o_count(hour),
        .run_stop(run_stop)
    );


    tick_counter #(
        .BIT_WIDTH(6),  //파라미터 재사용
        .TIMES    (60)
    ) min_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_min_tick),
        .o_tick(w_hour_tick),
        .mode(mode),
        .clear(clear),
        .o_count(min),
        .run_stop(run_stop)
    );

    tick_counter #(
        .BIT_WIDTH(6),  //파라미터 재사용
        .TIMES    (60)
    ) sec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_sec_tick),
        .o_tick(w_min_tick),
        .mode(mode),
        .clear(clear),
        .o_count(sec),
        .run_stop(run_stop)
    );

    tick_counter #(
        .BIT_WIDTH(7),   //파라미터 재사용
        .TIMES    (100)
    ) msec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .o_tick(w_sec_tick),
        .mode(mode),
        .clear(clear),
        .o_count(msec),
        .run_stop(run_stop)
    );

    tick_gen_100Hz U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .i_run_stop(run_stop),
        .o_tick_100hz(w_tick_100hz)
    );
endmodule


module watch_datapath (
    input clk,
    input reset,
    input btn_h,
    input btn_m,
    input btn_s,
    output [23:0] o_watch_time
);

    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;
    wire [6:0] w_msec;
    wire [5:0] w_sec, w_min;
    wire [4:0] w_hour;

    tick_counter_watch #(
        .BIT_WIDTH(7),
        .TIMES(100),
        .initial_value(0)
    ) watch_msec_cn (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .run_stop(1'b1),
        .clear(1'b0),
        .mode(1'b0),
        .o_count(w_msec),
        .o_tick(w_sec_tick)
    );


    tick_counter_watch #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .initial_value(0)
    ) watch_sec_cn (
        .clk(clk),
        .reset(reset),
        .i_tick(w_sec_tick | btn_s),
        .run_stop(1'b1),
        .clear(1'b0),
        .mode(1'b0),
        .o_count(w_sec),
        .o_tick(w_min_tick)
    );

    tick_counter_watch #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .initial_value(0)
    ) watch_min_cn (
        .clk(clk),
        .reset(reset),
        .i_tick(w_min_tick | btn_m),
        .run_stop(1'b1),
        .clear(1'b0),
        .mode(1'b0),
        .o_count(w_min),
        .o_tick(w_hour_tick)
    );

    tick_counter_watch #(
        .BIT_WIDTH(5),
        .TIMES(24),
        .initial_value(12)
    ) watch_hour_cn (
        .clk(clk),
        .reset(reset),
        .i_tick(w_hour_tick | btn_h),
        .run_stop(1'b1),
        .clear(1'b0),
        .mode(1'b0),
        .o_count(w_hour),
        .o_tick()
    );
    tick_gen_100Hz U_TICK_WATCH (
        .clk(clk),
        .reset(reset),
        .i_run_stop(1'b1),
        .o_tick_100hz(w_tick_100hz)
    );

    assign o_watch_time = {w_hour, w_min, w_sec, w_msec}; //순서 중요

endmodule

module tick_counter #(  //밀리모델
    parameter BIT_WIDTH = 7,
    TIMES = 100
) (
    input clk,
    input reset,
    input i_tick,
    input mode,
    input clear,
    input run_stop,
    output [BIT_WIDTH-1:0] o_count,
    output reg o_tick
);
    //sl_current
    reg [BIT_WIDTH-1:0] counter_reg, counter_next;  //현재값,다음값
    assign o_count = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset | clear) begin
            counter_reg <= 0;
        end else begin
            counter_reg <= counter_next;
        end
    end
    //cl_next
    always @(*) begin
        counter_next = counter_reg;  //초기
        o_tick = 1'b0;
        if (i_tick & run_stop) begin
            if (mode == 1'b1) begin
                //down
                if (counter_reg == 0) begin
                    counter_next = TIMES - 1;
                    o_tick = 1'b1;

                end else begin
                    counter_next = counter_reg - 1;
                    o_tick = 1'b0;
                end

            end else begin
                //up
                if (counter_reg == (TIMES - 1)) begin
                    counter_next = 0;
                    o_tick = 1'b1;
                end else begin
                    counter_next = counter_reg + 1;
                    o_tick = 1'b0;
                end
            end
        end
    end



endmodule

module tick_gen_100Hz (
    input clk,
    input reset,
    input i_run_stop,
    output reg o_tick_100hz  // alway의 출력은 항상 reg
);
    parameter f_count = 100_000_000 / 100;
    reg [$clog2(10_000_000)-1:0] r_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin  //reset 신호 초기화 중요
            r_counter <= 0;
            o_tick_100hz <= 1'b0;
        end else begin
            if (i_run_stop) begin
                r_counter <= r_counter + 1;
                o_tick_100hz <= 1'b0;
                if (r_counter == (f_count - 1)) begin
                    r_counter <= 0;
                    o_tick_100hz <= 1'b1;
                end else begin
                    o_tick_100hz <= 1'b0;
                end
            end
        end
    end
endmodule

module tick_counter_watch #(
    parameter BIT_WIDTH = 7,
    parameter TIMES = 100,
    parameter initial_value = 0
) (
    input clk,
    input reset,
    input i_tick,
    input run_stop,
    input clear,
    input mode,
    output [BIT_WIDTH-1:0] o_count,
    output reg o_tick
);

    reg [BIT_WIDTH-1:0] current_state, next_state;
    assign o_count = current_state;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state <= initial_value;
        end else if (clear) begin
            current_state <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        next_state = current_state;
        o_tick = 0;
        if (i_tick & run_stop) begin
            if (mode) begin
                if (current_state == 0) begin
                    next_state = TIMES - 1;
                    o_tick = 1;
                end else begin
                    next_state = current_state - 1;
                end
            end else begin
                if (current_state == (TIMES - 1)) begin
                    next_state = 0;
                    o_tick = 1;
                end else begin
                    next_state = current_state + 1;
                end
            end
        end
    end


endmodule


