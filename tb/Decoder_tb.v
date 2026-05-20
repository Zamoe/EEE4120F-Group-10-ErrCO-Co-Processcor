`timescale 1ns / 1ps

module Decoder_tb;

    reg     [15:0] data_in;
    reg     [5:0] parity;

    wire    [15:0] Error_Corr_Result;
    wire    SE_flag;
    wire    DE_flag;
    wire    parity_bit_error;

    Decoder uut (
        .data_in(data_in),
        .parity(parity),
        .Error_Corr_Result(Error_Corr_Result),
        .SE_flag(SE_flag),
        .DE_flag(DE_flag),
        .parity_bit_error(parity_bit_error)
    );

    // Encoder instance so the tb can compute correct parity for any data word
    reg  [15:0] enc_data;
    wire [5:0]  enc_parity;
    Encoder tb_enc (
        .data_in (enc_data),
        .parity  (enc_parity)
    );

    initial begin
        $dumpfile("../waves/Decoder_tb.vcd");
        $dumpvars(0, Decoder_tb);
    end

    integer fail_count;
    integer test_id;
    integer k;
    integer fb;

    initial begin
        fail_count = 0;
        test_id    = 1;
    end

    task check_result;
        input [15:0] got;
        input [15:0] expected;
        input got_SE;
        input expected_SE;
        input got_DE;
        input expected_DE;
        input got_PE;
        input expected_PE;
        input [63:0] id;
        begin
            if (got == expected && got_SE == expected_SE && got_DE==expected_DE && got_PE == expected_PE) begin
                $display("PASS [T%0d]: result = %0b (0x%h), expected = %0b (0x%h) | SE=%b DE=%b PE=%b", id, got, got, expected, expected, got_SE, got_DE, got_PE);
            end else begin
                $display("FAIL [T%0d]: result = %0b (0x%h), expected = %0b (0x%h)",
                         id, got, got, expected, expected);
                $display("           SE got=%b exp=%b | DE got=%b exp=%b | PE got=%b exp=%b",
                         got_SE, expected_SE, got_DE, expected_DE, got_PE, expected_PE);
                fail_count = fail_count + 1;
            end
        end
    endtask

initial begin
        $display("=== Decoder Testbench (extended) ===");

        $display("Test1: Correction of Single Bit Error");
        data_in = 16'h0001; parity = 6'b000000; #10;
        check_result(Error_Corr_Result, 16'h0000, SE_flag, 1'b1, DE_flag, 1'b0, parity_bit_error, 1'b0, test_id);
        test_id = test_id + 1;

        $display("Test2: Correction of Single Bit Error");
        data_in = 16'h0000; parity = 6'b100011; #10;
        check_result(Error_Corr_Result, 16'h0001, SE_flag, 1'b1, DE_flag, 1'b0, parity_bit_error, 1'b0, test_id);
        test_id = test_id + 1;

        $display("Test 3: Correction of Single Bit Error");
        data_in = 16'hFFFE; parity = 6'b011110; #10;
        check_result(Error_Corr_Result, 16'hFFFF, SE_flag, 1'b1, DE_flag, 1'b0, parity_bit_error, 1'b0, test_id);
        test_id = test_id + 1;

        $display("Test 4: Correction of Single Bit Error");
        data_in = 16'h0810; parity = 6'b110001; #10;
        check_result(Error_Corr_Result, 16'h0800, SE_flag, 1'b1, DE_flag, 1'b0, parity_bit_error, 1'b0, test_id);
        test_id = test_id + 1;

        // T5: parity 100011 is the valid parity for 0x0001; data 0x0101 is ONE
        // data bit (bit 8) away from that codeword -> single error, corrects to 0x0001.
        $display("Test 5: Single Bit Error (data bit 8) -> corrects to 0x0001");
        data_in = 16'h0101; parity = 6'b100011; #10;
        check_result(Error_Corr_Result, 16'h0001, SE_flag, 1'b1, DE_flag, 1'b0, parity_bit_error, 1'b0, test_id);
        test_id = test_id + 1;

        // T6: parity 100011 is valid for 0x0001; data 0x0111 is TWO data bits
        // (bits 4 and 8) away -> genuine double error, DE=1, data left unchanged.
        $display("Test 6: Double Error (data bits 4 and 8) -> DE flagged");
        data_in = 16'h0111; parity = 6'b100011; #10;
        check_result(Error_Corr_Result, 16'h0111, SE_flag, 1'b0, DE_flag, 1'b1, parity_bit_error, 1'b0, test_id);
        test_id = test_id + 1;

        // Tests 7..94 exhaustive single-bit-flip sweep
        $display("");
        $display("--- Tests 7-94: exhaustive single-bit-flip sweep ---");
        for (k = 0; k < 4; k = k + 1) begin
            case (k)
                0: enc_data = 16'h0000;
                1: enc_data = 16'hFFFF;
                2: enc_data = 16'hA5A5;
                3: enc_data = 16'h1234;
            endcase
            #5;
            for (fb = 0; fb < 16; fb = fb + 1) begin
                data_in = enc_data ^ (16'b1 << fb);
                parity  = enc_parity;
                #10;
                check_result(Error_Corr_Result, enc_data,
                             SE_flag, 1'b1, DE_flag, 1'b0,
                             parity_bit_error, 1'b0, test_id);
                test_id = test_id + 1;
            end
            for (fb = 0; fb < 6; fb = fb + 1) begin
                data_in = enc_data;
                parity  = enc_parity ^ (6'b1 << fb);
                #10;
                check_result(Error_Corr_Result, enc_data,
                             SE_flag, 1'b1, DE_flag, 1'b0,
                             parity_bit_error, (fb < 5) ? 1'b1 : 1'b0, test_id);
                test_id = test_id + 1;
            end
        end

        $display("");
        $display("--- Test 95: clean codeword (no error) ---");
        enc_data = 16'hA5A5; #5;
        data_in = enc_data;
        parity  = enc_parity;
        #10;
        check_result(Error_Corr_Result, enc_data,
                     SE_flag, 1'b0, DE_flag, 1'b0,
                     parity_bit_error, 1'b0, test_id);
        test_id = test_id + 1;

        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d TESTS FAILED ===", fail_count, test_id - 1);

        $finish;
    end

endmodule
