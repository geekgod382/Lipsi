`timescale 1ns/1ps

module lipsi_tb;

    reg clk;
    reg rst;
    reg clr;
    reg [15:0] sw;

    wire [15:0] led;
    wire [6:0] seg;
    wire [3:0] an;
    wire uart_tx;
    reg uart_rx = 1'b1;

    lipsi_top #(.CPU_HALF_PERIOD(27'd2)) uut (
        .clk(clk),
        .rst(rst),
        .clr(clr),
        .sw (sw),
        .led(led),
        .seg(seg),
        .an (an),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx)
    );

    initial clk = 0;
    always  #5 clk = ~clk;

    task wait_cpu_clocks;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge uut.clk_cpu);
        end
    endtask

    task do_reset;
        begin
            rst = 1;
            repeat(4) @(posedge clk);
            rst = 0;
            repeat(2) @(posedge clk);
        end
    endtask

    initial begin
        $display("Lipsi Processor Testbench");
        $display("Time: %0t | Starting tests", $time);

        rst = 1; clr = 0; sw = 16'h0000;
        repeat(4) @(posedge clk);
        rst = 0;
        $display("Time: %0t | Reset released", $time);

        $display("\nTEST 1: Mode 3 - beep pattern");
        sw = 16'h00AA;
        do_reset;
        $display("Time: %0t | XOR mode, mask=0xAA, waiting 20 CPU cycles...", $time);
        wait_cpu_clocks(20);
        $display("Time: %0t | LEDs: %08b", $time, led[7:0]);
        wait_cpu_clocks(1);
        $display("Time: %0t | LEDs: %08b", $time, led[7:0]);

        $display("\nTEST 2: Mode 1 - Step Counter");
        sw = 16'h2010;
        do_reset;
        $display("Time: %0t | Step counter, step=16", $time);
        wait_cpu_clocks(5);
        $display("Time: %0t | LEDs: %08b", $time, led[7:0]);
        wait_cpu_clocks(5);
        $display("Time: %0t | LEDs: %08b", $time, led[7:0]);
        wait_cpu_clocks(5);
        $display("Time: %0t | LEDs: %08b", $time, led[7:0]);
        wait_cpu_clocks(5);
        $display("Time: %0t | LEDs: %08b", $time, led[7:0]);

        $display("\nTEST 3: Mode 2 - Fibonacci");
        sw = 16'h4000;
        do_reset;
        $display("Time: %0t | Fibonacci mode", $time);
        wait_cpu_clocks(8);
        $display("Time: %0t | LEDs: %08b", $time, led[7:0]);
        wait_cpu_clocks(15);
        $display("Time: %0t | LEDs: %08b", $time, led[7:0]);
        wait_cpu_clocks(15);
        $display("Time: %0t | LEDs: %08b", $time, led[7:0]);
        wait_cpu_clocks(15);
        $display("Time: %0t | LEDs: %08b", $time, led[7:0]);
        wait_cpu_clocks(15);
        $display("Time: %0t | LEDs: %08b", $time, led[7:0]);
        wait_cpu_clocks(15);
        $display("Time: %0t | LEDs: %08b", $time, led[7:0]);

        $display("\nTEST 4: Soft Reset");
        wait_cpu_clocks(5);
        $display("Time: %0t | Before clr - LEDs: %08b", $time, led[7:0]);
        clr = 1;
        repeat(4) @(posedge clk);
        clr = 0;
        $display("Time: %0t | Soft reset applied", $time);
        wait_cpu_clocks(5);
        $display("Time: %0t | After clr  - LEDs: %08b", $time, led[7:0]);

        $display("\nTEST 5: Internal state check");
        sw = 16'h2010;
        do_reset;
        wait_cpu_clocks(3);
        $display("Time: %0t | PC=%03h  A=%02h  LEDs=%08b",
            $time, uut.u_cpu.PC, uut.u_cpu.A, led[7:0]);

        $display("\nTEST 6: Switch input - change XOR mask live");
        sw = 16'h00F0;
        do_reset;
        wait_cpu_clocks(10);
        $display("Time: %0t | mask=0xF0, LEDs: %08b", $time, led[7:0]);
        sw[7:0] = 8'h0F;
        wait_cpu_clocks(2);
        $display("Time: %0t | mask changed to 0x0F - LEDs: %08b", $time, led[7:0]);

        $display("\nTEST 7: Stability - Fibonacci long run");
        sw = 16'h4000;
        do_reset;
        begin : stability
            integer j;
            for (j = 0; j < 8; j = j + 1) begin
                wait_cpu_clocks(15);
                $display("Time: %0t | Fibonacci step %0d - LEDs: %08b", $time, j+1, led[7:0]);
            end
        end

        $display("\nTest Complete");
        $display("Time: %0t | All tests finished", $time);
        $finish;
    end

    initial begin
        $dumpfile("lipsi_tb.vcd");
        $dumpvars(0, lipsi_tb);
    end

endmodule
