// =========================================================================
// Project ErrCo: ErrCo StarCore-1 Co-Proccessor Parity Store Module
// =========================================================================
//
// Project Group 10
//
// MEMBERS:
//   - Member 1 Zameer Mahomed, MHMZAM005
//   - Member 2 Mahir Khan, KHNMAH014
//
// File        : ParityStore_tb.v
// Description : Testbench for ParityStore.v - the 8 x 6-bit parity shadow memory.
//
//   Build & run (from tb/):
//     iverilog -Wall -I ../src -o ../build/ParityStore_sim ../src/ParityStore.v ParityStore_tb.v
//     cd ../test && ../build/ParityStore_sim
//     gtkwave ../waves/ParityStore_tb.vcd &
//
// What this verifies:
//   - all 8 slots initialise to 0
//   - write-then-read-back at the same address
//   - the read port is combinational (tracks address with no clock edge)
//   - writes to different addresses are independent (no aliasing)
//   - parity_write_en actually gates the write (en low -> no change)
//   - only the low 3 bits of mem_access_addr select the slot
//   - read-before-write ordering on a same-cycle write+read
// =============================================================================
`timescale 1ns / 1ps

module ParityStore_tb;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg         clk;
    reg         parity_write_en;
    reg  [15:0] mem_access_addr;
    reg  [5:0]  parity_in;
    wire [5:0]  parity_out;

    ParityStore uut (
        .clk             (clk),
        .parity_write_en (parity_write_en),
        .mem_access_addr (mem_access_addr),
        .parity_in       (parity_in),
        .parity_out      (parity_out)
    );

    // -------------------------------------------------------------------------
    // Clock: 10ns period
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("../waves/ParityStore_tb.vcd");
        $dumpvars(0, ParityStore_tb);
    end

    // -------------------------------------------------------------------------
    // Bookkeeping
    // -------------------------------------------------------------------------
    integer fail_count;
    integer test_id;
    integer i;

    initial begin
        fail_count = 0;
        test_id    = 1;
    end

    // -------------------------------------------------------------------------
    // Check task: compare parity_out against an expected value
    // -------------------------------------------------------------------------
    task check_parity;
        input [5:0]  got;
        input [5:0]  expected;
        input [63:0] id;
        begin
            if (got === expected) begin
                $display("PASS [T%0d]: parity_out = %b (0x%h), expected = %b (0x%h)",
                         id, got, got, expected, expected);
            end else begin
                $display("FAIL [T%0d]: parity_out = %b (0x%h), expected = %b (0x%h)",
                         id, got, got, expected, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Helper: perform a synchronous write at a given address.
    // Sets up inputs, waits for the rising edge to land the write, then drops
    // the write-enable.  Leaves mem_access_addr pointing at the written slot.
    // -------------------------------------------------------------------------
    task do_write;
        input [15:0] addr;
        input [5:0]  data;
        begin
            @(negedge clk);                 // change inputs away from the edge
            mem_access_addr = addr;
            parity_in       = data;
            parity_write_en = 1'b1;
            @(posedge clk);                 // write commits here
            @(negedge clk);
            parity_write_en = 1'b0;
        end
    endtask

    // =========================================================================
    // Tests
    // =========================================================================
    initial begin
        // initialise
        parity_write_en = 1'b0;
        mem_access_addr = 16'd0;
        parity_in       = 6'd0;

        $display("=== ParityStore Testbench ===");

        // ---------------------------------------------------------------------
        // T1-T8 : every slot initialises to 0
        // ---------------------------------------------------------------------
        $display("");
        $display("--- T1-T8: all 8 slots initialise to 0 ---");
        #2; // let initial block settle, stay before first posedge activity
        for (i = 0; i < 8; i = i + 1) begin
            mem_access_addr = i[15:0];
            #1;
            check_parity(parity_out, 6'd0, test_id);
            test_id = test_id + 1;
        end

        // ---------------------------------------------------------------------
        // T9 : basic write-then-read-back at address 0
        // ---------------------------------------------------------------------
        $display("");
        $display("--- T9: write 0x2A to addr 0, read it back ---");
        do_write(16'd0, 6'h2A);
        mem_access_addr = 16'd0; #1;
        check_parity(parity_out, 6'h2A, test_id);
        test_id = test_id + 1;

        // ---------------------------------------------------------------------
        // T10 : combinational read - change address only, no clock edge,
        //       output must follow immediately
        // ---------------------------------------------------------------------
        $display("");
        $display("--- T10: read is combinational (addr change, no clk edge) ---");
        do_write(16'd5, 6'h15);             // put a known value in slot 5
        mem_access_addr = 16'd0;  #1;       // point at slot 0 (holds 0x2A from T9)
        mem_access_addr = 16'd5;  #1;       // switch to slot 5 with no edge between
        check_parity(parity_out, 6'h15, test_id);
        test_id = test_id + 1;

        // ---------------------------------------------------------------------
        // T11-T18 : address independence - write a distinct value to every
        //           slot, then read them all back. No aliasing.
        // ---------------------------------------------------------------------
        $display("");
        $display("--- T11-T18: 8 distinct values, one per slot, no aliasing ---");
        for (i = 0; i < 8; i = i + 1) begin
            // distinct 6-bit pattern per slot: 0x3F, 0x01, 0x02, ... pattern (i*9+7) masked
            do_write(i[15:0], (i*9 + 7) & 6'h3F);
        end
        for (i = 0; i < 8; i = i + 1) begin
            mem_access_addr = i[15:0]; #1;
            check_parity(parity_out, (i*9 + 7) & 6'h3F, test_id);
            test_id = test_id + 1;
        end

        // ---------------------------------------------------------------------
        // T19 : write-enable gating - with en LOW, a clock edge must NOT change
        //       the stored value
        // ---------------------------------------------------------------------
        $display("");
        $display("--- T19: parity_write_en LOW blocks the write ---");
        do_write(16'd3, 6'h3F);             // slot 3 := 0x3F
        @(negedge clk);
        mem_access_addr = 16'd3;
        parity_in       = 6'h00;            // try to overwrite with 0...
        parity_write_en = 1'b0;             // ...but enable is LOW
        @(posedge clk);                     // clock edge - should be ignored
        @(negedge clk);
        #1;
        check_parity(parity_out, 6'h3F, test_id);  // still 0x3F
        test_id = test_id + 1;

        // ---------------------------------------------------------------------
        // T20 : confirm the SAME slot then DOES update once enable is high
        // ---------------------------------------------------------------------
        $display("");
        $display("--- T20: same slot updates when enable is HIGH ---");
        do_write(16'd3, 6'h12);             // now actually overwrite slot 3
        mem_access_addr = 16'd3; #1;
        check_parity(parity_out, 6'h12, test_id);
        test_id = test_id + 1;

        // ---------------------------------------------------------------------
        // T21 : only the low 3 bits of mem_access_addr matter.
        //       addr 0x000B has low bits 011 = 3, so it must alias slot 3.
        // ---------------------------------------------------------------------
        $display("");
        $display("--- T21: high address bits ignored (0x000B -> slot 3) ---");
        mem_access_addr = 16'h000B; #1;     // 0b...1011 -> low 3 bits = 011 = 3
        check_parity(parity_out, 6'h12, test_id);  // same as slot 3 from T20
        test_id = test_id + 1;

        // ---------------------------------------------------------------------
        // T22 : write using a high-bit-laden address, read back with the
        //       plain 3-bit address - must land in the same slot.
        // ---------------------------------------------------------------------
        $display("");
        $display("--- T22: write at 0xFFFE, read at 0x0006 (both -> slot 6) ---");
        do_write(16'hFFFE, 6'h29);          // low 3 bits of 0xFFFE = 110 = 6
        mem_access_addr = 16'd6; #1;
        check_parity(parity_out, 6'h29, test_id);
        test_id = test_id + 1;

        // ---------------------------------------------------------------------
        // T23 : read-before-write ordering. In the same cycle that a write to
        //       slot 2 is committing, the read port should still show the OLD
        //       value until the edge passes, then the NEW value after.
        // ---------------------------------------------------------------------
        $display("");
        $display("--- T23: read-before-write on a same-cycle write to slot 2 ---");
        do_write(16'd2, 6'h0C);             // slot 2 := 0x0C (known starting value)
        @(negedge clk);
        mem_access_addr = 16'd2;
        parity_in       = 6'h33;
        parity_write_en = 1'b1;
        #1;
        // we are now between negedge and the next posedge: write has NOT committed
        check_parity(parity_out, 6'h0C, test_id);   // still old value
        test_id = test_id + 1;
        @(posedge clk);                      // write commits
        @(negedge clk);
        parity_write_en = 1'b0;
        #1;
        check_parity(parity_out, 6'h33, test_id);   // now new value
        test_id = test_id + 1;

        // ---------------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------------
        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d TESTS FAILED ===", fail_count, test_id - 1);

        $finish;
    end

endmodule
