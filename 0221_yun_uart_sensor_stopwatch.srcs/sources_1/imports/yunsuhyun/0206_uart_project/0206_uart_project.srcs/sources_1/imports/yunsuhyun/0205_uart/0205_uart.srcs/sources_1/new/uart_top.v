`timescale 1ns / 1ps

module uart_top (
    input  clk,
    input  rst,
    // input btn_down,
    input  uart_rx,
    output uart_tx,
    output [7:0] rx_data,
    output rx_done
);
    wire w_b_tick;


    // btn_debounce U_BD_TX_START (
    //     .clk  (clk),
    //     .reset(rst),
    //     .i_btn(btn_down),
    //     .o_btn(w_tx_start)
    // );
    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(rx_done),
        .b_tick(w_b_tick),
        .tx_data(rx_data),
        .tx_busy(),
        .tx_done(),
        .uart_tx(uart_tx)
    );

    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .rx(uart_rx),
        .b_tick(w_b_tick),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );


    baud_tick U_BOUD_TICK (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
    );

endmodule

module uart_rx (
    input clk,
    input rst,
    input rx,
    input b_tick,
    output [7:0] rx_data,
    output rx_done
);
    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;
    reg [1:0] c_state, n_state;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [3:0] bit_cnt_reg, bit_cnt_next;
    reg done_reg, done_next;
    reg [7:0] buf_reg, buf_next;
    //reg rx_reg, rx_next가 아닌이유는 외부에서 들어오는 신호라

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= 2'd0;
            b_tick_cnt_reg <= 5'd0;
            bit_cnt_reg <= 3'd0;
            done_reg <= 1'd0;
            buf_reg <= 8'd0;
        end else begin
            c_state <= n_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg <= bit_cnt_next;
            done_reg <= done_next;
            buf_reg <= buf_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next = bit_cnt_reg;
        done_next = done_reg;
        buf_next = buf_reg;
        case (c_state)
            IDLE: begin
                done_next = 3'd0;
                bit_cnt_next = 3'd0;
                b_tick_cnt_next = 5'd0;
                    buf_next = 8'd0;
                if (b_tick & !rx) begin
                    n_state  = START;
                end
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 0;
                        n_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                            buf_next = {rx, buf_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state   = IDLE;
                        done_next = 1'b1;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end


endmodule

module uart_tx (
    input clk,
    input rst,
    input tx_start,
    input b_tick,
    input [7:0] tx_data,
    output tx_busy,  //안전한 출력을 위해
    output tx_done,
    output uart_tx
);

    localparam IDLE = 2'd0, START = 2'd1;
    localparam DATA = 2'd2;
    localparam STOP = 2'd3;

    //state reg
    reg [1:0] c_state, n_state;
    reg
        tx_reg,
        tx_next;           //출력을 순차논리를 이용해 노이즈 제거하기 위해

    //BIT_CNT
    reg [2:0]
        bit_cnt_reg, bit_cnt_next;  //카운터를 피드백 구조 래치방지
    //tick_count
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    //busy,done
    reg busy_reg, busy_next, done_reg, done_next;
    //buffer
    reg [7:0] data_in_buf_reg, data_in_buf_next;
    //reg tx_start가 아닌이유는 rx_done 신호가 이미 동기화되어서 들어오는 거기때문
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;
    assign uart_tx = tx_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            tx_reg <= 1'b1;
            bit_cnt_reg <= 1'b0;
            busy_reg <= 0;
            done_reg <= 0;
            data_in_buf_reg <= 0;
            b_tick_cnt_reg <= 0;
        end else begin
            c_state <= n_state;
            tx_reg <= tx_next;
            bit_cnt_reg <= bit_cnt_next;
            busy_reg <= busy_next;
            done_reg <= done_next;
            data_in_buf_reg <= data_in_buf_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
        end
    end

    always @(*) begin
        n_state          = c_state;
        tx_next          = tx_reg;  //초기화-> latch 없앰
        bit_cnt_next     = bit_cnt_reg;
        b_tick_cnt_next  = b_tick_cnt_reg;
        busy_next        = busy_reg;
        done_next        = done_reg;
        data_in_buf_next = data_in_buf_reg;
        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                bit_cnt_next = 0;
                b_tick_cnt_next = 4'h0;
                busy_next = 0;
                done_next = 0;
                if (tx_start == 1) begin
                    n_state = START;
                    busy_next = 1'b1;
                    data_in_buf_next = tx_data;
                end
            end

            START: begin
                tx_next = 1'b0;
                if (b_tick == 1) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state = DATA;
                        b_tick_cnt_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            //bit_cnt_reg
            DATA: begin
                tx_next = data_in_buf_reg[0]; //비트 유지시간 확보
                if (b_tick == 1) begin
                    if (b_tick_cnt_reg == 15) begin
                            b_tick_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                           // bit_cnt_next = 0;
                        end else begin
                            b_tick_cnt_next = 0;
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_in_buf_next = {1'b0, data_in_buf_reg[7:1]};
                            n_state = DATA;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (b_tick == 1) begin
                    if (b_tick_cnt_reg == 15) begin
                        done_next = 1;
                        busy_next = 0;
                        n_state   = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule

module baud_tick (
    input clk,
    input rst,
    output reg b_tick
);

    parameter BAUDRATE = 9600 * 16;
    parameter F_COUNT = 100_000_000 / BAUDRATE;

    reg [$clog2(F_COUNT)-1 : 0] count_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            count_reg <= 0;
            b_tick <= 1'b0;
        end else begin
            if (count_reg == (F_COUNT - 1)) begin
                b_tick <= 1;
                count_reg <= 0;
            end else begin
                count_reg <= count_reg + 1;
                b_tick <= 0;
            end
        end
    end


endmodule


// `timescale 1ns / 1ps

