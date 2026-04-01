`timescale 1ns / 1ps

//r = 8'h72 = 0111_0010, l = 8'h6c = 0110_1100
//u = 8'h75 = 0111_0101, d = 8'h64 = 0110_0100

module uart_project_top(
    input clk,
    input rst,
    input [2:0] sw,
    input btn_r,
    input btn_l,
    input btn_u,
    input btn_d,
    input uart_rx,
    output uart_tx,
    output [3:0] fnd_digit,
    output [7:0] fnd_data
 );

 wire [7:0] w_rx_data;
 wire w_rx_done;
 wire [3:0] w_decoder_out;
 

  uart_top U_BD_LOOP_BACK(
    . clk(clk),
    . rst(rst),
    . uart_rx(uart_rx),
    . uart_tx(uart_tx),
    . rx_data(w_rx_data),
    . rx_done(w_rx_done)
);


     top_stopwatch U_BD_STOPWATCH_WATCH(  //내꺼
    .clk(clk),
    .reset(rst),
    .sw(sw),         // sw[0]:stopwatch down/up mode, sw[1]:watch/stopwatch select, sw[2]:hour min/sec msec
    .btn_r(btn_r),  // (sec/run_stop)
    .btn_l(btn_l),  // (hour/clear)
    .btn_u(btn_u),  //(min)
    .btn_d(btn_d),
    .uart_btn(w_decoder_out),
    .fnd_digit(fnd_digit),
    .fnd_data(fnd_data)
);

 askii_decoder U_BD_ASKII_DECODER(
    .clk(clk),
    .rst(rst),
    .data(w_rx_data),
    .rx_done(w_rx_done),
    .d_out(w_decoder_out)
);
   
endmodule


module askii_decoder(
    input clk,
    input rst,
    input [7:0] data,
    input rx_done,
    output reg [3:0] d_out
);

always@(posedge clk, posedge rst)begin
    if (rst)begin
        d_out <= 4'b0000;
    end else begin
    if(rx_done)begin
        case (data)
        8'h72: d_out = 4'b0001;  //r: d_out[0]
        8'h6c: d_out = 4'b0010;  //l: d_out[1]
        8'h75: d_out = 4'b0100;  //u: d_out[2]
        8'h64: d_out = 4'b1000;  //d: d_out[3]
        default: d_out = 4'b0000;
        endcase
    end else begin d_out <= 4'b0000;
    end
    end
end

endmodule
        


