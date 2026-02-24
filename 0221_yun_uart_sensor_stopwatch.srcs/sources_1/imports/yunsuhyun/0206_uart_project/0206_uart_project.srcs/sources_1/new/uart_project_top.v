`timescale 1ns / 1ps

module uart_project_top (
    input clk,
    input reset,
    
    // 스위치 및 물리 버튼 입력
    input [4:0] sw,        // sw[4]:초음파, sw[3]:온습도, sw[2]:시분/초밀리초, sw[1]:시계/스톱워치, sw[0]:스톱워치 up/down
    input btn_r, btn_l, btn_u, btn_d,
    
    // UART 통신 핀
    input rx,
    output tx,
    
    // 센서 입출력 핀
    output sr_trig,
    input  sr_echo,
    inout  dht_data_pin,
    
    // FND 디스플레이 출력 핀
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);

    // ==========================================
    // 1. 내부 통신 및 제어 신호용 Wire 선언
    // ==========================================
    wire [7:0] w_rx_data;
    wire w_rx_done;
    wire [4:0] w_uart_cmd; 
    wire w_tx_full;
    wire w_tx_push;
    wire [7:0] w_tx_push_data;

    wire [1:0] w_mux_sel;
    wire w_sw_btn_r, w_sw_btn_l, w_sw_btn_u, w_sw_btn_d;
    wire w_sr_start, w_dht_start, w_tx_start;

    wire [23:0] w_stopwatch_data;
    wire [15:0] w_sr_data;
    wire [15:0] w_humidity;
    wire [15:0] w_temperature;
    wire [15:0] w_dht_data;
    wire w_sr_tick;
    wire [15:0] w_bcd_16bit;

    assign w_dht_data = (sw[3] == 1'b1) ? w_humidity : w_temperature;


    // ==========================================
    // 2. UART 및 ASCII 디코더 (수신부)
    // ==========================================
    uart_top U_UART (
        .clk(clk), .rst(reset),
        .uart_rx(rx), .uart_tx(tx),
        .o_rx_data(w_rx_data), .o_rx_done(w_rx_done),
        .i_tx_data(w_tx_push_data), .i_tx_push(w_tx_push), .o_tx_full(w_tx_full)
    );

    askii_decoder U_ASCII_DEC (
        .clk(clk), .rst(reset), 
        .data(w_rx_data),
        .rx_done(w_rx_done),
        .d_out(w_uart_cmd)
    );

    // ==========================================
    // 3. 메인 Control Unit (신호 라우터)
    // ==========================================
    main_control_unit U_MAIN_CTRL (
        .clk(clk), .reset(reset),
        .sw_watch(sw[1]), .sw_dht(sw[3]), .sw_sr(sw[4]),
        .btn_r(btn_r), .btn_l(btn_l), .btn_u(btn_u), .btn_d(btn_d),
        .uart_r(w_uart_cmd[0]), .uart_l(w_uart_cmd[1]), 
        .uart_u(w_uart_cmd[2]), .uart_d(w_uart_cmd[3]), .uart_s(w_uart_cmd[4]),
        .o_mux_sel(w_mux_sel),
        .o_sw_btn_r(w_sw_btn_r), .o_sw_btn_l(w_sw_btn_l), 
        .o_sw_btn_u(w_sw_btn_u), .o_sw_btn_d(w_sw_btn_d),
        .o_sr_start(w_sr_start), .o_dht_start(w_dht_start),
        .o_tx_start(w_tx_start)
    );

    // ==========================================
    // 4. 하위 센서 및 스톱워치 연산 블록
    // ==========================================
    top_stopwatch U_STOPWATCH (
        .clk(clk), .reset(reset),
        .btn_run_stop(w_sw_btn_r), .btn_clear(w_sw_btn_l),
        .sw_up_down(sw[0]), .sw_mode(sw[1]),
        .o_stopwatch_data(w_stopwatch_data)
    );

    tick_gen_sr U_SR04_TICK (
        .clk(clk), .rst(reset), .s_tick(w_sr_tick)
    );

    sr04_controller_sr U_SR04_CTRL (
        .clk(clk), .rst(reset),
        .s_tick(w_sr_tick), .start(w_sr_start), 
        .echo(sr_echo), .trigger(sr_trig),
        .s_dist(w_sr_data)
    );

    dht11_controller_dht U_DHT11_CTRL (
        .clk(clk), .rst(reset), .start(w_dht_start), 
        .humidity(w_humidity), .temperature(w_temperature),
        .dht11_done(), .dht11_valid(), .debug(), 
        .dhtio(dht_data_pin)
    );

    // ==========================================
    // 5. 통합 FND 출력 및 ASCII 송신부
    // ==========================================
    fnd_controller U_FND_CTRL (
        .clk(clk), .reset(reset),
        .sel_display(sw[2]), .mux_sel(w_mux_sel),
        .fnd_in_data_stopwatch(w_stopwatch_data),
        .in_data_sr(w_sr_data), .in_data_dht(w_dht_data),
        .fnd_digit(fnd_digit), .fnd_data(fnd_data),
        .o_bcd_16bit(w_bcd_16bit) 
    );

    ascii_sender U_ASCII_SENDER (
        .clk(clk), .reset(reset),
        .tx_start(w_tx_start), .tx_fifo_full(w_tx_full),
        .i_bcd_16bit(w_bcd_16bit), 
        .tx_push_data(w_tx_push_data), .tx_push(w_tx_push)
    );

endmodule
// `timescale 1ns / 1ps

