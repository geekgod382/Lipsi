module lipsi_top (
    input        clk,
    input        rst,
    input        clr,
    input  [7:0] sw,
    output [7:0] leds,
    output [6:0] seg,
    output [3:0] an
);

    wire clk_slow;
    clk_div #(.HALF_PERIOD(27'd24_999_999)) u_clkdiv (
        .clk     (clk),
        .rst     (rst),
        .clk_slow(clk_slow)
    );

    wire [7:0] io_out;

    lipsi u_cpu (
        .clk    (clk_slow),
        .rst    (rst),
        .clr    (clr),
        .io_in  (sw),
        .io_out (io_out)
    );

    assign leds = io_out;

    seven_seg u_seg (
        .clk(clk),
        .rst(rst),
        .val(io_out),
        .seg(seg),
        .an (an)
    );

endmodule
