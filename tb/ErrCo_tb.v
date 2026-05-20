// =========================================================================
// Project ErrCo: ErrCo StarCore-1 Co-Proccessor Top Level Testbench
// =========================================================================
//
// Project Group 10
//
// MEMBERS:
//   - Member 1 Zameer Mahomed, MHMZAM005
//   - Member 2 Mahir Khan, KHNMAH014
//
// File        : ErrCo_tb.v
// Description : Unit testbench for ErrCo.v - the mode-aware co-processor top.
//               Exercises all four sub-ops in isolation, the operand
//               isolation behaviour, the LDC-vs-CHECK double-error gating
//               asymmetry, and the errco_active master gate.
//
//   Build & run (from tb/):
//     iverilog -Wall -I ../src -o ../build/ErrCo_sim \
//        ../src/Encoder.v ../src/Decoder.v ../src/ParityStore.v \
//        ../src/ErrCo_Control.v ../src/ErrCo.v ErrCo_tb.v
//     cd ../test && ../build/ErrCo_sim
//     gtkwave ../waves/ErrCo_tb.vcd &
//
// mode encoding: 00 ENCST  01 SCRUB  10 LDC  11 CHECK
// =============================================================================

`timescale 1ns / 1ps

module ErrCo_tb;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg         clk;
    reg  [1:0]  mode;
    reg         errco_active;
    reg  [15:0] mem_access_addr;
    reg  [15:0] reg_read_data_2;
    reg  [15:0] mem_read_data;

    wire [15:0] errco_result;
    wire        parity_we;
    wire        mem_we_errco;
    wire        reg_we_errco;
    wire        SE_flag;
    wire        DE_flag;
    wire        ErrCo_invalid;

    // mode name constants
    localparam ENCST = 2'b00;
    localparam SCRUB = 2'b01;
    localparam LDC   = 2'b10;
    localparam CHECK = 2'b11;

    ErrCo uut (
        .clk            (clk),
        .mode           (mode),
        .errco_active   (errco_active),
        .mem_access_addr(mem_access_addr),
        .reg_read_data_2(reg_read_data_2),
        .mem_read_data  (mem_read_data),
        .errco_result   (errco_result),
        .parity_we      (parity_we),
        .mem_we_errco   (mem_we_errco),
        .reg_we_errco   (reg_we_errco),
        .SE_flag        (SE_flag),
        .DE_flag        (DE_flag),
        .ErrCo_invalid  (ErrCo_invalid)
    );

    // -------------------------------------------------------------------------
    // Clock - 10 ns period
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always  #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("../waves/ErrCo_tb.vcd");
        $dumpvars(0, ErrCo_tb);
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
    // Generic check: compare a got value against expected, print PASS/FAIL.
    // Works for any width up to 16 bits; single-bit signals pass 0/1.
    // -------------------------------------------------------------------------
    task check;
        input [63:0] id;
        input [255:0] label;    // short text tag
        input [15:0] got;
        input [15:0] expected;
        begin
            if (got === expected) begin
                $display("PASS [T%0d] %0s: got 0x%h", id, label, got);
            end else begin
                $display("FAIL [T%0d] %0s: got 0x%h, expected 0x%h", id, label, got, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Helper: drive an ENCST (protected store). Holds across a rising edge so
    // the ParityStore write commits, then drops errco_active.
    // -------------------------------------------------------------------------
    task do_encst;
        input [15:0] addr;
        input [15:0] data;
        begin
            @(negedge clk);
            mode            = ENCST;
            errco_active    = 1'b1;
            mem_access_addr = addr;
            reg_read_data_2 = data;
            mem_read_data   = 16'd0;
            @(posedge clk);          // parity write commits here
            @(negedge clk);
            errco_active    = 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Encoder reference (independent) - used to predict the parity that ENCST
    // should have stored, so the parity-bit-error tests can corrupt a known
    // value. Mirrors the position-rule reference from Encoder_tb.v.
    // -------------------------------------------------------------------------
    reg [4:0] dpos [0:15];
    initial begin
        dpos[0]=5'd3;  dpos[1]=5'd5;  dpos[2]=5'd6;  dpos[3]=5'd7;
        dpos[4]=5'd9;  dpos[5]=5'd10; dpos[6]=5'd11; dpos[7]=5'd12;
        dpos[8]=5'd13; dpos[9]=5'd14; dpos[10]=5'd15; dpos[11]=5'd17;
        dpos[12]=5'd18; dpos[13]=5'd19; dpos[14]=5'd20; dpos[15]=5'd21;
    end
    function [5:0] ref_parity;
        input [15:0] d;
        integer di;
        reg r0,r1,r2,r3,r4,r5;
        begin
            r0=0;r1=0;r2=0;r3=0;r4=0;
            for (di=0; di<16; di=di+1) if (d[di]) begin
                if (dpos[di][0]) r0=r0^1'b1;
                if (dpos[di][1]) r1=r1^1'b1;
                if (dpos[di][2]) r2=r2^1'b1;
                if (dpos[di][3]) r3=r3^1'b1;
                if (dpos[di][4]) r4=r4^1'b1;
            end
            r5=(^d)^r0^r1^r2^r3^r4;
            ref_parity={r5,r4,r3,r2,r1,r0};
        end
    endfunction

    initial begin
        // initial values
        mode            = ENCST;
        errco_active    = 1'b0;
        mem_access_addr = 16'd0;
        reg_read_data_2 = 16'd0;
        mem_read_data   = 16'd0;
        #2;

        $display("=== ErrCo Testbench ===");

        // ==================================================================
        // ENCST (mode 00) - protected store
        // ==================================================================
        $display("");
        $display("--- ENCST (mode 00) ---");

        // T1-T3: ENCST asserts parity_we, no register write, no mem write.
        @(negedge clk);
        mode = ENCST; errco_active = 1'b1;
        mem_access_addr = 16'h0000; reg_read_data_2 = 16'hA5A5; mem_read_data = 16'd0;
        #1;
        check(test_id, "ENCST parity_we",    parity_we,    1'b1); test_id=test_id+1;
        check(test_id, "ENCST reg_we",       reg_we_errco, 1'b0); test_id=test_id+1;
        check(test_id, "ENCST mem_we_errco", mem_we_errco, 1'b0); test_id=test_id+1;
        @(posedge clk); @(negedge clk); errco_active = 1'b0;

        // T4: the parity actually stored at slot 0 matches the reference.
        #1;
        check(test_id, "ENCST stored parity", {10'b0, uut.ECC.PS.parity_store_ram[0]},
                                              {10'b0, ref_parity(16'hA5A5)}); test_id=test_id+1;

        // ==================================================================
        // LDC (mode 10) - load with correction
        // ==================================================================
        $display("");
        $display("--- LDC (mode 10) ---");

        // T5-T8: clean LDC. Store 0x1234, read it back clean -> errco_result
        // is the corrected (== original) data, reg_we high, no flags.
        do_encst(16'h0001, 16'h1234);
        @(negedge clk);
        mode = LDC; errco_active = 1'b1;
        mem_access_addr = 16'h0001; mem_read_data = 16'h1234;  // clean
        #1;
        check(test_id, "LDC clean result", errco_result, 16'h1234); test_id=test_id+1;
        check(test_id, "LDC clean reg_we", reg_we_errco, 1'b1);     test_id=test_id+1;
        check(test_id, "LDC clean SE",     {15'b0,SE_flag}, 16'd0); test_id=test_id+1;
        check(test_id, "LDC clean invalid",{15'b0,ErrCo_invalid}, 16'd0); test_id=test_id+1;
        @(negedge clk); errco_active = 1'b0;

        // T9-T12: LDC with a single-bit DATA error. Store 0x1234, read 0x1235
        // (bit 0 flipped) -> corrected back to 0x1234, SE=1, DE=0, reg_we=1.
        @(negedge clk);
        mode = LDC; errco_active = 1'b1;
        mem_access_addr = 16'h0001; mem_read_data = 16'h1235;  // single data-bit flip
        #1;
        check(test_id, "LDC SEU result",  errco_result, 16'h1234); test_id=test_id+1;
        check(test_id, "LDC SEU SE",      {15'b0,SE_flag}, 16'd1); test_id=test_id+1;
        check(test_id, "LDC SEU DE",      {15'b0,DE_flag}, 16'd0); test_id=test_id+1;
        check(test_id, "LDC SEU reg_we",  {15'b0,reg_we_errco}, 16'd1); test_id=test_id+1;
        @(negedge clk); errco_active = 1'b0;

        // T13-T16: LDC with a DOUBLE error. Store 0x1234, read 0x1237 (bits
        // 0 and 1 flipped) -> DE=1, reg_we MUST be 0, ErrCo_invalid=1.
        @(negedge clk);
        mode = LDC; errco_active = 1'b1;
        mem_access_addr = 16'h0001; mem_read_data = 16'h1237;  // two-bit flip
        #1;
        check(test_id, "LDC DE flag",     {15'b0,DE_flag}, 16'd1); test_id=test_id+1;
        check(test_id, "LDC DE reg_we=0", {15'b0,reg_we_errco}, 16'd0); test_id=test_id+1;
        check(test_id, "LDC DE invalid=1",{15'b0,ErrCo_invalid}, 16'd1); test_id=test_id+1;
        check(test_id, "LDC DE SE=0",     {15'b0,SE_flag}, 16'd0); test_id=test_id+1;
        @(negedge clk); errco_active = 1'b0;

        // ==================================================================
        // CHECK (mode 11) - diagnostic status word
        // ==================================================================
        $display("");
        $display("--- CHECK (mode 11) ---");

        // T17-T19: CHECK on a clean word -> status word 0x0000, reg_we=1.
        do_encst(16'h0002, 16'hCAFE);
        @(negedge clk);
        mode = CHECK; errco_active = 1'b1;
        mem_access_addr = 16'h0002; mem_read_data = 16'hCAFE;  // clean
        #1;
        check(test_id, "CHECK clean status", errco_result, 16'h0000); test_id=test_id+1;
        check(test_id, "CHECK clean reg_we", {15'b0,reg_we_errco}, 16'd1); test_id=test_id+1;
        check(test_id, "CHECK clean mem_we", {15'b0,mem_we_errco}, 16'd0); test_id=test_id+1;
        @(negedge clk); errco_active = 1'b0;

        // T20-T21: CHECK on a single-bit data error -> status word bit0 (SE)
        // set => 0x0001, reg_we still 1.
        @(negedge clk);
        mode = CHECK; errco_active = 1'b1;
        mem_access_addr = 16'h0002; mem_read_data = 16'hCAFF;  // bit 0 flipped
        #1;
        check(test_id, "CHECK SEU status", errco_result, 16'h0001); test_id=test_id+1;
        check(test_id, "CHECK SEU reg_we", {15'b0,reg_we_errco}, 16'd1); test_id=test_id+1;
        @(negedge clk); errco_active = 1'b0;

        // T22-T24: CHECK on a DOUBLE error -> status word bit1 (DE) set =>
        // 0x0002. Crucially reg_we is STILL 1 (CHECK reports DE, not gated).
        @(negedge clk);
        mode = CHECK; errco_active = 1'b1;
        mem_access_addr = 16'h0002; mem_read_data = 16'hCAFD;  // bits 0,1 flipped
        #1;
        check(test_id, "CHECK DE status",     errco_result, 16'h0002); test_id=test_id+1;
        check(test_id, "CHECK DE reg_we=1",   {15'b0,reg_we_errco}, 16'd1); test_id=test_id+1;
        check(test_id, "CHECK DE invalid=0",  {15'b0,ErrCo_invalid}, 16'd0); test_id=test_id+1;

        // ==================================================================
        // SCRUB (mode 01)
        // ==================================================================
        $display("");
        $display("--- SCRUB (mode 01) ---");

        // T25-T27: SCRUB on a single-bit DATA error. Store 0x0F0F, read
        // 0x0F0E -> corrected to 0x0F0F on errco_result, mem_we_errco=1
        // (write corrected word back), parity_we=0 (data error, not parity).
        do_encst(16'h0003, 16'h0F0F);
        @(negedge clk);
        mode = SCRUB; errco_active = 1'b1;
        mem_access_addr = 16'h0003; mem_read_data = 16'h0F0E;  // bit 0 flipped
        #1;
        check(test_id, "SCRUB data result",   errco_result, 16'h0F0F); test_id=test_id+1;
        check(test_id, "SCRUB data mem_we=1", {15'b0,mem_we_errco}, 16'd1); test_id=test_id+1;
        check(test_id, "SCRUB data pw=0",     {15'b0,parity_we},    16'd0); test_id=test_id+1;
        @(negedge clk); errco_active = 1'b0;

        // T28-T31: SCRUB on a PARITY-bit error. Store 0x0F0F clean, then
        // corrupt one bit of the stored parity at slot 3. Read the (clean)
        // data back under SCRUB: data is clean so mem_we_errco=1 writes the
        // same data, and parity_we=1 because the corrupted bit was a parity
        // bit -> ParityStore gets refreshed.
        do_encst(16'h0003, 16'h0F0F);
        uut.ECC.PS.parity_store_ram[3] = uut.ECC.PS.parity_store_ram[3] ^ 6'b000001;
        @(negedge clk);
        mode = SCRUB; errco_active = 1'b1;
        mem_access_addr = 16'h0003; mem_read_data = 16'h0F0F;  // data itself clean
        #1;
        check(test_id, "SCRUB parity result", errco_result, 16'h0F0F); test_id=test_id+1;
        check(test_id, "SCRUB parity pw=1",   {15'b0,parity_we},    16'd1); test_id=test_id+1;
        check(test_id, "SCRUB parity SE=1",   {15'b0,SE_flag},      16'd1); test_id=test_id+1;
        // T31: on a parity-bit error the data was clean, so the optimized
        // SCRUB skips the redundant data-memory write (mem_we_errco includes
        // `~parity_bit_error` term). Parity is rewritten via parity_we=1 above.
        check(test_id, "SCRUB parity mem_we=0",{15'b0,mem_we_errco},16'd0); test_id=test_id+1;
        @(posedge clk);   // let the parity rewrite commit
        @(negedge clk); errco_active = 1'b0;

        // T32: after the scrub, the refreshed parity at slot 3 should once
        // again equal the correct reference parity for 0x0F0F.
        #1;
        check(test_id, "SCRUB parity refreshed",
              {10'b0, uut.ECC.PS.parity_store_ram[3]},
              {10'b0, ref_parity(16'h0F0F)}); test_id=test_id+1;

        // T33-T35: SCRUB on a DOUBLE error -> mem_we_errco MUST be 0 (do not
        // write garbage back), parity_we=0, DE=1.
        do_encst(16'h0004, 16'h3C3C);
        @(negedge clk);
        mode = SCRUB; errco_active = 1'b1;
        mem_access_addr = 16'h0004; mem_read_data = 16'h3C3F;  // bits 0,1 flipped
        #1;
        check(test_id, "SCRUB DE mem_we=0", {15'b0,mem_we_errco}, 16'd0); test_id=test_id+1;
        check(test_id, "SCRUB DE pw=0",     {15'b0,parity_we},    16'd0); test_id=test_id+1;
        check(test_id, "SCRUB DE flag=1",   {15'b0,DE_flag},      16'd1); test_id=test_id+1;
        @(negedge clk); errco_active = 1'b0;

        // ==================================================================
        // errco_active master gate
        // ==================================================================
        $display("");
        $display("--- errco_active master gate ---");

        // T36-T39: with errco_active LOW, NO write-enable may assert no matter
        // what mode is presented. Sweep all four modes.
        @(negedge clk);
        errco_active = 1'b0;
        mode = ENCST; mem_access_addr = 16'h0000;
        reg_read_data_2 = 16'hFFFF; mem_read_data = 16'hFFFF;
        #1;
        check(test_id, "gate ENCST off", {13'b0,parity_we,mem_we_errco,reg_we_errco}, 16'd0); test_id=test_id+1;
        mode = SCRUB; #1;
        check(test_id, "gate SCRUB off", {13'b0,parity_we,mem_we_errco,reg_we_errco}, 16'd0); test_id=test_id+1;
        mode = LDC; #1;
        check(test_id, "gate LDC off",   {13'b0,parity_we,mem_we_errco,reg_we_errco}, 16'd0); test_id=test_id+1;
        mode = CHECK; #1;
        check(test_id, "gate CHECK off", {13'b0,parity_we,mem_we_errco,reg_we_errco}, 16'd0); test_id=test_id+1;

        // ==================================================================
        // Operand isolation - enc_data_in / dec_data_in held at 0 when the
        // respective sub-module is not needed.
        //   uut.enc_data_in : Encoder data input  (internal wire)
        //   uut.dec_data_in : Decoder data input  (internal wire)
        //
        // The Encoder is needed only for ENCST and for SCRUB *when the error
        // was a parity-bit error*. The Decoder is needed for SCRUB/LDC/CHECK.
        // In every other case the corresponding input must be 16'd0 so the
        // sub-module does not toggle (constant-zero operand isolation).
        // ==================================================================
        $display("");
        $display("--- operand isolation (enc_data_in / dec_data_in) ---");

        // T40: ENCST - Encoder IS needed, must see reg_read_data_2; Decoder
        //      is NOT needed, dec_data_in must be 0.
        @(negedge clk);
        mode = ENCST; errco_active = 1'b1;
        mem_access_addr = 16'h0000; reg_read_data_2 = 16'h5A5A; mem_read_data = 16'h1234;
        #1;
        check(test_id, "ENCST enc_data_in = reg_read_data_2", uut.enc_data_in, 16'h5A5A); test_id=test_id+1;
        check(test_id, "ENCST dec_data_in isolated (0)",       uut.dec_data_in, 16'h0000); test_id=test_id+1;
        @(negedge clk); errco_active = 1'b0;

        // T42: LDC - Decoder IS needed, must see mem_read_data; Encoder is
        //      NOT needed, enc_data_in must be 0.
        @(negedge clk);
        mode = LDC; errco_active = 1'b1;
        mem_access_addr = 16'h0000; reg_read_data_2 = 16'h5A5A; mem_read_data = 16'h1234;
        #1;
        check(test_id, "LDC dec_data_in = mem_read_data",  uut.dec_data_in, 16'h1234); test_id=test_id+1;
        check(test_id, "LDC enc_data_in isolated (0)",      uut.enc_data_in, 16'h0000); test_id=test_id+1;
        @(negedge clk); errco_active = 1'b0;

        // T44: CHECK - same as LDC: Decoder needed, Encoder isolated.
        @(negedge clk);
        mode = CHECK; errco_active = 1'b1;
        mem_access_addr = 16'h0000; reg_read_data_2 = 16'h5A5A; mem_read_data = 16'h1234;
        #1;
        check(test_id, "CHECK enc_data_in isolated (0)",   uut.enc_data_in, 16'h0000); test_id=test_id+1;

        // T45: SCRUB on a DATA-bit error - this is the case the fix changed.
        //      The error is in the data, so parity_bit_error=0, the Encoder is
        //      NOT needed (no parity rewrite), so enc_data_in must be isolated
        //      to 0 even though SCRUB is active. The Decoder must still see the
        //      data. Store 0x2222 clean, read 0x2223 (one data-bit flip).
        do_encst(16'h0006, 16'h2222);
        @(negedge clk);
        mode = SCRUB; errco_active = 1'b1;
        mem_access_addr = 16'h0006; reg_read_data_2 = 16'h5A5A; mem_read_data = 16'h2223;
        #1;
        check(test_id, "SCRUB(data err) enc_data_in isolated (0)", uut.enc_data_in, 16'h0000); test_id=test_id+1;
        check(test_id, "SCRUB(data err) dec_data_in = mem_read_data", uut.dec_data_in, 16'h2223); test_id=test_id+1;
        check(test_id, "SCRUB(data err) parity_we = 0",            {15'b0,parity_we}, 16'd0); test_id=test_id+1;
        @(negedge clk); errco_active = 1'b0;

        // T48: SCRUB on a PARITY-bit error - here the Encoder IS needed (parity
        //      gets rewritten), so enc_data_in must carry mem_read_data, NOT be
        //      isolated. Store 0x2222 clean, corrupt a stored parity bit, read
        //      the (clean) data back.
        do_encst(16'h0006, 16'h2222);
        uut.ECC.PS.parity_store_ram[6] = uut.ECC.PS.parity_store_ram[6] ^ 6'b000001;
        @(negedge clk);
        mode = SCRUB; errco_active = 1'b1;
        mem_access_addr = 16'h0006; reg_read_data_2 = 16'h5A5A; mem_read_data = 16'h2222;
        #1;
        check(test_id, "SCRUB(parity err) enc_data_in = mem_read_data", uut.enc_data_in, 16'h2222); test_id=test_id+1;
        check(test_id, "SCRUB(parity err) parity_we = 1",              {15'b0,parity_we}, 16'd1); test_id=test_id+1;
        @(posedge clk); @(negedge clk); errco_active = 1'b0;

        // T50: errco_active LOW - both sub-module inputs isolated regardless
        //      of mode. (enc_active and dec_active both fold in errco_active
        //      via the is_* terms.)
        @(negedge clk);
        errco_active = 1'b0;
        mode = ENCST; reg_read_data_2 = 16'hFFFF; mem_read_data = 16'hFFFF;
        #1;
        check(test_id, "gate off: enc_data_in isolated (0)", uut.enc_data_in, 16'h0000); test_id=test_id+1;
        check(test_id, "gate off: dec_data_in isolated (0)", uut.dec_data_in, 16'h0000); test_id=test_id+1;

        // ==================================================================
        // Summary
        // ==================================================================
        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d TESTS FAILED ===", fail_count, test_id - 1);

        $finish;
    end

endmodule
