// `timescale 1ns / 1ps

// interface sw_interface (
//     input logic clk
// );
//     logic       tick;
//     logic       reset;
//     logic       mode;
//     logic       count_mode;
//     logic [1:0] w_edit_msec;
//     logic [1:0] w_edit_sec;
//     logic [1:0] w_edit_min;
//     logic [1:0] w_edit_hour;
//     logic       sw_run_stop;
//     logic       sw_clear;
//     logic [6:0] disp_msec;
//     logic [5:0] disp_sec;
//     logic [5:0] disp_min;
//     logic [4:0] disp_hour;

//     assert_msec_max : assert property (@(posedge clk) disp_msec <= 99) else $error("msec out of range");
//     assert_sec_max  : assert property (@(posedge clk) disp_sec <= 59) else $error("sec out of range");
//     assert_min_max  : assert property (@(posedge clk) disp_min <= 59) else $error("min out of range");
//     assert_hour_max : assert property (@(posedge clk) disp_hour <= 23) else $error("hour out of range");


// endinterface

// class transaction;
//     logic            tick;
//     logic            reset;
//     logic            mode;
//     logic            count_mode;
//     logic      [1:0] w_edit_msec;
//     logic      [1:0] w_edit_sec;
//     logic      [1:0] w_edit_min;
//     logic      [1:0] w_edit_hour;
//     rand logic       sw_run_stop;
//     rand logic       sw_clear;
//     logic      [6:0] disp_msec;
//     logic      [5:0] disp_sec;
//     logic      [5:0] disp_min;
//     logic      [4:0] disp_hour;

//     constraint sw_con {
//         sw_run_stop dist {
//             1 := 10,
//             0 := 0
//         };
//         sw_clear dist {
//             1'b1 := 0,
//             0 := 10
//         };
//     }

//     function display(string name);
//         $display("%t : [%s] run=%b, clear=%b, time = %02d:%02d:%02d.%02d",
//                  $time, name, sw_run_stop, sw_clear, disp_hour, disp_min,
//                  disp_sec, disp_msec);
//     endfunction
// endclass

// class generator;
//     transaction tr;
//     mailbox #(transaction) gen2drv_mbox;
//     event gen_next_ev;

//     function new(mailbox#(transaction) gen2drv_mbox, event gen_next_ev);
//         this.gen2drv_mbox = gen2drv_mbox;
//         this.gen_next_ev  = gen_next_ev;
//     endfunction

//     task run(int count);
//         repeat (count) begin
//             tr = new();
//             tr.randomize();
//             gen2drv_mbox.put(tr);
//             tr.display("gen");
//             @(gen_next_ev);
//         end
//     endtask
// endclass

// class driver;
//     transaction tr;
//     mailbox #(transaction) gen2drv_mbox;
//     virtual sw_interface sw_if;

//     function new(mailbox#(transaction) gen2drv_mbox,
//                  virtual sw_interface sw_if);
//         this.gen2drv_mbox = gen2drv_mbox;
//         this.sw_if = sw_if;
//     endfunction

//     task preset();
//         sw_if.reset = 1;
//         sw_if.mode = 0;
//         sw_if.count_mode = 0;
//         sw_if.w_edit_hour = 0;
//         sw_if.w_edit_min = 0;
//         sw_if.w_edit_sec = 0;
//         sw_if.w_edit_msec = 0;
//         sw_if.sw_run_stop = 0;
//         sw_if.sw_clear = 0;
//         @(negedge sw_if.clk);
//         @(negedge sw_if.clk);
//         sw_if.reset  = 0;
//         sw_if.mode = 1;
//         @(negedge sw_if.clk);
//     endtask

//     task run();
//         forever begin
//             gen2drv_mbox.get(tr);
//             tr.display("drv");
//             @(negedge sw_if.clk);
//             // @(posedge sw_if.clk);
//             //#1;
//             sw_if.sw_run_stop = tr.sw_run_stop;
//             sw_if.sw_clear = tr.sw_clear;
//         end
//     endtask
// endclass


// class monitor;
//     transaction tr;
//     mailbox #(transaction) mon2scb_mbox;
//     virtual sw_interface sw_if;

//     function new(mailbox#(transaction) mon2scb_mbox,
//                  virtual sw_interface sw_if);
//         this.mon2scb_mbox = mon2scb_mbox;
//         this.sw_if = sw_if;
//     endfunction

//     task run();
//         forever begin
//             @(posedge sw_if.clk);
//             #1;
//             tr = new();
//             tr.tick = sw_if.tick;
//             tr.sw_run_stop = sw_if.sw_run_stop;
//             tr.sw_clear = sw_if.sw_clear;
//             tr.disp_hour = sw_if.disp_hour;
//             tr.disp_min = sw_if.disp_min;
//             tr.disp_sec = sw_if.disp_sec;
//             tr.disp_msec = sw_if.disp_msec;
//             mon2scb_mbox.put(tr);
//             tr.display("mon");
//         end
//     endtask
// endclass

// class scoreboard;
//     transaction tr;
//     mailbox #(transaction) mon2scb_mbox;
//     event gen_next_ev;

//     int comp_msec, comp_sec, comp_min, comp_hour;
//     int pass_cnt, fail_cnt;

//     function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
//         this.mon2scb_mbox = mon2scb_mbox;
//         this.gen_next_ev  = gen_next_ev;
//     endfunction
//     task run();
//         forever begin
//             mon2scb_mbox.get(tr);

//             // 1단계: [0-Cycle Latency] 현재 사이클 즉시 반영 신호 (clear)
//             if (tr.sw_clear) begin
//                 comp_hour = 0;
//                 comp_min  = 0;
//                 comp_sec  = 0;
//                 comp_msec = 0;
//             end

