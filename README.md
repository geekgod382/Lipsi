# Lipsi Processor — Basys3 Demo

A working implementation of the **Lipsi** 8-bit accumulator processor on the Digilent Basys3 FPGA board.

---

## What is Lipsi?

Lipsi is a minimal 8-bit processor with:
- An **8-bit accumulator** (register A)
- A **program counter** (PC)
- A **carry flag**
- **Full-duplex UART** (9600 baud) for serial communication with PuTTY
- 256 bytes of unified memory (program + registers)
- A simple **fetch → execute** pipeline (2–3 clock cycles per instruction)
- **Extended I/O**: 16 switches, 16 LEDs, 4-digit multiplexed 7-segment display

---

## Project Structure

```
Lipsi/
├── src/
│   ├── lipsi.v              ← CPU core: fetch-decode-execute FSM
│   ├── ALU.v                ← 8-bit ALU (add, sub, and, or, xor, load)
│   ├── memory.v             ← 256-byte memory + baked-in demo program
│   ├── top_level_module.v   ← Basys3 top: clock divider + CPU + 7-seg
│   ├── seven_segment.v      ← 4-digit multiplexed 7-segment driver
│   ├── clk_divider.v        ← Parameterised clock divider
│   ├── uart_rx.v            ← UART receiver module
│   └── uart_tx.v            ← UART transmitter module
├── lipsi.xdc                ← Basys3 pin constraints
├── design.vvp               ← Simulation output file (you will get this after running the testbench)
├── documentation.txt        ← Additional documentation
├── lipsi_tb.v               ← Testbench for simulation
├── lipsi_tb.vcd             ← Value change dump (simulation waveforms) (you will get this after running the GTKWave simulation)
└── README.md
```

---

## Controls

| Button | Function |
|--------|----------|
| BTNC   | Full reset — restarts program from address 0x00 |
| BTNU   | Soft reset (clr) — clears accumulator, keeps PC |

| Switches | Function |
|----------|----------|
| SW0–SW7  | Input data / Mode selection (original switches) |
| SW8–SW12 | Extended input data |
| SW13–SW15 | Extended mode select bits |

| Output | Function |
|--------|----------|
| LED0–LED7 | 8-bit accumulator display (original LEDs) |
| LED8–LED15 | Extended output display |
| 7-seg AN3–AN0 | 4-digit multiplexed 7-segment display |

| Serial | Configuration |
|--------|-----------------|
| UART TX (A18) | FPGA → PC (9600 baud, 8N1) |
| UART RX (B18) | PC → FPGA (9600 baud, 8N1) |

---

## Testing & Simulation

A comprehensive testbench (`lipsi_tb.v`) is provided to verify processor functionality:

- **Simulation environment**: Full-featured testbench with clock generation and reset control
- **Test coverage**: CPU core, ALU operations, memory access, UART integration
- **Waveform output**: GTKWave-compatible `.vcd` files for detailed signal analysis
- **Baud rate validation**: 9600 baud UART at 100 MHz system clock (CLK_PER_BIT = 10416)

### Running Simulation (Vivado)

1. Open your project in Vivado
2. Add `lipsi_tb.v` as a simulation source
3. Right-click on `lipsi_tb` and select **Set as Top Module** (for simulation)
4. Run **Simulation → Run Behavioral Simulation**
5. Export waveforms as `.vcd` for analysis in GTKWave

---

## Building in Vivado

1. Create a new RTL project targeting **xc7a35tcpg236-1** (Basys3)
2. Add all `.v` files from `src/` as design sources (including uart_rx.v and uart_tx.v)
3. Set `lipsi_top` (or `top_level_module`) as the top module
4. Add `lipsi.xdc` as a constraint file
5. Run Synthesis → Implementation → Generate Bitstream
6. Program the device
7. (Optional) Connect USB cable and open PuTTY at 9600 baud to interact via UART

---

## UART Communication

The processor integrates a full-duplex UART module for serial communication:

- **Baud rate**: 9600 baud (8 data bits, 1 stop bit, no parity)
- **TX module** (`uart_tx.v`): Transmits accumulator or register values to PC
- **RX module** (`uart_rx.v`): Receives commands from PC to control processor behavior
- **Interface**: Connect Basys3 USB port to host PC; use PuTTY or similar terminal at 9600 baud
- **Pin assignment**: TX (A18), RX (B18) — auto-detected USB-to-UART bridge on Basys3

This enables real-time monitoring and control of the processor over serial connection.
