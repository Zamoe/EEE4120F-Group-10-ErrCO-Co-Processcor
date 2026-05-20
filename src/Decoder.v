// =========================================================================
// Project ErrCo: ErrCo StarCore-1 Co-Proccessor Decoding Module Testbench
// =========================================================================
//
// Project Group 10
//
// MEMBERS:
//   - Member 1 Zameer Mahomed, MHMZAM005
//   - Member 2 Mahir Khan, KHNMAH014

// File        : Decoder.v
// Description : SEC-DED Hamming(22,16) 6-bit Error Syndrome Calculator and Single Bit Corrector
//
// =============================================================================

`timescale 1ns / 1ps
//`include "../src/Parameter.v"

//module definition
module Decoder (
    input [15:0] data_in, // 16-bit of data to perform Hamming XOR on
    input [5:0] parity, //corresponding 6-bit parity from the parity store

    //-------Outputs---------
    output reg [15:0] Error_Corr_Result, //corrected output result
    output SE_flag, // Single error detected (used for debugging in GTKWAVE)
    output DE_flag, // Unsued output flag to indicate double error has occured
    output parity_bit_error // ADDED: SE detected AND syndrome points to a parity bit (1,2,4,8,16) - data is clean, parity is corrupted
);

// ------Decoder Wires ---------
    //Parity Recalulation
    //declare 6 single-bit wires to represent 6-parity bits for decoder to calculate
    wire p0;
    wire p1;
    wire p2;
    wire p3;
    wire p4;
    wire p5;
    wire [5:0]  decoder_parity;     //parity of data to be checked

    //Error Syndrome wires
    wire [4:0]  error_syndrome;     // wire stores calculated 5-bit single error Syndrome
    wire        p5_error_check;     //6th bit parity double_error_check checks if double error has occured

    //TODO, should vlaues be defeualetd to zero?

