# Project ErrCo: Radiation-Hardened StarCore-1 Processor

## Overview
Project ErrCo introduces an error-correcting hardware co-processor integrated directly into the 16-bit single-cycle **StarCore-1** processor pipeline. By exploiting the unassigned `1010` opcode space, the **ErrCo Subsystem** delivers transparent, high-performance Single Error Correction and Double Error Detection (SEC-DED) using an Extended Hamming (22,16) block architecture. This design enables atomic fault repair within a single execution cycle without modifying the core baseline processing structures.

The development, synthesis verification, and systemic testing of this architecture are built upon **Icarus Verilog** for circuit simulation and **GTKWave** for digital signal validation.

---

## Architecture Specifications

- **Word Width:** 16 bits data payload + 6 bits systematic parity (22-bit total codeword width)
- **Registers:** 8 General Purpose Registers (R0–R7), featuring active write-enable interception
- **Memory Infrastructure:** Fully isolated, independent Harvard Address spaces
- **Instruction ROM:** 16 words × 16 bits (loaded from `test/test.prog`)
- **Data RAM Matrix:** 8 words × 16 bits (loaded from `test/test.data`) 
- **Parity Shadow RAM:** 8 words × 6 bits (Internal co-processor space tracking Data RAM indices)
- **Execution Lifecycle:** Strictly single-cycle combinational resolution; memories write synchronously on `posedge clk`, while error-syndrome evaluation, bit-flipping, and double-fault suppression settle combinationally within the single clock phase.

### Extended Instruction Set Architecture (ISA)

| Opcode (4-bit) | Mnemonic | Sub-Op (Bits [5:4]) | Type   | Description |
| -------------- | -------- | ------------------- | ------ | ----------- |
| `0000`         | LD       | —                   | I-type | Standard data load from data memory to register  |
| `0001`         | ST       | —                   | I-type | Standard unprotected register store to data memory  |
| `0010–1001`    | R-type   | —                   | R-type | Native compute operations (`ADD`, `SUB`, `AND`, etc.) |
| `1010`         | **ENCST**| `2'b00`             | ErrCo  | **Encoded Store:** Generate 6-bit parity and write to memory |
| `1010`         | **SCRUB**| `2'b01`             | ErrCo  | **Memory Scrub:** Read, verify, and overwrite corrected data/parity |
| `1010`         | **LDC** | `2'b10`             | ErrCo  | **Verified Load:** Load from data memory, correct single errors |
| `1010`         | **CHECK**| `2'b11`             | ErrCo  | **Diagnostic Check:** Output 16-bit status word `{13'b0, PE, DE, SE}`  |
| `1011`         | BEQ      | —                   | I-type | Branch if R[RS1] == R[RS2] |
| `1100`         | BNE      | —                   | I-type | Branch if R[RS1] != R[RS2] |
| `1101`         | JMP      | —                   | I-type | Unconditional jump |

---

## Folder Structure
