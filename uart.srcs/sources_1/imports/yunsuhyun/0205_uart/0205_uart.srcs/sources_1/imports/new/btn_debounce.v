`timescale 1ns / 1ps

module btn_debounce (  //내꺼
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);
// clock divider for debounce shift register
    // 100Mhz -> 100Khz
    // counter = 100M/100K = 1000
    //100MHZ->100KHZ COUNTER 1000필요
    parameter clk_div = 100_000;
    parameter f_count = 100_000_000/clk_div;
    reg [$clog2(f_count)-1:0] counter_reg;
    reg clk_100khz_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            clk_100khz_reg <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == f_count - 1) begin
                counter_reg <= 0;
                clk_100khz_reg <= 1'b1;
            end else begin
                clk_100khz_reg <= 1'b0;
            end
        end
    end



    //serises 8 tab F/F
    reg [7:0] q_reg, q_next;
    wire debounce;
    reg edge_reg;

    //SL
    always @(posedge clk_100khz_reg, posedge reset) begin
        if (reset) begin
            q_reg <= 0;
        end else begin
            q_reg <= q_next;
        end
    end

    always @(*) begin
        q_next = {i_btn, q_reg[7:1]};
    end

    //debounce,8input and
    assign debounce = & q_reg;


    //edge detection
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            edge_reg <= 1'b0;
        end else begin
            edge_reg <= debounce;
        end
    end

    assign o_btn = debounce & (~edge_reg);

endmodule
