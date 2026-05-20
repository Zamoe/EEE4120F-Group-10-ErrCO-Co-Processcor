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
// File        : Datapath.v
// Description : StarCore-1 Datapath.
//               Integrates all sub-components (Tasks 1-6) and implements the
//               full data-flow of the processor. Control signals arrive from
//               an external ControlUnit module (instantiated in StarCore1.v).
//               The opcode of the current instruction is exposed as an output
//               so the ControlUnit can decode it.
//
//               ErrCo extension: the ErrCo error-correction co-processor is
//               instantiated here. It is reached through opcode 1010, whose
//               2-bit sub-op (instr[5:4], exposed as the sub_op output) the
//               ControlUnit decodes into errco_active / errco_mode /
//               errco_to_reg. ErrCo produces its own write enables
//               (reg_we_errco, mem_we_scrub) with double-error gating; the
//               Datapath ORs those into the final register / data-memory
//               write enables. ErrCo's parity write enable is internal to the
//               co-processor and is only brought out for observability.
//
//               Internal structure (in order of data flow):
//               1.  Program Counter (PC) register
//               2.  PC+2 adder
//               3.  Instruction Memory (ROM)
//               4.  Register-file write-address multiplexer (RegDst)
//               5.  General Purpose Register File (GPR)
//               6.  Immediate sign-extension
//               7.  ALUSrc multiplexer
//               8.  ALU Control Unit
//               9.  ALU
//               10. Branch address adder + branch/sequential mux
//               11. Jump address computation + jump mux
//               12. Data Memory (RAM)  + ErrCo data-memory write mux
//               13. ErrCo co-processor
//               14. Write-back multiplexer (errco_to_reg / MemToReg)
//
// Task 7 - Student Implementation Required
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module Datapath (
    input        clk,

    // --- Control signals from ControlUnit ------------------------------------
    input        jump,          // Select jump target PC
    input        beq,           // Enable branch-on-equal
    input        bne,           // Enable branch-on-not-equal
    input        mem_read,      // Enable data memory read
    input        mem_write,     // Enable data memory write (posedge clk)
    input        alu_src,       // 0 = RS2; 1 = sign-extended immediate
    input        reg_dst,       // 0 = instr[8:6] (I-type); 1 = instr[5:3] (R-type)
    input        mem_to_reg,    // 0 = ALU result; 1 = memory read data
    input        reg_write,     // Enable register file write (posedge clk)
    input  [1:0] alu_op,        // ALU operation class for ALU_Control

    // --- ErrCo control signals from ControlUnit (ADDED) ----------------------
    input        errco_active,  // High only when opcode == 1010

    // --- Outputs to ControlUnit ----------------------------------------------
    output [3:0] opcode,        // Instruction opcode field [15:12]
    output [1:0] errco_sub_op         // ErrCo sub-op field instr[5:4] (ADDED)
);

    // =========================================================================
    // INTERNAL SIGNAL DECLARATIONS
    // All internal signals that interconnect sub-components go here.
    // =========================================================================

    // --- Program Counter ------------------------------------------------------
    reg  [15:0] pc_current;             // Current PC value (register)
    wire [15:0] pc_next;                // Next PC value (combinational)
    wire [15:0] pc2;                    // PC + 2 (sequential next address)

    // --- Instruction fetch ----------------------------------------------------
    wire [15:0] instr;                  // Fetched instruction word

    // --- Register file --------------------------------------------------------
    wire [2:0]  reg_write_dest;         // Write-back register address (after RegDst mux)
    wire [15:0] reg_write_data;         // Write-back data (after write-back mux)
    wire [2:0]  reg_read_addr_1;        // RS1 address (from instr[11:9])
    wire [2:0]  reg_read_addr_2;        // RS2 address (from instr[8:6])
    wire [15:0] reg_read_data_1;        // Data from RS1
    wire [15:0] reg_read_data_2;        // Data from RS2

    // --- Immediate extension --------------------------------------------------
    wire [15:0] ext_im;                 // Sign-extended 6-bit immediate

    // --- ALU ------------------------------------------------------------------
    wire [15:0] alu_operand_b;          // ALUSrc mux output (RS2 or immediate)
    wire [2:0]  alu_control;            // ALU function select from ALU_Control
    wire [15:0] alu_result;             // ALU computed result
    wire        zero_flag;              // ALU zero output

    // --- Branch / Jump PC computation ----------------------------------------
    wire [15:0] pc_branch;              // Branch target address
    wire        beq_taken;              // BEQ condition satisfied
    wire        bne_taken;              // BNE condition satisfied
    wire [15:0] pc_after_branch;        // PC selected after branch evaluation
    wire [12:0] jump_target;            // Jump target (12 bits + appended 0)
    wire [15:0] pc_jump;                // Full 16-bit jump target address

    // --- Data memory ----------------------------------------------------------
    wire [15:0] mem_read_data;          // Data read from memory
    wire [15:0] dm_write_data;          // Data-memory write port (ErrCo mux, ADDED)
    wire        dm_write_en;            // Final data-memory write enable (ADDED)

    // --- ErrCo co-processor (ADDED) ------------------------------------------
    wire [15:0] errco_result;           // ErrCo output: corrected data (LDC/SCRUB) or status word (CHECK)
    wire        errco_parity_we;        // ErrCo ParityStore write enable (internal to ErrCo; observability only)
    wire        errco_mem_we;           // ErrCo data-memory write enable (SCRUB writeback)
    wire        errco_reg_we;           // ErrCo register-file write enable (LDC/CHECK)
    wire        errco_SE;               // ErrCo single-error flag   (observability)
    wire        errco_DE;               // ErrCo double-error flag   (observability)
    wire        errco_invalid;          // ErrCo LDC-hit-double-error flag (observability)

    // --- Final register-file write enable (ADDED) ----------------------------
    wire        gpr_write_en;           // reg_write OR ErrCo's reg_we_errco

    // =========================================================================
    // 1. PROGRAM COUNTER
    // =========================================================================
    initial begin
        pc_current <= 16'd0;
    end

    always @(posedge clk) begin
        pc_current <= pc_next;
    end

    assign pc2 = pc_current + 16'd2;

    // =========================================================================
    // 2. INSTRUCTION MEMORY
    // =========================================================================
    InstructionMemory im (
        .pc (pc_current),
        .instruction (instr)
    );

    assign opcode = instr[15:12];   // opcode field
    assign errco_sub_op = instr[5:4];     // ErrCo sub-op field (ADDED)

    // =========================================================================
    // 3. REGISTER FILE WRITE-ADDRESS MULTIPLEXER (RegDst)
    // =========================================================================
    assign reg_write_dest = reg_dst ? instr[5:3] : instr[8:6];

    assign reg_read_addr_1 = instr[11:9];  // RS1
    assign reg_read_addr_2 = instr[8:6];   // RS2

    // =========================================================================
    // 4. GENERAL PURPOSE REGISTER FILE
    //   Write enable is the ControlUnit's reg_write ORed with ErrCo's
    //   reg_we_errco. The ControlUnit holds reg_write at 0 for the 1010
    //   family, so for LDC/CHECK the write comes purely from ErrCo (which
    //   already applies the double-error gating internally).
    // =========================================================================
    assign gpr_write_en = reg_write | errco_reg_we;

    GPR reg_file (
        .clk (clk),
        .reg_write_en     (gpr_write_en),
        .reg_write_dest   (reg_write_dest),
        .reg_write_data   (reg_write_data),
        .reg_read_addr_1  (reg_read_addr_1),
        .reg_read_data_1  (reg_read_data_1),
        .reg_read_addr_2  (reg_read_addr_2),
        .reg_read_data_2  (reg_read_data_2)
    );

    // =========================================================================
    // 5. IMMEDIATE SIGN-EXTENSION
    // =========================================================================
    assign ext_im = { {10{instr[5]}}, instr[5:0] };

    // =========================================================================
    // 6. ALUSrc MULTIPLEXER
    // =========================================================================
    assign alu_operand_b = alu_src ? ext_im : reg_read_data_2;

    // =========================================================================
    // 7. ALU CONTROL UNIT
    // =========================================================================
    ALU_Control alu_ctrl (
        .ALUOp   (alu_op),
        .Opcode  (instr[15:12]),
        .ALU_Cnt (alu_control)
    );

    // =========================================================================
    // 8. ALU
    // =========================================================================
    ALU alu_unit (
        .a           (reg_read_data_1),
        .b           (alu_operand_b),
        .alu_control (alu_control),
        .result      (alu_result),
        .zero        (zero_flag)
    );

    // =========================================================================
    // 9. BRANCH ADDRESS COMPUTATION AND PC-NEXT MUX CHAIN
    // =========================================================================
    assign pc_branch       = pc2 + {ext_im[14:0], 1'b0};
    assign beq_taken       = beq & zero_flag;
    assign bne_taken       = bne & ~zero_flag;
    assign pc_after_branch = (beq_taken | bne_taken) ? pc_branch : pc2;
    assign jump_target     = {instr[11:0], 1'b0};
    assign pc_jump         = {pc2[15:13], jump_target};
    assign pc_next         = jump ? pc_jump : pc_after_branch;

    // =========================================================================
    // 10. DATA MEMORY
    //   Write data: normally RS2 (plain ST).
    //   ADDED: For an ErrCo SCRUB the corrected word (errco_result) is written
    //          back instead - selected by ErrCo's mem_we_errco.
    //          Write enable: ControlUnit's mem_write ORed with ErrCo's
    //          mem_we_errco (the ControlUnit holds mem_write at 0 for the 1010
    //          family, so a SCRUB write comes purely from ErrCo).
    // =========================================================================
    assign dm_write_data = errco_mem_we ? errco_result : reg_read_data_2;
    assign dm_write_en   = mem_write | errco_mem_we;

    DataMemory dm (
        .clk             (clk),
        .mem_access_addr (alu_result),
        .mem_write_data  (dm_write_data),
        .mem_write_en    (dm_write_en),
        .mem_read        (mem_read),
        .mem_read_data   (mem_read_data)
    );

    // =========================================================================
    // 11. ErrCo: Error Correction Co-Processor
    //   mem_access_addr : ALU result (the data-memory address being operated on)
    //   reg_read_data_2 : value being stored (ENCST encodes this)
    //   mem_read_data   : value read from data memory (SCRUB/LDC/CHECK decode this)
    //   errco_result    : corrected data (SCRUB/LDC) or status word (CHECK)
    // =========================================================================
    ErrCo ECC (
        .clk             (clk),
        .mode            (errco_sub_op),
        .errco_active    (errco_active),
        .mem_access_addr (alu_result),
        .reg_read_data_2 (reg_read_data_2),
        .mem_read_data   (mem_read_data),
        .errco_result    (errco_result),
        .parity_we       (errco_parity_we),
        .mem_we_errco    (errco_mem_we),
        .reg_we_errco    (errco_reg_we),
        .SE_flag         (errco_SE),
        .DE_flag         (errco_DE),
        .ErrCo_invalid   (errco_invalid)
    );

    // =========================================================================
    // 12. WRITE-BACK MULTIPLEXER
    //   errco_to_reg = 1 -> errco_result   (LDC corrected word / CHECK status word)
    //   mem_to_reg   = 1 -> mem_read_data  (LD)
    //   otherwise        -> alu_result     (R-type and other compute instructions)
    //   errco_to_reg and mem_to_reg are mutually exclusive (the ControlUnit
    //   never asserts both), so this priority mux is unambiguous.
    // =========================================================================
    assign reg_write_data = errco_reg_we ? errco_result  :
                            mem_to_reg   ? mem_read_data :
                                           alu_result;

endmodule
