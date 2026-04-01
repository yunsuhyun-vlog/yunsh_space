`timescale 1ns / 1ps

module apb_uart (
    input               pclk,
    input               prst,
    //apb signal
    input        [31:0] paddr,
    input        [31:0] pwdata,   //tx_data_reg
    input               psel,
    input               penable,
    input               pwrite,
    output logic [31:0] prdata,   //rx_data_reg
    output logic        pready,
    //uart signal
    output logic        uart_tx,
    input  logic        uart_rx
);

    localparam [11:0] uart_ctl_addr = 12'h000;
    localparam [11:0] uart_baud_addr = 12'h004;
    localparam [11:0] uart_status_addr = 12'h008;
    localparam [11:0] uart_tx_addr = 12'h00c;
    localparam [11:0] uart_rx_addr = 12'h016;

    logic [7:0] tx_data_reg, rx_data_reg;
    logic [ 1:0] baud_reg;
    logic [31:0] ctl_reg;
    logic [ 1:0] status_reg;
    logic tx_busy, rx_done;

    assign pready = (penable & psel) ? 1'b1 : 1'b0;
    assign status_reg = {rx_done, tx_busy};

    assign prdata = (paddr[11:0] == uart_rx_addr)?{24'h000_000,rx_data_reg}:
    (paddr[11:0] == uart_ctl_addr)?ctl_reg:
    (paddr[11:0] == uart_baud_addr)?{30'd0,baud_reg}:
    (paddr[11:0] == uart_status_addr)?{30'd0, status_reg}:
    (paddr[11:0] == uart_tx_addr)?{24'h000_000,tx_data_reg}:32'hxxxx_xxxx;

    always_ff @(posedge pclk, posedge prst) begin
        if (prst) begin
            tx_data_reg <= 8'b0;
            //status_reg <= 32'b0;
            baud_reg <= 2'b0;
            ctl_reg <= 0;
        end else begin
            if (pready) begin
                if (pwrite) begin
                    case (paddr[11:0])
                        uart_ctl_addr:  ctl_reg <= pwdata[31:0];
                        uart_baud_addr: baud_reg <= pwdata[1:0];
                        //uart_status_addr: status_reg <= pwdata[1:0];
                        uart_tx_addr:   tx_data_reg <= pwdata[7:0];
                    endcase
                end
            end
        end
    end


    uart_top U_UART_CORE (
        .clk(pclk),
        .rst(prst),
        .uart_rx(uart_rx),  // 칩 외부에서 들어오는 RX 핀
        .baud_data(baud_reg),  // APB를 통해 설정된 속도 값
        .uart_tx(uart_tx),  // 칩 외부로 나가는 TX 핀
        .tx_data(tx_data_reg),  // APB를 통해 들어온 전송할 데이터
        .tx_start   (ctl_reg[0]),      // APB를 통해 들어온 전송 시작 트리거 (0번 비트)
        .rx_data    (rx_data_reg),     // UART가 수신한 데이터를 APB 읽기용 레지스터 선에 연결
        .rx_done(rx_done),  // 수신 완료 상태를 status_reg 선에 연결
        .tx_busy(tx_busy)  // 송신 중 상태를 status_reg 선에 연결
    );

endmodule




module uart_top (
    input  logic       clk,
    input  logic       rst,
    input  logic       uart_rx,
    input  logic [1:0] baud_data,
    output logic       uart_tx,

    input  logic [7:0]  tx_data,   // APB 레지스터에서 들어오는 전송할 데이터
    input  logic        tx_start,  // APB 컨트롤 레지스터(ctl_reg[0])에서 들어오는 전송 시작 신호
    output logic [7:0]  rx_data,   // APB 레지스터로 넘겨줄 수신된 데이터
    output logic        rx_done,   // APB 상태 레지스터(status_reg[1])로 넘겨줄 수신 완료 플래그
    output logic        tx_busy    // APB 상태 레지스터(status_reg[0])로 넘겨줄 송신 중 플래그

);
    logic w_b_tick;

    // 송신부 (TX): APB 버스에서 주는 데이터와 시작 신호를 받도록 연결
    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),  // 외부(APB) 제어 신호 연결
        .b_tick(w_b_tick),
        .tx_data(tx_data),  // 외부(APB) 데이터 연결
        .tx_busy(tx_busy),  // 외부(APB)로 상태 출력
        .tx_done  (),              // (현재 시스템에서는 인터럽트를 안 쓰므로 비워둠)
        .uart_tx(uart_tx)
    );

    // 수신부 (RX): 수신된 데이터와 상태를 APB 버스로 넘기도록 연결
    uart_rx U_UART_RX (
        .clk    (clk),
        .rst    (rst),
        .rx     (uart_rx),
        .b_tick (w_b_tick),
        .rx_data(rx_data),   // 외부(APB)로 데이터 출력
        .rx_done(rx_done)    // 외부(APB)로 상태 출력
    );

    // 속도 생성부 (Baud Tick): APB 버스에서 계산해준 분주비를 받음
    baud_tick U_BAUD_TICK (
        .clk   (clk),
        .rst   (rst),
        .baud_sel  (baud_data),  // 외부(APB)에서 설정한 속도 값 연결
        .b_tick(w_b_tick)
    );

endmodule


module uart_rx (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    input  logic       b_tick,
    output logic [7:0] rx_data,
    output logic       rx_done
);
    typedef enum logic [1:0] {
        IDLE  = 2'd0,
        START = 2'd1,
        DATA  = 2'd2,
        STOP  = 2'd3
    } state_e;

    state_e c_state, n_state;

    logic [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic [3:0] bit_cnt_reg, bit_cnt_next;
    logic done_reg, done_next;
    logic [7:0] buf_reg, buf_next;

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state        <= IDLE;
            b_tick_cnt_reg <= 5'd0;
            bit_cnt_reg    <= 4'd0;
            done_reg       <= 1'b0;
            buf_reg        <= 8'd0;
        end else begin
            c_state        <= n_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            done_reg       <= done_next;
            buf_reg        <= buf_next;
        end
    end

    always_comb begin
        n_state         = c_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        done_next       = done_reg;
        buf_next        = buf_reg;

        case (c_state)
            IDLE: begin
                done_next       = 1'b0;
                bit_cnt_next    = 4'd0;
                b_tick_cnt_next = 5'd0;
                buf_next        = 8'd0;
                if (b_tick & !rx) begin
                    n_state = START;
                end
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 0;
                        n_state         = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        buf_next        = {rx, buf_reg[7:1]};
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
            default: n_state = IDLE;
        endcase
    end
endmodule


module uart_tx (
    input  logic       clk,
    input  logic       rst,
    input  logic       tx_start,
    input  logic       b_tick,
    input  logic [7:0] tx_data,
    output logic       tx_busy,
    output logic       tx_done,
    output logic       uart_tx
);
    typedef enum logic [1:0] {
        IDLE  = 2'd0,
        START = 2'd1,
        DATA  = 2'd2,
        STOP  = 2'd3
    } state_e;

    state_e c_state, n_state;

    logic tx_reg, tx_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    logic [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic busy_reg, busy_next, done_reg, done_next;
    logic [7:0] data_in_buf_reg, data_in_buf_next;

    assign tx_busy = busy_reg;
    assign tx_done = done_reg;
    assign uart_tx = tx_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state         <= IDLE;
            tx_reg          <= 1'b1;
            bit_cnt_reg     <= 3'd0;
            busy_reg        <= 1'b0;
            done_reg        <= 1'b0;
            data_in_buf_reg <= 8'd0;
            b_tick_cnt_reg  <= 4'd0;
        end else begin
            c_state         <= n_state;
            tx_reg          <= tx_next;
            bit_cnt_reg     <= bit_cnt_next;
            busy_reg        <= busy_next;
            done_reg        <= done_next;
            data_in_buf_reg <= data_in_buf_next;
            b_tick_cnt_reg  <= b_tick_cnt_next;
        end
    end

    always_comb begin
        n_state          = c_state;
        tx_next          = tx_reg;
        bit_cnt_next     = bit_cnt_reg;
        b_tick_cnt_next  = b_tick_cnt_reg;
        busy_next        = busy_reg;
        done_next        = done_reg;
        data_in_buf_next = data_in_buf_reg;

        case (c_state)
            IDLE: begin
                tx_next         = 1'b1;
                bit_cnt_next    = 3'd0;
                b_tick_cnt_next = 4'd0;
                busy_next       = 1'b0;
                done_next       = 1'b0;
                if (tx_start) begin
                    n_state          = START;
                    busy_next        = 1'b1;
                    data_in_buf_next = tx_data;
                end
            end
            START: begin
                tx_next = 1'b0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state         = DATA;
                        b_tick_cnt_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_in_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next     = bit_cnt_reg + 1;
                            data_in_buf_next = {1'b0, data_in_buf_reg[7:1]};
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        done_next = 1'b1;
                        busy_next = 1'b0;
                        n_state   = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            default: n_state = IDLE;
        endcase
    end
endmodule


// module baud_tick (
//     input  logic        clk,
//     input  logic        rst,
//     input  logic [31:0] baud,
//     output logic        b_tick
// );

//     logic [31:0] count_reg;

//     always_ff @(posedge clk or posedge rst) begin
//         if (rst) begin
//             count_reg <= 32'd0;
//             b_tick    <= 1'b0;
//         end else begin
//             if (count_reg >= (baud - 1)) begin
//                 b_tick    <= 1'b1;
//                 count_reg <= 32'd0;
//             end else begin
//                 count_reg <= count_reg + 1;
//                 b_tick    <= 1'b0;
//             end
//         end
//     end
// endmodule

module baud_tick (
    input  logic       clk,
    input  logic       rst,
    input  logic [1:0] baud_sel,
    output logic       b_tick
);

    // 시스템 클럭을 상수로 명시하여 가독성과 유지보수성 확보
    localparam SYS_CLK = 100_000_000;

    logic [31:0] limit;
    logic [31:0] count_reg;

    // 조합 논리: 합성 툴이 컴파일 시점에 아래 식을 계산하여 최종 상수로 변환함
    always_comb begin
        case (baud_sel)
            2'b00: limit = (SYS_CLK / (9600 * 16)) - 1;
            2'b01: limit = (SYS_CLK / (19200 * 16)) - 1;
            2'b10: limit = (SYS_CLK / (115200 * 16)) - 1;
            default: limit = (SYS_CLK / (9600 * 16)) - 1;  // 기본값 9600 bps
        endcase
    end

    // 순차 논리: 설정된 limit 값까지만 카운트
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            count_reg <= 32'd0;
            b_tick    <= 1'b0;
        end else begin
            if (count_reg >= limit) begin
                b_tick    <= 1'b1;
                count_reg <= 32'd0;
            end else begin
                count_reg <= count_reg + 1;
                b_tick    <= 1'b0;
            end
        end
    end
endmodule





