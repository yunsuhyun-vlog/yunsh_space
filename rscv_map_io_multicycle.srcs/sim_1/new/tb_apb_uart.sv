
`timescale 1ns / 1ps

module tb_apb_uart();

    // 1. 신호 선언
    logic        pclk;
    logic        prst;
    logic [31:0] paddr;
    logic [31:0] pwdata;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] prdata;
    logic        pready;
    logic        uart_tx;
    logic        uart_rx;

    // 2. 루프백(Loopback) 결선: TX로 나간 신호가 RX로 바로 들어오도록 물리적 선 연결
    assign uart_rx = uart_tx;

    // 3. 검증할 하드웨어(DUT: Device Under Test) 인스턴스화
    apb_uart DUT (
        .pclk(pclk),
        .prst(prst),
        .paddr(paddr),
        .pwdata(pwdata),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .prdata(prdata),
        .pready(pready),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx)
    );

    // 4. 시스템 클럭 생성 (100MHz = 10ns 주기)
    always #5 pclk = ~pclk;

    // --- CPU의 쓰기 동작을 흉내내는 APB Write Task ---
    task apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge pclk);
            paddr   <= addr;
            pwdata  <= data;
            pwrite  <= 1'b1;
            psel    <= 1'b1;
            penable <= 1'b0; // Setup Phase
            
            @(posedge pclk);
            penable <= 1'b1; // Access Phase
            
            wait(pready);    // 하드웨어가 준비될 때까지 대기
            
            @(posedge pclk);
            psel    <= 1'b0;
            penable <= 1'b0;
        end
    endtask

    // --- 시나리오 시작 ---
    initial begin
        // 초기화
        pclk    = 0;
        prst    = 1;
        psel    = 0;
        penable = 0;
        pwrite  = 0;
        paddr   = 32'h0;
        pwdata  = 32'h0;

        // 리셋 해제
        #20 prst = 0;
        #20;

        // [시나리오 1] Baud Rate 설정 (2'b10 = 115200 bps 선택)
        // 시뮬레이션 시간을 단축하기 위해 가장 빠른 속도로 설정합니다.
        apb_write(12'h004, 32'd2); 

        // [시나리오 2] TX 데이터 전송 ('A' = 0x41)
        apb_write(12'h00C, 32'h41);

        // [시나리오 3] TX Start Trigger 발생 (방아쇠 당기기)
        apb_write(12'h000, 32'd1);
        
        // [시나리오 4] TX Start Trigger 초기화 (방아쇠 놓기)
        apb_write(12'h000, 32'd0);

        // 하드웨어가 115200bps로 전송을 완료하고 RX로 다시 받을 때까지 충분히 대기
        // (1비트당 약 8.68us 소요, 10비트 전송에 약 86.8us 소요)
        #100000; 

        // 파형 확인을 위해 시뮬레이션 종료
        $finish;
    end

endmodule