// module uart_top (
//     input  clk,
//     input  rst,
//     input btn_down,
//     output uart_tx
// );
//     wire w_b_tick, w_tx_start;

//      btn_debounce U_BD_TX_START (  
//     . clk(clk),
//     . reset(rst),
//     . i_btn(btn_down),
//     . o_btn(w_tx_start)
// );

//     uart_tx U_UART_TX (
//         .clk(clk),
//         .rst(rst),
//         .tx_start(w_tx_start),
//         .b_tick(w_b_tick),
//         .tx_data(8'h30),
//         .tx_busy(),
//         .tx_done(),
//         .uart_tx(uart_tx)
//     );

//     baud_tick U_BOUD_TICK (
//         .clk(clk),
//         .reset(rst),
//         .b_tick(w_b_tick)
//     );

// endmodule


// module uart_tx (
//     input clk,
//     input rst,
//     input tx_start,
//     input b_tick,
//     input [7:0] tx_data,
//     output tx_busy,    //안전한 출력을 위해
//     output tx_done,
//     output uart_tx
// );

//     localparam IDLE = 3'd0, WAIT = 3'd1, START = 3'd2;
//     localparam DATA =3'd3;
//     localparam STOP = 3'd4;

//     // //16counter
//     reg [3:0] tick_count;
//     //state reg
//     reg [2:0] c_state, n_state;
//     //tx_output
//     reg tx_reg, tx_next;           //출력을 순차논리를 이용해 노이즈 제거하기 위해
//     //BIT_CNT
//     reg[3:0] bit_cnt_reg, bit_cnt_next;    //카운터를 피드백 구조 래치방지
//     //busy,done
//     reg busy_reg, busy_next, done_reg, done_next;
//     //buffer
//     reg[7:0] data_in_buf_reg,data_in_buf_next;

//     assign tx_busy = busy_reg;
//     assign tx_done = done_reg;
//     assign uart_tx = tx_reg;


//     always @(posedge clk, posedge rst) begin
//         if (rst) begin
//             c_state <= IDLE;
//             tx_reg  <= 1'b1;
//             bit_cnt_reg <= 1'b0;
//             busy_reg <=0;
//             done_reg <=0;
//             data_in_buf_reg <=0;
//             tick_count <= 0;

//         end else begin
//             c_state <= n_state;
//             tx_reg  <= tx_next;
//             busy_reg <= busy_next;
//             done_reg <= done_next;
//             data_in_buf_reg <= data_in_buf_next;
//             if(b_tick)begin
//                 if(tick_count == 15)begin
//                     tick_count <= 0;
//                     bit_cnt_reg <= bit_cnt_next;
//                 end else begin
//                     tick_count <= tick_count +1;
//         end
//     end
//         end
//     end

//     always @(*) begin
//         n_state = c_state;
//         tx_next = tx_reg;  //초기화-> latch 없앰
//         bit_cnt_next = bit_cnt_reg;
//         busy_next = busy_reg;
//         done_next = done_reg;
//         data_in_buf_next = data_in_buf_reg;
//         case (c_state)
//             IDLE: begin
//                 tx_next = 1'b1;
//                 bit_cnt_next = 0;
//                 data_in_buf_next =0;
//                 busy_next = 0;
//                 done_next = 0;
//                 tick_count =0;
//                 if (tx_start == 1) begin
//                     n_state = WAIT;
//                     busy_next = 1'b1;
//                     data_in_buf_next = tx_data;
//                 end
//             end
//             WAIT: begin
//                 if (tick_count == 15) begin
//                     n_state = START;
//                 end
//             end
//             START: begin
//                 tx_next = 1'b0;
//                 if (tick_count == 15) begin
//                     n_state = DATA;
//                 end
//             end
//             DATA: begin
//                 tx_next = data_in_buf_reg[bit_cnt_reg];
//                 if (tick_count == 15) begin
//                     if(bit_cnt_reg == 7) begin
//                     n_state = STOP;
//                     end else begin
//                     bit_cnt_next = bit_cnt_reg +1;
//                     n_state = DATA;
//                 end
//             end
//             end
//             STOP: begin
//                 tx_next = 1'b1;
//                 if (tick_count == 15) begin
//                     done_next = 1;
//                     n_state = IDLE;
//                 end
//             end
//         endcase
//     end
// endmodule

// module baud_tick_16 (
//     input clk,
//     input reset,
//     output reg b_tick
// );

//     parameter BAUDRATE = 9600 * 16;
//     parameter F_COUNT = 100_000_000 / BAUDRATE;

//     reg [$clog2(F_COUNT)-1 : 0] count_reg;

//     always @(posedge clk, posedge reset) begin
//         if (reset) begin
//             count_reg <= 0;
//             b_tick <= 1'b0;
//         end else begin
//             if (count_reg == (F_COUNT - 1)) begin
//                 b_tick <= 1;
//                 count_reg <= 0;
//             end else begin
//                 count_reg <= count_reg + 1;
//                 b_tick <= 0;
//             end
//         end
//     end
// endmodule





