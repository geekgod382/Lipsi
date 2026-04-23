// ============================================================
//  Lipsi Top-Level — Basys3
//
//  Instantiates the real Lipsi processor core. The CPU runs
//  a program stored in memory and operates fully autonomously.
//
//  ┌─────────────────────────────────────────────────────────┐
//  │  HOW TO USE                                             │
//  │                                                         │
//  │  1. Set switches BEFORE pressing reset (BTNC)           │
//  │     SW0=1          → Mode 1: Step Counter               │
//  │     SW1=1          → Mode 2: Fibonacci                  │
//  │     SW0=0, SW1=0   → Mode 3: XOR Toggle                 │
//  │                                                         │
//  │  2. Press BTNC to (re)start. CPU reads switches,        │
//  │     dispatches to the selected mode, and runs forever.  │
//  │                                                         │
//  │  Mode 1: SW7-SW1 set the step size.                     │
//  │          Display counts 0, N, 2N, 3N … (wraps at 256)   │
//  │  Mode 2: No extra switches needed.                      │
//  │          Display shows Fibonacci: 1,1,2,3,5,8,13,21…    │
//  │  Mode 3: SW7-SW2 set the blink pattern.                 │
//  │          LEDs flash that pattern on/off repeatedly.     │
//  │                                                         │
//  │  BTNU = clear accumulator (soft reset, keeps PC)        │
//  └─────────────────────────────────────────────────────────┘
//
//  Clock: 100 MHz → divided to 4 Hz for the CPU.
//         7-seg multiplexer always runs at 100 MHz.
// ============================================================
module lipsi_top (
    input        clk,         // 100 MHz Basys3 oscillator
    input        rst,         // BTNC — full reset (restart program)
    input        clr,         // BTNU — clear accumulator only
    input  [7:0] sw,          // SW7-SW0 → io_in to CPU
    output [7:0] leds,        // LD7-LD0 ← io_out from CPU
    output [6:0] seg,         // 7-segment segments
    output [3:0] an           // 7-segment digit select
);

    // ── Slow clock: 100 MHz → 4 Hz ───────────────────────────
    // HALF_PERIOD = (100_000_000 / (2 * 4)) - 1 = 12_499_999
    // At 4 Hz each mode step is clearly visible:
    //   Mode 1/2: new number every 250ms — easy to follow
    //   Mode 3:   LEDs flash at 2 Hz — clearly a pattern, not noise
    wire clk_slow;
    clk_div #(.HALF_PERIOD(27'd12_499_999)) u_clkdiv (
        .clk     (clk),
        .rst     (rst),
        .clk_slow(clk_slow)
    );

    // ── Lipsi processor core ──────────────────────────────────
    wire [7:0] io_out;

    lipsi u_cpu (
        .clk    (clk_slow),   // CPU ticks at 4 Hz
        .rst    (rst),
        .clr    (clr),
        .io_in  (sw),
        .io_out (io_out)
    );

    // ── Outputs ───────────────────────────────────────────────
    assign leds = io_out;

    // 7-seg multiplexer runs at full 100 MHz — no flicker
    seven_seg u_seg (
        .clk(clk),
        .rst(rst),
        .val(io_out),
        .seg(seg),
        .an (an)
    );

endmodule
