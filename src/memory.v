module lipsi_mem (
    input            clk,
    input            we,
    input      [8:0] rd_addr,   // 9-bit address (512 locations)
    input      [8:0] wr_addr,
    input      [7:0] wr_data,
    output reg [7:0] rd_data
);
    (* ram_style = "block" *)   // use BRAM on Basys3 for 512 bytes
    reg [7:0] mem [0:511];

    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1)
            mem[i] = 8'h00;

        //  DISPATCHER  (0x00 – 0x17)
        //
        //  Checks mode switches in priority order:
        //  1. SW15+SW13 both → Mode 5 Echo       → 0x90
        //  2. SW13 only      → Mode 1 Step        → 0x18
        //  3. SW14 only      → Mode 2 Fibonacci   → 0x25
        //  4. SW15 only      → Mode 4 Hello World → 0x50
        //  5. default        → Mode 3 XOR Toggle  → 0x43
        //
        //  Mode5 check: A = mode & 0x05, A = A-5, BZ→Mode5
        //  (A==0 only when SW15=1 AND SW13=1)
        mem[9'h00] = 8'hF2;
        mem[9'h01] = 8'hC4; mem[9'h02] = 8'h05;   // A & 0x05
        mem[9'h03] = 8'hC1; mem[9'h04] = 8'h05;   // A - 5
        mem[9'h05] = 8'hD2; mem[9'h06] = 8'h90;   // BZ → Mode5 @ 0x90

        mem[9'h07] = 8'hF2;
        mem[9'h08] = 8'hC4; mem[9'h09] = 8'h01;   // A & 0x01 (SW13)
        mem[9'h0A] = 8'hD3; mem[9'h0B] = 8'h18;   // BNZ → Mode1 @ 0x18

        mem[9'h0C] = 8'hF2;
        mem[9'h0D] = 8'hC4; mem[9'h0E] = 8'h02;   // A & 0x02 (SW14)
        mem[9'h0F] = 8'hD3; mem[9'h10] = 8'h25;   // BNZ → Mode2 @ 0x25

        mem[9'h11] = 8'hF2;
        mem[9'h12] = 8'hC4; mem[9'h13] = 8'h04;   // A & 0x04 (SW15)
        mem[9'h14] = 8'hD3; mem[9'h15] = 8'h50;   // BNZ → Mode4 @ 0x50

        mem[9'h16] = 8'hD0; mem[9'h17] = 8'h43;   // JMP → Mode3 @ 0x43

        //  MODE 1 — STEP COUNTER  (0x18 – 0x24)
        //
        //  r3 = step size (from SW7-SW0)
        //  r0 = running counter (starts at 0)
        //  Each tick: r0 += r3, display r0 on LEDs+7seg
        //
        //  Load register: A=0 then OR reg (func=101)
        //  Example: load r0 → C4 00 (A=0), 50 (A|r0)
        //  Add r3 to A:  03 (A+r3, func=000, reg=3)
        mem[9'h18] = 8'hF0;                        // A = data switches (step)
        mem[9'h19] = 8'h83;                        // r3 = step
        mem[9'h1A] = 8'hC4; mem[9'h1B] = 8'h00;   // A = 0
        mem[9'h1C] = 8'h80;                        // r0 = 0 (counter init)

        // loop @ 0x1D
        mem[9'h1D] = 8'hC4; mem[9'h1E] = 8'h00;   // A = 0
        mem[9'h1F] = 8'h50;                        // A = r0 (load counter)
        mem[9'h20] = 8'h03;                        // A = A + r3 (add step)
        mem[9'h21] = 8'h80;                        // r0 = A
        mem[9'h22] = 8'hF1;                        // io_out = A (display)
        mem[9'h23] = 8'hD0; mem[9'h24] = 8'h1D;   // JMP loop

        //  MODE 2 — FIBONACCI  (0x25 – 0x42)
        //
        //  r0=prev(0), r1=curr(1), r2=next
        //  Displays curr each tick, restarts on 256-wrap
        mem[9'h25] = 8'hC4; mem[9'h26] = 8'h00;   // A = 0
        mem[9'h27] = 8'h80;                        // r0 = 0 (prev)
        mem[9'h28] = 8'hC0; mem[9'h29] = 8'h01;   // A = 1
        mem[9'h2A] = 8'h81;                        // r1 = 1 (curr)

        // loop @ 0x2B
        mem[9'h2B] = 8'hC4; mem[9'h2C] = 8'h00;
        mem[9'h2D] = 8'h51;                        // A = curr
        mem[9'h2E] = 8'hF1;                        // display curr

        mem[9'h2F] = 8'hC4; mem[9'h30] = 8'h00;
        mem[9'h31] = 8'h50;                        // A = prev
        mem[9'h32] = 8'h01;                        // A = prev + curr
        mem[9'h33] = 8'h82;                        // r2 = next

        mem[9'h34] = 8'hC4; mem[9'h35] = 8'h00;
        mem[9'h36] = 8'h51;                        // A = curr
        mem[9'h37] = 8'h80;                        // r0 = curr (prev=curr)

        mem[9'h38] = 8'hC4; mem[9'h39] = 8'h00;
        mem[9'h3A] = 8'h52;                        // A = next
        mem[9'h3B] = 8'h81;                        // r1 = next (curr=next)
        mem[9'h3C] = 8'hD2; mem[9'h3D] = 8'h25;   // BZ → restart (overflowed)
        mem[9'h3E] = 8'hD0; mem[9'h3F] = 8'h2B;   // JMP loop

        //  MODE 3 — XOR TOGGLE  (0x43 – 0x4F)
        //
        //  r3 = XOR mask (from SW7-SW0)
        //  Alternates LEDs between mask and 0x00
        mem[9'h43] = 8'hF0;                        // A = data switches (mask)
        mem[9'h44] = 8'h83;                        // r3 = mask

        // loop @ 0x45
        mem[9'h45] = 8'hC4; mem[9'h46] = 8'h00;
        mem[9'h47] = 8'h53;                        // A = r3 (mask)
        mem[9'h48] = 8'hF1;                        // display mask
        mem[9'h49] = 8'hC4; mem[9'h4A] = 8'h00;   // A = 0
        mem[9'h4B] = 8'hF1;                        // display 0
        mem[9'h4C] = 8'hD0; mem[9'h4D] = 8'h45;   // JMP loop

        //  MODE 4 — HELLO WORLD  (0x50 – 0x8F)
        //
        //  Sends "Hello!\r\n" via UART with busy-poll before each char.
        //  Busy-poll + send sequence per character (5 bytes):
        //    poll: F5        A = TX busy flag
        //          D3 poll   BNZ poll  (spin while busy)
        //          C0 CC     A = ASCII code
        //          F3        UART send
        //
        //  After sending all chars: HALT (JMP to self)
        //  Press BTNC to reset and print again.
        //
        //  Characters: H(48) e(65) l(6C) l(6C) o(6F) !(21) \r(0D) \n(0A)
        //  8 chars × 5 bytes = 40 bytes → 0x50–0x77, then HALT at 

        // 'H' = 0x48
        mem[9'h50] = 8'hF5;
        mem[9'h51] = 8'hD3; mem[9'h52] = 8'h50;   // BNZ poll
        mem[9'h53] = 8'hC0; mem[9'h54] = 8'h48;   // A = 'H'
        mem[9'h55] = 8'hF3;                        // send

        // 'e' = 0x65
        mem[9'h56] = 8'hF5;
        mem[9'h57] = 8'hD3; mem[9'h58] = 8'h56;
        mem[9'h59] = 8'hC0; mem[9'h5A] = 8'h65;   // A = 'e'
        mem[9'h5B] = 8'hF3;

        // 'l' = 0x6C
        mem[9'h5C] = 8'hF5;
        mem[9'h5D] = 8'hD3; mem[9'h5E] = 8'h5C;
        mem[9'h5F] = 8'hC0; mem[9'h60] = 8'h6C;   // A = 'l'
        mem[9'h61] = 8'hF3;

        // 'l' = 0x6C
        mem[9'h62] = 8'hF5;
        mem[9'h63] = 8'hD3; mem[9'h64] = 8'h62;
        mem[9'h65] = 8'hC0; mem[9'h66] = 8'h6C;   // A = 'l'
        mem[9'h67] = 8'hF3;

        // 'o' = 0x6F
        mem[9'h68] = 8'hF5;
        mem[9'h69] = 8'hD3; mem[9'h6A] = 8'h68;
        mem[9'h6B] = 8'hC0; mem[9'h6C] = 8'h6F;   // A = 'o'
        mem[9'h6D] = 8'hF3;

        // '!' = 0x21
        mem[9'h6E] = 8'hF5;
        mem[9'h6F] = 8'hD3; mem[9'h70] = 8'h6E;
        mem[9'h71] = 8'hC0; mem[9'h72] = 8'h21;   // A = '!'
        mem[9'h73] = 8'hF3;

        // '\r' = 0x0D
        mem[9'h74] = 8'hF5;
        mem[9'h75] = 8'hD3; mem[9'h76] = 8'h74;
        mem[9'h77] = 8'hC0; mem[9'h78] = 8'h0D;   // A = '\r'
        mem[9'h79] = 8'hF3;

        // '\n' = 0x0A
        mem[9'h7A] = 8'hF5;
        mem[9'h7B] = 8'hD3; mem[9'h7C] = 8'h7A;
        mem[9'h7D] = 8'hC0; mem[9'h7E] = 8'h0A;   // A = '\n'
        mem[9'h7F] = 8'hF3;

        // HALT — JMP to self
        mem[9'h80] = 8'hD0; mem[9'h81] = 8'h80;

        //  MODE 5 — ECHO  (0x90 – 0x96)
        //
        //  Polls UART RX latch via F4.
        //  If non-zero → a byte arrived, echo it back via F3.
        //  Loop forever.
        //
        //  Note: rx_latch in top_level holds the last received
        //  byte. It is updated whenever uart_rx fires.
        //  CPU polls at 4Hz — comfortable for interactive typing.

        // loop @ 0x90
        mem[9'h90] = 8'hF4;                        // A = rx_latch
        mem[9'h91] = 8'hD2; mem[9'h92] = 8'h90;   // BZ loop (nothing yet)
        mem[9'h93] = 8'hF5;
        mem[9'h94] = 8'hD3; mem[9'h95] = 8'h93;   // wait until TX ready
        mem[9'h96] = 8'hF4;                        // re-read byte (A may have changed)
        mem[9'h97] = 8'hF3;                        // echo
        mem[9'h98] = 8'hD0; mem[9'h99] = 8'h90;   // JMP loop

    end // initial

    always @(posedge clk) begin
        if (we) mem[wr_addr] <= wr_data;
    end

    always @(*) begin
        rd_data = mem[rd_addr];
    end

endmodule
