`timescale 1ns / 1ps `timescale 1ns / 1ps

interface sw_interface (
    input logic clk
);
    logic       tick;
    logic       reset;
    logic       mode;
    logic       count_mode;
    logic [1:0] w_edit_msec;
    logic [1:0] w_edit_sec;
    logic [1:0] w_edit_min;
    logic [1:0] w_edit_hour;
    logic       sw_run_stop;
    logic       sw_clear;
    logic [6:0] disp_msec;
    logic [5:0] disp_sec;
    logic [5:0] disp_min;
    logic [4:0] disp_hour;
endinterface

class transaction;
    logic            tick;
    logic            reset;
    logic            mode;
    logic            count_mode;
    logic            sw_run_stop;
    logic            sw_clear;
    logic      [6:0] disp_msec;
    logic      [5:0] disp_sec;
    logic      [5:0] disp_min;
    logic      [4:0] disp_hour;
    rand logic [1:0] w_edit_msec;
    rand logic [1:0] w_edit_sec;
    rand logic [1:0] w_edit_min;
    rand logic [1:0] w_edit_hour;
    //sel
    rand logic [1:0] edit_sel;

    // constraint w_con1 {
    //     edit_sel dist {
    //         2'b00 := 0,
    //         2'b01 := 0,
    //         2'b10 := 5,
    //         2'b11 := 5
    //     };
    // }

    constraint w_con1 {edit_sel inside {2'b10, 2'b11};}

    constraint w_con {
        // msec sel
        if (edit_sel == 2'b00) {
            w_edit_msec dist {
                2'b00 := 8,  //hold
                2'b01 := 1,  //up
                2'b10 := 0,
                2'b11 := 1  //down
            };
            w_edit_sec == 2'b00;
            w_edit_min == 2'b00;
            w_edit_hour == 2'b00;
        }
        // sec sel
        else
        if (edit_sel == 2'b01) {
            w_edit_msec == 2'b00;
            w_edit_sec dist {
                2'b00 := 8,
                2'b01 := 1,
                2'b10 := 0,
                2'b11 := 1
            };
            w_edit_min == 2'b00;
            w_edit_hour == 2'b00;
        }
        // min sel
        else
        if (edit_sel == 2'b10) {
            w_edit_msec == 2'b00;
            w_edit_sec == 2'b00;
            w_edit_min dist {
                2'b00 := 8,
                2'b01 := 1,
                2'b10 := 0,
                2'b11 := 1
            };
            w_edit_hour == 2'b00;
        }
        // hour sel
        else
        if (edit_sel == 2'b11) {
            w_edit_msec == 2'b00;
            w_edit_sec == 2'b00;
            w_edit_min == 2'b00;
            w_edit_hour dist {
                2'b00 := 8,
                2'b01 := 1,
                2'b10 := 0,
                2'b11 := 1
            };
        }
    }

    function display(string name);
        $display(
            "%t : [%s] edit_sel=%b, w_edit_msec=%b, w_edit_sec=%b, w_edit_min=%b, w_edit_hour=%b, time = %02d:%02d:%02d.%02d",
            $time, name, edit_sel, w_edit_msec, w_edit_sec, w_edit_min,
            w_edit_hour, disp_hour, disp_min, disp_sec, disp_msec);
    endfunction
endclass

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task run(int count);
        repeat (count) begin
            tr = new();
            tr.randomize();
            gen2drv_mbox.put(tr);
            tr.display("gen");
            @(gen_next_ev);
        end
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual sw_interface sw_if;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual sw_interface sw_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.sw_if = sw_if;
    endfunction

    task preset();
        sw_if.reset = 1;
        sw_if.mode = 0;
        sw_if.count_mode = 0;
        sw_if.w_edit_hour = 0;
        sw_if.w_edit_min = 0;
        sw_if.w_edit_sec = 0;
        sw_if.w_edit_msec = 0;
        sw_if.sw_run_stop = 0;
        sw_if.sw_clear = 0;
        @(negedge sw_if.clk);
        @(negedge sw_if.clk);
        sw_if.reset = 0;
        sw_if.mode  = 0;
        @(negedge sw_if.clk);
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            tr.display("drv");
            @(negedge sw_if.clk);
            // @(posedge sw_if.clk);
            // #1;
            sw_if.w_edit_msec = tr.w_edit_msec;
            sw_if.w_edit_sec  = tr.w_edit_sec;
            sw_if.w_edit_min  = tr.w_edit_min;
            sw_if.w_edit_hour = tr.w_edit_hour;
        end
    endtask
endclass


