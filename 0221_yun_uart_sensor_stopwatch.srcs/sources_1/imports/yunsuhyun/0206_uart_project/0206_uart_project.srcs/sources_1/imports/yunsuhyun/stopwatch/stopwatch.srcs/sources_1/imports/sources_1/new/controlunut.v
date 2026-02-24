`timescale 1ns / 1ps

module main_control_unit (
    input clk,
    input rst,

    // 개별 스위치 입력
    input sw_watch,  // sw[1]: 시계/스톱워치
    input sw_dht,  // sw[3]: 온습도 선택 및 모드 진입
    input sw_sr,  // sw[4]: 초음파 모드 진입

    // 물리 버튼 및 UART 신호
    input btn_r,
    btn_l,
    btn_u,
    btn_d,
    input uart_r,
    uart_l,
    uart_u,
    uart_d,
    uart_s,

    output reg [1:0] o_mux_sel,  // FND 컨트롤러로 갈 MUX 선택 신호

    // 하위 모듈 제어 신호
    output o_sw_btn_r,
    output o_sw_btn_l,
    output o_sw_btn_u,
    output o_sw_btn_d,
    output o_sr_start,
    output o_dht_start,
    output o_tx_start
);

 always @(*) begin
        if (sw_sr) begin
            o_mux_sel = 2'b01;      // 초음파 모드 (FND 컨트롤러 규격 일치)
        end else if (sw_dht) begin
            o_mux_sel = 2'b10;      // 온습도 모드 (FND 컨트롤러 규격 일치)
        end else begin
            o_mux_sel = 2'b00;      // 기본값: 스톱워치 모드
        end
    end

    assign o_sw_btn_r  = (o_mux_sel == 0) ? (btn_r | uart_r) : 0;
    assign o_sw_btn_l  = (o_mux_sel == 0) ? (btn_l | uart_l) : 0;
    assign o_sw_btn_u  = (o_mux_sel == 0) ? (btn_u | uart_u) : 0;
    assign o_sw_btn_d  = (o_mux_sel == 0) ? (btn_d | uart_d) : 0;

    assign o_sr_start  = (o_mux_sel == 2'b11) ? (btn_r | uart_r) : 0;
    assign o_dht_start = (o_mux_sel == 2'b10) ? (btn_r | uart_r) : 0;

    assign o_tx_start  = uart_s;
endmodule



module control_unit (
    input clk,
    input rst,
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
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            current_state <= stop;  //초기설정 stop
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


// module control_unit (        
//     input clk,
//     input rst,
//     input i_mode,
//     input i_run_stop,
//     input i_clear,
//     output o_mode,
//     output reg o_run_stop,
//     output reg o_clear
// );

//     localparam stop = 2'b00, run = 2'b01, clear = 2'b10;
//     reg [1:0] current_state, next_state;
//     assign o_mode = i_mode;
//     //SL
//     always @(posedge clk, posedge rst) begin
//         if  rst) begin
//             current_state <= stop;              //초기설정 stop
//         end else begin
//             current_state <= next_state;
//         end
//     end
//     //CL
//     always @(*) begin
//         next_state = current_state;
//         o_run_stop = 1'b0;
//         o_clear = 1'b0;
//         case (current_state)
//             stop: begin
//                 //moor output
//                 o_run_stop = 1'b0;
//                 o_clear = 1'b0;
//                 if (i_run_stop == 1) begin
//                     next_state = run;
//                 end else if (i_clear) begin
//                     next_state = clear;
//                 end
//             end
//             run: begin
//                 o_run_stop = 1'b1;
//                 o_clear = 1'b0;
//                 if (i_run_stop) begin
//                     next_state = stop;
//                 end
//             end
//             clear: begin
//                 o_run_stop = 1'b0;
//                 o_clear = 1'b1;
//                 next_state = stop;
//             end
//         endcase
//     end
// endmodule


