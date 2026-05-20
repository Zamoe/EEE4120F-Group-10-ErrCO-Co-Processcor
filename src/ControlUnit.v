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
// File        : ControlUnit.v
// Description : Main Control Unit.
//               Decodes the 4-bit opcode from the fetched instruction and
//               asserts the full set of control signals that govern the
//               Datapath for the current clock cycle.
//               This is a purely combinational module.
//
//               ErrCo extension: opcode 1010 is the error-correction
//               co-processor instruction. Its 2-bit sub_op field (instr[5:4])
//               selects one of four operations. For the 1010 family the
//               ControlUnit only drives the BASE datapath signals (address
//               path + mem_read) and the ErrCo control signals (errco_active,
//               errco_mode, errco_to_reg). It deliberately leaves reg_write
//               and mem_write at 0: the actual register / data-memory write
//               enables for ErrCo operations are produced inside ErrCo.v
//               (reg_we_errco, mem_we_scrub, parity_we) because only ErrCo
//               knows the double-error gating. The Datapath ORs those in.
//
// Task 6 - Student Implementation Required
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module ControlUnit (
    input  [3:0] opcode,        // Instruction opcode [15:12] from Datapath
    input  [1:0] errco_sub_op,        // ADDED: ErrCo sub-op, instr[5:4], only meaningful when opcode==1010

    // ALU control
    output reg [1:0] alu_op,    // Passed to ALU_Control: 10=mem, 01=branch, 00=R-type

    // PC control
    output reg       jump,      // Assert to select the jump target PC
    output reg       beq,       // Assert to enable branch-on-equal
    output reg       bne,       // Assert to enable branch-on-not-equal

    // Memory control
    output reg       mem_read,  // Assert to enable data memory read output
    output reg       mem_write, // Assert to write data memory on posedge clk

    // Datapath multiplexer selects
    output reg       alu_src,   // 0 = RS2 register value; 1 = sign-extended immediate
    output reg       reg_dst,   // 0 = instr[8:6] (I-type WS); 1 = instr[5:3] (R-type WS)
    output reg       mem_to_reg,// 0 = ALU result; 1 = data memory read data (for LD)
    output reg       reg_write, // Assert to write the register file on posedge clk

    // --- ErrCo co-processor control (ADDED) ----------------------------------
    output reg       errco_active // High only when opcode == 1010
);

    // -------------------------------------------------------------------------
    // Control signal truth table:
    //
    // Opcode | Instr     | RegDst | ALUSrc | MemToReg | RegWrite | MemRd | MemWr | Branch | ALUOp | Jump
    // -------+-----------+--------+--------+----------+----------+-------+-------+--------+-------+-----
    // 0000   | LD        |   0    |   1    |    1     |    1     |   1   |   0   |   0    |  10   |  0
    // 0001   | ST        |   0    |   1    |    0     |    0     |   0   |   1   |   0    |  10   |  0
    // 0010-  | R-type    |   1    |   0    |    0     |    1     |   0   |   0   |   0    |  00   |  0
    // 1001   | (ADD-SLT) |        |        |          |          |       |       |        |       |
    // 1010   | ErrCo     |  see ErrCo sub-op table below
    // 1011   | BEQ       |   0    |   0    |    0     |    0     |   0   |   0   |   1    |  01   |  0
    // 1100   | BNE       |   0    |   0    |    0     |    0     |   0   |   0   |   1    |  01   |  0
    // 1101   | JMP       |   0    |   0    |    0     |    0     |   0   |   0   |   0    |  00   |  1
    //
    // ErrCo sub-op table (opcode 1010, sub_op = instr[5:4]):
    //
    // sub_op | name  | errco_active | errco_mode | MemRd | ALUSrc | ALUOp | errco_to_reg | RegWr | MemWr
    // -------+-------+--------------+------------+-------+--------+-------+--------------+-------+------
    //  00    | ENCST |      1       |    00      |   0   |   1    |  10   |      0       |   0   |   0
    //  01    | SCRUB |      1       |    01      |   1   |   1    |  10   |      0       |   0   |   0
    //  10    | LDC   |      1       |    10      |   1   |   1    |  10   |      1       |   0   |   0
    //  11    | CHECK |      1       |    11      |   1   |   1    |  10   |      1       |   0   |   0
    //
    //   - All four compute R[RS1]+imm for the memory address -> ALUSrc=1, ALUOp=10.
    //   - ENCST is a store: it does not read memory -> MemRd=0. The other three
    //     read memory so the Decoder has something to work on -> MemRd=1.
    //   - RegWr / MemWr stay 0 here: ErrCo.v drives the real enables
    //     (reg_we_errco / mem_we_scrub / parity_we) with double-error gating,
    //     and the Datapath ORs them into the final write enables.
    //   - errco_to_reg=1 only for LDC/CHECK, the two that route errco_result
    //     into a register. SCRUB writes memory, ENCST writes only parity.
    //
    // For BEQ and BNE the Branch signal is asserted; the Datapath uses
    // beq & zero_flag and bne & ~zero_flag to decide whether the branch is taken.
    // -------------------------------------------------------------------------

    always @(*) begin
        //  safe defaults: no writes, no branches, no jumps, ErrCo idle
        reg_dst      = 1'b0;
        alu_src      = 1'b0;
        mem_to_reg   = 1'b0;
        reg_write    = 1'b0;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        beq          = 1'b0;
        bne          = 1'b0;
        alu_op       = 2'b00;
        jump         = 1'b0;
        errco_active = 1'b0;

        case (opcode)
            4'b0000: begin  // LD
                alu_src   = 1'b1;
                mem_to_reg= 1'b1;
                reg_write = 1'b1;
                mem_read  = 1'b1;
                alu_op    = 2'b10;
            end

            4'b0001: begin  // ST
                // Reverted to the original pre-ErrCo store: a plain
                // unprotected store with no parity encoding. Protected
                // stores are done explicitly via the 1010 ENCST sub-op.
                // Leaving ST unprotected saves the Encoder + ParityStore
                // switching activity on stores that do not need protection.
                alu_src   = 1'b1;
                mem_write = 1'b1;
                alu_op    = 2'b10;
            end

            // R-type instructions share identical control signals.
            4'b0010, 4'b0011, 4'b0100, 4'b0101,
            4'b0110, 4'b0111, 4'b1000, 4'b1001: begin
                reg_dst   = 1'b1;
                reg_write = 1'b1;
                alu_op    = 2'b00;
            end

            4'b1010: begin  // ErrCo co-processor instruction
                // Common to all four sub-ops: compute R[RS1]+imm for the
                // memory address, and tell ErrCo it is active this cycle.
                errco_active = 1'b1;
                alu_src      = 1'b1;
                alu_op       = 2'b10;

                case (errco_sub_op)
                    2'b00: begin  // ENCST - protected store
                        // store, so no memory read; ErrCo drives parity_we
                        mem_write    = 1'b1;
                    end
                    2'b01: begin  // SCRUB - read, correct, write back to memory
                        mem_read     = 1'b1;
                    end
                    2'b10: begin  // LDC - load with correction into a register
                        mem_read     = 1'b1;
                    end
                    2'b11: begin  // CHECK - diagnostic status word into a register
                        mem_read     = 1'b1;
                    end
                endcase
            end

            4'b1011: begin  // BEQ
                beq    = 1'b1;
                alu_op = 2'b01;
            end

            4'b1100: begin  // BNE - same as BEQ but bne
                bne    = 1'b1;
                alu_op = 2'b01;
            end

            4'b1101: begin  // JMP
                jump   = 1'b1; // only jump changes
            end

            default: begin
                // Safe defaults already set above.
            end
        endcase
    end

endmodule
