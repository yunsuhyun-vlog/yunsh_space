`timescale 1ns / 1ps

module instruction_mem (
    input        [31:0] instr_addr,
    output logic [31:0] instr_data
);

    logic [31:0] rom[0:255];

    initial begin

        //    $readmemh("rv32i_romdata.mem",rom);
        //    $readmemh("apb_ram.mem",rom);
        // $readmemh("apb_gpo.mem",rom);
        //$readmemh("apb_bram_gpo_gpi.mem",rom);
        //  $readmemh("test.mem", rom);
        $readmemh("apb_gpio_led_blink.mem", rom);

        // // --- [1단계] 데이터 생성 및 메모리 저장 ---
        // rom[0] = 32'h12345137; // lui x2, 0x12345      -> x2의 상위 비트에 12345000 세팅
        // rom[1] = 32'h67810113;  // addi x2, x2, 0x678   -> x2 = 12345678 완성
        // rom[2] = 32'h00202023; // sw x2, 0(x0)         -> dmem[0]에 12345678 저장
        // rom[3] = 32'h00002183; // lw x3, 0(x0)         -> 예상: x3 = 12345678 (3~0번지)

        // // 1. PC = 16번지 (0x10)
        // // jal x4, +4 (다음 PC는 20번지(0x14), x4에 복귀 주소 20(0x14) 저장)
        // rom[4] = 32'h0040026F;

        // // 2. PC = 20번지 (0x14)
        // // jalr x5, 1(x1) (x1 + 1 = 타겟 주소, x5에 복귀 주소 24(0x18) 저장)
        // rom[5] = 32'h001082E7;



// // --- [1단계] APB RAM 베이스 주소 설정 및 데이터 생성 ---
//         rom[0] = 32'h100000B7; // lui x1, 0x10000      -> x1에 APB RAM 베이스 주소(0x10000000) 세팅
//         rom[1] = 32'h12345137; // lui x2, 0x12345      -> x2의 상위 비트에 0x12345000 세팅
//         rom[2] = 32'h67810113; // addi x2, x2, 0x678   -> x2 = 0x12345678 완성

//         // --- [2단계] 메모리 저장 및 로드 ---
//         rom[3] = 32'h0020A023; // sw x2, 0(x1)         -> dmem(0x10000000)에 12345678 저장
//         rom[4] = 32'h0000A183; // lw x3, 0(x1)         -> 0x10000000 번지 값을 읽어 x3에 12345678 저장

//         // --- [3단계] 점프 명령어 ---
//         rom[5] = 32'h0040026F; // jal x4, +4           -> x4에 24(0x18) 저장
//         rom[6] = 32'h001082E7; // jalr x5, 1(x1)       -> x1 + 1 주소로 점프, x5에 28(0x1C) 저장
    end
    assign instr_data = rom[instr_addr[31:2]]; //pc가 4씩 증가하지만 비트를 잘라서 1씩 증가하도록 인식하게 만듬 
endmodule


