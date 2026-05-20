// =========================================================================
// Project ErrCo: ErrCo StarCore-1 Co-Proccessor Encoding Module
// =========================================================================
//
// Project Group 10
//
// MEMBERS:
//   - Member 1 Zameer Mahomed, MHMZAM005
//   - Member 2 Mahir Khan, KHNMAH014

// File        : Encoder.v
// Description : SEC-DED Hamming(22,16) 6-bit Parity Generator
//
// =============================================================================

`timescale 1ns / 1ps
//`include "../src/Parameter.v"

//module definition
module Encoder (
    input [15:0] data_in, // 16-bit of data to perform Hamming XOR on
    output [5:0] parity //calculated 6-bit parity
);
    //declare 6 single-bit wires to represent 6-parity bits
    wire p0;
    wire p1;
    wire p2;
    wire p3;
    wire p4;
    wire p5;

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

    assign p5 = (^data_in) ^ p0 ^ p1 ^ p2 ^ p3 ^ p4;

    //create 6-bit parity from p0-p5
    assign parity = {p5,p4, p3, p2, p1, p0};

endmodule

