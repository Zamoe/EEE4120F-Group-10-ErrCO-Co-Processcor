// =========================================================================
// Project ErrCo: ErrCo StarCore-1 Co-Proccessor Control Module Testbench
// =========================================================================
//
// Project Group 10
//
// MEMBERS:
//   - Member 1 Zameer Mahomed, MHMZAM005
//   - Member 2 Mahir Khan, KHNMAH014
//
// File        : ErrCo_Control_tb.v
// Description : Testbench for ErrCo_Control.v - exercises the Encoder ->
//               ParityStore -> Decoder chain as a unit.
//
//   Build & run (from tb/):
//     iverilog -Wall -I ../src -o ../build/ErrCo_Control_sim \
//        ../src/Encoder.v ../src/Decoder.v ../src/ParityStore.v \
//        ../src/ErrCo_Control.v ErrCo_Control_tb.v
//     cd ../test && ../build/ErrCo_Control_sim
//     gtkwave ../waves/ErrCo_Control_tb.vcd &
//
// Notes:
//   - check_result now takes EXPLICIT expected SE/DE/PE values. The previous
//     version only checked that (data,SE,DE) matched one of several
//     "valid-looking" patterns, which let a single-bit-error test silently
//     pass through the double-error branch. Each test now states its intent.
//   - Parity-bit-error tests (T7-T9) corrupt a stored parity word directly
//     via a hierarchical poke into uut.PS.parity_store_ram[], since a bad
//     parity value cannot be injected through the normal module interface.
// =============================================================================

