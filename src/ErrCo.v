// =========================================================================
// Project ErrCo: ErrCo StarCore-1 Co-Proccessor Top Level ErrCo Module
// =========================================================================
//
// Project Group 10
//
// MEMBERS:
//   - Member 1 Zameer Mahomed, MHMZAM005
//   - Member 2 Mahir Khan, KHNMAH014
//
// File        : ErrCo.v
// Description : SEC-DED Hamming(22,16) co-processor - mode-aware top layer.
//
//   ErrCo.v is to ErrCo_Control.v what ControlUnit.v is to Datapath.v:
//   ErrCo_Control is the pure structural wiring of Encoder + ParityStore +
//   Decoder; ErrCo is the control layer that decodes the 2-bit sub-op,
//   selects the sub-module inputs (with operand isolation), and generates
//   the gated write-enables the main StarCore1 datapath consumes.
//
//   The co-processor is reached through opcode 1010. The 2-bit `mode` field
//   selects one of four operations:
//
//     mode 00  ENCST  - protected store: encode parity for reg_read_data_2
//                       and write it into ParityStore at mem_access_addr.
//     mode 01  SCRUB  - read mem_read_data, decode/correct, write the
//                       corrected word back to data memory. If the error
//                       was in a stored PARITY bit (data was clean) also
//                       re-encode and rewrite the parity word.
//     mode 10  LDC    - load-with-correction: decode/correct mem_read_data
//                       and write the corrected word to a register.
//     mode 11  CHECK  - diagnostic: decode mem_read_data and write a status
//                       word {.., PE, DE, SE} to a register so software can
//                       branch on memory health.
//
//   errco_active is high ONLY when the opcode actually is 1010. mode[1:0]
//   are just instruction bits and exist for every instruction, so every
//   write-enable below is gated by errco_active - without it ErrCo would
//   act on unrelated instructions.
//
//   Build/run of the unit testbench (from tb/):
//     iverilog -Wall -I ../src -o ../build/ErrCo_sim \
//        ../src/Encoder.v ../src/Decoder.v ../src/ParityStore.v \
//        ../src/ErrCo_Control.v ../src/ErrCo.v ErrCo_tb.v
//     cd ../test && ../build/ErrCo_sim
// =============================================================================