// //r = 8'h72 = 0111_0010, l = 8'h6c = 0110_1100
// //u = 8'h75 = 0111_0101, d = 8'h64 = 0110_0100

// module uart_project_top(
//     input clk,
//     input rst,
//     input [4:0] sw,
//     input btn_r,
//     input btn_l,
//     input btn_u,
//     input btn_d,
//     input uart_rx,
//     output uart_tx,
//     output [3:0] fnd_digit,
//     output [7:0] fnd_data
//  );

//  wire [7:0] w_rx_data;
//  wire w_rx_done;
//  wire [3:0] w_decoder_out;
 

//   uart_top U_BD_LOOP_BACK(
//     . clk(clk),
//     . rst(rst),
//     . uart_rx(uart_rx),
//     . uart_tx(uart_tx),
//     . rx_data(w_rx_data),
//     . rx_done(w_rx_done)
// );


//      top_stopwatch U_BD_STOPWATCH_WATCH(  //내꺼
//     .clk(clk),
//     .reset(rst),
//     .sw(sw),         // sw[0]:stopwatch down/up mode, sw[1]:watch/stopwatch select, sw[2]:hour min/sec msec
//     .btn_r(btn_r),  // (sec/run_stop)
//     .btn_l(btn_l),  // (hour/clear)
//     .btn_u(btn_u),  //(min)
//     .btn_d(btn_d),
//     .uart_btn(w_decoder_out),
//     .fnd_digit(fnd_digit),
//     .fnd_data(fnd_data)
// );

//  askii_decoder U_BD_ASKII_DECODER(
//     .clk(clk),
//     .rst(rst),
//     .data(w_rx_data),
//     .rx_done(w_rx_done),
//     .d_out(w_decoder_out)
// );
   
// endmodule


module askii_decoder(
    input clk,
    input rst,
    input [7:0] data,
    input rx_done,
    output reg [4:0] d_out  // 's' 명령어를 포함하기 위해 5비트로 확장
);
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            d_out <= 5'b00000;
        end else begin
            if (rx_done) begin
                case (data)
                    8'h72: d_out = 5'b00001; // r: d_out[0]
                    8'h6c: d_out = 5'b00010; // l: d_out[1]
                    8'h75: d_out = 5'b00100; // u: d_out[2]
                    8'h64: d_out = 5'b01000; // d: d_out[3]
                    8'h73: d_out = 5'b10000; // s: d_out[4] (추가된 송신 트리거)
                    default: d_out = 5'b00000;
                endcase
            end else begin 
                d_out <= 5'b00000;
            end
        end
    end

endmodule
        
`timescale 1ns / 1ps

module ascii_sender (
    input clk,
    input reset,
    
    input tx_start,           // UART 송신 트리거
    input tx_fifo_full,       // TX FIFO 가득 참 여부 확인
    input [15:0] i_bcd_16bit, // fnd_controller에서 받은 4자리 연산 완료 데이터
    
    output reg [7:0] tx_push_data,
    output reg tx_push
);

    // 16비트 데이터를 4개의 4비트(1자리 BCD 숫자)로 단순 분할 (연산 없음)
    wire [3:0] d1 = i_bcd_16bit[15:12];
    wire [3:0] d2 = i_bcd_16bit[11:8];
    wire [3:0] d3 = i_bcd_16bit[7:4];
    wire [3:0] d4 = i_bcd_16bit[3:0];

    // UART TX FIFO 순차 전송 FSM
    localparam IDLE    = 3'd0;
    localparam CHAR1   = 3'd1;
    localparam CHAR2   = 3'd2;
    localparam CHAR3   = 3'd3;
    localparam CHAR4   = 3'd4;
    localparam SEND_CR = 3'd5;
    localparam SEND_LF = 3'd6;
    
    reg [2:0] state, next_state;

    always @(posedge clk, posedge reset) begin
        if (reset) state <= IDLE;
        else       state <= next_state;
    end

    always @(*) begin
        next_state = state;
        tx_push = 1'b0;
        tx_push_data = 8'h00;

        case (state)
            IDLE: begin
                if (tx_start && !tx_fifo_full) next_state = CHAR1;
            end
            CHAR1: begin
                if (!tx_fifo_full) begin
                    tx_push = 1'b1;
                    tx_push_data = {4'h3, d1}; // '3'을 붙여 문자로 변환
                    next_state = CHAR2;
                end
            end
            CHAR2: begin
                if (!tx_fifo_full) begin
                    tx_push = 1'b1;
                    tx_push_data = {4'h3, d2};
                    next_state = CHAR3;
                end
            end
            CHAR3: begin
                if (!tx_fifo_full) begin
                    tx_push = 1'b1;
                    tx_push_data = {4'h3, d3};
                    next_state = CHAR4;
                end
            end
            CHAR4: begin
                if (!tx_fifo_full) begin
                    tx_push = 1'b1;
                    tx_push_data = {4'h3, d4};
                    next_state = SEND_CR; 
                end
            end
            SEND_CR: begin 
                if (!tx_fifo_full) begin
                    tx_push = 1'b1;
                    tx_push_data = 8'h0D; // \r
                    next_state = SEND_LF; 
                end
            end
            SEND_LF: begin 
                if (!tx_fifo_full) begin
                    tx_push = 1'b1;
                    tx_push_data = 8'h0A; // \n
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end
endmodule
