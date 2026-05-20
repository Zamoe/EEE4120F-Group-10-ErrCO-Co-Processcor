// =============================================================================
// EEE4120F Practical 4 - StarCore-1 Processor
// File        : ControlUnit_tb.v
// Description : Testbench for the Main Control Unit (Task 6 + ErrCo extension).
//               Applies every defined opcode and verifies all control signal
//               outputs. For opcode 1010 (ErrCo) it sweeps all four sub_op
//               values and checks the ErrCo control signals as well.
//
// Run (from tb/):
//   iverilog -Wall -I ../src -o ../build/cu_sim ../src/ControlUnit.v ControlUnit_tb.v
//   cd ../test && ../build/cu_sim
//   gtkwave ../waves/cu_tb.vcd &
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module ControlUnit_tb;

    reg  [3:0] opcode;
    reg  [1:0] errco_sub_op;          // ADDED: ErrCo sub-op input

    wire [1:0] alu_op;
    wire       jump;
    wire       beq;
    wire       bne;
    wire       mem_read;
    wire       mem_write;
    wire       alu_src;
    wire       reg_dst;
    wire       mem_to_reg;
    wire       reg_write;
    // ADDED: ErrCo control outputs
    wire       errco_active;

    ControlUnit uut (
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

    initial begin
        $dumpfile("../waves/cu_tb.vcd");
        $dumpvars(0, ControlUnit_tb);
    end

    integer fail_count;
    integer test_id;

    // -------------------------------------------------------------------------
    // Composite check task - verifies all 11 control signals in one call.
    // Base-datapath signals first, then the ErrCo signal.
    // -------------------------------------------------------------------------
    task check_ctrl;
        input [1:0] e_alu_op;
        input       e_jump, e_beq, e_bne;
        input       e_mem_read, e_mem_write;
        input       e_alu_src, e_reg_dst;
        input       e_mem_to_reg, e_reg_write;
        input       e_errco_active;
        input [63:0] id;

        reg failed;
        begin
            failed = 1'b0;

            if (alu_op       !== e_alu_op)       begin $display("  MISMATCH alu_op:       %b vs %b", alu_op,       e_alu_op);       failed=1; end
            if (jump         !== e_jump)         begin $display("  MISMATCH jump:         %b vs %b", jump,         e_jump);         failed=1; end
            if (beq          !== e_beq)          begin $display("  MISMATCH beq:          %b vs %b", beq,          e_beq);          failed=1; end
            if (bne          !== e_bne)          begin $display("  MISMATCH bne:          %b vs %b", bne,          e_bne);          failed=1; end
            if (mem_read     !== e_mem_read)     begin $display("  MISMATCH mem_read:     %b vs %b", mem_read,     e_mem_read);     failed=1; end
            if (mem_write    !== e_mem_write)    begin $display("  MISMATCH mem_write:    %b vs %b", mem_write,    e_mem_write);    failed=1; end
            if (alu_src      !== e_alu_src)      begin $display("  MISMATCH alu_src:      %b vs %b", alu_src,      e_alu_src);      failed=1; end
            if (reg_dst      !== e_reg_dst)      begin $display("  MISMATCH reg_dst:      %b vs %b", reg_dst,      e_reg_dst);      failed=1; end
            if (mem_to_reg   !== e_mem_to_reg)   begin $display("  MISMATCH mem_to_reg:   %b vs %b", mem_to_reg,   e_mem_to_reg);   failed=1; end
            if (reg_write    !== e_reg_write)    begin $display("  MISMATCH reg_write:    %b vs %b", reg_write,    e_reg_write);    failed=1; end
            if (errco_active !== e_errco_active) begin $display("  MISMATCH errco_active: %b vs %b", errco_active, e_errco_active); failed=1; end

            if (failed) begin
                $display("FAIL [T%0d]: opcode=%b errco_sub_op=%b", id, opcode, errco_sub_op);
                fail_count = fail_count + 1;
            end else
                $display("PASS [T%0d]: opcode=%b errco_sub_op=%b all signals correct", id, opcode, errco_sub_op);
        end
    endtask

    initial begin
        fail_count = 0;
        test_id    = 1;
        errco_sub_op     = 2'b00;     // default; only matters for opcode 1010
        $display("=== ControlUnit Testbench ===");
        $display("    check_ctrl(alu_op, jump, beq, bne, mem_read, mem_write, alu_src, reg_dst, mem_to_reg, reg_write, errco_active, errco_mode, errco_to_reg, id)");

        // ------------------------------------------------------------------
        // Base ISA opcodes
        // ------------------------------------------------------------------

        // LD (0000)
        opcode = 4'b0000; errco_sub_op = 2'b00; #10;
        //         alu_op  jmp   beq   bne   mr    mw    as    rd    mtr   rw    eact  emode  e2reg
        check_ctrl(2'b10, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, test_id);
        test_id = test_id + 1;

        // ST (0001) - reverted to plain unprotected store: ErrCo NOT involved
        opcode = 4'b0001; errco_sub_op = 2'b00; #10;
        check_ctrl(2'b10, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, test_id);
        test_id = test_id + 1;

        // R-type: ADD..SLT (0010..1001) - all identical
        opcode = 4'b0010; #10;
        check_ctrl(2'b00, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, test_id);
        test_id = test_id + 1;
        opcode = 4'b0011; #10;
        check_ctrl(2'b00, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, test_id);
        test_id = test_id + 1;
        opcode = 4'b0100; #10;
        check_ctrl(2'b00, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, test_id);
        test_id = test_id + 1;
        opcode = 4'b0101; #10;
        check_ctrl(2'b00, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, test_id);
        test_id = test_id + 1;
        opcode = 4'b0110; #10;
        check_ctrl(2'b00, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, test_id);
        test_id = test_id + 1;
        opcode = 4'b0111; #10;
        check_ctrl(2'b00, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, test_id);
        test_id = test_id + 1;
        opcode = 4'b1000; #10;
        check_ctrl(2'b00, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, test_id);
        test_id = test_id + 1;
        opcode = 4'b1001; #10;
        check_ctrl(2'b00, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, test_id);
        test_id = test_id + 1;

        // BEQ (1011)
        opcode = 4'b1011; #10;
        check_ctrl(2'b01, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, test_id);
        test_id = test_id + 1;

        // BNE (1100)
        opcode = 4'b1100; #10;
        check_ctrl(2'b01, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, test_id);
        test_id = test_id + 1;

        // JMP (1101)
        opcode = 4'b1101; #10;
        check_ctrl(2'b00, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, test_id);
        test_id = test_id + 1;

        // Undefined opcode (1111) - all safe defaults, ErrCo idle
        opcode = 4'b1111; #10;
        check_ctrl(2'b00, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, test_id);
        test_id = test_id + 1;

        // ------------------------------------------------------------------
        // ErrCo opcode 1010 - sweep all four sub_op values
        // ------------------------------------------------------------------
        $display("--- ErrCo (opcode 1010) sub-op sweep ---");

        // ENCST (sub_op 00): protected store. alu_src=1, alu_op=10, NO mem_read,
        // reg_write/mem_write stay 0 (ErrCo drives parity_we itself).
        // errco_active=1, errco_mode=00, errco_to_reg=0.
        opcode = 4'b1010; errco_sub_op = 2'b00; #10;
        // ENCST: mem_write IS asserted by the ControlUnit (option-b: ENCST writes
        // data memory via the normal store path; ErrCo separately writes parity)
        check_ctrl(2'b10, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, test_id);
        test_id = test_id + 1;

        // SCRUB (sub_op 01): read, correct, write back to memory. mem_read=1,
        // alu_src=1, alu_op=10. errco_active=1, errco_mode=01, errco_to_reg=0
        // (writes memory, not a register). reg_write/mem_write stay 0.
        opcode = 4'b1010; errco_sub_op = 2'b01; #10;
        check_ctrl(2'b10, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, test_id);
        test_id = test_id + 1;

        // LDC (sub_op 10): load with correction into a register. mem_read=1,
        // errco_to_reg=1, errco_mode=10. reg_write stays 0 (ErrCo's reg_we_errco
        // drives the actual write, with double-error gating).
        opcode = 4'b1010; errco_sub_op = 2'b10; #10;
        check_ctrl(2'b10, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, test_id);
        test_id = test_id + 1;

        // CHECK (sub_op 11): diagnostic status word into a register. Same
        // datapath shape as LDC. errco_mode=11, errco_to_reg=1.
        opcode = 4'b1010; errco_sub_op = 2'b11; #10;
        check_ctrl(2'b10, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, test_id);
        test_id = test_id + 1;

        // Sanity: sub_op must be ignored when opcode is NOT 1010. Drive a
        // non-1010 opcode with each sub_op value; errco_active must stay 0.
        $display("--- sub_op ignored for non-1010 opcodes ---");
        opcode = 4'b0000; errco_sub_op = 2'b11; #10;   // LD with junk sub_op
        check_ctrl(2'b10, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, test_id);
        test_id = test_id + 1;
        opcode = 4'b0010; errco_sub_op = 2'b10; #10;   // R-type with junk sub_op
        check_ctrl(2'b00, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, test_id);
        test_id = test_id + 1;

        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d TESTS FAILED ===", fail_count, test_id - 1);
        $finish;
    end

endmodule
