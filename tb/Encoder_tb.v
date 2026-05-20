// =========================================================================
// Project ErrCo: ErrCo StarCore-1 Co-Proccessor Encoding Module Testbench
// =========================================================================
//
// Project Group 10
//
// MEMBERS:
//   - Member 1 Zameer Mahomed, MHMZAM005
//   - Member 2 Mahir Khan, KHNMAH014
//
// File        : Encoder_tb.v
// Description : verify the SEC-DED Hamming(22,16) 6-bit Parity Generator
//
//   iverilog -Wall -I ../src -o ../build/Encoder_sim ../src/Encoder.v Encoder_tb.v - need to be in tb
//   cd ../test && ../build/Encoder_sim -- need to be in test
//   gtkwave ../waves/Encoder_tb.vcd &
//   iverilog -Wall -I ../src -o ../build/Encoder_sim ../src/Encoder.v Encoder_tb.v && ../build/Encoder_sim
//
// T1-T6  : original hand-written named regression tests.
// T7     : exhaustive sweep of all 65536 input words, checked against an
//          INDEPENDENT reference. The reference derives each parity bit from
//          the Hamming position rule (parity bit k covers a data bit iff bit k
//          of that data bit's codeword position is set) - deliberately a
//          different formulation from the Encoder's hardcoded XOR lists, so a
//          transcription error in either would be caught.
// =============================================================================
`timescale 1ns / 1ps

module Encoder_tb;

    reg     [15:0] data_in;
    wire    [5:0]  parity;

    Encoder uut (
        .data_in(data_in),
        .parity(parity)
    );

    // -------------------------------------------------------------------------
    // Waveform dump - always include this block
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("../waves/Encoder_tb.vcd");
        $dumpvars(0, Encoder_tb);
    end

    // -------------------------------------------------------------------------
    // Failure counter
    // -------------------------------------------------------------------------
    integer fail_count;
    integer test_id;

    initial begin
        fail_count = 0;
        test_id    = 1;
    end

    // -------------------------------------------------------------------------
    // Independent reference model
    // -------------------------------------------------------------------------
    // Codeword position (1-indexed Hamming position) of each of the 16 data
    // bits. Positions 1,2,4,8,16 are the parity bits, so the data bits take
    // the remaining positions in order.
    reg [4:0] dpos [0:15];
    initial begin
        dpos[0]  = 5'd3;   dpos[1]  = 5'd5;   dpos[2]  = 5'd6;   dpos[3]  = 5'd7;
        dpos[4]  = 5'd9;   dpos[5]  = 5'd10;  dpos[6]  = 5'd11;  dpos[7]  = 5'd12;
        dpos[8]  = 5'd13;  dpos[9]  = 5'd14;  dpos[10] = 5'd15;  dpos[11] = 5'd17;
        dpos[12] = 5'd18;  dpos[13] = 5'd19;  dpos[14] = 5'd20;  dpos[15] = 5'd21;
    end

    // ref_parity: compute the expected 6-bit parity for a data word using the
    // position rule. Parity bit k accumulates a data bit iff bit k of that data
    // bit's codeword position is set. p5 is the overall parity (XOR of all data
    // bits and all five lower parity bits).
    function [5:0] ref_parity;
        input [15:0] d;
        integer di;
        reg r0, r1, r2, r3, r4, r5;
        begin
            r0 = 1'b0; r1 = 1'b0; r2 = 1'b0; r3 = 1'b0; r4 = 1'b0;
            for (di = 0; di < 16; di = di + 1) begin
                if (d[di]) begin
                    if (dpos[di][0]) r0 = r0 ^ 1'b1;
                    if (dpos[di][1]) r1 = r1 ^ 1'b1;
                    if (dpos[di][2]) r2 = r2 ^ 1'b1;
                    if (dpos[di][3]) r3 = r3 ^ 1'b1;
                    if (dpos[di][4]) r4 = r4 ^ 1'b1;
                end
            end
            r5 = (^d) ^ r0 ^ r1 ^ r2 ^ r3 ^ r4;
            ref_parity = {r5, r4, r3, r2, r1, r0};
        end
    endfunction

    // -------------------------------------------------------------------------
    // Reusable check task (named regression tests T1-T6)
    // -------------------------------------------------------------------------
    task check_result;
        input [5:0] got;
        input [5:0] expected;
        input [63:0] id;        // test number for display
        begin
            if (got !== expected) begin
                $display("FAIL [T%0d]: result = %0b (0x%h), expected = %0b (0x%h)",
                         id, got, got, expected, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [T%0d]: result = %0b (0x%h)", id, got, got);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Sweep bookkeeping
    // -------------------------------------------------------------------------
    integer v;
    integer sweep_errors;
    reg [5:0] expected_par;

initial begin
        $display("=== Encoder Testbench ===");

        // ------------------- T1-T6 : named regression tests ------------------
        $display("All zeros");
        data_in = 16'd0; #10;
        check_result(parity, 6'b000000, test_id);
        test_id = test_id + 1;

        data_in = 16'h0001; #10;
        $display("Bit D0");
        check_result(parity, 6'b100011, test_id);
        test_id = test_id + 1;

        data_in = 16'h0010; #10;
        $display("Bit D4");
        check_result(parity, 6'b101001, test_id);
        test_id = test_id + 1;

        data_in = 16'h0800; #10;
        $display("Bit D11");
        check_result(parity, 6'b110001, test_id);
        test_id = test_id + 1;

        data_in = 16'h0003; #10;
        $display("D0 & D1");
        check_result(parity, 6'b000110, test_id);
        test_id = test_id + 1;

        data_in = 16'hFFFF; #10;
        $display("All Ones");
        check_result(parity, 6'b011110, test_id);
        test_id = test_id + 1;

        // ------------- T7 : exhaustive sweep of all 65536 inputs -------------
        // Checked against the independent position-rule reference above.
        $display("");
        $display("--- T%0d: exhaustive sweep, all 65536 input words ---", test_id);
        sweep_errors = 0;
        for (v = 0; v < 65536; v = v + 1) begin
            data_in = v[15:0];
            #1;
            expected_par = ref_parity(v[15:0]);
            if (parity !== expected_par) begin
                sweep_errors = sweep_errors + 1;
                if (sweep_errors <= 20)
                    $display("  MISMATCH at data=0x%h : encoder=%b  reference=%b",
                             v[15:0], parity, expected_par);
            end
        end

        if (sweep_errors == 0) begin
            $display("PASS [T%0d]: all 65536 input words match the reference", test_id);
        end else begin
            $display("FAIL [T%0d]: %0d / 65536 input words mismatched", test_id, sweep_errors);
            fail_count = fail_count + 1;
        end
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
