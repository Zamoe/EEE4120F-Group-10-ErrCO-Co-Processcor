// =========================================================================
// Practical 4: StarCore-1 - Single-Cycle Processor in Verilog
// =========================================================================
//
// GROUP NUMBER:16
//
// MEMBERS:
//   - Member 1 Zameer Mahomed, MHMZAM005
//   - Member 2 Mahir Khan, KHNMAH014
//
// File        : StarCore1.v
// Description : Top-level StarCore-1 processor module.
//               Connects the Datapath and ControlUnit together.
//               The only external input is the clock signal; all internal
//               signals flow between the two sub-modules via wires.
//
//               ErrCo extension: three extra control wires carry the ErrCo
//               signals from the ControlUnit to the Datapath
//               (errco_active, errco_mode, errco_to_reg), and one extra wire
//               (sub_op) carries the ErrCo sub-op field instr[5:4] from the
//               Datapath back to the ControlUnit so it can be decoded.
//
// Task 8 - Student Implementation Required
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module StarCore1 (
    input clk       // System clock - drives both the Datapath and GPR/DataMemory
);

    // =========================================================================
    // INTERNAL CONTROL WIRES
    // ControlUnit outputs -> Datapath inputs, and the Datapath opcode/sub_op
    // outputs -> ControlUnit inputs.
    // =========================================================================
    wire        jump;
    wire        beq;
    wire        bne;
    wire        mem_read;
    wire        mem_write;
    wire        alu_src;
    wire        reg_dst;
    wire        mem_to_reg;
    wire        reg_write;
    wire [1:0]  alu_op;
    wire [3:0]  opcode;

    // --- ErrCo control wires (ADDED) -----------------------------------------
    wire [1:0]  errco_sub_op;        // Datapath -> ControlUnit : instr[5:4]
    wire        errco_active;  // ControlUnit -> Datapath

    // =========================================================================
    // DATAPATH INSTANTIATION
    // =========================================================================
    Datapath DU (
        .clk          (clk),
        .jump         (jump),
        .beq          (beq),
        .bne          (bne),
        .mem_read     (mem_read),
        .mem_write    (mem_write),
        .alu_src      (alu_src),
        .reg_dst      (reg_dst),
        .mem_to_reg   (mem_to_reg),
        .reg_write    (reg_write),
        .alu_op       (alu_op),
        .errco_active (errco_active),
        .opcode       (opcode),
        .errco_sub_op (errco_sub_op)
    );

    // =========================================================================
    // CONTROL UNIT INSTANTIATION
    // =========================================================================
    ControlUnit CU (
        .opcode       (opcode),
        .errco_sub_op (errco_sub_op),
        .alu_op       (alu_op),
        .jump         (jump),
        .beq          (beq),
        .bne          (bne),
        .mem_read     (mem_read),
        .mem_write    (mem_write),
        .alu_src      (alu_src),
        .reg_dst      (reg_dst),
        .mem_to_reg   (mem_to_reg),
        .reg_write    (reg_write),
        .errco_active (errco_active)
    );

endmodule
