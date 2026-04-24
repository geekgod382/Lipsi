module clk_div #(
    parameter [26:0] HALF_PERIOD = 27'd49_999_999
) (
    input  clk,
    input  rst,
    output reg clk_slow
);
    reg [26:0] counter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter  <= 0;
            clk_slow <= 0;
        end else begin
            if (counter >= HALF_PERIOD) begin
                counter  <= 0;
                clk_slow <= ~clk_slow;
            end else begin
                counter <= counter + 1;
            end
        end
    end
endmodule
