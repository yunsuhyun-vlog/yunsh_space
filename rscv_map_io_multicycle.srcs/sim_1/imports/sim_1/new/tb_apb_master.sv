`timescale 1ns / 1ps

module tb_apb_master ();
    logic
        pclk,
        prst,
        wreq,
        rreq,
        ready,
        psel0,
        psel1,
        psel2,
        psel3,
        psel4,
        psel5,
        penable,
        pwrite,
        pready0,
        pready1,
        pready2,
        pready3,
        pready4,
        pready5;
    logic [31:0]
        addr,
        wdata,
        rdata,
        paddr,
        pwdata,
        prdata0,
        prdata1,
        prdata2,
        prdata3,
        prdata4,
        prdata5;

    apb_master dut (.*);

    always #5 pclk = ~pclk;

    initial begin
        #0 pclk = 0;
        prst  = 1;
        addr  = 0;
        rreq  = 0;
        wreq  = 0;
        wdata = 0;
        pready0 = 0; pready1 = 0; pready2 = 0; pready3 = 0; pready4 = 0; pready5 = 0;
        prdata0 = 0; prdata1 = 0; prdata2 = 0; prdata3 = 0; prdata4 = 0; prdata5 = 0;
        
        @(negedge pclk);
        @(negedge pclk);
        prst = 0;

        /* ---------------------------------------------------------
           1. psel0 (RAM: 0x1000_0000) - Write 0 & Read 0
        --------------------------------------------------------- */
        // Write 0
        @(posedge pclk); #1;
        addr  = 32'h1000_0000;
        wdata = 32'h0000_0000;
        wreq  = 1;
        wait(psel0 && penable);
        pready0 = 1;
        @(posedge pclk); #1;
        pready0 = 0;
        wreq = 0;
        
        // Read 0
        @(posedge pclk); #1;
        addr  = 32'h1000_0000;
        rreq  = 1;
        wait(psel0 && penable);
        pready0 = 1;
        prdata0 = 32'h0000_0000;
        @(posedge pclk); #1;
        pready0 = 0;
        rreq = 0;

        /* ---------------------------------------------------------
           2. psel1 (GPO: 0x2000_0000) - Write 1 
        --------------------------------------------------------- */
        // Write 1
        @(posedge pclk); #1;
        addr  = 32'h2000_0000;
        wdata = 32'h0000_0001;
        wreq  = 1;
        wait(psel1 && penable);
        pready1 = 1;
        @(posedge pclk); #1;
        pready1 = 0;
        wreq = 0;

        /* ---------------------------------------------------------
           3. psel2 (GPI: 0x2000_1000) -  Read 2
        --------------------------------------------------------- */

        // Read 2
        @(posedge pclk); #1;
        addr  = 32'h2000_1000;
        rreq  = 1;
        wait(psel2 && penable);
        pready2 = 1;
        prdata2 = 32'h0000_0002;
        @(posedge pclk); #1;
        pready2 = 0;
        rreq = 0;

        /* ---------------------------------------------------------
           4. psel3 (GPIO: 0x2000_2000) - Write 3 & Read 3
        --------------------------------------------------------- */
        // Write 3
        @(posedge pclk); #1;
        addr  = 32'h2000_2000;
        wdata = 32'h0000_0003;
        wreq  = 1;
        wait(psel3 && penable);
        pready3 = 1;
        @(posedge pclk); #1;
        pready3 = 0;
        wreq = 0;

        // Read 3
        @(posedge pclk); #1;
        addr  = 32'h2000_2000;
        rreq  = 1;
        wait(psel3 && penable);
        pready3 = 1;
        prdata3 = 32'h0000_0003;
        @(posedge pclk); #1;
        pready3 = 0;
        rreq = 0;

        /* ---------------------------------------------------------
           5. psel4 (FND: 0x2000_3000) - Write 4 & Read 4
        --------------------------------------------------------- */
        // Write 4
        @(posedge pclk); #1;
        addr  = 32'h2000_3000;
        wdata = 32'h0000_0004;
        wreq  = 1;
        wait(psel4 && penable);
        pready4 = 1;
        @(posedge pclk); #1;
        pready4 = 0;
        wreq = 0;

        // Read 4
        @(posedge pclk); #1;
        addr  = 32'h2000_3000;
        rreq  = 1;
        wait(psel4 && penable);
        pready4 = 1;
        prdata4 = 32'h0000_0004;
        @(posedge pclk); #1;
        pready4 = 0;
        rreq = 0;

        /* ---------------------------------------------------------
           6. psel5 (UART: 0x2000_4000) - Write 5 & Read 5
        --------------------------------------------------------- */
        // Write 5
        @(posedge pclk); #1;
        addr  = 32'h2000_4000;
        wdata = 32'h0000_0005;
        wreq  = 1;
        wait(psel5 && penable);
        pready5 = 1;
        @(posedge pclk); #1;
        pready5 = 0;
        wreq = 0;

        // Read 5
        @(posedge pclk); #1;
        addr  = 32'h2000_4000;
        rreq  = 1;
        wait(psel5 && penable);
        pready5 = 1;
        prdata5 = 32'h0000_0005;
        @(posedge pclk); #1;
        pready5 = 0;
        rreq = 0;

        // 시뮬레이션 종료
        @(posedge pclk);
        @(posedge pclk);
        $stop;
    end
endmodule
        
        
        // `timescale 1ns / 1ps

// module tb_apb_master ();
//     logic
//         pclk,
//         prst,
//         wreq,
//         rreq,
//         ready,
//         psel0,
//         psel1,
//         psel2,
//         psel3,
//         psel4,
//         psel5,
//         penable,
//         pwrite,
//         pready0,
//         pready1,
//         pready2,
//         pready3,
//         pready4,
//         pready5;
//     logic [31:0]
//         addr,
//         wdata,
//         rdata,
//         paddr,
//         pwdata,
//         prdata0,
//         prdata1,
//         prdata2,
//         prdata3,
//         prdata4,
//         prdata5;

//     apb_master dut (.*);

//     always #5 pclk = ~pclk;

//     initial begin
//         #0 pclk = 0;
//         prst  = 1;
//         addr  = 0;
//         rreq  = 0;
//         wreq  = 0;
//         wdata = 0;
//         @(negedge pclk);
//         @(negedge pclk);
//         prst = 0;

//         //ram write test,0x1000_0000
//         @(posedge pclk);
//         #1;
//         addr  = 32'h1000_0000;
//         wdata = 32'h0000_0041;
//         wreq  = 1;
//         // @(posedge pclk);
//         // #1;
//         @(psel0 & penable) pready0 = 1;
//         @(posedge pclk);
//         #1;
//         pready0 = 0;
//         wreq =0;


//         //UART read test with 2cycle waiting ,0x2000_4000, 
//         @(posedge pclk);
//         #1;
//         rreq  = 1;
//         addr  = 32'h2000_4000;

//         @(psel5 & penable);
//         @(posedge pclk);
//         @(posedge pclk);
//         #1;
//         pready5 = 1;
//         prdata5 = 32'h0000_0041;
        
//         @(posedge pclk);
//         #1;
//         pready5 =1'b0;
//         rreq =0;
//         @(posedge pclk);
//         @(posedge pclk);
//         $stop;
//     end
// endmodule
