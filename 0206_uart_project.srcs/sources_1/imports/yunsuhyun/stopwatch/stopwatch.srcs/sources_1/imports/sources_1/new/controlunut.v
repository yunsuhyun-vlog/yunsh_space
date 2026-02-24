`timescale 1ns / 1ps


module control_unit (        //내꺼
    input clk,
    input reset,
    input i_mode,
    input i_run_stop,
    input i_clear,
    output o_mode,
    output reg o_run_stop,
    output reg o_clear
);

    localparam stop = 2'b00, run = 2'b01, clear = 2'b10;
    reg [1:0] current_state, next_state;
    assign o_mode = i_mode;
    //SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state <= stop;              //초기설정 stop
        end else begin
            current_state <= next_state;
        end
    end
    //CL
    always @(*) begin
        next_state = current_state;
        o_run_stop = 1'b0;
        o_clear = 1'b0;
        case (current_state)
            stop: begin
                //moor output
                o_run_stop = 1'b0;
                o_clear = 1'b0;
                if (i_run_stop == 1) begin
                    next_state = run;
                end else if (i_clear) begin
                    next_state = clear;
                end
            end
            run: begin
                o_run_stop = 1'b1;
                o_clear = 1'b0;
                if (i_run_stop) begin
                    next_state = stop;
                end
            end
            clear: begin
                o_run_stop = 1'b0;
                o_clear = 1'b1;
                next_state = stop;
            end
        endcase
    end
endmodule


