// =============================================================================
// EEE4120F Practical 4 — StarCore-1 Processor
// File        : DataMemory_tb.v
// Description : Testbench for the Data Memory module (Task 4).
//               Verifies synchronous write, gated combinational read,
//               write followed by immediate read, and disabled-write safety.
//
// Run:
//   iverilog -Wall -I ../src -o ../build/dm_sim ../src/DataMemory.v DataMemory_tb.v
//   cd ../test && ../build/dm_sim
//   gtkwave ../waves/dm_tb.vcd &
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module DataMemory_tb;

    reg        clk;
    reg  [15:0] mem_access_addr;
    reg  [15:0] mem_write_data;
    reg        mem_write_en;
    reg        mem_read;
    wire [15:0] mem_read_data;

    DataMemory uut (
        .clk             (clk),
        .mem_access_addr (mem_access_addr),
        .mem_write_data  (mem_write_data),
        .mem_write_en    (mem_write_en),
        .mem_read        (mem_read),
        .mem_read_data   (mem_read_data)
    );

    initial clk = 1'b0;
    always  #5 clk = ~clk;

    initial begin
        $dumpfile("../waves/dm_tb.vcd");
        $dumpvars(0, DataMemory_tb);
    end

    integer fail_count;
    integer test_id;

    task check;  // task to check if address holds correct data
        input [15:0] addr1;
        input [15:0] exp;
        begin
            mem_read = 1'b1;
            mem_access_addr = addr1; #5;
            if (mem_read_data !== exp) begin  // expected value from test.data
                $display("FAIL [T%0d]: addr=%0d got=0x%h exp=0x%h", test_id, addr1, mem_read_data, exp);
                fail_count = fail_count + 1;
            end else
                $display("PASS [T%0d]", test_id);
            test_id = test_id + 1;
        end
    endtask

    task write; // task to write to an address
        input [15:0] addr2;
        input [15:0] data;
        begin
            // Write to address
            mem_write_en    = 1'b1;
            mem_access_addr = addr2;
            mem_write_data  = data;
            @(posedge clk); #1;
            mem_write_en    = 1'b0;
        end
    endtask

    initial begin
        fail_count      = 0;
        test_id         = 1;
        mem_write_en    = 1'b0;
        mem_read        = 1'b0;
        mem_access_addr = 16'd0;
        mem_write_data  = 16'd0;

        $display("=== DataMemory Testbench ===");

        // ------------------------------------------------------------------
        // TEST GROUP 1: Read back initial values loaded from test.data
        // ------------------------------------------------------------------
        $display("--- Group 1: Verify $readmemb initialisation ---");

        // TODO: Read each of the 8 memory locations and verify against
        //       the known contents of your test.data file.
        //       Remember: only mem_access_addr[2:0] is used as the index.
        //       Address 16'd0 -> word 0, address 16'd2 -> word 2, etc.
        //       (Or use address 16'd0 -> word 0, address 16'd1 -> word 1,
        //        since only the lower 3 bits matter.)
        //
        //       mem_read = 1'b1;
        //       mem_access_addr = 16'd0; #5;
        //       if (mem_read_data !== 16'h0001)  // expected value from test.data line 0
        //           $display("FAIL [T%0d]: addr=0 got=0x%h exp=0x0001", test_id, mem_read_data);
        //       else
        //           $display("PASS [T%0d]", test_id);
        //       test_id = test_id + 1;

        // Read from each address and check if it holds the correct value
        check(16'd0, 16'h0001);
        check(16'd1, 16'h0002);
        check(16'd2, 16'h0003);
        check(16'd3, 16'h0004);
        check(16'd4, 16'h0005);
        check(16'd5, 16'h0006);
        check(16'd6, 16'h0007);
        check(16'd7, 16'h0008);


        // Clean up
        mem_read        = 1'b0;
        mem_access_addr = 16'd0;

        // ------------------------------------------------------------------
        // TEST GROUP 2: Write new values to all 8 locations, then read back
        // ------------------------------------------------------------------
        $display("--- Group 2: Write then read all 8 locations ---");

        // TODO: Write a distinct value to each of the 8 addresses using
        //       mem_write_en and posedge clk, then read each back.
        //
        //       // Write to address 0
        //       mem_write_en    = 1'b1;
        //       mem_access_addr = 16'd0;
        //       mem_write_data  = 16'hABCD;
        //       @(posedge clk); #1;
        //       mem_write_en    = 1'b0;
        //
        //       // Read back from address 0
        //       mem_read = 1'b1;
        //       mem_access_addr = 16'd0; #5;
        //       if (mem_read_data !== 16'hABCD) ...
        //       test_id = test_id + 1;

        // Write to each address
        write(16'd0, 16'hABCD);
        write(16'd1, 16'hA123);
        write(16'd2, 16'h8CD8);
        write(16'd3, 16'hAAAA);
        write(16'd4, 16'hFEED);
        write(16'd5, 16'hEFFD);
        write(16'd6, 16'hDEFF);
        write(16'd7, 16'hACDC);

        // Clean up
        mem_read        = 1'b0;
        mem_access_addr = 16'd0;

        // Read from each address and check if it holds the correct value
        check(16'd0, 16'hABCD);
        check(16'd1, 16'hA123);
        check(16'd2, 16'h8CD8);
        check(16'd3, 16'hAAAA);
        check(16'd4, 16'hFEED);
        check(16'd5, 16'hEFFD);
        check(16'd6, 16'hDEFF);
        check(16'd7, 16'hACDC);

        // Clean up
        mem_write_en    = 1'b0;
        mem_access_addr = 16'd0;
        mem_write_data  = 16'd0;

        // ------------------------------------------------------------------
        // TEST GROUP 3: mem_read = 0 must produce 16'd0 output
        // ------------------------------------------------------------------
        $display("--- Group 3: mem_read disabled -> output must be 0 ---");

        // TODO: De-assert mem_read and verify the output is 16'd0 regardless
        //       of the address.
        //
        //       mem_read = 1'b0;
        //       mem_access_addr = 16'd0; #5;
        //       if (mem_read_data !== 16'd0)
        //           $display("FAIL [T%0d]: mem_read=0 but output=%h", test_id, mem_read_data);
        //       else
        //           $display("PASS [T%0d]: output = 0 when mem_read=0", test_id);
        //       test_id = test_id + 1;

        mem_read = 1'b0;
        mem_access_addr = 16'd0; #5;
        if (mem_read_data !== 16'd0) begin
            $display("FAIL [T%0d]: mem_read=0 but output=%h", test_id, mem_read_data);
            fail_count = fail_count + 1;
        end else $display("PASS [T%0d]: output = 0 when mem_read=0", test_id);
        test_id = test_id + 1;

        // ------------------------------------------------------------------
        // TEST GROUP 4: Write then immediately read on the next cycle
        // ------------------------------------------------------------------
        $display("--- Group 4: Write followed by immediate read ---");

        // TODO: Write to address 3, then on the very next cycle read back
        //       from address 3 and confirm the new value is returned.

        write(16'd3, 16'hBEEF);  // The write task waits for posedge clk and adds #1 settling delay before returning,

        check(16'd3, 16'hBEEF);  // so check runs exactly one cycle after the write — verifying data is readable immediately.

        // clean up
        mem_write_en    = 1'b0;
        mem_read        = 1'b0;
        mem_access_addr = 16'd0;
        mem_write_data  = 16'd0;

        // ------------------------------------------------------------------
        // TEST GROUP 5: Disabled write must not alter memory
        // ------------------------------------------------------------------
        $display("--- Group 5: mem_write_en=0 must not overwrite memory ---");

        // TODO: Assert mem_write_en=0, clock one cycle, then read and confirm
        //       the previous value is unchanged.

        mem_read = 1'b1; // enable read
        mem_access_addr = 16'd5; #5; // select target address and read from it
        $display("Address = %0d, original value = %h",mem_access_addr, mem_read_data);

        mem_write_en    = 1'b0; // Asser mem_write_en=0
        mem_write_data  = 16'h9999; // Set data that should no be written to the address
        @(posedge clk); #1;
        $display("Attempting to write %h to address %0d", mem_write_data, mem_access_addr);

        mem_read = 1'b1; // assert mem_read
        mem_access_addr = 16'd5; #5; // read from target address again
        if (mem_read_data == 16'h9999) begin
            $display("FAIL [T%0d]: mem_write_en=0 but output=%h", test_id, mem_read_data); // check if memory was overwritten with mem_write_en=0
            fail_count = fail_count + 1;
        end else begin
            if (mem_read_data !== 16'hEFFD) begin
                $display("FAIL [T%0d]: expected original value but output=%h", test_id, mem_read_data); // check if the original value is still in the target memory address
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [T%0d]: memory not overwritten", test_id);
            end
        end
        test_id = test_id + 1;

        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d TESTS FAILED ===", fail_count, test_id - 1);
        $finish;
    end

endmodule
