
// =============================================================================
// EEE4120F Practical 4 — StarCore-1 Processor
// File        : InstructionMemory_tb.v
// Description : Testbench for the Instruction Memory module (Task 3).
//               Walks the PC through all valid addresses and verifies the
//               correct instruction word is output combinationally.
//
// Run:
//   iverilog -Wall -I ../src -o ../build/im_sim ../src/InstructionMemory.v InstructionMemory_tb.v
//   cd ../test && ../build/im_sim
//   gtkwave ../waves/im_tb.vcd &
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module InstructionMemory_tb;

    reg  [15:0] pc;
    wire [15:0] instruction;

    InstructionMemory uut (.pc(pc), .instruction(instruction));

    initial begin
        $dumpfile("../waves/im_tb.vcd");
        $dumpvars(0, InstructionMemory_tb);
    end

    integer fail_count;
    integer test_id;
    // Expected instruction words — these must match the contents of test.prog.
    // Update these values after you finalise your test.prog file.
    reg [15:0] expected [0:14];

    task check;
        input [15:0] got;
        input [15:0] exp;
        begin
            if ( got !== exp ) begin
                $display ( " FAIL [ Test %0d ]: got %0d (0 x %h ) , expected %0d (0x%h)", test_id, got, got, exp, exp);
                fail_count = fail_count+1;
            end else begin
                $display ( " PASS [ Test %0d ]: %0d " , test_id , got );
            end
        end
    endtask

    initial begin
        fail_count = 0;
        test_id    = 1;

        $display("=== InstructionMemory Testbench ===");

        // TODO: Load the expected values to match your test.prog file.
        //       For example, if your first instruction is ADD R2,R0,R1 (0010000001010000):
        //           expected[0]  = 16'b0010000001010000;
        //       Fill in all 15 entries to match your test.prog exactly.
        //
        //       expected[0]  = 16'bXXXXXXXXXXXXXXXX;
        //       expected[1]  = 16'bXXXXXXXXXXXXXXXX;
        //       ... (fill all 15)
        expected[0] = 16'b0000010000000000;
        expected[1] = 16'b0000010001000001;
        expected[2] = 16'b0010000001010000;
        expected[3] = 16'b0001001010000000;
        expected[4] = 16'b0011000001010000;
        expected[5] = 16'b0111000001010000;
        expected[6] = 16'b1000000001010000;
        expected[7] = 16'b1001000001010000;
        expected[8] = 16'b0010000000000000;
        expected[9] = 16'b1011000001000001;
        expected[10] = 16'b1100000001000000;
        expected[11] = 16'b1101000000000000;
        expected[12] = 16'b0000000000000000;
        expected[13] = 16'b0000000000000000;
        expected[14] = 16'b0000000000000000;

        // TODO: Walk PC through addresses 0, 2, 4, ... 28 (14 instructions).
        //       At each address, verify instruction == expected[rom_index].
        //       Verify also that the output is combinational (no clock needed).
        //
        //       For each address:
        //           pc = 16'd0; #5;  // set PC, wait for combinational output
        //           if (instruction !== expected[0])
        //               $display("FAIL [T%0d]: PC=0 got %b exp %b",
        //                        test_id, instruction, expected[0]);
        //           else
        //               $display("PASS [T%0d]: PC=0 instr=%b", test_id, instruction);
        //           test_id = test_id + 1;
        //
        //           pc = 16'd2; #5;
        //           ... and so on.
        pc = 16'd0; #5;
        check(instruction, expected[0]);
        test_id = test_id + 1;

        pc = 16'd2; #5;
        check(instruction, expected[1]);
        test_id = test_id + 1;

        pc = 16'd4; #5;
        check(instruction, expected[2]);
        test_id = test_id + 1;

        pc = 16'd6; #5;
        check(instruction, expected[3]);
        test_id = test_id + 1;

        pc = 16'd8; #5;
        check(instruction, expected[4]);
        test_id = test_id + 1;

        pc = 16'd10; #5;
        check(instruction, expected[5]);
        test_id = test_id + 1;

        pc = 16'd12; #5;
        check(instruction, expected[6]);
        test_id = test_id + 1;

        pc = 16'd14; #5;
        check(instruction, expected[7]);
        test_id = test_id + 1;

        pc = 16'd16; #5;
        check(instruction, expected[8]);
        test_id = test_id + 1;

        pc = 16'd18; #5;
        check(instruction, expected[9]);
        test_id = test_id + 1;

        pc = 16'd20; #5;
        check(instruction, expected[10]);
        test_id = test_id + 1;

        pc = 16'd22; #5;
        check(instruction, expected[11]);
        test_id = test_id + 1;

        pc = 16'd24; #5;
        check(instruction, expected[12]);
        test_id = test_id + 1;

        pc = 16'd26; #5;
        check(instruction, expected[13]);
        test_id = test_id + 1;

        pc = 16'd26; #5;
        check(instruction, expected[14]);

        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d TESTS PASSED ===", test_id);
        else
            $display("=== %0d / %0d TESTS FAILED ===", fail_count, test_id);
        $finish;
    end

endmodule
