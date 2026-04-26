module lipsi (
    input clk,
    input rst,
    input clr,
    input [7:0] io_in,
    input [7:0] mode_in,
    input [7:0] uart_rx_data,
    input uart_tx_busy,
    output reg uart_tx_send,
    output reg [7:0] uart_tx_byte,
    output reg [7:0] io_out
);
    //9-bit PC 
    reg [8:0] PC;
    reg [7:0] A;
    reg carry;
    reg [7:0] instr;
    reg [1:0] state;
    reg [2:0] alu_func;

    localparam FETCH   = 2'b00;
    localparam EXECUTE = 2'b01;
    localparam EXEC2   = 2'b11;

    reg mem_we;
    reg [8:0] mem_rd_addr;
    reg [8:0] mem_wr_addr;
    reg [7:0] mem_wr_data;
    wire [7:0] mem_rd_data;

    lipsi_mem u_mem (
        .clk (clk),
        .we (mem_we),
        .rd_addr (mem_rd_addr),
        .wr_addr (mem_wr_addr),
        .wr_data (mem_wr_data),
        .rd_data (mem_rd_data)
    );

    wire [7:0] alu_result;
    wire alu_carry;

    lipsi_alu u_alu (
        .func (alu_func),
        .a (A),
        .operand (mem_rd_data),
        .carry_in (carry),
        .result (alu_result),
        .carry_out(alu_carry)
    );

    always @(posedge clk or posedge rst or posedge clr) begin
        if (rst) begin
            PC <= 9'h000;
            A <= 8'h00;
            carry <= 1'b0;
            state <= FETCH;
            mem_we <= 1'b0;
            io_out <= 8'h00;
            mem_rd_addr <= 9'h000;
            instr  <= 8'h00;
            uart_tx_send <= 1'b0;
            uart_tx_byte <= 8'h00;
        end else if (clr) begin
            A <= 8'h00;
            carry <= 1'b0;
            state <= FETCH;
            mem_we <= 1'b0;
            io_out <= 8'h00;
            mem_rd_addr <= PC;
            instr <= 8'h00;
            uart_tx_send <= 1'b0;
        end else begin
            mem_we <= 1'b0;
            uart_tx_send <= 1'b0;

            case (state)

                FETCH: begin
                    mem_rd_addr <= PC;
                    PC <= PC + 1;
                    state <= EXECUTE;
                end

                EXECUTE: begin
                    instr <= mem_rd_data;
                    casez (mem_rd_data)

                        // 0fff rrrr            f rx          ALU register             A = A f m[r]
                        // 1000 rrrr            st rx         store A into register    m[r] = A
                        // 1001 rrrr            brl rx        branch and link          m[r] = PC, PC = A
                        // 1010 rrrr            ldind (rx)    load indirect            A = m[m[r]]
                        // 1011 rrrr            stind (rx)    store indirect           m[m[r]] = A
                        // 1100 -fff nnnn nnnn  fi n          ALU immediate            A = A f n
                        // 1101 --00 aaaa aaaa  br            branch                   PC = a
                        // 1101 --10 aaaa aaaa  brz           branch if A is zero      PC = a
                        // 1101 --11 aaaa aaaa  brnz          branch if A is not zero  PC = a
                        // 1110 --ff            sh            ALU shift                A = shift(A)
                        // 1111 aaaa            io            input and output IO = A, A = IO
                        // 1111 1111            exit          exit for the tester      PC = PC

                        // ALU register: 0fff rrrr
                        8'b0xxx_xxxx: begin
                            alu_func <= mem_rd_data[6:4];
                            mem_rd_addr <= {5'b1_0000, mem_rd_data[3:0]};
                            state <= EXEC2;
                        end

                        // Store: 1000 rrrr
                        8'b1000_xxxx: begin
                            mem_we <= 1'b1;
                            mem_wr_addr <= {5'b1_0000, mem_rd_data[3:0]};
                            mem_wr_data <= A;
                            state <= FETCH;
                        end

                        // ALU immediate: 1100 -fff | nn
                        8'b1100_xxxx: begin
                            alu_func <= mem_rd_data[2:0];
                            mem_rd_addr <= PC;
                            PC <= PC + 1;
                            state <= EXEC2;
                        end

                        // JMP: 1101 --00 | aa
                        8'b1101_xx00: begin
                            mem_rd_addr <= PC;
                            PC <= PC + 1;
                            state <= EXEC2;
                        end

                        // BZ: 1101 --10 | aa
                        8'b1101_xx10: begin
                            mem_rd_addr <= PC;
                            PC <= PC + 1;
                            state <= EXEC2;
                        end

                        // BNZ: 1101 --11 | aa
                        8'b1101_xx11: begin
                            mem_rd_addr <= PC;
                            PC <= PC + 1;
                            state <= EXEC2;
                        end

                        // IO: 1111 xxxx
                        8'b1111_xxxx: begin
                            case (mem_rd_data[3:0])
                                4'h0: A <= io_in;
                                4'h1: io_out <= A;
                                4'h2: A <= mode_in;
                                4'h3: begin
                                    uart_tx_byte <= A;
                                    uart_tx_send <= 1'b1;
                                end
                                4'h4: A <= uart_rx_data;
                                4'h5: A <= {7'b0, uart_tx_busy};
                                default: io_out <= A;
                            endcase
                            state <= FETCH;
                        end

                        default: state <= FETCH;
                    endcase
                end

                EXEC2: begin
                    casez (instr)

                        8'b0xxx_xxxx: begin
                            A <= alu_result;
                            carry <= alu_carry;
                            state <= FETCH;
                        end

                        8'b1100_xxxx: begin
                            A <= alu_result;
                            carry <= alu_carry;
                            state <= FETCH;
                        end

                        // JMP — target byte is 8-bit, zero-extended to 9-bit
                        8'b1101_xx00: begin
                            PC <= {1'b0, mem_rd_data};
                            state <= FETCH;
                        end

                        8'b1101_xx10: begin
                            if (A == 8'h00) PC <= {1'b0, mem_rd_data};
                            state <= FETCH;
                        end

                        8'b1101_xx11: begin
                            if (A != 8'h00) PC <= {1'b0, mem_rd_data};
                            state <= FETCH;
                        end

                        default: state <= FETCH;
                    endcase
                end

            endcase
        end
    end
endmodule
