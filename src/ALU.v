module lipsi_alu (
    input [2:0] func,
    input [7:0] a,
    input [7:0] operand,
    input carry_in,
    output reg [7:0] result,
    output reg carry_out
);
    always @(*) begin
        carry_out = 0;
        case (func)
            3'b000: {carry_out, result} = a + operand;
            3'b001: {carry_out, result} = a - operand;

            3'b100: result = a & operand;
            3'b101: result = a | operand;
            3'b110: result = a ^ operand;
            3'b111: result = a;
        endcase
    end
endmodule