//             // 2단계: [비교] 현재 출력과 예상값 비교
//             if ((tr.disp_msec == comp_msec) && (tr.disp_sec == comp_sec) &&
//                 (tr.disp_min  == comp_min)  && (tr.disp_hour == comp_hour)) begin
//                 pass_cnt++;
//             end else begin
//                 fail_cnt++;
//                 $display(
//                     "FAIL: comp_time:%02d:%02d:%02d.%02d | real_time:%02d:%02d:%02d.%02d",
//                     comp_hour, comp_min, comp_sec, comp_msec, tr.disp_hour,
//                     tr.disp_min, tr.disp_sec, tr.disp_msec);
//             end

//             // 3단계: [1-Cycle Latency] 다음 사이클 반영 신호 (tick)
//             // clear가 1일 때는 카운트가 무시되므로 조건에 !tr.sw_clear 추가
//             if (tr.tick) begin
//                 comp_msec++;
//                 if (comp_msec == 100) begin
//                     comp_msec = 0;
//                     comp_sec++;
//                     if (comp_sec == 60) begin
//                         comp_sec = 0;
//                         comp_min++;
//                         if (comp_min == 60) begin
//                             comp_min = 0;
//                             comp_hour++;
//                             if (comp_hour == 24) comp_hour = 0;
//                         end
//                     end
//                 end
//             end
//             ->gen_next_ev;
//         end
//     endtask
// endclass
// //     task run();
// //         forever begin
// //             mon2scb_mbox.get(tr);
// //             //compare
// //             if ((tr.disp_msec == comp_msec) && (tr.disp_sec == comp_sec) &&
// //                 (tr.disp_min  == comp_min)  && (tr.disp_hour == comp_hour)) begin
// //                 pass_cnt++;
// //             end else begin
// //                 fail_cnt++;
// //                 $display(
// //                     "FAIL: comp_time:%02d:%02d:%02d.%02d | real_time:%02d:%02d:%02d.%02d",
// //                     comp_hour, comp_min, comp_sec, comp_msec, tr.disp_hour,
// //                     tr.disp_min, tr.disp_sec, tr.disp_msec);
// //             end
// //             //clear
// //             if (tr.sw_clear) begin
// //                 comp_hour = 0;
// //                 comp_min  = 0;
// //                 comp_sec  = 0;
// //                 comp_msec = 0;
// //             end 
// //              //run
// //             else if (tr.tick) begin   //else if (tr.sw_run_stop && tr.tick) begin
// //                 comp_msec++;
// //                 if (comp_msec == 100) begin
// //                     comp_msec = 0;
// //                     comp_sec++;
// //                     if (comp_sec == 60) begin
// //                         comp_sec = 0;
// //                         comp_min++;
// //                         if (comp_min == 60) begin
// //                             comp_min = 0;
// //                             comp_hour++;
// //                             if (comp_hour == 24) comp_hour = 0;
// //                         end
// //                     end
// //                 end
// //             end
// //             ->gen_next_ev;
// //         end
// //     endtask
// // endclass

// class enviroment;

//     generator gen;
//     driver drv;
//     monitor mon;
//     scoreboard scb;

//     mailbox #(transaction) gen2drv_mbox;
//     mailbox #(transaction) mon2scb_mbox;

//     event gen_next_ev;

//     function new(virtual sw_interface sw_if);
//         gen2drv_mbox = new();
//         mon2scb_mbox = new();
//         gen = new(gen2drv_mbox, gen_next_ev);
//         drv = new(gen2drv_mbox, sw_if);
//         mon = new(mon2scb_mbox, sw_if);
//         scb = new(mon2scb_mbox, gen_next_ev);
//     endfunction

//     task run();
//         fork
//             gen.run(1000);
//             drv.run();
//             mon.run();
//             scb.run();
//         join_any
//         $display("**stopwatch run/stop/clear Verification**");
//         $display("-----------------------------------------");
//         $display("**pass_cnt = %3d                       **", scb.pass_cnt);
//         $display("**fail_cnt = %3d                       **", scb.fail_cnt);
//         $display("-----------------------------------------");
//         $stop;
//     endtask

// endclass


// module tb_stopwatch_watch ();

//     logic clk;
//     sw_interface sw_if (clk);
//     enviroment env;

//     watch_stopwatch_datapath dut (
//         .clk(clk),
//         .reset(sw_if.reset),
//         .mode(sw_if.mode),         
//         .count_mode(sw_if.count_mode),    
//         .w_edit_msec(sw_if.w_edit_msec),
//         .w_edit_sec(sw_if.w_edit_sec),
//         .w_edit_min(sw_if.w_edit_min),
//         .w_edit_hour(sw_if.w_edit_hour),
//         .sw_run_stop(sw_if.sw_run_stop),
//         .sw_clear(sw_if.sw_clear),
//         .disp_msec(sw_if.disp_msec),
//         .disp_sec(sw_if.disp_sec),
//         .disp_min(sw_if.disp_min),
//         .disp_hour(sw_if.disp_hour)
//     );
//     defparam dut.u_watch.U_TICK_GEN.F_COUNT = 10;
//         defparam dut.u_stopwatch.U_TICK_GEN.F_COUNT = 10;
//     assign sw_if.tick = dut.u_stopwatch.w_tick_100hz;

//     always #5 clk = ~clk;

//     initial begin
//         clk = 0;
//         env = new(sw_if);
//         env.drv.preset();
//         env.run();
//     end

// endmodule