// --------------Same Parity logic from Encoder Module --------------------
    //-----------XOR------------
    //Follow Hamming Matrix
    //all powers of 2 are parity bits and rest are data
    //This means d0,d1,d3 & d15 are removed:giving mapping for XOR:
    //pos 0 - p0: 0,1,3,4,6,8,10,11,13.15
    //pos 1 - p1: 0,2,3,5,6,9,10,12,13
    //pos 2 - p2: 1,2,3,7,8,9,10,14,15
    //pos 4 - p3: 4,5,6,7,8,9,10
    //pos 8 - p4: 11,12,13,14,15
    //pos 16- p5: 1-15,p1-p4

    //XOR TREE

    assign p0 = data_in[0] ^ data_in[1] ^ data_in[3] ^ data_in[4] ^ data_in[6] ^ data_in[8] ^ data_in[10] ^ data_in[11] ^ data_in[13] ^ data_in[15];

    assign p1 = data_in[0]^data_in[2]^data_in[3]^data_in[5]^data_in[6]^data_in[9]^data_in[10]^data_in[12]^data_in[13];

    assign p2 = data_in[1]^data_in[2]^data_in[3]^data_in[7]^data_in[8]^data_in[9]^data_in[10]^data_in[14]^data_in[15];

    assign p3 = data_in[4]^data_in[5]^data_in[6]^data_in[7]^data_in[8]^data_in[9]^data_in[10];

    assign p4 = data_in[11]^data_in[12]^data_in[13]^data_in[14]^data_in[15];

    // FIXED: p5 (overall SEC-DED parity) recomputed from STORED parity bits, not
    // freshly-recomputed ones. Otherwise a SEU in a stored parity bit is invisible
    // to p5_error_check and gets misreported as a double error.
    assign p5 = (^data_in) ^ parity[0] ^ parity[1] ^ parity[2] ^ parity[3] ^ parity[4];

    //create 6-bit parity from p0-p5
    assign decoder_parity = {p5,p4, p3, p2, p1, p0};

    //-------- Decoder: Syndrome calculation ----------
    assign error_syndrome = decoder_parity[4:0] ^ parity[4:0];  //XOR calc with expected parity
    assign p5_error_check = decoder_parity[5] ^ parity[5];      //XOR extra calc bit with expected extra parity

    //-------- Decoder: Error detection ----------
    // if error_syndrome !=0, then theres definitely a single or more bit error
    // if p5_error_check == 0, then even number of XOR flips, so indicates double or quadruple etc, error has occured
    // if both error_syndrome !=0 and p5_error_check is 1, then there is definitely a single bit error
    //NOTE: technically this flag could pass for 3 or more bit errors - but with 6-parity, not checking for them here and assuming 3 or more bit is unlikely

    // FIXED: SEC-DED decode table -> a single error exists whenever the overall
    // parity check fails. Also covers the case where p5 itself is the flipped bit
    // (error_syndrome==0, p5_error_check==1): data is clean, correction case block
    // falls through to default and leaves it untouched.
    assign SE_flag = p5_error_check; //SE flag 1 means Single bit error

    // if p5_error_check is now 0, there is definitely a double error

    //assign DE_flag = (error_syndrome != 5'b0) && (p5_error_check == 1'b0); //DE flag = 1 means double bit error.
    assign DE_flag = (error_syndrome != 5'b0) && (p5_error_check == 1'b0); //DE flag = 1 means double bit error.

    // -------- Decoder: Parity-Bit Error Detection ----------
    // ADDED: parity_bit_error asserts when SE is high but the syndrome lands at a parity-bit position
    // (1, 2, 4, 8, or 16). In this case the data bits are clean - it is the stored parity that was corrupted.
    // Used by SCRUB (1010 sub-op 01) to know whether to refresh ParityStore.
    assign parity_bit_error = SE_flag && (
        (error_syndrome == 5'd1)  ||
        (error_syndrome == 5'd2)  ||
        (error_syndrome == 5'd4)  ||
        (error_syndrome == 5'd8)  ||
        (error_syndrome == 5'd16)
    );

    //-------- Decoder: Error Correction ----------

    // The codeword with parity bits is 22-bit as parity bits are powers of 2
    //each power of 2 index is removed, so indices of syndrome need to reflect that

    // =============================================================================
    // VISUAL SYNDROME TO DATA BIT MAPING TABLE
    // -----------------------------------------------------------------------------
    // Syndrome (Dec) | Codeword Pos | Targeted Bit | Note
    // -----------------------------------------------------------------------------
    //      3         |    Pos 3     |  data_in[0]  | First Data Bit
    //      5         |    Pos 5     |  data_in[1]  |
    //      6         |    Pos 6     |  data_in[2]  |
    //      7         |    Pos 7     |  data_in[3]  |
    //      9         |    Pos 9     |  data_in[4]  | After  Parity P3 (Pos 8)
    //      10        |    Pos 10    |  data_in[5]  |
    //      11        |    Pos 11    |  data_in[6]  |
    //      12        |    Pos 12    |  data_in[7]  |
    //      13        |    Pos 13    |  data_in[8]  |
    //      14        |    Pos 14    |  data_in[9]  |
    //      15        |    Pos 15    |  data_in[10] |
    //      17        |    Pos 17    |  data_in[11] |  After Parity P4 (Pos 16)
    //      18        |    Pos 18    |  data_in[12] |
    //      19        |    Pos 19    |  data_in[13] |
    //      20        |    Pos 20    |  data_in[14] |
    //      21        |    Pos 21    |  data_in[15] | Last Data Bit
    // =============================================================================


    always @(*) begin
        //default case leave data alone & set output as the input data
        Error_Corr_Result = data_in;

        if (SE_flag) begin //only start if single bit error
            case(error_syndrome) // based on what postion syndrome has identified
                // bit flip corresponding bit
                5'd3 : Error_Corr_Result[0] = ~data_in[0];
                5'd5 : Error_Corr_Result[1] = ~data_in[1];
                5'd6 : Error_Corr_Result[2] = ~data_in[2];
                5'd7 : Error_Corr_Result[3] = ~data_in[3];
                5'd9 : Error_Corr_Result[4] = ~data_in[4];
                5'd10: Error_Corr_Result[5] = ~data_in[5];
                5'd11: Error_Corr_Result[6] = ~data_in[6];
                5'd12: Error_Corr_Result[7] = ~data_in[7];
                5'd13: Error_Corr_Result[8] = ~data_in[8];
                5'd14: Error_Corr_Result[9] = ~data_in[9];
                5'd15: Error_Corr_Result[10] = ~data_in[10];
                5'd17: Error_Corr_Result[11] = ~data_in[11];
                5'd18: Error_Corr_Result[12] = ~data_in[12];
                5'd19: Error_Corr_Result[13] = ~data_in[13];
                5'd20: Error_Corr_Result[14] = ~data_in[14];
                5'd21: Error_Corr_Result[15] = ~data_in[15];
                default: Error_Corr_Result = data_in; //default case
            endcase
        end
    end

endmodule
