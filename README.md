# Lipsi ALU Demo - Manual Basys3 Implementation

Lipsi ALU Demo is a direct ALU instantiation on the Basys3 FPGA board, allowing real-time testing of all 8 ALU operations through switch inputs and LED/7-segment display outputs.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Operations Supported](#operations-supported)
3. [Hardware Pin Configuration](#hardware-pin-configuration)
4. [Component Descriptions](#component-descriptions)
5. [Operation Behavior](#operation-behavior)
6. [File Structure](#file-structure)

---

## Project Overview

This project now supports **dual modes** on the Basys3 FPGA board:
- **ALU Demo Mode** (mode_select = 0): Direct ALU instantiation with real-time switch control for testing all 8 operations
- **Processor Mode** (mode_select = 1): Full processor execution with fetch-execute pipeline, memory, and programmed instructions

**Key Features:**
- 8 different ALU operations (ADD, SUB, ADC, SBB, AND, OR, XOR, LOAD)
- Two 4-bit operand inputs (extended to 8-bit internally)
- Carry output visualization on LED[4]
- Full 8-bit result display in hexadecimal on 7-segment display
- Conditional LED output (off for ADD/SUB, on for other operations in ALU mode)
- Mode selection via SW15 switch
- Seamless switching between manual ALU testing and programmed processor execution

---

## Operations Supported

The ALU supports 8 operations selected via the 3-bit `func` input:

| func[2:0] | Operation | Description | Carry Behavior |
|-----------|-----------|-------------|-----------------|
| 3'b000 | ADD | A + Operand | Carry_out = 1 if result > 255 |
| 3'b001 | SUB | A - Operand | Carry_out = 1 if A < Operand |
| 3'b010 | ADC | A + Operand + Carry_in | Carry_out from addition |
| 3'b011 | SBB | A - Operand - Carry_in | Carry_out from subtraction |
| 3'b100 | AND | A & Operand | Bitwise AND |
| 3'b101 | OR  | A \| Operand | Bitwise OR |
| 3'b110 | XOR | A ^ Operand | Bitwise XOR |
| 3'b111 | LOAD | Operand | Load second operand only |

---

## Hardware Pin Configuration

### Control Inputs

| Function | Pins | Basys3 Location | Purpose |
|----------|------|-----------------|---------|
| Reset (rst) | U18 | BTNC | Reset all outputs |
| Clear (clr) | T18 | BTNU | Clear all outputs |
| Mode Select | R3 | SW15 | 0=ALU Demo, 1=Processor Mode |

### ALU Demo Mode Inputs (when mode_select = 0)

| Function | Pins | Basys3 Location |
|----------|------|-----------------|
| Operation Select func[0] | U1 | SW0 |
| Operation Select func[1] | T1 | SW1 |
| Operation Select func[2] | R2 | SW2 |

#### First Operand Input (a_in[3:0])

| Bit | Pin | Basys3 Location |
|-----|-----|-----------------|
| a_in[0] | V17 | SW3 |
| a_in[1] | V16 | SW4 |
| a_in[2] | W16 | SW5 |
| a_in[3] | W17 | SW6 |

#### Second Operand Input (operand_in[3:0])

| Bit | Pin | Basys3 Location |
|-----|-----|-----------------|
| operand_in[0] | W15 | SW7 |
| operand_in[1] | V15 | SW8 |
| operand_in[2] | W14 | SW9 |
| operand_in[3] | W13 | SW10 |

### Processor Mode Inputs (when mode_select = 1)

| Function | Pins | Basys3 Location |
|----------|------|-----------------|
| Processor Input io_in_sw[7:0] | V17,V16,W16,W17,W15,V15,W14,W13 | SW0-SW7 |

### Output LEDs

#### ALU Mode LEDs (leds_alu[4:0])

| Bit | Pin | Purpose |
|-----|-----|---------|
| leds_alu[0] | U16 | Result[0] |
| leds_alu[1] | E19 | Result[1] |
| leds_alu[2] | U19 | Result[2] |
| leds_alu[3] | V19 | Result[3] |
| leds_alu[4] | W18 | Carry_out (for arithmetic ops) |

#### Processor Mode LEDs (leds_proc[7:0])

| Bit | Pin | Purpose |
|-----|-----|---------|
| leds_proc[0] | U16 | io_out[0] |
| leds_proc[1] | E19 | io_out[1] |
| leds_proc[2] | U19 | io_out[2] |
| leds_proc[3] | V19 | io_out[3] |
| leds_proc[4] | W18 | io_out[4] |
| leds_proc[5] | U15 | io_out[5] |
| leds_proc[6] | U14 | io_out[6] |
| leds_proc[7] | V14 | io_out[7] |

**Note:** LEDs remain **OFF for ADD and SUB operations** in ALU mode. For other operations, LEDs display the result.

### 7-Segment Display (seg[6:0], an[3:0])

Displays the result in hexadecimal:
- **ALU Mode**: Shows full 8-bit ALU result (rightmost for lower 4 bits, left for upper 4 bits)
- **Processor Mode**: Shows processor io_out[7:0] in hex

This allows overflow visualization (e.g., ADD with carry shows "1x" on the display).

---

## Component Descriptions

### 1. **ALU.v** - Arithmetic Logic Unit

The core computation unit performing all 8 operations on 8-bit operands.

**Inputs:**
- `func[2:0]`: 3-bit operation selector
- `a[7:0]`: First operand (from a_in padded with 4 leading zeros)
- `operand[7:0]`: Second operand (from operand_in padded with 4 leading zeros)
- `carry_in`: Carry input (fixed at 0 for this demo)

**Outputs:**
- `result[7:0]`: 8-bit operation result
- `carry_out`: Carry/borrow flag

**Implementation:** Combinatorial logic with immediate results.

---

### 2. **seven_segment.v** - 7-Segment Display Driver

Multiplexes a 7-segment LED display to show the ALU result in hexadecimal.

**Features:**
- **Display Format**: Two hex digits (rightmost for lower 4 bits, left for upper 4 bits)
- **Multiplexing**: Refreshes at ~400 Hz for flicker-free display
- **Active-Low Logic**: Segments turn on when LOW (Basys3 standard)
- **Conversion**: Implements hex-to-7-segment encoding for digits 0-F

**Segment Layout:**
```
    aaa
   f   b
    ggg
   e   c
    ddd
```

---

### 3. **top_level_module.v** - System Integration

The top-level wrapper integrating the ALU, LED control logic, and 7-segment display.

**Key Functions:**
- Instantiates the ALU with switch inputs
- Manages LED output with conditional logic (off for ADD/SUB)
- Handles CLEAR button to reset all outputs
- Interfaces with 7-segment display controller

**Input Mapping:**
- 4-bit switches → First operand (a_in)
- 4-bit switches → Second operand (operand_in)
- 3-bit switches → Operation select (func)

**Output Mapping:**
- 5 LEDs → Result display (conditional)
- 7-segment → Full 8-bit hex result

---

## Operation Behavior

### Arithmetic Operations (ADD, SUB, ADC, SBB)

For operations `func[2:0] ∈ {000, 001, 010, 011}`:
- **LEDs**: OFF (set to 5'b0) - no LED display for these operations
- **7-Segment**: Shows full 8-bit result in hex
- **Carry_out**: Computed but only relevant for carry-flag-aware operations

**Example - ADD (000):**
- a_in = 4'b0101 (5 in decimal)
- operand_in = 4'b0011 (3 in decimal)
- result = 8'b00001000 (8 in hex, displays as "08")
- leds = OFF
- carry_out = 0

### Binary Logic Operations (AND, OR, XOR)

For operations `func[2:0] ∈ {100, 101, 110}`:
- **LEDs**: Display result[3:0] without carry
- **7-Segment**: Shows full 8-bit result in hex
- **Carry_out**: Not applicable but computed anyway

**Example - AND (100):**
- a_in = 4'b1111 (F in hex)
- operand_in = 4'b1010 (A in hex)
- result = 8'b00001010 (A in hex, displays as "0A")
- leds = 5'b01010 (displays result[3:0])

### LOAD Operation (111)

For operation `func[2:0] = 111`:
- **Result**: Simply the second operand (operand_in)
- **LEDs**: Display result without carry
- **7-Segment**: Shows operand_in in hex

---

## File Structure

```
Lipsi/
|-- README.md              # This file (UPDATED for dual-mode)
|-- lipsi.xdc              # Basys3 pin constraints (UPDATED for dual-mode)
|-- src/
    |-- ALU.v              # Arithmetic Logic Unit
    |-- seven_segment.v    # 7-segment display driver
    |-- top_level_module.v # Top-level integration (UPDATED for dual-mode)
    |-- memory.v           # 256-byte RAM (integrated)
    |-- clk_divider.v      # Clock frequency divider (integrated)
    |-- lipsi.v            # Main processor core (integrated)
```

**Dual-Mode Architecture:**
- **ALU Demo Mode**: Direct ALU instantiation with switch control for real-time testing
- **Processor Mode**: Full processor pipeline with memory and instruction execution
- **Mode Selection**: Controlled by SW15 switch
- **Seamless Switching**: Change modes without resynthesizing

**Important Note:** Reintegrating the original processor files would require significant changes to `top_level_module.v` and `lipsi.xdc`:
- The processor expects `io_in` (8-bit input from switches) and produces `io_out` (8-bit output to LEDs)
- The current pin assignments are optimized for the ALU demo (separate operand inputs, operation select)
- Switching modes would require updating the top-level module to instantiate the processor instead of direct ALU, and adjusting pin constraints accordingly
- The behavior would change from real-time ALU testing to programmed execution from memory

---

## Getting Started

1. **Open the project** in Vivado or your FPGA design tool
2. **Set constraints** from `lipsi.xdc` (already configured for Basys3 dual-mode)
3. **Synthesize and implement** the design
4. **Program the FPGA** with the generated bitstream
5. **Choose your mode** using SW15:
   - **SW15 = 0 (ALU Demo Mode)**: Real-time ALU testing
   - **SW15 = 1 (Processor Mode)**: Programmed execution (requires `program.hex`)

### ALU Demo Mode Usage (SW15 = 0)

- Set switches SW0-SW2 to select an operation (func)
- Set switches SW3-SW6 for the first operand (a_in)
- Set switches SW7-SW10 for the second operand (operand_in)
- Press BTNC to reset all outputs
- Press BTNU to clear all outputs
- Observe results on the LEDs and 7-segment display

### Processor Mode Usage (SW15 = 1)

- Ensure `program.hex` exists in the project directory with your program
- Use switches SW0-SW7 as processor input (io_in)
- The processor will execute instructions from memory at 1 Hz (slow clock)
- Observe execution on LEDs (io_out) and 7-segment display
- Press BTNC to reset the processor
- Press BTNU to clear outputs

---

## Example Usage Scenarios

**Scenario 1: ADD 5 + 3**
- Set func = 000 (ADD)
- Set a_in = 0101 (5)
- Set operand_in = 0011 (3)
- LEDs: OFF (ADD operation)
- 7-Segment: "08" (result in hex)

**Scenario 2: AND F XOR A**
- Set func = 110 (XOR)
- Set a_in = 1111 (F)
- Set operand_in = 1010 (A)
- LEDs: 5'b00101 (shows result[3:0])
- 7-Segment: "05" (F XOR A = 5)

**Scenario 3: LOAD value**
- Set func = 111 (LOAD)
- Set operand_in to any value (e.g., 1100 = C)
- LEDs: 5'b01100 (shows C)
- 7-Segment: "0C" (shows loaded value)

---

## Design Highlights

- **Minimal Instruction Set**: Only essential instructions for a working processor
- **Single-Cycle Pipeline**: Simplifies design and debugging
- **Memory-Mapped I/O**: Integrates I/O operations naturally into the instruction set
- **FPGA-Optimized**: Uses block RAM and leverages FPGA resources efficiently
- **Observable**: 1 Hz clock allows human observation without special test equipment

