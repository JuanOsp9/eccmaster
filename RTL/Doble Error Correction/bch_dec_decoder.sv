// -----------------------------------------------------------------------------
// Module: bch_dec_decoder
// Description: Parallel DEC Decoder using Syndrome Mapping.
// Structure: Syndrome Gen -> Error Location (LUT) -> Error Corrector
// Reference: "Parallel Double Error Correcting Code Design...", Section III-C.
// -----------------------------------------------------------------------------
module bch_dec_decoder #(
    parameter DATA_WIDTH = 16,
    parameter CHECK_WIDTH = 10,
    parameter CODE_WIDTH = 26
) (
    input  logic [CODE_WIDTH-1:0]  codeword_i,
    output logic [DATA_WIDTH-1:0]  data_o,
    output logic                   error_detected_o,
    output logic                   double_error_o // Optional status
);

    // -------------------------------------------------------------------------
    // Stage 1: Syndrome Generator
    // Logic: s = v * H^T [cite: 184]
    // Re-computes check bits and XORs with received check bits.
    // -------------------------------------------------------------------------
    logic [CHECK_WIDTH-1:0] syndrome;
    logic [CHECK_WIDTH-1:0] computed_check_bits;
    logic [DATA_WIDTH-1:0]  received_data;
    logic [CHECK_WIDTH-1:0] received_check_bits;

    // H Matrix Transpose component (Parity part)
    // Needs to match the Encoder's G matrix relationship.
    logic [CHECK_WIDTH-1:0] H_parity_transpose [0:DATA_WIDTH-1];
 
  // Parity Matrix assignments for Data Width 16
  initial begin
     H_parity_transpose[15] = 10'h344;
    H_parity_transpose[14] = 10'h1a2;
    H_parity_transpose[13] = 10'h0d1;
    H_parity_transpose[12] = 10'h3dc;
    H_parity_transpose[11] = 10'h1ee;
    H_parity_transpose[10] = 10'h0f7;
    H_parity_transpose[9] = 10'h3cf;
    H_parity_transpose[8] = 10'h253;
    H_parity_transpose[7] = 10'h29d;
    H_parity_transpose[6] = 10'h2fa;
    H_parity_transpose[5] = 10'h17d;
    H_parity_transpose[4] = 10'h30a;
    H_parity_transpose[3] = 10'h185;
    H_parity_transpose[2] = 10'h376;
    H_parity_transpose[1] = 10'h1bb;
    H_parity_transpose[0] = 10'h369;
  end
  // ----------------------------------

    assign received_data       = codeword_i[CODE_WIDTH-1:CHECK_WIDTH];
    assign received_check_bits = codeword_i[CHECK_WIDTH-1:0];

    always_comb begin
        computed_check_bits = '0;
        // Re-calculate parity from received data
        for (int i = 0; i < CHECK_WIDTH; i++) begin
            for (int j = 0; j < DATA_WIDTH; j++) begin
                if (H_parity_transpose[j][i]) begin
                    computed_check_bits[i] = computed_check_bits[i] ^ received_data[j];
                end
            end
        end
        // Syndrome is XOR of received and computed check bits
        syndrome = received_check_bits ^ computed_check_bits;
    end

    // Error Detection Flag: OR of all syndrome bits [cite: 185]
    assign error_detected_o = |syndrome;

    // -------------------------------------------------------------------------
    // Stage 2: Error Location Decoder
    // Logic: Maps syndrome patterns to error vectors.
    // This replaces the iterative Berlekamp-Massey algorithm.
    // -------------------------------------------------------------------------
    logic [CODE_WIDTH-1:0] error_pattern;

    always_comb begin
        error_pattern = '0;
        double_error_o = 0;

        if (error_detected_o) begin
            // In a real synthesis, this large case statement is synthesized
            // into the "Boolean function mapping" mentioned in the paper[cite: 90].
            // It maps the 10-bit syndrome to the specific 16-bit error pattern.
           
          case (syndrome)
              10'h001: error_pattern[0] = 1'b1; // Check Bit 0
    10'h002: error_pattern[1] = 1'b1; // Check Bit 1
    10'h003: begin error_pattern[0] = 1'b1; error_pattern[1] = 1'b1; end
    10'h004: error_pattern[2] = 1'b1; // Check Bit 2
    10'h005: begin error_pattern[0] = 1'b1; error_pattern[2] = 1'b1; end
    10'h006: begin error_pattern[1] = 1'b1; error_pattern[2] = 1'b1; end
    10'h008: error_pattern[3] = 1'b1; // Check Bit 3
    10'h009: begin error_pattern[0] = 1'b1; error_pattern[3] = 1'b1; end
    10'h00a: begin error_pattern[1] = 1'b1; error_pattern[3] = 1'b1; end
    10'h00c: begin error_pattern[2] = 1'b1; error_pattern[3] = 1'b1; end
    10'h010: error_pattern[4] = 1'b1; // Check Bit 4
    10'h011: begin error_pattern[0] = 1'b1; error_pattern[4] = 1'b1; end
    10'h012: begin error_pattern[1] = 1'b1; error_pattern[4] = 1'b1; end
    10'h013: begin error_pattern[19] = 1'b1; error_pattern[22] = 1'b1; end
    10'h014: begin error_pattern[2] = 1'b1; error_pattern[4] = 1'b1; end
    10'h018: begin error_pattern[3] = 1'b1; error_pattern[4] = 1'b1; end
    10'h019: begin error_pattern[11] = 1'b1; error_pattern[24] = 1'b1; end
    10'h01f: begin error_pattern[10] = 1'b1; error_pattern[12] = 1'b1; end
    10'h020: error_pattern[5] = 1'b1; // Check Bit 5
    10'h021: begin error_pattern[0] = 1'b1; error_pattern[5] = 1'b1; end
    10'h022: begin error_pattern[1] = 1'b1; error_pattern[5] = 1'b1; end
    10'h024: begin error_pattern[2] = 1'b1; error_pattern[5] = 1'b1; end
    10'h026: begin error_pattern[20] = 1'b1; error_pattern[23] = 1'b1; end
    10'h027: begin error_pattern[13] = 1'b1; error_pattern[24] = 1'b1; end
    10'h028: begin error_pattern[3] = 1'b1; error_pattern[5] = 1'b1; end
    10'h02d: begin error_pattern[10] = 1'b1; error_pattern[25] = 1'b1; end
    10'h030: begin error_pattern[4] = 1'b1; error_pattern[5] = 1'b1; end
    10'h032: begin error_pattern[12] = 1'b1; error_pattern[25] = 1'b1; end
    10'h03e: begin error_pattern[11] = 1'b1; error_pattern[13] = 1'b1; end
    10'h040: error_pattern[6] = 1'b1; // Check Bit 6
    10'h041: begin error_pattern[0] = 1'b1; error_pattern[6] = 1'b1; end
    10'h042: begin error_pattern[1] = 1'b1; error_pattern[6] = 1'b1; end
    10'h044: begin error_pattern[2] = 1'b1; error_pattern[6] = 1'b1; end
    10'h048: begin error_pattern[3] = 1'b1; error_pattern[6] = 1'b1; end
    10'h04c: begin error_pattern[21] = 1'b1; error_pattern[24] = 1'b1; end
    10'h04e: begin error_pattern[14] = 1'b1; error_pattern[25] = 1'b1; end
    10'h050: begin error_pattern[4] = 1'b1; error_pattern[6] = 1'b1; end
    10'h051: begin error_pattern[7] = 1'b1; error_pattern[23] = 1'b1; end
    10'h053: begin error_pattern[9] = 1'b1; error_pattern[18] = 1'b1; end
    10'h055: begin error_pattern[11] = 1'b1; error_pattern[21] = 1'b1; end
    10'h060: begin error_pattern[5] = 1'b1; error_pattern[6] = 1'b1; end
    10'h063: begin error_pattern[10] = 1'b1; error_pattern[14] = 1'b1; end
    10'h067: begin error_pattern[16] = 1'b1; error_pattern[17] = 1'b1; end
    10'h06b: begin error_pattern[13] = 1'b1; error_pattern[21] = 1'b1; end
    10'h077: begin error_pattern[7] = 1'b1; error_pattern[20] = 1'b1; end
    10'h07c: begin error_pattern[12] = 1'b1; error_pattern[14] = 1'b1; end
    10'h07d: begin error_pattern[8] = 1'b1; error_pattern[15] = 1'b1; end
    10'h080: error_pattern[7] = 1'b1; // Check Bit 7
    10'h081: begin error_pattern[0] = 1'b1; error_pattern[7] = 1'b1; end
    10'h082: begin error_pattern[1] = 1'b1; error_pattern[7] = 1'b1; end
    10'h084: begin error_pattern[2] = 1'b1; error_pattern[7] = 1'b1; end
    10'h085: begin error_pattern[8] = 1'b1; error_pattern[13] = 1'b1; end
    10'h088: begin error_pattern[3] = 1'b1; error_pattern[7] = 1'b1; end
    10'h08b: begin error_pattern[19] = 1'b1; error_pattern[25] = 1'b1; end
    10'h090: begin error_pattern[4] = 1'b1; error_pattern[7] = 1'b1; end
    10'h091: begin error_pattern[6] = 1'b1; error_pattern[23] = 1'b1; end
    10'h093: begin error_pattern[15] = 1'b1; error_pattern[21] = 1'b1; end
    10'h098: begin error_pattern[22] = 1'b1; error_pattern[25] = 1'b1; end
    10'h09d: begin error_pattern[9] = 1'b1; error_pattern[17] = 1'b1; end
    10'h0a0: begin error_pattern[5] = 1'b1; error_pattern[7] = 1'b1; end
    10'h0a2: begin error_pattern[8] = 1'b1; error_pattern[24] = 1'b1; end
    10'h0a6: begin error_pattern[10] = 1'b1; error_pattern[19] = 1'b1; end
    10'h0a9: begin error_pattern[16] = 1'b1; error_pattern[18] = 1'b1; end
    10'h0aa: begin error_pattern[12] = 1'b1; error_pattern[22] = 1'b1; end
    10'h0b5: begin error_pattern[10] = 1'b1; error_pattern[22] = 1'b1; end
    10'h0b7: begin error_pattern[6] = 1'b1; error_pattern[20] = 1'b1; end
    10'h0b9: begin error_pattern[12] = 1'b1; error_pattern[19] = 1'b1; end
    10'h0bb: begin error_pattern[8] = 1'b1; error_pattern[11] = 1'b1; end
    10'h0c0: begin error_pattern[6] = 1'b1; error_pattern[7] = 1'b1; end
    10'h0c1: begin error_pattern[4] = 1'b1; error_pattern[23] = 1'b1; end
    10'h0c5: begin error_pattern[14] = 1'b1; error_pattern[19] = 1'b1; end
    10'h0c6: begin error_pattern[11] = 1'b1; error_pattern[15] = 1'b1; end
    10'h0ce: begin error_pattern[17] = 1'b1; error_pattern[18] = 1'b1; end
    10'h0d0: begin error_pattern[0] = 1'b1; error_pattern[23] = 1'b1; end
    10'h0d1: error_pattern[23] = 1'b1; // Data Bit 13
    10'h0d3: begin error_pattern[1] = 1'b1; error_pattern[23] = 1'b1; end
    10'h0d5: begin error_pattern[2] = 1'b1; error_pattern[23] = 1'b1; end
    10'h0d6: begin error_pattern[14] = 1'b1; error_pattern[22] = 1'b1; end
    10'h0d7: begin error_pattern[5] = 1'b1; error_pattern[20] = 1'b1; end
    10'h0d9: begin error_pattern[3] = 1'b1; error_pattern[23] = 1'b1; end
    10'h0df: begin error_pattern[15] = 1'b1; error_pattern[24] = 1'b1; end
    10'h0e7: begin error_pattern[4] = 1'b1; error_pattern[20] = 1'b1; end
    10'h0ee: begin error_pattern[8] = 1'b1; error_pattern[21] = 1'b1; end
    10'h0f1: begin error_pattern[5] = 1'b1; error_pattern[23] = 1'b1; end
    10'h0f3: begin error_pattern[2] = 1'b1; error_pattern[20] = 1'b1; end
    10'h0f5: begin error_pattern[1] = 1'b1; error_pattern[20] = 1'b1; end
    10'h0f6: begin error_pattern[0] = 1'b1; error_pattern[20] = 1'b1; end
    10'h0f7: error_pattern[20] = 1'b1; // Data Bit 10
    10'h0f8: begin error_pattern[13] = 1'b1; error_pattern[15] = 1'b1; end
    10'h0fa: begin error_pattern[9] = 1'b1; error_pattern[16] = 1'b1; end
    10'h0ff: begin error_pattern[3] = 1'b1; error_pattern[20] = 1'b1; end
    10'h100: error_pattern[8] = 1'b1; // Check Bit 8
    10'h101: begin error_pattern[0] = 1'b1; error_pattern[8] = 1'b1; end
    10'h102: begin error_pattern[1] = 1'b1; error_pattern[8] = 1'b1; end
    10'h104: begin error_pattern[2] = 1'b1; error_pattern[8] = 1'b1; end
    10'h105: begin error_pattern[7] = 1'b1; error_pattern[13] = 1'b1; end
    10'h108: begin error_pattern[3] = 1'b1; error_pattern[8] = 1'b1; end
    10'h10a: begin error_pattern[9] = 1'b1; error_pattern[14] = 1'b1; end
    10'h110: begin error_pattern[4] = 1'b1; error_pattern[8] = 1'b1; end
    10'h117: begin error_pattern[18] = 1'b1; error_pattern[25] = 1'b1; end
    10'h119: begin error_pattern[20] = 1'b1; error_pattern[21] = 1'b1; end
    10'h120: begin error_pattern[5] = 1'b1; error_pattern[8] = 1'b1; end
    10'h122: begin error_pattern[7] = 1'b1; error_pattern[24] = 1'b1; end
    10'h125: begin error_pattern[12] = 1'b1; error_pattern[18] = 1'b1; end
    10'h126: begin error_pattern[16] = 1'b1; error_pattern[22] = 1'b1; end
    10'h135: begin error_pattern[16] = 1'b1; error_pattern[19] = 1'b1; end
    10'h13a: begin error_pattern[10] = 1'b1; error_pattern[18] = 1'b1; end
    10'h13b: begin error_pattern[7] = 1'b1; error_pattern[11] = 1'b1; end
    10'h13d: begin error_pattern[6] = 1'b1; error_pattern[15] = 1'b1; end
    10'h13f: begin error_pattern[21] = 1'b1; error_pattern[23] = 1'b1; end
    10'h140: begin error_pattern[6] = 1'b1; error_pattern[8] = 1'b1; end
    10'h141: begin error_pattern[17] = 1'b1; error_pattern[22] = 1'b1; end
    10'h144: begin error_pattern[9] = 1'b1; error_pattern[25] = 1'b1; end
    10'h14c: begin error_pattern[11] = 1'b1; error_pattern[20] = 1'b1; end
    10'h152: begin error_pattern[17] = 1'b1; error_pattern[19] = 1'b1; end
    10'h154: begin error_pattern[13] = 1'b1; error_pattern[23] = 1'b1; end
    10'h155: begin error_pattern[20] = 1'b1; error_pattern[24] = 1'b1; end
    10'h159: begin error_pattern[14] = 1'b1; error_pattern[18] = 1'b1; end
    10'h15d: begin error_pattern[5] = 1'b1; error_pattern[15] = 1'b1; end
    10'h169: begin error_pattern[9] = 1'b1; error_pattern[10] = 1'b1; end
    10'h16a: begin error_pattern[11] = 1'b1; error_pattern[23] = 1'b1; end
    10'h16d: begin error_pattern[4] = 1'b1; error_pattern[15] = 1'b1; end
    10'h16e: begin error_pattern[7] = 1'b1; error_pattern[21] = 1'b1; end
    10'h172: begin error_pattern[13] = 1'b1; error_pattern[20] = 1'b1; end
    10'h173: begin error_pattern[23] = 1'b1; error_pattern[24] = 1'b1; end
    10'h175: begin error_pattern[3] = 1'b1; error_pattern[15] = 1'b1; end
    10'h176: begin error_pattern[9] = 1'b1; error_pattern[12] = 1'b1; end
    10'h179: begin error_pattern[2] = 1'b1; error_pattern[15] = 1'b1; end
    10'h17c: begin error_pattern[0] = 1'b1; error_pattern[15] = 1'b1; end
    10'h17d: error_pattern[15] = 1'b1; // Data Bit 5
    10'h17f: begin error_pattern[1] = 1'b1; error_pattern[15] = 1'b1; end
    10'h180: begin error_pattern[7] = 1'b1; error_pattern[8] = 1'b1; end
    10'h181: begin error_pattern[2] = 1'b1; error_pattern[13] = 1'b1; end
    10'h182: begin error_pattern[5] = 1'b1; error_pattern[24] = 1'b1; end
    10'h184: begin error_pattern[0] = 1'b1; error_pattern[13] = 1'b1; end
    10'h185: error_pattern[13] = 1'b1; // Data Bit 3
    10'h187: begin error_pattern[1] = 1'b1; error_pattern[13] = 1'b1; end
    10'h18a: begin error_pattern[15] = 1'b1; error_pattern[20] = 1'b1; end
    10'h18c: begin error_pattern[12] = 1'b1; error_pattern[16] = 1'b1; end
    10'h18d: begin error_pattern[3] = 1'b1; error_pattern[13] = 1'b1; end
    10'h18f: begin error_pattern[18] = 1'b1; error_pattern[22] = 1'b1; end
    10'h193: begin error_pattern[10] = 1'b1; error_pattern[16] = 1'b1; end
    10'h195: begin error_pattern[4] = 1'b1; error_pattern[13] = 1'b1; end
    10'h197: begin error_pattern[14] = 1'b1; error_pattern[17] = 1'b1; end
    10'h19b: begin error_pattern[5] = 1'b1; error_pattern[11] = 1'b1; end
    10'h19c: begin error_pattern[18] = 1'b1; error_pattern[19] = 1'b1; end
    10'h1a0: begin error_pattern[1] = 1'b1; error_pattern[24] = 1'b1; end
    10'h1a2: error_pattern[24] = 1'b1; // Data Bit 14
    10'h1a3: begin error_pattern[0] = 1'b1; error_pattern[24] = 1'b1; end
    10'h1a5: begin error_pattern[5] = 1'b1; error_pattern[13] = 1'b1; end
    10'h1a6: begin error_pattern[2] = 1'b1; error_pattern[24] = 1'b1; end
    10'h1aa: begin error_pattern[3] = 1'b1; error_pattern[24] = 1'b1; end
    10'h1ab: begin error_pattern[4] = 1'b1; error_pattern[11] = 1'b1; end
    10'h1ac: begin error_pattern[15] = 1'b1; error_pattern[23] = 1'b1; end
    10'h1ae: begin error_pattern[6] = 1'b1; error_pattern[21] = 1'b1; end
    10'h1b2: begin error_pattern[4] = 1'b1; error_pattern[24] = 1'b1; end
    10'h1b3: begin error_pattern[3] = 1'b1; error_pattern[11] = 1'b1; end
    10'h1b9: begin error_pattern[1] = 1'b1; error_pattern[11] = 1'b1; end
    10'h1ba: begin error_pattern[0] = 1'b1; error_pattern[11] = 1'b1; end
    10'h1bb: error_pattern[11] = 1'b1; // Data Bit 1
    10'h1be: begin error_pattern[16] = 1'b1; error_pattern[25] = 1'b1; end
    10'h1bf: begin error_pattern[2] = 1'b1; error_pattern[11] = 1'b1; end
    10'h1c5: begin error_pattern[6] = 1'b1; error_pattern[13] = 1'b1; end
    10'h1ce: begin error_pattern[5] = 1'b1; error_pattern[21] = 1'b1; end
    10'h1cf: begin error_pattern[9] = 1'b1; error_pattern[19] = 1'b1; end
    10'h1d1: begin error_pattern[8] = 1'b1; error_pattern[23] = 1'b1; end
    10'h1d9: begin error_pattern[17] = 1'b1; error_pattern[25] = 1'b1; end
    10'h1dc: begin error_pattern[9] = 1'b1; error_pattern[22] = 1'b1; end
    10'h1e2: begin error_pattern[6] = 1'b1; error_pattern[24] = 1'b1; end
    10'h1e6: begin error_pattern[3] = 1'b1; error_pattern[21] = 1'b1; end
    10'h1ea: begin error_pattern[2] = 1'b1; error_pattern[21] = 1'b1; end
    10'h1eb: begin error_pattern[12] = 1'b1; error_pattern[17] = 1'b1; end
    10'h1ec: begin error_pattern[1] = 1'b1; error_pattern[21] = 1'b1; end
    10'h1ee: error_pattern[21] = 1'b1; // Data Bit 11
    10'h1ef: begin error_pattern[0] = 1'b1; error_pattern[21] = 1'b1; end
    10'h1f0: begin error_pattern[14] = 1'b1; error_pattern[16] = 1'b1; end
    10'h1f4: begin error_pattern[10] = 1'b1; error_pattern[17] = 1'b1; end
    10'h1f7: begin error_pattern[8] = 1'b1; error_pattern[20] = 1'b1; end
    10'h1fb: begin error_pattern[6] = 1'b1; error_pattern[11] = 1'b1; end
    10'h1fd: begin error_pattern[7] = 1'b1; error_pattern[15] = 1'b1; end
    10'h1fe: begin error_pattern[4] = 1'b1; error_pattern[21] = 1'b1; end
    10'h200: error_pattern[9] = 1'b1; // Check Bit 9
    10'h201: begin error_pattern[0] = 1'b1; error_pattern[9] = 1'b1; end
    10'h202: begin error_pattern[1] = 1'b1; error_pattern[9] = 1'b1; end
    10'h204: begin error_pattern[2] = 1'b1; error_pattern[9] = 1'b1; end
    10'h208: begin error_pattern[3] = 1'b1; error_pattern[9] = 1'b1; end
    10'h20a: begin error_pattern[8] = 1'b1; error_pattern[14] = 1'b1; end
    10'h20b: begin error_pattern[12] = 1'b1; error_pattern[15] = 1'b1; end
    10'h20d: begin error_pattern[16] = 1'b1; error_pattern[20] = 1'b1; end
    10'h210: begin error_pattern[4] = 1'b1; error_pattern[9] = 1'b1; end
    10'h213: begin error_pattern[6] = 1'b1; error_pattern[18] = 1'b1; end
    10'h214: begin error_pattern[10] = 1'b1; error_pattern[15] = 1'b1; end
    10'h21d: begin error_pattern[7] = 1'b1; error_pattern[17] = 1'b1; end
    10'h220: begin error_pattern[5] = 1'b1; error_pattern[9] = 1'b1; end
    10'h221: begin error_pattern[19] = 1'b1; error_pattern[21] = 1'b1; end
    10'h22b: begin error_pattern[16] = 1'b1; error_pattern[23] = 1'b1; end
    10'h232: begin error_pattern[21] = 1'b1; error_pattern[22] = 1'b1; end
    10'h239: begin error_pattern[15] = 1'b1; error_pattern[25] = 1'b1; end
    10'h240: begin error_pattern[6] = 1'b1; error_pattern[9] = 1'b1; end
    10'h243: begin error_pattern[4] = 1'b1; error_pattern[18] = 1'b1; end
    10'h244: begin error_pattern[8] = 1'b1; error_pattern[25] = 1'b1; end
    10'h24a: begin error_pattern[13] = 1'b1; error_pattern[19] = 1'b1; end
    10'h24c: begin error_pattern[17] = 1'b1; error_pattern[23] = 1'b1; end
    10'h251: begin error_pattern[1] = 1'b1; error_pattern[18] = 1'b1; end
    10'h252: begin error_pattern[0] = 1'b1; error_pattern[18] = 1'b1; end
    10'h253: error_pattern[18] = 1'b1; // Data Bit 8
    10'h257: begin error_pattern[2] = 1'b1; error_pattern[18] = 1'b1; end
    10'h259: begin error_pattern[13] = 1'b1; error_pattern[22] = 1'b1; end
    10'h25b: begin error_pattern[3] = 1'b1; error_pattern[18] = 1'b1; end
    10'h267: begin error_pattern[11] = 1'b1; error_pattern[22] = 1'b1; end
    10'h269: begin error_pattern[8] = 1'b1; error_pattern[10] = 1'b1; end
    10'h26a: begin error_pattern[17] = 1'b1; error_pattern[20] = 1'b1; end
    10'h26d: begin error_pattern[19] = 1'b1; error_pattern[24] = 1'b1; end
    10'h273: begin error_pattern[5] = 1'b1; error_pattern[18] = 1'b1; end
    10'h274: begin error_pattern[11] = 1'b1; error_pattern[19] = 1'b1; end
    10'h276: begin error_pattern[8] = 1'b1; error_pattern[12] = 1'b1; end
    10'h277: begin error_pattern[14] = 1'b1; error_pattern[15] = 1'b1; end
    10'h27a: begin error_pattern[7] = 1'b1; error_pattern[16] = 1'b1; end
    10'h27e: begin error_pattern[22] = 1'b1; error_pattern[24] = 1'b1; end
    10'h280: begin error_pattern[7] = 1'b1; error_pattern[9] = 1'b1; end
    10'h282: begin error_pattern[18] = 1'b1; error_pattern[23] = 1'b1; end
    10'h287: begin error_pattern[10] = 1'b1; error_pattern[21] = 1'b1; end
    10'h28d: begin error_pattern[4] = 1'b1; error_pattern[17] = 1'b1; end
    10'h28f: begin error_pattern[13] = 1'b1; error_pattern[14] = 1'b1; end
    10'h295: begin error_pattern[3] = 1'b1; error_pattern[17] = 1'b1; end
    10'h298: begin error_pattern[12] = 1'b1; error_pattern[21] = 1'b1; end
    10'h299: begin error_pattern[2] = 1'b1; error_pattern[17] = 1'b1; end
    10'h29c: begin error_pattern[0] = 1'b1; error_pattern[17] = 1'b1; end
    10'h29d: error_pattern[17] = 1'b1; // Data Bit 7
    10'h29f: begin error_pattern[1] = 1'b1; error_pattern[17] = 1'b1; end
    10'h2a1: begin error_pattern[15] = 1'b1; error_pattern[22] = 1'b1; end
    10'h2a4: begin error_pattern[18] = 1'b1; error_pattern[20] = 1'b1; end
    10'h2a8: begin error_pattern[14] = 1'b1; error_pattern[24] = 1'b1; end
    10'h2aa: begin error_pattern[21] = 1'b1; error_pattern[25] = 1'b1; end
    10'h2b1: begin error_pattern[11] = 1'b1; error_pattern[14] = 1'b1; end
    10'h2b2: begin error_pattern[15] = 1'b1; error_pattern[19] = 1'b1; end
    10'h2ba: begin error_pattern[6] = 1'b1; error_pattern[16] = 1'b1; end
    10'h2bd: begin error_pattern[5] = 1'b1; error_pattern[17] = 1'b1; end
    10'h2c1: begin error_pattern[13] = 1'b1; error_pattern[25] = 1'b1; end
    10'h2cb: begin error_pattern[10] = 1'b1; error_pattern[24] = 1'b1; end
    10'h2cd: begin error_pattern[11] = 1'b1; error_pattern[12] = 1'b1; end
    10'h2cf: begin error_pattern[8] = 1'b1; error_pattern[19] = 1'b1; end
    10'h2d1: begin error_pattern[9] = 1'b1; error_pattern[23] = 1'b1; end
    10'h2d2: begin error_pattern[10] = 1'b1; error_pattern[11] = 1'b1; end
    10'h2d3: begin error_pattern[7] = 1'b1; error_pattern[18] = 1'b1; end
    10'h2d4: begin error_pattern[12] = 1'b1; error_pattern[24] = 1'b1; end
    10'h2da: begin error_pattern[5] = 1'b1; error_pattern[16] = 1'b1; end
    10'h2dc: begin error_pattern[8] = 1'b1; error_pattern[22] = 1'b1; end
    10'h2dd: begin error_pattern[6] = 1'b1; error_pattern[17] = 1'b1; end
    10'h2e4: begin error_pattern[14] = 1'b1; error_pattern[21] = 1'b1; end
    10'h2e6: begin error_pattern[24] = 1'b1; error_pattern[25] = 1'b1; end
    10'h2ea: begin error_pattern[4] = 1'b1; error_pattern[16] = 1'b1; end
    10'h2ec: begin error_pattern[10] = 1'b1; error_pattern[13] = 1'b1; end
    10'h2f2: begin error_pattern[3] = 1'b1; error_pattern[16] = 1'b1; end
    10'h2f3: begin error_pattern[12] = 1'b1; error_pattern[13] = 1'b1; end
    10'h2f7: begin error_pattern[9] = 1'b1; error_pattern[20] = 1'b1; end
    10'h2f8: begin error_pattern[1] = 1'b1; error_pattern[16] = 1'b1; end
    10'h2fa: error_pattern[16] = 1'b1; // Data Bit 6
    10'h2fb: begin error_pattern[0] = 1'b1; error_pattern[16] = 1'b1; end
    10'h2fe: begin error_pattern[2] = 1'b1; error_pattern[16] = 1'b1; end
    10'h2ff: begin error_pattern[11] = 1'b1; error_pattern[25] = 1'b1; end
    10'h300: begin error_pattern[8] = 1'b1; error_pattern[9] = 1'b1; end
    10'h302: begin error_pattern[3] = 1'b1; error_pattern[14] = 1'b1; end
    10'h304: begin error_pattern[6] = 1'b1; error_pattern[25] = 1'b1; end
    10'h308: begin error_pattern[1] = 1'b1; error_pattern[14] = 1'b1; end
    10'h30a: error_pattern[14] = 1'b1; // Data Bit 4
    10'h30b: begin error_pattern[0] = 1'b1; error_pattern[14] = 1'b1; end
    10'h30d: begin error_pattern[22] = 1'b1; error_pattern[23] = 1'b1; end
    10'h30e: begin error_pattern[2] = 1'b1; error_pattern[14] = 1'b1; end
    10'h314: begin error_pattern[16] = 1'b1; error_pattern[21] = 1'b1; end
    10'h318: begin error_pattern[13] = 1'b1; error_pattern[17] = 1'b1; end
    10'h31a: begin error_pattern[4] = 1'b1; error_pattern[14] = 1'b1; end
    10'h31e: begin error_pattern[19] = 1'b1; error_pattern[23] = 1'b1; end
    10'h326: begin error_pattern[11] = 1'b1; error_pattern[17] = 1'b1; end
    10'h329: begin error_pattern[6] = 1'b1; error_pattern[10] = 1'b1; end
    10'h32a: begin error_pattern[5] = 1'b1; error_pattern[14] = 1'b1; end
    10'h32b: begin error_pattern[20] = 1'b1; error_pattern[22] = 1'b1; end
    10'h32e: begin error_pattern[15] = 1'b1; error_pattern[18] = 1'b1; end
    10'h336: begin error_pattern[6] = 1'b1; error_pattern[12] = 1'b1; end
    10'h338: begin error_pattern[19] = 1'b1; error_pattern[20] = 1'b1; end
    10'h33f: begin error_pattern[17] = 1'b1; error_pattern[24] = 1'b1; end
    10'h340: begin error_pattern[2] = 1'b1; error_pattern[25] = 1'b1; end
    10'h341: begin error_pattern[11] = 1'b1; error_pattern[16] = 1'b1; end
    10'h344: error_pattern[25] = 1'b1; // Data Bit 15
    10'h345: begin error_pattern[0] = 1'b1; error_pattern[25] = 1'b1; end
    10'h346: begin error_pattern[1] = 1'b1; error_pattern[25] = 1'b1; end
    10'h349: begin error_pattern[5] = 1'b1; error_pattern[10] = 1'b1; end
    10'h34a: begin error_pattern[6] = 1'b1; error_pattern[14] = 1'b1; end
    10'h34c: begin error_pattern[3] = 1'b1; error_pattern[25] = 1'b1; end
    10'h34f: begin error_pattern[7] = 1'b1; error_pattern[19] = 1'b1; end
    10'h353: begin error_pattern[8] = 1'b1; error_pattern[18] = 1'b1; end
    10'h354: begin error_pattern[4] = 1'b1; error_pattern[25] = 1'b1; end
    10'h356: begin error_pattern[5] = 1'b1; error_pattern[12] = 1'b1; end
    10'h358: begin error_pattern[16] = 1'b1; error_pattern[24] = 1'b1; end
    10'h35c: begin error_pattern[7] = 1'b1; error_pattern[22] = 1'b1; end
    10'h361: begin error_pattern[3] = 1'b1; error_pattern[10] = 1'b1; end
    10'h364: begin error_pattern[5] = 1'b1; error_pattern[25] = 1'b1; end
    10'h366: begin error_pattern[4] = 1'b1; error_pattern[12] = 1'b1; end
    10'h368: begin error_pattern[0] = 1'b1; error_pattern[10] = 1'b1; end
    10'h369: error_pattern[10] = 1'b1; // Data Bit 0
    10'h36b: begin error_pattern[1] = 1'b1; error_pattern[10] = 1'b1; end
    10'h36d: begin error_pattern[2] = 1'b1; error_pattern[10] = 1'b1; end
    10'h372: begin error_pattern[2] = 1'b1; error_pattern[12] = 1'b1; end
    10'h373: begin error_pattern[17] = 1'b1; error_pattern[21] = 1'b1; end
    10'h374: begin error_pattern[1] = 1'b1; error_pattern[12] = 1'b1; end
    10'h376: error_pattern[12] = 1'b1; // Data Bit 2
    10'h377: begin error_pattern[0] = 1'b1; error_pattern[12] = 1'b1; end
    10'h379: begin error_pattern[4] = 1'b1; error_pattern[10] = 1'b1; end
    10'h37d: begin error_pattern[9] = 1'b1; error_pattern[15] = 1'b1; end
    10'h37e: begin error_pattern[3] = 1'b1; error_pattern[12] = 1'b1; end
    10'h37f: begin error_pattern[13] = 1'b1; error_pattern[16] = 1'b1; end
    10'h381: begin error_pattern[12] = 1'b1; error_pattern[20] = 1'b1; end
    10'h385: begin error_pattern[9] = 1'b1; error_pattern[13] = 1'b1; end
    10'h387: begin error_pattern[15] = 1'b1; error_pattern[16] = 1'b1; end
    10'h38a: begin error_pattern[7] = 1'b1; error_pattern[14] = 1'b1; end
    10'h38f: begin error_pattern[6] = 1'b1; error_pattern[19] = 1'b1; end
    10'h395: begin error_pattern[23] = 1'b1; error_pattern[25] = 1'b1; end
    10'h39c: begin error_pattern[6] = 1'b1; error_pattern[22] = 1'b1; end
    10'h39d: begin error_pattern[8] = 1'b1; error_pattern[17] = 1'b1; end
    10'h39e: begin error_pattern[10] = 1'b1; error_pattern[20] = 1'b1; end
    10'h3a2: begin error_pattern[9] = 1'b1; error_pattern[24] = 1'b1; end
    10'h3a7: begin error_pattern[12] = 1'b1; error_pattern[23] = 1'b1; end
    10'h3b3: begin error_pattern[20] = 1'b1; error_pattern[25] = 1'b1; end
    10'h3b8: begin error_pattern[10] = 1'b1; error_pattern[23] = 1'b1; end
    10'h3bb: begin error_pattern[9] = 1'b1; error_pattern[11] = 1'b1; end
    10'h3bd: begin error_pattern[18] = 1'b1; error_pattern[21] = 1'b1; end
    10'h3c4: begin error_pattern[7] = 1'b1; error_pattern[25] = 1'b1; end
    10'h3c7: begin error_pattern[3] = 1'b1; error_pattern[19] = 1'b1; end
    10'h3cb: begin error_pattern[2] = 1'b1; error_pattern[19] = 1'b1; end
    10'h3cc: begin error_pattern[4] = 1'b1; error_pattern[22] = 1'b1; end
    10'h3cd: begin error_pattern[1] = 1'b1; error_pattern[19] = 1'b1; end
    10'h3ce: begin error_pattern[0] = 1'b1; error_pattern[19] = 1'b1; end
    10'h3cf: error_pattern[19] = 1'b1; // Data Bit 9
    10'h3d4: begin error_pattern[3] = 1'b1; error_pattern[22] = 1'b1; end
    10'h3d6: begin error_pattern[13] = 1'b1; error_pattern[18] = 1'b1; end
    10'h3d8: begin error_pattern[2] = 1'b1; error_pattern[22] = 1'b1; end
    10'h3db: begin error_pattern[14] = 1'b1; error_pattern[23] = 1'b1; end
    10'h3dc: error_pattern[22] = 1'b1; // Data Bit 12
    10'h3dd: begin error_pattern[0] = 1'b1; error_pattern[22] = 1'b1; end
    10'h3de: begin error_pattern[1] = 1'b1; error_pattern[22] = 1'b1; end
    10'h3df: begin error_pattern[4] = 1'b1; error_pattern[19] = 1'b1; end
    10'h3e0: begin error_pattern[15] = 1'b1; error_pattern[17] = 1'b1; end
    10'h3e8: begin error_pattern[11] = 1'b1; error_pattern[18] = 1'b1; end
    10'h3e9: begin error_pattern[7] = 1'b1; error_pattern[10] = 1'b1; end
    10'h3ee: begin error_pattern[9] = 1'b1; error_pattern[21] = 1'b1; end
    10'h3ef: begin error_pattern[5] = 1'b1; error_pattern[19] = 1'b1; end
    10'h3f1: begin error_pattern[18] = 1'b1; error_pattern[24] = 1'b1; end
    10'h3f6: begin error_pattern[7] = 1'b1; error_pattern[12] = 1'b1; end
    10'h3fa: begin error_pattern[8] = 1'b1; error_pattern[16] = 1'b1; end
    10'h3fc: begin error_pattern[5] = 1'b1; error_pattern[22] = 1'b1; end
    10'h3fd: begin error_pattern[14] = 1'b1; error_pattern[20] = 1'b1; end
    default: double_error_o = 1'b1;

endcase
        end
    end

    // -------------------------------------------------------------------------
    // Stage 3: Error Corrector
    // Logic: Stack of XOR gates[cite: 188].
    // -------------------------------------------------------------------------
    always_comb begin
        // FIX #2: Correct Data using the UPPER bits of error_pattern
        // error_pattern[25:10] corresponds to received_data[15:0]
        data_o = received_data ^ error_pattern[CODE_WIDTH-1 : CHECK_WIDTH];
    end
endmodule