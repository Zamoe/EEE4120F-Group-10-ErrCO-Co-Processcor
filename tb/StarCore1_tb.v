// =========================================================================
// Project ErrCo: ErrCo StarCore-1 Co-Proccessor Integration Testbench
// =========================================================================
//
// Project Group 10
//
// MEMBERS:
//   - Member 1 Zameer Mahomed, MHMZAM005
//   - Member 2 Mahir Khan, KHNMAH014
//
// File        : StarCore1_tb.v
// Description : Top-level integration testbench for the StarCore1 processor
//               with the ErrCo error-correction co-processor.
//
//               Runs the 15-instruction program in test.prog. The program is
//               structured in two halves: the first half (instructions 0-7)
//               exercises the base ISA - LD, ADD, SUB, AND, OR, SLT, ST - so
//               any regression in those would surface here; the second half
//               (instructions 8-13) exercises the four ErrCo sub-ops -
//               ENCST, LDC, CHECK, SCRUB. Instruction 14 is JMP-to-self for
//               a clean halt.
//
//               Two SEUs are injected into data memory via hierarchical
//               pokes at sim time 96 ns, immediately after the two ENCST
//               instructions have committed their writes:
//
//                 Mem[5] ^= 16'h0001  (one bit flipped - single-error path)
//                 Mem[6] ^= 16'h0003  (two bits flipped - double-error path)
//
//               Verification points along the way:
//                 - every base-ISA register write produces the expected value
//                 - both ENCST instructions wrote the right data into memory
//                 - LDC R1<-Mem[5] returns the CORRECTED value (=5, not 4)
//                   and errco_SE was high during the LDC cycle
//                 - CHECK R4<-Mem[5] returns status_word = 0x0001 (SE bit set)
//                 - SCRUB Mem[5] restored memory to its original clean value
//                 - LDC R5<-Mem[6] does NOT write R5 (DE-gated): R5 stays at
//                   2, the value it had from the AND instruction at cycle 5.
//                   errco_DE and errco_invalid were high during the LDC cycle.
//                 - PC parks at 0x001c after the JMP-self
//
//   Build & run (from tb/):
//     iverilog -Wall -I ../src -o ../build/star_sim \
//        ../src/Parameter.v ../src/ALU.v ../src/GPR.v \
//        ../src/InstructionMemory.v ../src/DataMemory.v \
//        ../src/ALU_Control.v ../src/ControlUnit.v \
//        ../src/Encoder.v ../src/Decoder.v ../src/ParityStore.v \
//        ../src/ErrCo_Control.v ../src/ErrCo.v \
//        ../src/Datapath.v ../src/StarCore1.v \
//        StarCore1_tb.v
//     cd ../test && ../build/star_sim
//     gtkwave ../waves/StarCore1_tb.vcd &
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module StarCore1_tb;

    reg clk;

    // -------------------------------------------------------------------------
    // DUT - the only external input is the clock
    // -------------------------------------------------------------------------
    StarCore1 uut (.clk(clk));

    // -------------------------------------------------------------------------
    // Clock - 10 ns period, posedges at 5, 15, 25, ... ns
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always  #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("../waves/StarCore1_tb.vcd");
        $dumpvars(0, StarCore1_tb);
    end

    // -------------------------------------------------------------------------
    // Bookkeeping
    // -------------------------------------------------------------------------
    integer fail_count;
    integer test_id;

    initial begin
        fail_count = 0;
        test_id    = 1;
    end

    // -------------------------------------------------------------------------
    // Check tasks - one per kind of state we want to observe
    // -------------------------------------------------------------------------
    task check_reg;
        input [2:0]  r;
        input [15:0] expected;
        input [255:0] label;
        reg [15:0] got;
        begin
            got = uut.DU.reg_file.reg_array[r];
            if (got === expected)
                $display("PASS [T%0d] %0s: R%0d = 0x%h", test_id, label, r, got);
            else begin
                $display("FAIL [T%0d] %0s: R%0d got 0x%h, expected 0x%h",
                         test_id, label, r, got, expected);
                fail_count = fail_count + 1;
            end
            test_id = test_id + 1;
        end
    endtask

    task check_mem;
        input [2:0]  addr;
        input [15:0] expected;
        input [255:0] label;
        reg [15:0] got;
        begin
            got = uut.DU.dm.memory[addr];
            if (got === expected)
                $display("PASS [T%0d] %0s: Mem[%0d] = 0x%h", test_id, label, addr, got);
            else begin
                $display("FAIL [T%0d] %0s: Mem[%0d] got 0x%h, expected 0x%h",
                         test_id, label, addr, got, expected);
                fail_count = fail_count + 1;
            end
            test_id = test_id + 1;
        end
    endtask

    task check_flag;
        input        got;
        input        expected;
        input [255:0] label;
        begin
            if (got === expected)
                $display("PASS [T%0d] %0s: flag = %b", test_id, label, got);
            else begin
                $display("FAIL [T%0d] %0s: got %b, expected %b",
                         test_id, label, got, expected);
                fail_count = fail_count + 1;
            end
            test_id = test_id + 1;
        end
    endtask

    task check_pc;
        input [15:0] expected;
        input [255:0] label;
        reg [15:0] got;
        begin
            got = uut.DU.pc_current;
            if (got === expected)
                $display("PASS [T%0d] %0s: PC = 0x%h", test_id, label, got);
            else begin
                $display("FAIL [T%0d] %0s: PC got 0x%h, expected 0x%h",
                         test_id, label, got, got, expected);
                fail_count = fail_count + 1;
            end
            test_id = test_id + 1;
        end
    endtask

    // =========================================================================
    // Main stimulus / verification flow
    // =========================================================================
    initial begin
        $display("=== StarCore1 Integration Testbench ===");
        $display("");
        $display("--- Phase 1: base ISA verification ---");

        // Cycle 1 posedge at 5 ns - LD R1 <- Mem[1] = 2
        @(posedge clk); #1;
        check_reg(3'd1, 16'h0002, "R1 after LD R1, R0+1");

        // Cycle 2 - LD R2 <- Mem[2] = 3
        @(posedge clk); #1;
        check_reg(3'd2, 16'h0003, "R2 after LD R2, R0+2");

        // Cycle 3 - ADD R3, R1, R2 -> 5
        @(posedge clk); #1;
        check_reg(3'd3, 16'h0005, "R3 after ADD");

        // Cycle 4 - SUB R4, R2, R1 -> 1
        @(posedge clk); #1;
        check_reg(3'd4, 16'h0001, "R4 after SUB");

        // Cycle 5 - AND R5, R1, R2 -> 2.  THIS value of R5 matters later: it
        // is what R5 should still hold after the DE-suppressed LDC at cycle 14.
        @(posedge clk); #1;
        check_reg(3'd5, 16'h0002, "R5 after AND (the value DE-suppression must preserve)");

        // Cycle 6 - OR R6, R1, R2 -> 3
        @(posedge clk); #1;
        check_reg(3'd6, 16'h0003, "R6 after OR");

        // Cycle 7 - SLT R7, R1, R2 -> 1  (2 < 3)
        @(posedge clk); #1;
        check_reg(3'd7, 16'h0001, "R7 after SLT");

        // Cycle 8 - ST R3 -> Mem[4]  (plain unprotected store: ErrCo not involved)
        @(posedge clk); #1;
        check_mem(3'd4, 16'h0005, "Mem[4] after plain ST");

        $display("");
        $display("--- Phase 2: ENCST writes (data + parity) ---");

        // Cycle 9 - ENCST R3 -> Mem[5]   (protected store: data AND parity)
        @(posedge clk); #1;
        check_mem(3'd5, 16'h0005, "Mem[5] after ENCST R3 - data half");
        // parity_store_ram[5] was written by ErrCo; just confirm it is non-zero
        // (the exact value is verified exhaustively by Encoder_tb)
        if (uut.DU.ECC.ECC.PS.parity_store_ram[5] !== 6'd0)
            $display("PASS [T%0d] parity[5] non-zero after ENCST: 6'b%b",
                     test_id, uut.DU.ECC.ECC.PS.parity_store_ram[5]);
        else begin
            $display("FAIL [T%0d] parity[5] still zero after ENCST", test_id);
            fail_count = fail_count + 1;
        end
        test_id = test_id + 1;

        // Cycle 10 - ENCST R2 -> Mem[6]
        @(posedge clk); #1;
        check_mem(3'd6, 16'h0003, "Mem[6] after ENCST R2 - data half");

        // ====================================================================
        // SEU INJECTION POINT (sim time ~96 ns)
        // Both ENCSTs have committed. Cycle 11 (LDC R1 <- Mem[5]) is about to
        // begin its combinational evaluation. We inject:
        //   Mem[5] ^= 0x0001  (one-bit flip - correctable, exercises the SEC path)
        //   Mem[6] ^= 0x0003  (two-bit flip - uncorrectable, exercises the DE path)
        // Parity for both addresses was written by the ENCSTs and is unchanged
        // so the decoder will see a mismatch on the next read.
        // ====================================================================
        $display("");
        $display("--- INJECT: SEUs into data memory (sim time %0t ns) ---", $time);
        $display("    Mem[5] = 0x%h -> flipping bit 0", uut.DU.dm.memory[5]);
        $display("    Mem[6] = 0x%h -> flipping bits 0 and 1", uut.DU.dm.memory[6]);

        uut.DU.dm.memory[5] = uut.DU.dm.memory[5] ^ 16'h0001;
        uut.DU.dm.memory[6] = uut.DU.dm.memory[6] ^ 16'h0003;

        check_mem(3'd5, 16'h0004, "Mem[5] post-inject (5 XOR 1)");
        check_mem(3'd6, 16'h0000, "Mem[6] post-inject (3 XOR 3)");

        $display("");
        $display("--- Phase 3: single-error correction path (LDC + CHECK + SCRUB on Mem[5]) ---");

        // Mid-way through cycle 11 - check the live error flags.
        // Cycle 11 runs 95 -> 105 ns. We are at ~96 ns post-injection, so
        // sample at ~101 ns (well into the cycle, signals settled).
        #5;
        check_flag(uut.DU.errco_SE,      1'b1, "errco_SE during LDC of corrupted Mem[5]");
        check_flag(uut.DU.errco_DE,      1'b0, "errco_DE clear (correctable)");
        check_flag(uut.DU.errco_invalid, 1'b0, "errco_invalid clear");

        // Cycle 11 posedge at 105 ns - LDC R1 <- Mem[5].  The corrected
        // value (=5) reaches the register, NOT the corrupted 0x0004.
        @(posedge clk); #1;
        check_reg(3'd1, 16'h0005, "R1 after LDC: corrected back to 5");

        // Cycle 12 posedge - CHECK R4 <- status word for Mem[5].  Mem[5] is
        // still corrupted at this point (SCRUB has not run yet).  The decoder
        // sees a single data-bit error so the status word should be:
        //   {13'b0, PE=0, DE=0, SE=1} = 0x0001
        @(posedge clk); #1;
        check_reg(3'd4, 16'h0001, "R4 after CHECK: status word reports SE=1");

        // Cycle 13 posedge - SCRUB Mem[5].  The decoder corrects 0x0004 -> 5,
        // and mem_we_errco writes 5 back to memory[5].
        @(posedge clk); #1;
        check_mem(3'd5, 16'h0005, "Mem[5] after SCRUB: restored to original 0x0005");

        $display("");
        $display("--- Phase 4: double-error path (LDC of double-corrupted Mem[6]) ---");

        // Mid-way through cycle 14 (125 -> 135 ns) - sample the live flags.
        // We are at ~126 ns. Sample at ~130 ns.
        #4;
        check_flag(uut.DU.errco_DE,      1'b1, "errco_DE during LDC of double-corrupted Mem[6]");
        check_flag(uut.DU.errco_invalid, 1'b1, "errco_invalid asserted - GPR write suppressed");
        check_flag(uut.DU.errco_SE,      1'b0, "errco_SE clear (no single-bit correction)");

        // Cycle 14 posedge at 135 ns - LDC R5 <- Mem[6] would have happened,
        // but the DE-gated reg_we_errco was held low.  R5 should STILL hold
        // 0x0002, the value latched by the AND at cycle 5 - this is the key
        // observable proof that DE-suppression works at the integration level.
        @(posedge clk); #1;
        check_reg(3'd5, 16'h0002, "R5 unchanged - LDC suppressed by DE");

        // Mem[6] was never scrubbed -> it should still hold the corrupted value
        check_mem(3'd6, 16'h0000, "Mem[6] still corrupted (never scrubbed)");

        $display("");
        $display("--- Phase 5: JMP-to-self halts the PC ---");

        // Cycle 15 posedge at 145 ns - JMP-to-self.  PC <- 0x001c (its own
        // address).  Run a couple more cycles to confirm PC stays parked.
        @(posedge clk); #1;
        check_pc(16'h001c, "PC after JMP-self (first time)");
        @(posedge clk); #1;
        check_pc(16'h001c, "PC after JMP-self (second time - confirms halt)");
        @(posedge clk); #1;
        check_pc(16'h001c, "PC after JMP-self (third time)");

        // ====================================================================
        // Summary
        // ====================================================================
        $display("");
        $display("=== Final architectural state ===");
        $display("    R1=0x%h  R2=0x%h  R3=0x%h  R4=0x%h",
                 uut.DU.reg_file.reg_array[1], uut.DU.reg_file.reg_array[2],
                 uut.DU.reg_file.reg_array[3], uut.DU.reg_file.reg_array[4]);
        $display("    R5=0x%h  R6=0x%h  R7=0x%h",
                 uut.DU.reg_file.reg_array[5], uut.DU.reg_file.reg_array[6],
                 uut.DU.reg_file.reg_array[7]);
        $display("    Mem[4]=0x%h Mem[5]=0x%h Mem[6]=0x%h",
                 uut.DU.dm.memory[4], uut.DU.dm.memory[5], uut.DU.dm.memory[6]);
        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d TESTS FAILED ===", fail_count, test_id - 1);

        $finish;
    end

endmodule
