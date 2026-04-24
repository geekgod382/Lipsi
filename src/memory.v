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

        mem[8'h00] = 8'hF0;
        mem[8'h01] = 8'hC4;
        mem[8'h02] = 8'h01;
        mem[8'h03] = 8'hD3;
        mem[8'h04] = 8'h10;
        mem[8'h05] = 8'hF0;
        mem[8'h06] = 8'hC4;
        mem[8'h07] = 8'h02;
        mem[8'h08] = 8'hD3;
        mem[8'h09] = 8'h30;
        mem[8'h0A] = 8'hD0;
        mem[8'h0B] = 8'h60;

        mem[8'h10] = 8'hF0;
        mem[8'h11] = 8'h83;
        mem[8'h12] = 8'hC4;
        mem[8'h13] = 8'h00;
        mem[8'h14] = 8'h80;

        mem[8'h16] = 8'hC4;
        mem[8'h17] = 8'h00;
        mem[8'h18] = 8'h50;
        mem[8'h19] = 8'h03;
        mem[8'h1A] = 8'h80;
        mem[8'h1B] = 8'hF1;
        mem[8'h1C] = 8'hD0;
        mem[8'h1D] = 8'h16;

        mem[8'h30] = 8'hC4;
        mem[8'h31] = 8'h00;
        mem[8'h32] = 8'h80;
        mem[8'h33] = 8'hC0;
        mem[8'h34] = 8'h01;
        mem[8'h35] = 8'h81;

        mem[8'h36] = 8'hC4;
        mem[8'h37] = 8'h00;
        mem[8'h38] = 8'h51;
        mem[8'h39] = 8'hF1;

        mem[8'h3A] = 8'hC4;
        mem[8'h3B] = 8'h00;
        mem[8'h3C] = 8'h50;
        mem[8'h3D] = 8'h01;
        mem[8'h3E] = 8'h82;

        mem[8'h3F] = 8'hC4;
        mem[8'h40] = 8'h00;
        mem[8'h41] = 8'h51;
        mem[8'h42] = 8'h80;

        mem[8'h43] = 8'hC4;
        mem[8'h44] = 8'h00;
        mem[8'h45] = 8'h52;
        mem[8'h46] = 8'h81;
        mem[8'h47] = 8'hD2;
        mem[8'h48] = 8'h30;
        mem[8'h49] = 8'hD0;
        mem[8'h4A] = 8'h36;

        mem[8'h60] = 8'hF0;
        mem[8'h61] = 8'h83;

        mem[8'h62] = 8'hC4;
        mem[8'h63] = 8'h00;
        mem[8'h64] = 8'h53;
        mem[8'h65] = 8'hF1;
        mem[8'h66] = 8'hC4;
        mem[8'h67] = 8'h00;
        mem[8'h68] = 8'hF1;
        mem[8'h69] = 8'hD0;
        mem[8'h6A] = 8'h62;

    end

    always @(posedge clk) begin
        if (we)
            mem[wr_addr] <= wr_data;
    end

    always @(*) begin
        rd_data = mem[rd_addr];
    end

endmodule