`timescale 1ns / 1ps

module ErrCo_Control_tb;
    reg         clk;
    reg         parity_write_en;
    reg  [15:0] mem_access_addr;
    reg  [15:0] data_encoder;
    reg  [15:0] data_to_decoder;

    wire [15:0] Error_Corr_Result;
    wire        SE_flag;
    wire        DE_flag;
    wire        parity_bit_error;

    // -------------------------------------------------------------------------
    // Instantiate ErrCo_Control
    // -------------------------------------------------------------------------
    ErrCo_Control uut (
        .clk(clk),
        .parity_write_en(parity_write_en),
        .mem_access_addr(mem_access_addr),
        .data_encoder(data_encoder),
        .data_to_decoder(data_to_decoder),
        .Error_Corr_Result(Error_Corr_Result),
        .SE_flag(SE_flag),
        .DE_flag(DE_flag),
        .parity_bit_error(parity_bit_error)
    );

    // -------------------------------------------------------------------------
    // Clock generation - 10 ns period
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always  #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("../waves/ErrCo_Control_tb.vcd");
        $dumpvars(0, ErrCo_Control_tb);
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
    // Reusable check task.
    //   check_data = 1 : compare got_data against exp_data
    //   check_data = 0 : data is don't-care (e.g. an uncorrectable double
    //                    error - the corrected output is meaningless)
    // SE/DE/PE are always checked against their explicit expected values.
    // -------------------------------------------------------------------------
    task check_result;
        input [15:0] got_data;
        input [15:0] exp_data;
        input        check_data;
        input        got_SE;
        input        exp_SE;
        input        got_DE;
        input        exp_DE;
        input        got_PE;
        input        exp_PE;
        input [63:0] id;
        reg data_ok, flags_ok;
        begin
            data_ok  = (!check_data) || (got_data === exp_data);
            flags_ok = (got_SE === exp_SE) && (got_DE === exp_DE) && (got_PE === exp_PE);
            if (data_ok && flags_ok) begin
                if (check_data)
                    $display("PASS [T%0d]: result = 0x%h (exp 0x%h) | SE=%b DE=%b PE=%b",
                             id, got_data, exp_data, got_SE, got_DE, got_PE);
                else
                    $display("PASS [T%0d]: result = 0x%h (data don't-care) | SE=%b DE=%b PE=%b",
                             id, got_data, got_SE, got_DE, got_PE);
            end else begin
                $display("FAIL [T%0d]: result = 0x%h, expected 0x%h (check_data=%b)",
                         id, got_data, exp_data, check_data);
                $display("           SE got=%b exp=%b | DE got=%b exp=%b | PE got=%b exp=%b",
                         got_SE, exp_SE, got_DE, exp_DE, got_PE, exp_PE);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Helper: synchronous write of one parity word.
    // Drives the inputs, holds across one rising edge, then drops the enable.
    // -------------------------------------------------------------------------
    task store_parity;
        input [15:0] addr;
        input [15:0] data;
        begin
            mem_access_addr = addr;
            data_encoder    = data;
            parity_write_en = 1'b1;
            #10;                       // spans a rising edge -> write commits
            parity_write_en = 1'b0;
        end
    endtask

    initial begin
        // initial values
        parity_write_en = 1'b0;
        mem_access_addr = 16'd0;
        data_encoder    = 16'd0;
        data_to_decoder = 16'd0;

        $display("=== ErrCo_Control Testbench ===");
        #2;

        // ------------------------------------------------------------------
        // T1: clean write then clean read - no corruption
        // ------------------------------------------------------------------
        $display("Test 1: No corruption (addr 0)");
        store_parity(16'h0000, 16'hAAAA);
        data_to_decoder = 16'hAAAA;
        #5;
        check_result(Error_Corr_Result, 16'hAAAA, 1'b1,
                     SE_flag, 1'b0, DE_flag, 1'b0, parity_bit_error, 1'b0, test_id);
        test_id = test_id + 1;

        // ------------------------------------------------------------------
        // T2: clean write/read at a different address
        // ------------------------------------------------------------------
        $display("Test 2: No corruption (addr 3)");
        store_parity(16'h0003, 16'hBAAA);
        data_to_decoder = 16'hBAAA;
        #5;
        check_result(Error_Corr_Result, 16'hBAAA, 1'b1,
                     SE_flag, 1'b0, DE_flag, 1'b0, parity_bit_error, 1'b0, test_id);
        test_id = test_id + 1;

        // ------------------------------------------------------------------
        // T3: single-bit DATA error -> corrected. 0xACAA stored, 0xADAA read
        //     (0xACAA ^ 0xADAA = 0x0100, one bit). Must correct to 0xACAA,
        //     SE=1, DE=0, PE=0.  (Under the old buggy decoder this was
        //     misreported as a double error and the loose check task accepted
        //     it - it now genuinely verifies single-error correction.)
        // ------------------------------------------------------------------
        $display("Test 3: SEU detection and correction (data bit)");
        store_parity(16'h0100, 16'hACAA);
        data_to_decoder = 16'hADAA;        // single data-bit flip
        #5;
        check_result(Error_Corr_Result, 16'hACAA, 1'b1,
                     SE_flag, 1'b1, DE_flag, 1'b0, parity_bit_error, 1'b0, test_id);
        test_id = test_id + 1;

        // ------------------------------------------------------------------
        // T4: double error -> detected, not corrected. 0xAAAA stored,
        //     0xBABA read (differs in two bits). Expect SE=0, DE=1, PE=0.
        //     The corrected-data output is meaningless on a DE -> check_data=0.
        // ------------------------------------------------------------------
        $display("Test 4: Double error detection");
        store_parity(16'h0000, 16'hAAAA);
        data_to_decoder = 16'hBABA;        // two-bit flip
        #5;
        check_result(Error_Corr_Result, 16'h0000, 1'b0,
                     SE_flag, 1'b0, DE_flag, 1'b1, parity_bit_error, 1'b0, test_id);
        test_id = test_id + 1;

        // ------------------------------------------------------------------
        // T5/T6: ParityStore address independence. Store two different words
        //        at addr 0 and addr 1, then read each back.
        // ------------------------------------------------------------------
        $display("Test 5: Parity Store - addr 0 holds its own word");
        store_parity(16'h0000, 16'h1111);
        store_parity(16'h0001, 16'hFFFF);
        mem_access_addr = 16'h0000;
        data_to_decoder = 16'h1111;        // clean read of addr 0
        #5;
        check_result(Error_Corr_Result, 16'h1111, 1'b1,
                     SE_flag, 1'b0, DE_flag, 1'b0, parity_bit_error, 1'b0, test_id);
        test_id = test_id + 1;

        $display("Test 6: Parity Store - addr 1 word, single-bit error corrected");
        mem_access_addr = 16'h0001;
        data_to_decoder = 16'hFFFE;        // 0xFFFF stored, bit 0 flipped
        #5;
        check_result(Error_Corr_Result, 16'hFFFF, 1'b1,
                     SE_flag, 1'b1, DE_flag, 1'b0, parity_bit_error, 1'b0, test_id);
        test_id = test_id + 1;

        // ------------------------------------------------------------------
        // T7: PARITY-bit error. Store 0x1234 cleanly, then corrupt one bit of
        //     the STORED parity word directly. Data is clean, so the decoder
        //     must leave it untouched, report SE=1, DE=0, and PE=1.
        // ------------------------------------------------------------------
        $display("Test 7: Parity-bit error (stored parity corrupted, data clean)");
        store_parity(16'h0002, 16'h1234);
        // hierarchical poke: flip bit 0 of the parity stored at slot 2
        uut.PS.parity_store_ram[2] = uut.PS.parity_store_ram[2] ^ 6'b000001;
        mem_access_addr = 16'h0002;
        data_to_decoder = 16'h1234;        // data itself is clean
        #5;
        check_result(Error_Corr_Result, 16'h1234, 1'b1,
                     SE_flag, 1'b1, DE_flag, 1'b0, parity_bit_error, 1'b1, test_id);
        test_id = test_id + 1;

        // ------------------------------------------------------------------
        // T8: parity-bit error on a different parity bit / address.
        // ------------------------------------------------------------------
        $display("Test 8: Parity-bit error (different bit and address)");
        store_parity(16'h0004, 16'h5678);
        uut.PS.parity_store_ram[4] = uut.PS.parity_store_ram[4] ^ 6'b001000; // flip bit 3
        mem_access_addr = 16'h0004;
        data_to_decoder = 16'h5678;
        #5;
        check_result(Error_Corr_Result, 16'h5678, 1'b1,
                     SE_flag, 1'b1, DE_flag, 1'b0, parity_bit_error, 1'b1, test_id);
        test_id = test_id + 1;

        // ------------------------------------------------------------------
        // T9: flip the p5 (overall) parity bit. Syndrome is 0 so PE=0, but the
        //     overall-parity check still fires -> SE=1, DE=0, data untouched.
        // ------------------------------------------------------------------
        $display("Test 9: p5 (overall parity) bit flipped -> SE=1, PE=0");
        store_parity(16'h0005, 16'h9ABC);
        uut.PS.parity_store_ram[5] = uut.PS.parity_store_ram[5] ^ 6'b100000; // flip bit 5
        mem_access_addr = 16'h0005;
        data_to_decoder = 16'h9ABC;
        #5;
        check_result(Error_Corr_Result, 16'h9ABC, 1'b1,
                     SE_flag, 1'b1, DE_flag, 1'b0, parity_bit_error, 1'b0, test_id);
        test_id = test_id + 1;

        // ------------------------------------------------------------------
        // T10: clean read after all the corruption tests - confirms nothing
        //      is persistently broken and a fresh slot still round-trips.
        // ------------------------------------------------------------------
        $display("Test 10: Clean round-trip after corruption tests");
        store_parity(16'h0007, 16'hC3C3);
        data_to_decoder = 16'hC3C3;
        #5;
        check_result(Error_Corr_Result, 16'hC3C3, 1'b1,
                     SE_flag, 1'b0, DE_flag, 1'b0, parity_bit_error, 1'b0, test_id);
        test_id = test_id + 1;

        // -----------------------------------------------------------------------
        // Summary
        // -----------------------------------------------------------------------
        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d TESTS FAILED ===", fail_count, test_id - 1);

        $finish;
    end

endmodule
