
`timescale 1ns / 1ps

module tb_uart_top ();

    reg clk, rst;
    reg [2:0] sw;
    reg btn_r, btn_l, btn_u, btn_d;
    reg uart_rx;
    wire uart_tx;
    wire [3:0] fnd_digit;
    wire [7:0] fnd_data;

    // 9600 Baudrate 기준: 1 / 9600 = 104,166.66... ns
    // FPGA 내부에서 16배 오버샘플링을 하더라도, 외부에서 들어오는 데이터 주기는 변하지 않습니다.
    parameter BIT_PERIOD = 104167; 

    uart_project_top dut(
        .clk(clk),
        .rst(rst),
        .sw(sw),
        .btn_r(btn_r),
        .btn_l(btn_l),
        .btn_u(btn_u),
        .btn_d(btn_d),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

    // 100MHz 클록 생성
    always #5 clk = ~clk;

    // UART 전송 Task
    task send_uart_char(input [7:0] data);
        integer i;
        begin
            uart_rx = 0; // Start Bit
            #(BIT_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i]; // Data Bits
                #(BIT_PERIOD);
            end
            uart_rx = 1; // Stop Bit
            #(BIT_PERIOD);
            #(BIT_PERIOD); // 문자 간 여유 시간
        end
    endtask

//     initial begin
//         // 초기화
//         clk = 0; rst = 1; sw = 3'b000;
//         btn_r = 0; btn_l = 0; btn_u = 0; btn_d = 0;
//         uart_rx = 1; // Idle 상태는 1
        
//         #100 rst = 0;
//         #1000;

//         // --- 테스트 1: PC에서 'r' (8'h72) 보내기 ---
//         // Stopwatch 시작/정지 확인
//         send_uart_char(8'h72); 
        
//         #200000000; // 0.2초 정도 시계 흐르는 것 관찰

//         // --- 테스트 2: PC에서 'u' (8'h75) 보내기 ---
//         // 시계 모드(sw[1]=1)에서 분 증가 확인
//         sw = 3'b010; 
//         #1000;
//         send_uart_char(8'h75);

//         #100000000;
//         $stop;
//     end

// endmodule

initial begin
        // --- 0. 초기화 ---
        clk = 0; rst = 1; sw = 3'b000;
        btn_r = 0; btn_l = 0; btn_u = 0; btn_d = 0;
        uart_rx = 1; 
        #100 rst = 0;
        #1000;

        // --- 1. [Stopwatch] 연속 제어 테스트 (Start -> Stop -> Clear) ---
        send_uart_char(8'h72); // 'r' : Start
        #50000000;             // 50ms 대기 (동작 관찰)
        send_uart_char(8'h72); // 'r' : Stop
        #10000000;
        send_uart_char(8'h6c); // 'l' : Clear (00:00:00으로 돌아가는지 확인)
        #10000000;


        sw[1] = 1'b1;          // Watch 모드 전환
        sw[2] = 1'b1;          // Hour/Min 표시 모드
        #1000;
        // 1시 2분으로 설정하기 위해 연속 송신
        send_uart_char(8'h6c); // 'l' : Hour +1 (1시)
        send_uart_char(8'h75); // 'u' : Min +1  (1분)
        send_uart_char(8'h75); // 'u' : Min +1  (2분)
        #20000000;

        // --- 4. [Exception] 정의되지 않은 명령어 입력 ---
        send_uart_char(8'h78); // 'x' : 정의되지 않은 ASCII 송신
        #10000000;             // 시스템에 아무 변화가 없어야 정상 (검증 포인트)

        #100000000;
        $stop;
    end

    endmodule