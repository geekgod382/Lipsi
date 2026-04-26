module uart_tx (
    input clk,
    input rst,
    input tx_start,
    input [7:0] tx_data,
    output reg tx,
    output reg tx_busy
);
    localparam CLK_PER_BIT = 10416;

    reg [13:0] clk_count;
    reg [3:0] bit_index;
    reg [9:0] shift_reg;

    localparam IDLE = 2'd0;
    localparam START = 2'd1;
    localparam DATA = 2'd2;
    localparam STOP = 2'd3;

    reg [1:0] state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx <= 1'b1;
            tx_busy <= 1'b0;
            clk_count <= 0;
            bit_index <= 0;
        end else begin
            case (state)

                IDLE: begin
                    tx <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        shift_reg <= {1'b1, tx_data, 1'b0};
                        clk_count <= 0;
                        bit_index <= 0;
                        tx_busy <= 1'b1;
                        state <= DATA;
                    end
                end

                DATA: begin
                    tx <= shift_reg[0];
                    if (clk_count < CLK_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        shift_reg <= {1'b0, shift_reg[9:1]};
                        if (bit_index == 9) begin
                            state <= IDLE;
                        end else begin
                            bit_index <= bit_index + 1;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
