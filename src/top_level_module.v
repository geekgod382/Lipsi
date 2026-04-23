// ============================================================
//  Lipsi Top-Level — Basys3
//
//  This instantiates the REAL lipsi.v processor core.
//  The processor fetches instructions from baked-in memory
//  and runs autonomously — no switch fiddling needed.
//
//  What you'll see on the board:
//    • 7-segment display counts up 00→01→02…FF and wraps
//    • LEDs mirror the low 5 bits of the accumulator
//    • BTNC (rst) resets PC and accumulator to 0
//    • BTNU (clr) clears accumulator but keeps PC
//    • SW[7:0] are readable by the program via IO read (0xF0)
//      (useful if you expand the program later)
//
//  Clock:  100 MHz Basys3 oscillator → divided to ~1 Hz so
//          you can actually watch the counter tick.
// ============================================================
module lipsi_top (
    input        clk,         // 100 MHz
    input        rst,         // BTNC — full reset
    input        clr,         // BTNU — clear accumulator
    input  [7:0] sw,          // SW15-SW8 ignored; SW7-SW0 → io_in
    output [7:0] leds,        // LD7-LD0  ← io_out from processor
    output [6:0] seg,
    output [3:0] an
);

    // ── Slow clock so the counter is visible ─────────────────
    wire clk_slow;
    clk_div #(.HALF_PERIOD(27'd49_999_999)) u_clkdiv (
        .clk(clk), .rst(rst), .clk_slow(clk_slow)
    );

    // ── Lipsi processor core ──────────────────────────────────
    wire [7:0] io_out;

    lipsi u_cpu (
        .clk    (clk_slow),
        .rst    (rst),
        .clr    (clr),
        .io_in  (sw),
        .io_out (io_out)
    );

    // ── Outputs ───────────────────────────────────────────────
    assign leds = io_out;

    seven_seg u_seg (
        .clk(clk),          // 7-seg multiplexer runs at full speed
        .rst(rst),
        .val(io_out),
        .seg(seg),
        .an (an)
    );

endmodule