`timescale 1ns / 1ps

module ErrCo (
    input        clk,

    // --- control inputs from the main CPU ----------------------------------
    input  [1:0] mode,          // 1010 sub-op: 00 ENCST / 01 SCRUB / 10 LDC / 11 CHECK
    input        errco_active,  // high only when opcode == 1010

    // --- data inputs from the main CPU -------------------------------------
    input  [15:0] mem_access_addr,   // ALU result - indexes ParityStore
    input  [15:0] reg_read_data_2,   // value being stored (ENCST encodes this)
    input  [15:0] mem_read_data,     // value read from data memory (SCRUB/LDC/CHECK decode this)

    // --- outputs to the main CPU -------------------------------------------
    output [15:0] errco_result,  // muxed: corrected_data (01/10) or status_word (11)
    output        parity_we,     // ParityStore write enable
    output        mem_we_errco,  // SCRUB: drive data-mem write port from errco_result + enable write
    output        reg_we_errco,  // LDC/CHECK: this instruction writes the register file
    output        SE_flag,       // single error found (always valid, any decode mode)
    output        DE_flag,       // double error found (always valid, any decode mode)
    output        ErrCo_invalid  // LDC hit an uncorrectable double error - load suppressed
);

    // =========================================================================
    // Mode decode (one-hot, all qualified by errco_active)
    // =========================================================================
    wire is_encst = errco_active & (mode == 2'b00);
    wire is_scrub = errco_active & (mode == 2'b01);
    wire is_ldc   = errco_active & (mode == 2'b10);
    wire is_check = errco_active & (mode == 2'b11);
    //ADDED Zameer 
    wire        parity_bit_error;

    // =========================================================================
    // Operand isolation enables
    //   The Encoder is needed for ENCST (encode the stored value) and for
    //   SCRUB *only when* the error turned out to be in a stored parity bit.
    //   The Decoder is needed for every read-side mode (SCRUB/LDC/CHECK).
    //   When a sub-module is not needed its data input is forced to zero so
    //   it does not toggle - this is constant-zero operand isolation and is
    //   the power-saving feature for High Performance Embedded Systems.
    //
    //   NOTE: enc_active for SCRUB depends on parity_bit_error, which is an
    //   OUTPUT of the Decoder. That is a legal combinational dependency (no
    //   loop): Decoder -> parity_bit_error -> enc_active -> Encoder ->
    //   parity_encoded -> ParityStore D-input. The Encoder output never feeds
    //   back into the Decoder. The whole chain still settles within one cycle.
    // =========================================================================
    wire enc_active = is_encst | (is_scrub & parity_bit_error);
    wire dec_active = is_scrub | is_ldc | is_check;

    // =========================================================================
    // Sub-module input muxes (with operand isolation)
    //   Encoder data : gated by enc_active. The Encoder is only needed for
    //                  ENCST and for SCRUB-when-parity_bit_error; in every
    //                  other case (including a SCRUB that hit a plain data-bit
    //                  error) its input is forced to 0 so it does not toggle.
    //                    enc_active && ENCST  -> reg_read_data_2 (stored value)
    //                    enc_active && SCRUB  -> mem_read_data   (clean memory
    //                                            word being re-protected)
    //                    !enc_active          -> 0
    //   Decoder data : gated by dec_active.
    //                    SCRUB/LDC/CHECK      -> mem_read_data
    //                    else                 -> 0
    // =========================================================================
    wire [15:0] enc_data_in = !enc_active ? 16'd0           :
                              is_encst    ? reg_read_data_2 :
                                            mem_read_data;   // is_scrub & parity_bit_error

    wire [15:0] dec_data_in = dec_active ? mem_read_data : 16'd0;

    // =========================================================================
    // ErrCo_Control - the structural Encoder/ParityStore/Decoder datapath
    // =========================================================================
    wire [15:0] corrected_data;
    

    ErrCo_Control ECC (
        .clk              (clk),
        .parity_write_en  (parity_we),       // generated below
        .mem_access_addr  (mem_access_addr),
        .data_encoder     (enc_data_in),
        .data_to_decoder  (dec_data_in),
        .Error_Corr_Result(corrected_data),
        .SE_flag          (SE_flag),
        .DE_flag          (DE_flag),
        .parity_bit_error (parity_bit_error)
    );

    // =========================================================================
    // Status word (mode 11 CHECK)
    //   bit 0 = SE : a single error was found (corrected if it was a data bit)
    //   bit 1 = DE : a double error was found (uncorrectable)
    //   bit 2 = PE : the single error was in a stored parity bit (data clean)
    //   PE implies SE - parity_bit_error is defined as SE_flag && (syndrome is
    //   a parity-bit position), so a parity-bit error reads back as 3'b101.
    // =========================================================================
    wire [15:0] status_word = {13'b0, parity_bit_error, DE_flag, SE_flag};

    // =========================================================================
    // ErrCo result output mux
    //   modes 01/10 -> corrected_data
    //   mode 11     -> status_word
    //   mode 00     -> defaults to corrected_data; ENCST has dec_active=0 so
    //                  corrected_data is 0x0000, and reg_we_errco=0 so nothing
    //                  consumes it anyway.
    // =========================================================================
    assign errco_result = is_check ? status_word : corrected_data;

    // =========================================================================
    // Write-enable generation (all already qualified by errco_active via the
    // is_* terms)
    // =========================================================================

    // ParityStore write:
    //   ENCST always writes freshly-encoded parity.
    //   SCRUB rewrites parity ONLY when the corrupted bit was a parity bit
    //   (parity_bit_error) and the word is still correctable (~DE_flag).
    assign parity_we = is_encst |
                       (is_scrub & parity_bit_error & ~DE_flag);

    // Data-memory writeback for SCRUB: write the corrected word back, unless
    // the error is an uncorrectable double error.
    assign mem_we_errco = is_scrub & ~DE_flag & ~parity_bit_error;

    // Register-file write:
    //   LDC writes the corrected word, but ONLY if it was correctable (~DE).
    //   CHECK always writes its status word - reporting DE is the whole point,
    //   so CHECK is deliberately NOT gated on ~DE.
    assign reg_we_errco = (is_ldc & ~DE_flag) | is_check;

    // LDC hit an uncorrectable double error: the load is suppressed (reg_we is
    // low above) and this flag tells software / the testbench it happened.
    assign ErrCo_invalid = is_ldc & DE_flag;

endmodule
