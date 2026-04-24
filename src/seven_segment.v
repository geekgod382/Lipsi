module seven_seg (
    input clk,
    input rst,
    input [7:0] val,
    output reg [6:0] seg,
    output reg [3:0] an
);
    reg [16:0] refresh_cnt;
    wire [1:0] sel;

    always @(posedge clk or posedge rst) begin
        if (rst) refresh_cnt <= 0;
        else     refresh_cnt <= refresh_cnt + 1;
    end

    assign sel = refresh_cnt[16:15];

    reg [3:0] digit;

    always @(*) begin
        case (sel)
            2'b00: begin an = 4'b1110; digit = 4'h0;  end
            2'b01: begin an = 4'b1101; digit = 4'h0;  end
            2'b10: begin an = 4'b1011; digit = val[7:4]; end
            2'b11: begin an = 4'b0111; digit = val[3:0]; end
    always @(*) begin
        case (digit)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
        endcase
    end
endmodule