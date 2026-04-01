// `timescale 1ns / 1ps

// module tb_dh11 ();

//     reg clk, rst, start;
//     reg dht11_sensor_io;  //센서가 내보낼 전압값
//     reg sensor_io_sel;  // 출력 제어 (1: 출력상태, 0: z상태)
//     reg [39:0] dht11_sensor_data;
//     wire dhtio, dht11_done, dht11_valid;
//     reg  [3:0] sw;
//     wire [7:0] fnd_data;
//     wire [3:0] fnd_digit;
//     wire [2:0] led;

//     pullup (dhtio);

//     integer i;

//     assign dhtio = (sensor_io_sel) ? dht11_sensor_io : 1'bz;

//     top_dht11 dut (
//         .clk      (clk),
//         .rst      (rst),
//         .btn_r    (start),      // TB의 start 신호를 btn_r에 연결
//         .sw   (sw),     // 추가한 스위치 신호 연결
//         .dhtio    (dhtio),
//         .fnd_data (fnd_data),   // 추가한 FND 데이터 연결
//         .fnd_digit(fnd_digit),  // 추가한 FND 자릿수 연결
//         .led      (led)         // 추가한 LED 연결
//     );

//     always #5 clk = ~clk;

//     initial begin
//         #0;
//         clk = 0;
//         rst = 1;
//         start = 0;
//         dht11_sensor_io = 1;
//         sensor_io_sel = 0;
//         i = 0;
//         //huminity integal, decimal, temp integal, decimal, checksum

//         sw = 4'b1000;  //습도 출력모드

//         dht11_sensor_data = {8'h32, 8'h00, 8'h19, 8'h00, 8'h4b};


//         //rst
//         #20;
//         rst = 0;
//         #20;
//         start = 1;
//         #10;
//         start = 0;

//         //19msec + 40usec
//         // start signal + wait
//         #(1900 * 10 * 1000 + 40_000);

//         sensor_io_sel   = 1;
//         //sync_l, sync_h
//         dht11_sensor_io = 0;
//         #(80_000);
//         dht11_sensor_io = 1;
//         #(80_000);

//         //40bit data pattern
//         for (i = 39; i >= 0; i = i - 1) begin
//             dht11_sensor_io = 0;
//             #(50_000);
//             dht11_sensor_io = 1'b1;
//             if (dht11_sensor_data[i] == 0) begin
//                 #(28_000);
//             end else begin
//                 #(70_000);
//             end
//         end

//         dht11_sensor_io = 0;
//         #(50_000);
//         sensor_io_sel = 0;
//         #(100_000);

//         #1000_000;
//         $stop;

//     end

// endmodule


`timescale 1ns / 1ps

module tb_dh11 ();

    reg clk, rst, start;
    reg dht11_sensor_io;  
    reg sensor_io_sel;  
    reg [39:0] dht11_sensor_data;
    wire dhtio, dht11_done, dht11_valid;
    reg  [3:0] sw;
    wire [7:0] fnd_data;
    wire [3:0] fnd_digit;
    wire [2:0] led;

    pullup (dhtio);

    integer i, j; // 반복문을 위한 변수 j 추가

    assign dhtio = (sensor_io_sel) ? dht11_sensor_io : 1'bz;

    top_dht11 dut (
        .clk      (clk),
        .rst      (rst),
        .btn_r    (start),      
        .sw       (sw),     
        .dhtio    (dhtio),
        .fnd_data (fnd_data),   
        .fnd_digit(fnd_digit),  
        .led      (led)         
    );

    always #5 clk = ~clk;

    initial begin
        #0;
        clk = 0;
        rst = 1;
        start = 0;
        dht11_sensor_io = 1;
        sensor_io_sel = 0;
        
        sw = 4'b1000;  // 습도 출력모드
        dht11_sensor_data = {8'h32, 8'h00, 8'h19, 8'h00, 8'h4b};

        // 초기 리셋 (루프 밖에서 1회만 실행)
        #20;
        rst = 0;
        #20;

        // 15회 반복 측정 루프
        for (j = 0; j < 15; j = j + 1) begin
            
            // 1. 시작 신호 인가
            start = 1;
            #10;
            start = 0;

            // 2. MCU의 19ms 대기 및 센서 응답 대기 시간 모사
            #(1900 * 10 * 1000 + 40_000);

            // 3. 센서 ACK 신호 (Low 80us, High 80us)
            sensor_io_sel   = 1;
            dht11_sensor_io = 0;
            #(80_000);
            dht11_sensor_io = 1;
            #(80_000);

            // 4. 40비트 데이터 전송
            for (i = 39; i >= 0; i = i - 1) begin
                dht11_sensor_io = 0;
                #(50_000);
                dht11_sensor_io = 1'b1;
                if (dht11_sensor_data[i] == 0) begin
                    #(28_000);
                end else begin
                    #(70_000);
                end
            end

            // 5. 센서 통신 종료 처리 (50us Low 후 릴리스)
            dht11_sensor_io = 0;
            #(50_000);
            sensor_io_sel = 0;
            #1000_000;
        end

        $stop;
    end

endmodule