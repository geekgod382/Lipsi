module lipsi_top (
    input        clk,
    input        rst,
    input        clr,
    input  [15:0] sw,
    output [15:0] led,
    output [6:0]  seg,
    output [3:0]  an,
    input         uart_rx,
    output        uart_tx
);

    wire clk_cpu;
    clk_div #(.HALF_PERIOD(27'd12_499_999)) u_clkdiv (
        .clk     (clk),
        .rst     (rst),
        .clk_slow(clk_cpu)
    );

    wire [7:0] mode_in = {5'b00000, sw[15], sw[14], sw[13]};

    wire        uart_tx_send;
    wire [7:0]  uart_tx_byte;
    wire        uart_tx_busy;
    wire        uart_rx_ready;
    wire [7:0]  uart_rx_byte;

    reg [7:0] rx_latch;
    always @(posedge clk or posedge rst) begin
        if (rst)
            rx_latch <= 8'h00;
        else if (uart_rx_ready)
            rx_latch <= uart_rx_byte;
    end

    wire [7:0] io_out;

    lipsi u_cpu (
        .clk          (clk_cpu),
        .rst          (rst),
        .clr          (clr),
        .io_in        (sw[7:0]),
        .mode_in      (mode_in),
        .uart_rx_data (rx_latch),
        .uart_tx_busy (uart_tx_busy),
        .uart_tx_send (uart_tx_send),
        .uart_tx_byte (uart_tx_byte),
        .io_out       (io_out)
    );

    uart_tx u_uart_tx (
        .clk      (clk),
        .rst      (rst),
        .tx_start (uart_tx_send),
        .tx_data  (uart_tx_byte),
        .tx_busy  (uart_tx_busy),
        .tx       (uart_tx)
    );

    uart_rx u_uart_rx (
        .clk      (clk),
        .rst      (rst),
        .rx       (uart_rx),
        .rx_ready (uart_rx_ready),
        .rx_data  (uart_rx_byte)
    );

    assign led[7:0]  = io_out;
    assign led[15:8] = 8'h00;

    seven_seg u_seg (
        .clk (clk),
        .rst (rst),
        .val (io_out),
        .seg (seg),
        .an  (an)
    );

endmodule
