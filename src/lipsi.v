module lipsi (
    input clk,
    input rst,
    input clr,
    input [7:0] io_in,
    output reg [7:0] io_out
);
    reg [7:0] PC;
    reg [7:0] A;
    reg carry;
    reg [7:0] instr;
    reg [1:0] state;
    reg [2:0] alu_func;

    // States
    localparam FETCH   = 2'b00;
    localparam EXECUTE = 2'b01;
    localparam FETCH2  = 2'b10;
    localparam EXEC2   = 2'b11;

    // Memory signals
    reg mem_we;
    reg [7:0] mem_rd_addr, mem_wr_addr, mem_wr_data;
    wire [7:0] mem_rd_data;

    lipsi_mem u_mem (
        .clk(clk), .we(mem_we),
        .rd_addr(mem_rd_addr), .wr_addr(mem_wr_addr),
        .wr_data(mem_wr_data), .rd_data(mem_rd_data)
    );

    // ALU signals
    wire [7:0] alu_result;
    wire alu_carry;

    lipsi_alu u_alu (
        .func(alu_func), .a(A), .operand(mem_rd_data),
        .carry_in(carry), .result(alu_result), .carry_out(alu_carry)
    );

    always @(posedge clk or posedge rst or posedge clr) begin
        if (rst) begin
            PC <= 8'h00;
            A <= 8'h00;
            carry <= 1'b0;
            state <= FETCH;
            mem_we <= 1'b0;
            io_out <= 8'h00;

            mem_rd_addr <= 8'h00;
            instr <= 8'h00;
        end else if (clr) begin
            A <= 8'h00;
            carry <= 1'b0;
            state <= FETCH;
            mem_we <= 1'b0;
            io_out <= 8'h00;
            mem_rd_addr <= PC;
            instr <= 8'h00;
        end else begin
            mem_we <= 1'b0; // default: no write

            case (state)

                // ── CYCLE 1: send PC to memory, increment PC ──────────────
                FETCH: begin
                    mem_rd_addr <= PC;
                    PC          <= PC + 1;
                    state       <= EXECUTE;
                end

                // ── CYCLE 2: instruction arrives from memory ──────────────
                EXECUTE: begin
                    instr <= mem_rd_data; // latch instruction
                    casez (mem_rd_data)

                        // ALU with register operand: A = A f mem[r]
                        // Encoding: 0fff rrrr
                        8'b0???_????: begin
                            alu_func    <= mem_rd_data[6:4];
                            mem_rd_addr <= {4'b1000, mem_rd_data[3:0]};
                            state       <= EXEC2; // wait for register read
                        end

                        // Store A into register: mem[r] = A
                        // Encoding: 1000 rrrr
                        8'b1000_????: begin
                            mem_we      <= 1'b1;
                            mem_wr_addr <= {4'b1000, mem_rd_data[3:0]};
                            mem_wr_data <= A;
                            state       <= FETCH;
                        end

                        // ALU immediate (2-byte): A = A f n
                        // Encoding: 1100 -fff | nnnn nnnn
                        8'b1100_????: begin
                            alu_func    <= mem_rd_data[2:0];
                            mem_rd_addr <= PC;      // fetch immediate byte
                            PC          <= PC + 1;
                            state       <= EXEC2;
                        end

                        // Unconditional branch: PC = addr
                        // Encoding: 1101 --00 | aaaa aaaa
                        8'b1101_??00: begin
                            mem_rd_addr <= PC;      // fetch target address
                            PC          <= PC + 1;
                            state       <= EXEC2;
                        end

                        // Branch if zero: if A==0, PC = addr
                        // Encoding: 1101 --10 | aaaa aaaa
                        8'b1101_??10: begin
                            mem_rd_addr <= PC;
                            PC          <= PC + 1;
                            state       <= EXEC2;
                        end

                        // Branch if not zero: if A!=0, PC = addr
                        // Encoding: 1101 --11 | aaaa aaaa
                        8'b1101_??11: begin
                            mem_rd_addr <= PC;
                            PC          <= PC + 1;
                            state       <= EXEC2;
                        end

                        // IO: read input into A / write A to output
                        // Encoding: 1111 aaaa
                        8'b1111_????: begin
                            if (mem_rd_data[3:0] == 4'h0)
                                A <= io_in;         // read switches
                            else
                                io_out <= A;        // write to LEDs
                            state <= FETCH;
                        end

                        default: state <= FETCH;
                    endcase
                end

                // ── CYCLE 3: second byte / register data arrives ──────────
                EXEC2: begin
                    casez (instr)

                        // ALU register: apply ALU now that register data is ready
                        8'b0???_????: begin
                            A           <= alu_result;
                            carry       <= alu_carry;
                            state       <= FETCH;
                        end

                        // ALU immediate: second byte is the immediate value
                        8'b1100_????: begin
                            A           <= alu_result;
                            carry       <= alu_carry;
                            state       <= FETCH;
                        end

                        // Unconditional branch
                        8'b1101_??00: begin
                            PC    <= mem_rd_data;
                            state <= FETCH;
                        end

                        // Branch if zero
                        8'b1101_??10: begin
                            if (A == 8'h00)
                                PC <= mem_rd_data;
                            state <= FETCH;
                        end

                        // Branch if not zero
                        8'b1101_??11: begin
                            if (A != 8'h00)
                                PC <= mem_rd_data;
                            state <= FETCH;
                        end

                        default: state <= FETCH;
                    endcase
                end

            endcase
        end
    end
endmodule
