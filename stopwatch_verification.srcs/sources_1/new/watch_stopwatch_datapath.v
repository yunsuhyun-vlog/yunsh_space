`timescale 1ns / 1ps


module watch_stopwatch_datapath (
    input clk,
    input reset,
    input        mode,  // 0: Watch mode, 1: Stopwatch mode
    input count_mode,  // 0Up/1Down count

    input [1:0] w_edit_msec,
    input [1:0] w_edit_sec,
    input [1:0] w_edit_min,
    input [1:0] w_edit_hour,

    input sw_run_stop,
    input sw_clear,

    output [6:0] disp_msec,
    output [5:0] disp_sec,
    output [5:0] disp_min,
    output [4:0] disp_hour
);

    // watch out
    wire [6:0] w_msec;
    wire [5:0] w_sec;
    wire [5:0] w_min;
    wire [4:0] w_hour;

    // stopwatch out
    wire [6:0] sw_msec;
    wire [5:0] sw_sec;
    wire [5:0] sw_min;
    wire [4:0] sw_hour;

    // watch datapath
    watch_datapath u_watch (
        .clk       (clk),
        .reset     (reset),
        .count_mode(count_mode),
        .edit_msec (w_edit_msec),
        .edit_sec  (w_edit_sec),
        .edit_min  (w_edit_min),
        .edit_hour (w_edit_hour),
        .msec      (w_msec),
        .sec       (w_sec),
        .min       (w_min),
        .hour      (w_hour)
    );

    // stopwatch datapath
    stopwatch_datapath u_stopwatch (
        .clk       (clk),
        .reset     (reset),
        .count_mode(count_mode),
        .run_stop  (sw_run_stop),
        .clear     (sw_clear),
        .msec      (sw_msec),
        .sec       (sw_sec),
        .min       (sw_min),
        .hour      (sw_hour)
    );

    //output
    assign disp_msec = (mode) ? sw_msec : w_msec;
    assign disp_sec  = (mode) ? sw_sec : w_sec;
    assign disp_min  = (mode) ? sw_min : w_min;
    assign disp_hour = (mode) ? sw_hour : w_hour;

endmodule

module watch_datapath (
    input        clk,
    input        reset,
    input        count_mode,
    input  [1:0] edit_msec,
    input  [1:0] edit_sec,
    input  [1:0] edit_min,
    input  [1:0] edit_hour,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);

    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;

    tick_counter #(
        .BIT_WIDTH(5),
        .TIMES(24),
        .INIT_CNT(12)
    ) hour_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_hour_tick),
        .count_mode(count_mode),
        .run_stop(),
        .clear(1'b0),
        .edit_sign(edit_hour),
        .o_count(hour),
        .o_tick()
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .INIT_CNT(0)
    ) min_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_min_tick),
        .count_mode(count_mode),
        .run_stop(),
        .clear(1'b0),
        .edit_sign(edit_min),
        .o_count(min),
        .o_tick(w_hour_tick)
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .INIT_CNT(0)
    ) sec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_sec_tick),
        .count_mode(count_mode),
        .run_stop(),
        .clear(1'b0),
        .edit_sign(edit_sec),
        .o_count(sec),
        .o_tick(w_min_tick)
    );
    tick_counter #(
        .BIT_WIDTH(7),
        .TIMES(100),
        .INIT_CNT(0)
    ) msec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .count_mode(count_mode),
        .run_stop(),
        .clear(1'b0),
        .edit_sign(edit_msec),
        .o_count(msec),
        .o_tick(w_sec_tick)
    );

    tick_gen_100Hz U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .i_run_stop(1'b1),
        .o_tick_100hz(w_tick_100hz)
    );

endmodule


module stopwatch_datapath (
    input        clk,
    input        reset,
    input        count_mode,
    input        run_stop,
    input        clear,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);

    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;

    tick_counter #(
        .BIT_WIDTH(5),
        .TIMES(24),
        .INIT_CNT(0)
    ) hour_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_hour_tick),
        .count_mode(count_mode),
        .run_stop(run_stop),
        .clear(clear),
        .edit_sign(2'b0),
        .o_count(hour),
        .o_tick()
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .INIT_CNT(0)
    ) min_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_min_tick),
        .count_mode(count_mode),
        .run_stop(run_stop),
        .clear(clear),
        .edit_sign(2'b0),
        .o_count(min),
        .o_tick(w_hour_tick)
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .INIT_CNT(0)
    ) sec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_sec_tick),
        .count_mode(count_mode),
        .run_stop(run_stop),
        .clear(clear),
        .edit_sign(2'b0),
        .o_count(sec),
        .o_tick(w_min_tick)
    );
    tick_counter #(
        .BIT_WIDTH(7),
        .TIMES(100),
        .INIT_CNT(0)
    ) msec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .count_mode(count_mode),
        .run_stop(run_stop),
        .clear(clear),
        .edit_sign(2'b0),
        .o_count(msec),
        .o_tick(w_sec_tick)
    );

    tick_gen_100Hz U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .i_run_stop(run_stop),
        .o_tick_100hz(w_tick_100hz)
    );

endmodule


module MUX_2x1_24bit (
    input         sel,
    input  [23:0] i_sel0,
    input  [23:0] i_sel1,
    output [23:0] o_mux
);
    assign o_mux = (sel) ? i_sel1 : i_sel0;

endmodule


module tick_counter #(
    parameter BIT_WIDTH = 7,
              TIMES     = 100,
              INIT_CNT  = 0
) (
    input                      clk,
    input                      reset,
    input                      i_tick,
    input                      count_mode,
    input                      run_stop,
    input                      clear,
    input      [          1:0] edit_sign,
    output     [BIT_WIDTH-1:0] o_count,
    output reg                 o_tick
);

    // counter reg
    reg [BIT_WIDTH - 1:0] counter_reg, counter_next;

    assign o_count = counter_reg;

    // state register SL
    always @(posedge clk, posedge reset) begin
        if (reset | clear) begin
            counter_reg <= INIT_CNT;
        end else begin
            counter_reg <= counter_next;
        end
    end

    // next combinational logic (CL)
    always @(*) begin
        counter_next = counter_reg;
        o_tick       = 1'b0;

        case (edit_sign)
            2'b01:  // edit mode: up
            if (counter_reg == (TIMES - 1)) begin
                counter_next = 0;
            end else begin
                counter_next = counter_reg + 1;
            end
            2'b11:  // edit mode: down
            if (counter_reg == 0) begin
                counter_next = (TIMES - 1);
            end else begin
                counter_next = counter_reg - 1;
            end
            default:  // edit mode off
            // up count
            if (i_tick & (count_mode == 0)) begin
                if (counter_reg == (TIMES - 1)) begin
                    counter_next = 0;
                    o_tick       = 1'b1;
                end else begin
                    counter_next = counter_reg + 1;
                    o_tick       = 1'b0;
                end
                // down count
            end else if (i_tick & (count_mode == 1)) begin
                if (counter_reg == 0) begin
                    counter_next = (TIMES - 1);
                    o_tick       = 1'b1;
                end else begin
                    counter_next = counter_reg - 1;
                    o_tick       = 1'b0;
                end
            end
        endcase
    end

endmodule

// tick = 100hz
module tick_gen_100Hz (
    input      clk,
    input      reset,
    input      i_run_stop,
    output reg o_tick_100hz
);

    parameter F_COUNT = 100_000_000 / 100;

    reg [$clog2(F_COUNT)-1:0] r_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter    <= 0;
            o_tick_100hz <= 1'b0;
        end else begin
            if (i_run_stop) begin
                r_counter <= r_counter + 1;
                if (r_counter == (F_COUNT - 1)) begin
                    r_counter    <= 0;
                    o_tick_100hz <= 1'b1;
                end else begin
                    o_tick_100hz <= 1'b0;
                end
            end
        end
    end

endmodule
