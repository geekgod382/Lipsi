module uart_rx (
    input        clk,
    input        rst,
    input        rx,
    output reg [7:0] rx_data,
    output reg   rx_ready
);
    localparam CLK_PER_BIT  = 10416;
    localparam HALF_BIT     = 5208;

    reg [13:0] clk_count;
    reg [3:0]  bit_index;
    reg [7:0]  shift_reg;
    reg        rx_sync0, rx_sync1;

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            rx_ready  <= 1'b0;
            rx_data   <= 8'h00;
            clk_count <= 0;
            bit_index <= 0;
            rx_sync0  <= 1'b1;
            rx_sync1  <= 1'b1;
        end else begin
            rx_sync0 <= rx;
            rx_sync1 <= rx_sync0;

            rx_ready <= 1'b0;

            case (state)

                IDLE: begin
                    if (!rx_sync1) begin
                        clk_count <= 0;
                        state     <= START;
                    end
                end

                START: begin
                    if (clk_count == HALF_BIT) begin
                        if (!rx_sync1) begin
                            clk_count <= 0;
                            bit_index <= 0;
                            state     <= DATA;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                DATA: begin
                    if (clk_count == CLK_PER_BIT - 1) begin
                        clk_count <= 0;
                        shift_reg <= {rx_sync1, shift_reg[7:1]};
                        if (bit_index == 7) begin
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                STOP: begin
                    if (clk_count == CLK_PER_BIT - 1) begin
                        rx_ready  <= 1'b1;
                        rx_data   <= shift_reg;
                        clk_count <= 0;
                        state     <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
