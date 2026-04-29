// -----------------------------------------------------------------------------
// Module: bch_ecc_top
// Description: Wrapper connecting Encoder and Decoder with Error Injection.
//              Simulates the flow: Data -> Encode -> [Channel/Error] -> Decode
// -----------------------------------------------------------------------------
module bch_ecc_top #(
    // Default to 32-bit configuration (matches your likely thesis target)
    parameter DATA_WIDTH = 32,
    parameter CHECK_WIDTH = 12,
    parameter CODE_WIDTH = 44  // DATA + CHECK
) (
    // User Interface
    input  logic [DATA_WIDTH-1:0]  data_i,          // Write Data
    output logic [DATA_WIDTH-1:0]  data_o,          // Read Data (Corrected)
   
    // Status Signals
    output logic                   error_detected_o,
    output logic                   double_error_o,  // High if 2 errors detected
   
    // Error Injection (The "Virtual Radiation")
    // Set bits to 1 here to simulate bit flips in storage.
    // e.g., Set bit 0 and 5 to '1' to simulate a Double Bit Upset.
    input  logic [CODE_WIDTH-1:0]  force_error_vector_i
);

    // -------------------------------------------------------------------------
    // Internal Signals
    // -------------------------------------------------------------------------
    logic [CODE_WIDTH-1:0] encoded_codeword;
    logic [CODE_WIDTH-1:0] corrupted_codeword;

    // -------------------------------------------------------------------------
    // 1. INSTANTIATE ENCODER
    //    Calculates parity bits for the input data.
    // -------------------------------------------------------------------------
    bch_dec_encoder #(
        .DATA_WIDTH (DATA_WIDTH),
        .CHECK_WIDTH(CHECK_WIDTH),
        .CODE_WIDTH (CODE_WIDTH)
    ) encoder_inst (
        .data_i     (data_i),
        .codeword_o (encoded_codeword)
    );

    // -------------------------------------------------------------------------
    // 2. ERROR INJECTION (Simulating SRAM Bit Flips)
    //    In a real chip, this is the SRAM array.
    //    Here, we use an XOR gate to flip bits based on the input vector.
    //    If force_error_vector_i is 0, data passes through clean.
    // -------------------------------------------------------------------------
    assign corrupted_codeword = encoded_codeword ^ force_error_vector_i;

    // -------------------------------------------------------------------------
    // 3. INSTANTIATE DECODER
    //    Takes the (potentially) corrupted codeword and fixes it.
    // -------------------------------------------------------------------------
    bch_dec_decoder #(
        .DATA_WIDTH (DATA_WIDTH),
        .CHECK_WIDTH(CHECK_WIDTH),
        .CODE_WIDTH (CODE_WIDTH)
    ) decoder_inst (
        .codeword_i       (corrupted_codeword),
        .data_o           (data_o),
        .error_detected_o (error_detected_o),
        .double_error_o   (double_error_o)
    );

endmodule