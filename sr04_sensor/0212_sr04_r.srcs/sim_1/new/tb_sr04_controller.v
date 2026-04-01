`timescale 1ns / 1ps

module tb_sr04_controller ();

    reg clk, rst, echo, btn_r;
    wire trigger;
    wire [7:0] fnd_data;
    wire [3:0] fnd_digit;

    sr04_top dut (
        .clk(clk),
        .rst(rst),
        .echo(echo),
        .btn_r(btn_r),
        .trigger(trigger),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

    always #5 clk = ~clk;

    initial begin
        #0;
        clk   = 0;
        rst   = 1;
        echo  = 0;
        btn_r = 0;

        #10;
        rst = 0;
        //10cm
        #10 btn_r = 1;

        #1000_00;
        btn_r = 0;
        echo  = 1;

        #(10 * 1000 * 58);
        echo = 0;

        #1000_000;
        //5cm
        btn_r = 1;
        #1000_000;

        #15000;
        btn_r = 0;
        echo  = 1;

        #(5 * 1000 * 58);
        echo = 0;

        #5000_000 $stop;

    end

endmodule

// `timescale 1ns / 1ps

// module tb_sr04_controller ();

//     reg clk, rst, echo, btn_r;
//     wire trigger;
//     wire [23:0] s_dist;

//     sr04_top dut (
//         .clk(clk),
//         .rst(rst),
//         .echo(echo),
//         .btn_r(btn_r),
//         .trigger(trigger),
//         .s_dist(s_dist)
//     );

//     always #5 clk = ~clk;

//     initial begin
//         #0;
//         clk   = 0;
//         rst   = 1;
//         echo  = 0;
//         btn_r = 0;

//         #10;
//         rst = 0;
//         //10cm
//         #10 btn_r = 1;

//         #1000_00;
//         btn_r = 0;
//         echo = 1;

//         #(10 * 1000 * 58);
//         echo = 0;

//         #10000;
//         //5cm
//         btn_r = 1;
//         #1000_00;

//         #15000;
//         btn_r = 0;
//         echo = 1;

//         #(5 * 1000 * 58);
//         echo = 0;

//         #1000
//         $stop;

//     end

// endmodule
