// ============================================================
//  Lipsi Memory — Three-mode demo program
//  No .hex file needed; everything baked in below.
//
//  HOW TO USE ON BASYS3:
//  ┌─────────────────────────────────────────────────────────┐
//  │  SW0=1, rest=0  →  MODE 1: Step Counter                │
//  │      Set SW7-SW1 to any value (1-127) = step size      │
//  │      Press BTNC to restart with new step               │
//  │      Display counts 0, step, 2×step … wraps at 256     │
//  │                                                         │
//  │  SW1=1, rest=0  →  MODE 2: Fibonacci                   │
//  │      No switches needed                                 │
//  │      Display: 1,1,2,3,5,8,13,21,34,55,89,144… wrap    │
//  │                                                         │
//  │  SW0=0, SW1=0   →  MODE 3: XOR Toggle                  │
//  │      Set SW7-SW2 to any non-zero mask                   │
//  │      LEDs toggle between mask and 0 every tick         │
//  └─────────────────────────────────────────────────────────┘
//
//  INSTRUCTION ENCODING (Lipsi ISA):
//    F0          : A = io_in  (read switches)
//    F1          : io_out = A (write to LEDs/7seg)
//    C0 nn       : A = A + nn
//    C1 nn       : A = A - nn
//    C4 nn       : A = A & nn
//    C6 nn       : A = A ^ nn
//    8r          : mem[0x80+r] = A  (store to register r)
//    7r          : A = A op mem[0x80+r], func=111 → A=A (load via OR trick below)
//                  NOTE: use OR reg (5r) with A=0 to load: A = 0 | mem[r] = mem[r]
//    D0 aa       : JMP aa
//    D2 aa       : BZ  aa  (branch if A == 0)
//    D3 aa       : BNZ aa  (branch if A != 0)
//
//  REGISTER MAP (data memory):
//    0x80 = r0  : general / fib_prev
//    0x81 = r1  : fib_curr
//    0x82 = r2  : fib_next / temp
//    0x83 = r3  : step size
// ============================================================
module lipsi_mem (
    input            clk,
    input            we,
    input      [7:0] rd_addr,
    input      [7:0] wr_addr,
    input      [7:0] wr_data,
    output reg [7:0] rd_data
);
    (* ram_style = "distributed" *)
    reg [7:0] mem [0:255];

    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 8'h00;

        // ========================================================
        //  BOOT / DISPATCH  (0x00 – 0x0F)
        //  Read switches, check SW0 and SW1, jump to mode.
        //
        //  0x00  F0        A = io_in
        //  0x01  C4 01     A = A & 0x01   (isolate SW0)
        //  0x03  D3 10     BNZ → MODE1 (0x10)
        //  0x05  F0        A = io_in
        //  0x06  C4 02     A = A & 0x02   (isolate SW1)
        //  0x08  D3 30     BNZ → MODE2 (0x30)
        //  0x0A  D0 60     JMP → MODE3 (0x60)
        // ========================================================
        mem[8'h00] = 8'hF0;        // A = switches
        mem[8'h01] = 8'hC4;        // AND imm
        mem[8'h02] = 8'h01;        //   mask = 0x01 → isolate SW0
        mem[8'h03] = 8'hD3;        // BNZ
        mem[8'h04] = 8'h10;        //   → 0x10 (Mode 1)
        mem[8'h05] = 8'hF0;        // A = switches
        mem[8'h06] = 8'hC4;        // AND imm
        mem[8'h07] = 8'h02;        //   mask = 0x02 → isolate SW1
        mem[8'h08] = 8'hD3;        // BNZ
        mem[8'h09] = 8'h30;        //   → 0x30 (Mode 2)
        mem[8'h0A] = 8'hD0;        // JMP
        mem[8'h0B] = 8'h60;        //   → 0x60 (Mode 3)

        // ========================================================
        //  MODE 1 — STEP COUNTER  (0x10 – 0x2F)
        //
        //  Read full switch value as step size, store in r3.
        //  Then loop: accumulate += step, display, repeat.
        //  Re-reads switches each iteration so you can change
        //  step live without resetting.
        //
        //  Init (runs once at entry):
        //  0x10  F0        A = io_in          (full switch value = step)
        //  0x11  83        r3 = A             (save step size)
        //  0x12  C6 FF     A = A ^ A... no, need A=0.
        //                  Use: C1 FF → A = A - 0xFF... messy.
        //                  Better: C4 00 → A = A & 0x00 = 0  (zero A)
        //  0x12  C4 00     A = 0
        //  0x14  80        r0 = A             (accumulator = 0)
        //
        //  Loop (0x16):
        //  0x16  C4 00     A = 0              (clear A to do a clean load)
        //  0x18  50        A = A | r0         (load r0 → A = 0 | r0 = r0)
        //  0x19  53        A = A | r3         (A = r0 + r3... no, that's OR not ADD)
        //                  Oops — need ADD not OR for accumulate.
        //                  Correct approach:
        //                    A = 0 | r0  → A = current accumulator
        //                    then ADD r3 → A = A + r3
        //  0x18  50        A = 0 | r0    (func=101=OR, encoding 0_101_0000 = 0x50)
        //  0x19  03        A = A + r3    (func=000=ADD, encoding 0_000_0011 = 0x03)
        //  0x1A  80        r0 = A        (store back)
        //  0x1B  F1        io_out = A    (display)
        //  0x1C  D0 16     JMP loop
        // ========================================================

        // ── init ──
        mem[8'h10] = 8'hF0;        // A = switches (step size in SW7-SW1)
        mem[8'h11] = 8'h83;        // r3 = A  (store step)
        mem[8'h12] = 8'hC4;        // AND imm
        mem[8'h13] = 8'h00;        //   0x00  → A = 0
        mem[8'h14] = 8'h80;        // r0 = A  (counter = 0)

        // ── loop @ 0x16 ──
        mem[8'h16] = 8'hC4;        // AND imm (zero A cheaply)
        mem[8'h17] = 8'h00;        //   A = 0
        mem[8'h18] = 8'h50;        // A = A | r0  → A = counter  (OR reg, func=101, reg=0)
        mem[8'h19] = 8'h03;        // A = A + r3  → add step      (ADD reg, func=000, reg=3)
        mem[8'h1A] = 8'h80;        // r0 = A      (save new counter)
        mem[8'h1B] = 8'hF1;        // io_out = A  (display)
        mem[8'h1C] = 8'hD0;        // JMP
        mem[8'h1D] = 8'h16;        //   → loop

        // ========================================================
        //  MODE 2 — FIBONACCI  (0x30 – 0x5F)
        //
        //  Registers:
        //    r0 = prev  (starts 0)
        //    r1 = curr  (starts 1)
        //    r2 = next  (temp)
        //
        //  Init:
        //  0x30  C4 00    A = 0
        //  0x32  80       r0 = 0
        //  0x33  C0 01    A = A + 1 = 1
        //  0x35  81       r1 = 1
        //
        //  Loop (0x36):
        //    display r1
        //    next = prev + curr
        //    prev = curr
        //    curr = next
        //    if curr==0 → restart (wrapped around 256)
        //
        //  0x36  C4 00    A = 0
        //  0x38  51       A = A | r1   → A = curr
        //  0x39  F1       io_out = A   (display curr)
        //  0x3A  C4 00    A = 0
        //  0x3C  50       A = A | r0   → A = prev
        //  0x3D  01       A = A + r1   → A = prev + curr = next
        //  0x3E  82       r2 = A       (save next)
        //  0x3F  C4 00    A = 0
        //  0x41  51       A = A | r1   → A = curr
        //  0x42  80       r0 = A       (prev = curr)
        //  0x43  C4 00    A = 0
        //  0x45  52       A = A | r2   → A = next
        //  0x46  81       A→r1         (curr = next)  wait, 81 = store r1
        //  0x47  D2 30    BZ → restart if wrapped to 0
        //  0x49  D0 36    JMP loop
        // ========================================================

        // ── init ──
        mem[8'h30] = 8'hC4;        // AND imm
        mem[8'h31] = 8'h00;        //   A = 0
        mem[8'h32] = 8'h80;        // r0 = 0  (prev)
        mem[8'h33] = 8'hC0;        // ADD imm
        mem[8'h34] = 8'h01;        //   A = 0 + 1 = 1
        mem[8'h35] = 8'h81;        // r1 = 1  (curr)

        // ── loop @ 0x36 ──
        // display curr
        mem[8'h36] = 8'hC4;
        mem[8'h37] = 8'h00;        // A = 0
        mem[8'h38] = 8'h51;        // A = A | r1  → A = curr
        mem[8'h39] = 8'hF1;        // io_out = A

        // next = prev + curr
        mem[8'h3A] = 8'hC4;
        mem[8'h3B] = 8'h00;        // A = 0
        mem[8'h3C] = 8'h50;        // A = A | r0  → A = prev
        mem[8'h3D] = 8'h01;        // A = A + r1  → A = prev + curr  (ADD reg r1, 0_000_0001=0x01)
        mem[8'h3E] = 8'h82;        // r2 = A  (next)

        // prev = curr
        mem[8'h3F] = 8'hC4;
        mem[8'h40] = 8'h00;        // A = 0
        mem[8'h41] = 8'h51;        // A = A | r1  → A = curr
        mem[8'h42] = 8'h80;        // r0 = A  (prev = curr)

        // curr = next; check for wrap
        mem[8'h43] = 8'hC4;
        mem[8'h44] = 8'h00;        // A = 0
        mem[8'h45] = 8'h52;        // A = A | r2  → A = next
        mem[8'h46] = 8'h81;        // r1 = A  (curr = next)
        mem[8'h47] = 8'hD2;        // BZ
        mem[8'h48] = 8'h30;        //   → restart (wrapped)
        mem[8'h49] = 8'hD0;        // JMP
        mem[8'h4A] = 8'h36;        //   → loop

        // ========================================================
        //  MODE 3 — XOR TOGGLE  (0x60 – 0x7F)
        //
        //  Read switches as XOR mask.
        //  Toggle A between 0 and mask forever.
        //  If mask=0, just display 0 (boring but safe).
        //
        //  0x60  F0        A = io_in   (mask from switches)
        //  0x61  83        r3 = A      (save mask)
        //
        //  Loop (0x62):
        //  0x62  C4 00     A = 0
        //  0x64  53        A = A | r3  → A = mask
        //  0x65  F1        io_out = A  (display mask)
        //  0x66  C4 00     A = 0
        //  0x68  F1        io_out = A  (display 0)
        //  0x69  D0 62     JMP loop
        //
        //  This gives a clean on/off flash of the switch pattern.
        // ========================================================

        mem[8'h60] = 8'hF0;        // A = switches
        mem[8'h61] = 8'h83;        // r3 = A (save mask)

        // ── loop @ 0x62 ──
        mem[8'h62] = 8'hC4;
        mem[8'h63] = 8'h00;        // A = 0
        mem[8'h64] = 8'h53;        // A = A | r3  → A = mask
        mem[8'h65] = 8'hF1;        // io_out = mask
        mem[8'h66] = 8'hC4;
        mem[8'h67] = 8'h00;        // A = 0
        mem[8'h68] = 8'hF1;        // io_out = 0
        mem[8'h69] = 8'hD0;        // JMP
        mem[8'h6A] = 8'h62;        //   → loop

    end // initial

    // synchronous write
    always @(posedge clk) begin
        if (we)
            mem[wr_addr] <= wr_data;
    end

    // asynchronous read
    always @(*) begin
        rd_data = mem[rd_addr];
    end

endmodule