class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual sw_interface sw_if;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual sw_interface sw_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.sw_if = sw_if;
    endfunction

    task run();
        forever begin
            @(posedge sw_if.clk);
            #1;
            // @(negedge sw_if.clk)
            tr = new();
            tr.tick = sw_if.tick;
            tr.w_edit_msec = sw_if.w_edit_msec;
            tr.w_edit_sec = sw_if.w_edit_sec;
            tr.w_edit_min = sw_if.w_edit_min;
            tr.w_edit_hour = sw_if.w_edit_hour;
            tr.disp_hour = sw_if.disp_hour;
            tr.disp_min = sw_if.disp_min;
            tr.disp_sec = sw_if.disp_sec;
            tr.disp_msec = sw_if.disp_msec;
            mon2scb_mbox.put(tr);
            tr.display("mon");
        end
    endtask
endclass

class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;

    int comp_msec, comp_sec, comp_min, comp_hour;
    int pass_cnt, fail_cnt;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev = gen_next_ev;
        this.comp_hour = 12;
        this.comp_min = 0;
        this.comp_sec = 0;
        this.comp_msec = 0;
    endfunction
    
    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.display("scb");

            // edit
            // hour
            if (tr.w_edit_hour == 2'b01)
                comp_hour = (comp_hour == 23) ? 0 : comp_hour + 1;
            else if (tr.w_edit_hour == 2'b11)
                comp_hour = (comp_hour == 0) ? 23 : comp_hour - 1;

            // min
            if (tr.w_edit_min == 2'b01)
                comp_min = (comp_min == 59) ? 0 : comp_min + 1;
            else if (tr.w_edit_min == 2'b11)
                comp_min = (comp_min == 0) ? 59 : comp_min - 1;

            // sec
            if (tr.w_edit_sec == 2'b01)
                comp_sec = (comp_sec == 59) ? 0 : comp_sec + 1;
            else if (tr.w_edit_sec == 2'b11)
                comp_sec = (comp_sec == 0) ? 59 : comp_sec - 1;

            // msec
            if (tr.w_edit_msec == 2'b01)
                comp_msec = (comp_msec == 99) ? 0 : comp_msec + 1;
            else if (tr.w_edit_msec == 2'b11)
                comp_msec = (comp_msec == 0) ? 99 : comp_msec - 1;

            // comp data, disp data compare
            if ((tr.disp_msec == comp_msec) && (tr.disp_sec == comp_sec) &&
                (tr.disp_min  == comp_min)  && (tr.disp_hour == comp_hour)) begin
                pass_cnt++;
                $display("PASS:edit: H=%d, M=%d, S=%d, MS=%d", tr.w_edit_hour,
                         tr.w_edit_min, tr.w_edit_sec, tr.w_edit_msec);
                         $display(
                    "PASS: comp_time:%02d:%02d:%02d.%02d | real_time:%02d:%02d:%02d.%02d",
                    comp_hour, comp_min, comp_sec, comp_msec, tr.disp_hour,
                    tr.disp_min, tr.disp_sec, tr.disp_msec);
            end else begin
                fail_cnt++;
                $display("edit: H=%d, M=%d, S=%d, MS=%d", tr.w_edit_hour,
                         tr.w_edit_min, tr.w_edit_sec, tr.w_edit_msec);
                $display(
                    "FAIL: comp_time:%02d:%02d:%02d.%02d | real_time:%02d:%02d:%02d.%02d",
                    comp_hour, comp_min, comp_sec, comp_msec, tr.disp_hour,
                    tr.disp_min, tr.disp_sec, tr.disp_msec);
            end

            // tick 
            if (tr.tick && comp_msec == 99 && comp_sec == 59 && comp_min == 59 && 
                tr.w_edit_msec == 2'b00 && tr.w_edit_sec == 2'b00 && tr.w_edit_min == 2'b00) begin
                comp_hour = (comp_hour == 23) ? 0 : comp_hour + 1;
            end

            if (tr.tick && comp_msec == 99 && comp_sec == 59 && 
                tr.w_edit_msec == 2'b00 && tr.w_edit_sec == 2'b00) begin
                comp_min = (comp_min == 59) ? 0 : comp_min + 1;
            end

            if (tr.tick && comp_msec == 99 && tr.w_edit_msec == 2'b00) begin
                comp_sec = (comp_sec == 59) ? 0 : comp_sec + 1;
            end

            if (tr.tick && tr.w_edit_msec == 2'b00) begin
                comp_msec = (comp_msec == 99) ? 0 : comp_msec + 1;
            end

            ->gen_next_ev;
        end
    endtask
endclass

//     task run();
//         forever begin
//             mon2scb_mbox.get(tr);

//             //hour
//             if (tr.w_edit_hour == 2'b01) begin
//                 comp_hour = (comp_hour == 23) ? 0 : comp_hour + 1;
//             end else if (tr.w_edit_hour == 2'b11) begin
//                 comp_hour = (comp_hour == 0) ? 23 : comp_hour - 1;
//             end else if (tr.tick && comp_msec == 99 && comp_sec == 59 && comp_min == 59 && 
//                          tr.w_edit_msec == 2'b00 && tr.w_edit_sec == 2'b00 && tr.w_edit_min == 2'b00) begin
//                 comp_hour = (comp_hour == 23) ? 0 : comp_hour + 1;
//             end

//             //min
//             if (tr.w_edit_min == 2'b01) begin
//                 comp_min = (comp_min == 59) ? 0 : comp_min + 1;
//             end else if (tr.w_edit_min == 2'b11) begin
//                 comp_min = (comp_min == 0) ? 59 : comp_min - 1;
//             end else if (tr.tick && comp_msec == 99 && comp_sec == 59 && 
//                          tr.w_edit_msec == 2'b00 && tr.w_edit_sec == 2'b00) begin
//                 comp_min = (comp_min == 59) ? 0 : comp_min + 1;
//             end
//             //sec
//             if (tr.w_edit_sec == 2'b01) begin
//                 comp_sec = (comp_sec == 59) ? 0 : comp_sec + 1;
//             end else if (tr.w_edit_sec == 2'b11) begin
//                 comp_sec = (comp_sec == 0) ? 59 : comp_sec - 1;
//             end else if (tr.tick && comp_msec == 99 && tr.w_edit_msec == 2'b00) begin
//                 comp_sec = (comp_sec == 59) ? 0 : comp_sec + 1;
//             end
//             //msec
//             if (tr.w_edit_msec == 2'b01) begin
//                 comp_msec = (comp_msec == 99) ? 0 : comp_msec + 1;
//             end else if (tr.w_edit_msec == 2'b11) begin
//                 comp_msec = (comp_msec == 0) ? 99 : comp_msec - 1;
//             end else if (tr.tick) begin
//                 comp_msec = (comp_msec == 99) ? 0 : comp_msec + 1;
//             end

//             //compare
//             if ((tr.disp_msec == comp_msec) && (tr.disp_sec == comp_sec) &&
//                 (tr.disp_min  == comp_min)  && (tr.disp_hour == comp_hour)) begin
//                 pass_cnt++;
//                 $display("PASS:edit: H=%d, M=%d, S=%d, MS=%d", tr.w_edit_hour,
//                          tr.w_edit_min, tr.w_edit_sec, tr.w_edit_msec);
//             end else begin
//                 fail_cnt++;
//                 $display("edit: H=%d, M=%d, S=%d, MS=%d", tr.w_edit_hour,
//                          tr.w_edit_min, tr.w_edit_sec, tr.w_edit_msec);
//                 $display(
//                     "FAIL: comp_time:%02d:%02d:%02d.%02d | real_time:%02d:%02d:%02d.%02d",
//                     comp_hour, comp_min, comp_sec, comp_msec, tr.disp_hour,
//                     tr.disp_min, tr.disp_sec, tr.disp_msec);
//             end
//             ->gen_next_ev;

//         end
//     endtask
// endclass

class enviroment;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event gen_next_ev;

    function new(virtual sw_interface sw_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, sw_if);
        mon = new(mon2scb_mbox, sw_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction

    task run();
        fork
            gen.run(11);
            drv.run();
            mon.run();
            scb.run();
        join_any
        $display("**watch edit_mode Verification**");
        $display("--------------------------------");
        $display("**pass_cnt = %3d              **", scb.pass_cnt);
        $display("**fail_cnt = %3d              **", scb.fail_cnt);
        $display("--------------------------------");
        $stop;
    endtask

endclass


module tb_watch_stopwatch ();

    logic clk;
    sw_interface sw_if (clk);
    enviroment env;

    watch_stopwatch_datapath dut (
        .clk(clk),
        .reset(sw_if.reset),
        .mode(sw_if.mode),          // 0: Watch 모드 화면 출력, 1: Stopwatch 모드 화면 출력
        .count_mode(sw_if.count_mode),    // 0Up/1Down 카운트 (공통.어 신호
        .w_edit_msec(sw_if.w_edit_msec),
        .w_edit_sec(sw_if.w_edit_sec),
        .w_edit_min(sw_if.w_edit_min),
        .w_edit_hour(sw_if.w_edit_hour),
        .sw_run_stop(sw_if.sw_run_stop),
        .sw_clear(sw_if.sw_clear),
        .disp_msec(sw_if.disp_msec),
        .disp_sec(sw_if.disp_sec),
        .disp_min(sw_if.disp_min),
        .disp_hour(sw_if.disp_hour)
    );
    defparam dut.u_watch.U_TICK_GEN.F_COUNT = 10;
        defparam dut.u_stopwatch.U_TICK_GEN.F_COUNT = 10;
    assign sw_if.tick = dut.u_watch.w_tick_100hz;

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        env = new(sw_if);
        env.drv.preset();
        env.run();
    end

endmodule


