# Lipsi Processor — Basys3 Demo

A working implementation of the **Lipsi** 8-bit accumulator processor on the Digilent Basys3 FPGA board.

---

## What is Lipsi?

Lipsi is a minimal 8-bit processor with:
- An **8-bit accumulator** (register A)
- A **program counter** (PC)
- A **carry flag**
- 256 bytes of unified memory (program + registers)
- A simple **fetch → execute** pipeline (2–3 clock cycles per instruction)

It is not a calculator. The hardware is fixed; behaviour comes entirely from the **program stored in memory**. Change the program, get completely different behaviour — that is what makes it a processor.

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
│   └── clk_divider.v        ← Parameterised clock divider
├── lipsi.xdc                ← Basys3 pin constraints
└── README.md
```

---

## Demo Program — Three Modes

The CPU runs a program baked into `memory.v`. **No `.hex` file needed.**  
Set switches **before** pressing BTNC (reset) to select a mode.

### Mode 1 — Step Counter `SW0=1`

Set SW7–SW1 to any non-zero value = step size N.

```
Display: 00 → N → 2N → 3N → … → (wraps at 256) → 00 → …
```

Shows the ALU doing repeated addition using **register load/store** and **immediate add**.

### Mode 2 — Fibonacci `SW1=1`

No extra switches needed.

```
Display: 01 → 01 → 02 → 03 → 05 → 08 → 0D → 15 → 22 → …
         (hex) wraps back to 01 after overflow past 255
```

Uses three registers (r0=prev, r1=curr, r2=next), demonstrating **register file operations**, **addition**, and **conditional branch** (BZ to restart on overflow).

### Mode 3 — XOR Toggle `SW0=0, SW1=0` (default)

Set SW7–SW2 to any pattern.

```
LEDs: [your pattern] → 00000000 → [your pattern] → 00000000 → …
```

Shows the processor reading I/O, storing a value, and toggling it with OR/AND logic in a loop.

---

## Controls

| Button | Function |
|--------|----------|
| BTNC   | Full reset — restarts program from address 0x00 |
| BTNU   | Soft reset — clears accumulator, keeps PC |

| Switch | Function |
|--------|----------|
| SW0    | Mode select bit 0 |
| SW1    | Mode select bit 1 |
| SW7–SW2 | Step size (Mode 1) / XOR mask (Mode 3) |

---

## ISA Reference

| Encoding       | Mnemonic        | Operation                        |
|----------------|-----------------|----------------------------------|
| `F0`           | IN              | A ← io_in (switches)             |
| `F1`           | OUT             | io_out ← A (LEDs + 7-seg)        |
| `C0 nn`        | ADD #nn         | A ← A + nn                       |
| `C1 nn`        | SUB #nn         | A ← A − nn                       |
| `C4 nn`        | AND #nn         | A ← A & nn                       |
| `C5 nn`        | OR  #nn         | A ← A \| nn                      |
| `C6 nn`        | XOR #nn         | A ← A ^ nn                       |
| `0fff_rrrr`    | ALU reg         | A ← A op mem[0x80+r]             |
| `8r`           | STORE r         | mem[0x80+r] ← A                  |
| `D0 aa`        | JMP aa          | PC ← aa                          |
| `D2 aa`        | BZ  aa          | if A==0: PC ← aa                 |
| `D3 aa`        | BNZ aa          | if A!=0: PC ← aa                 |

**Register file:** `mem[0x80]`–`mem[0x8F]` = r0–r15 (read/write via ALU reg and STORE).

---

## Building in Vivado

1. Create a new RTL project targeting **xc7a35tcpg236-1** (Basys3)
2. Add all `.v` files from `src/` as design sources
3. Set `lipsi_top` as the top module
4. Add `lipsi.xdc` as a constraint file
5. Run Synthesis → Implementation → Generate Bitstream
6. Program the device

---

## Why this feels like a real processor

A mod-N counter is hardwired logic — you cannot make it do anything else without redesigning the circuit.

This processor runs **three completely different algorithms** (step counting, Fibonacci, XOR toggling) on the **exact same hardware**, selected purely by the program in memory. The silicon does not change. The program does. That is the definition of a stored-program processor.
