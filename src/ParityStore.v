// =========================================================================
// Project ErrCo: ErrCo StarCore-1 Co-Proccessor Parity Store Module
// =========================================================================
//
// Project Group 10
//
// MEMBERS:
//   - Member 1 Zameer Mahomed, MHMZAM005
//   - Member 2 Mahir Khan, KHNMAH014

// File        : ParityStore.v
// Description : SEC-DED Hamming(22,16) 6-bit Parity Storage Module
// This module stores a data's parity in its own register that shadows the same address of the data stored in StarCore1
//Operates following StarCore1 GPR and Datamemory modules
// =============================================================================

`timescale 1ns / 1ps

module ParityStore (
    input clk,
    // --- Write port (synchronous) -------------------------------------------
    input        parity_write_en, // Write enable; write occurs on posedge clk
    input  [15:0] mem_access_addr,  // Source memory address

    input  [5:0] parity_in,       // Data to write from Encoder
    output [5:0] parity_out
);
    // -------------------------------------------------------------------------
    // 3-bit address for parity
    wire [2:0] parity_addr = mem_access_addr[2:0];
    //parity memory needs to contain 8 6-bit words. 
    reg [5:0] parity_store_ram [7:0];
     
    //zero out the register in first run
    initial begin
        for (integer i = 0; i < 8; i = i + 1) begin
            //blocking
            parity_store_ram[i] = 6'd0;
        end
    end

    //-------- Parity store ---------
    //on positiev clock edge
    always @(posedge clk) begin
        //only store the address if write is enabled
        if (parity_write_en) begin
            parity_store_ram[parity_addr] <= parity_in;
        end
    end
    //---------Parity Read---------
    assign parity_out = parity_store_ram[parity_addr];

endmodule
