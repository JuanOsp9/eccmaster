
// -----------------------------------------------------------------------------
// Module: bch_dec_decoder
// Description: Parallel DEC Decoder using Syndrome Mapping.
// Structure: Syndrome Gen -> Error Location (LUT) -> Error Corrector
// Reference: "Parallel Double Error Correcting Code Design...", Section III-C.
// -----------------------------------------------------------------------------
module bch_dec_decoder #(
    parameter DATA_WIDTH = 32,
    parameter CHECK_WIDTH = 12,
    parameter CODE_WIDTH = 44
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
    H_parity_transpose[31] = 12'h3e6;
    H_parity_transpose[30] = 12'h1f3;
    H_parity_transpose[29] = 12'ha65;
    H_parity_transpose[28] = 12'hfae;
    H_parity_transpose[27] = 12'h7d7;
    H_parity_transpose[26] = 12'h977;
    H_parity_transpose[25] = 12'he27;
    H_parity_transpose[24] = 12'hd8f;
    H_parity_transpose[23] = 12'hc5b;
    H_parity_transpose[22] = 12'hcb1;
    H_parity_transpose[21] = 12'hcc4;
    H_parity_transpose[20] = 12'h662;
    H_parity_transpose[19] = 12'h331;
    H_parity_transpose[18] = 12'hb04;
    H_parity_transpose[17] = 12'h582;
    H_parity_transpose[16] = 12'h2c1;
    H_parity_transpose[15] = 12'hbfc;
    H_parity_transpose[14] = 12'h5fe;
    H_parity_transpose[13] = 12'h2ff;
    H_parity_transpose[12] = 12'hbe3;
    H_parity_transpose[11] = 12'hf6d;
    H_parity_transpose[10] = 12'hd2a;
    H_parity_transpose[9] = 12'h695;
    H_parity_transpose[8] = 12'h9d6;
    H_parity_transpose[7] = 12'h4eb;
    H_parity_transpose[6] = 12'h8e9;
    H_parity_transpose[5] = 12'hee8;
    H_parity_transpose[4] = 12'h774;
    H_parity_transpose[3] = 12'h3ba;
    H_parity_transpose[2] = 12'h1dd;
    H_parity_transpose[1] = 12'ha72;
    H_parity_transpose[0] = 12'h539;
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
            // It maps the 12-bit syndrome to the specific 32-bit error pattern.
           
          case (syndrome)
              12'h001: error_pattern[0] = 1'b1; // Check Bit 0
    12'h002: error_pattern[1] = 1'b1; // Check Bit 1
    12'h003: begin error_pattern[0] = 1'b1; error_pattern[1] = 1'b1; end
    12'h004: error_pattern[2] = 1'b1; // Check Bit 2
    12'h005: begin error_pattern[0] = 1'b1; error_pattern[2] = 1'b1; end
    12'h006: begin error_pattern[1] = 1'b1; error_pattern[2] = 1'b1; end
    12'h008: error_pattern[3] = 1'b1; // Check Bit 3
    12'h009: begin error_pattern[0] = 1'b1; error_pattern[3] = 1'b1; end
    12'h00a: begin error_pattern[1] = 1'b1; error_pattern[3] = 1'b1; end
    12'h00c: begin error_pattern[2] = 1'b1; error_pattern[3] = 1'b1; end
    12'h010: error_pattern[4] = 1'b1; // Check Bit 4
    12'h011: begin error_pattern[0] = 1'b1; error_pattern[4] = 1'b1; end
    12'h012: begin error_pattern[1] = 1'b1; error_pattern[4] = 1'b1; end
    12'h014: begin error_pattern[2] = 1'b1; error_pattern[4] = 1'b1; end
    12'h017: begin error_pattern[13] = 1'b1; error_pattern[41] = 1'b1; end
    12'h018: begin error_pattern[3] = 1'b1; error_pattern[4] = 1'b1; end
    12'h01f: begin error_pattern[24] = 1'b1; error_pattern[27] = 1'b1; end
    12'h020: error_pattern[5] = 1'b1; // Check Bit 5
    12'h021: begin error_pattern[0] = 1'b1; error_pattern[5] = 1'b1; end
    12'h022: begin error_pattern[1] = 1'b1; error_pattern[5] = 1'b1; end
    12'h024: begin error_pattern[2] = 1'b1; error_pattern[5] = 1'b1; end
    12'h028: begin error_pattern[3] = 1'b1; error_pattern[5] = 1'b1; end
    12'h02e: begin error_pattern[14] = 1'b1; error_pattern[42] = 1'b1; end
    12'h030: begin error_pattern[4] = 1'b1; error_pattern[5] = 1'b1; end
    12'h03e: begin error_pattern[25] = 1'b1; error_pattern[28] = 1'b1; end
    12'h040: error_pattern[6] = 1'b1; // Check Bit 6
    12'h041: begin error_pattern[0] = 1'b1; error_pattern[6] = 1'b1; end
    12'h042: begin error_pattern[1] = 1'b1; error_pattern[6] = 1'b1; end
    12'h044: begin error_pattern[2] = 1'b1; error_pattern[6] = 1'b1; end
    12'h048: begin error_pattern[3] = 1'b1; error_pattern[6] = 1'b1; end
    12'h050: begin error_pattern[4] = 1'b1; error_pattern[6] = 1'b1; end
    12'h05c: begin error_pattern[15] = 1'b1; error_pattern[43] = 1'b1; end
    12'h060: begin error_pattern[5] = 1'b1; error_pattern[6] = 1'b1; end
    12'h075: begin error_pattern[33] = 1'b1; error_pattern[34] = 1'b1; end
    12'h07c: begin error_pattern[26] = 1'b1; error_pattern[29] = 1'b1; end
    12'h080: error_pattern[7] = 1'b1; // Check Bit 7
    12'h081: begin error_pattern[0] = 1'b1; error_pattern[7] = 1'b1; end
    12'h082: begin error_pattern[1] = 1'b1; error_pattern[7] = 1'b1; end
    12'h084: begin error_pattern[2] = 1'b1; error_pattern[7] = 1'b1; end
    12'h088: begin error_pattern[3] = 1'b1; error_pattern[7] = 1'b1; end
    12'h08b: begin error_pattern[15] = 1'b1; error_pattern[31] = 1'b1; end
    12'h090: begin error_pattern[4] = 1'b1; error_pattern[7] = 1'b1; end
    12'h09f: begin error_pattern[33] = 1'b1; error_pattern[35] = 1'b1; end
    12'h0a0: begin error_pattern[5] = 1'b1; error_pattern[7] = 1'b1; end
    12'h0a1: begin error_pattern[20] = 1'b1; error_pattern[38] = 1'b1; end
    12'h0a3: begin error_pattern[16] = 1'b1; error_pattern[39] = 1'b1; end
    12'h0a5: begin error_pattern[22] = 1'b1; error_pattern[36] = 1'b1; end
    12'h0bb: begin error_pattern[12] = 1'b1; error_pattern[29] = 1'b1; end
    12'h0c0: begin error_pattern[6] = 1'b1; error_pattern[7] = 1'b1; end
    12'h0c1: begin error_pattern[9] = 1'b1; error_pattern[28] = 1'b1; end
    12'h0c3: begin error_pattern[23] = 1'b1; error_pattern[40] = 1'b1; end
    12'h0c7: begin error_pattern[12] = 1'b1; error_pattern[26] = 1'b1; end
    12'h0cf: begin error_pattern[17] = 1'b1; error_pattern[37] = 1'b1; end
    12'h0d7: begin error_pattern[31] = 1'b1; error_pattern[43] = 1'b1; end
    12'h0dd: begin error_pattern[8] = 1'b1; error_pattern[14] = 1'b1; end
    12'h0e7: begin error_pattern[24] = 1'b1; error_pattern[30] = 1'b1; end
    12'h0e9: begin error_pattern[11] = 1'b1; error_pattern[18] = 1'b1; end
    12'h0ea: begin error_pattern[34] = 1'b1; error_pattern[35] = 1'b1; end
    12'h0eb: begin error_pattern[10] = 1'b1; error_pattern[19] = 1'b1; end
    12'h0f3: begin error_pattern[8] = 1'b1; error_pattern[42] = 1'b1; end
    12'h0f7: begin error_pattern[21] = 1'b1; error_pattern[32] = 1'b1; end
    12'h0f8: begin error_pattern[27] = 1'b1; error_pattern[30] = 1'b1; end
    12'h0ff: begin error_pattern[9] = 1'b1; error_pattern[25] = 1'b1; end
    12'h100: error_pattern[8] = 1'b1; // Check Bit 8
    12'h101: begin error_pattern[0] = 1'b1; error_pattern[8] = 1'b1; end
    12'h102: begin error_pattern[1] = 1'b1; error_pattern[8] = 1'b1; end
    12'h104: begin error_pattern[2] = 1'b1; error_pattern[8] = 1'b1; end
    12'h108: begin error_pattern[3] = 1'b1; error_pattern[8] = 1'b1; end
    12'h110: begin error_pattern[4] = 1'b1; error_pattern[8] = 1'b1; end
    12'h115: begin error_pattern[19] = 1'b1; error_pattern[26] = 1'b1; end
    12'h116: begin error_pattern[16] = 1'b1; error_pattern[32] = 1'b1; end
    12'h119: begin error_pattern[25] = 1'b1; error_pattern[43] = 1'b1; end
    12'h120: begin error_pattern[5] = 1'b1; error_pattern[8] = 1'b1; end
    12'h127: begin error_pattern[28] = 1'b1; error_pattern[43] = 1'b1; end
    12'h131: begin error_pattern[9] = 1'b1; error_pattern[31] = 1'b1; end
    12'h139: begin error_pattern[10] = 1'b1; error_pattern[12] = 1'b1; end
    12'h13e: begin error_pattern[34] = 1'b1; error_pattern[36] = 1'b1; end
    12'h13f: begin error_pattern[18] = 1'b1; error_pattern[20] = 1'b1; end
    12'h140: begin error_pattern[6] = 1'b1; error_pattern[8] = 1'b1; end
    12'h142: begin error_pattern[21] = 1'b1; error_pattern[39] = 1'b1; end
    12'h145: begin error_pattern[15] = 1'b1; error_pattern[25] = 1'b1; end
    12'h146: begin error_pattern[17] = 1'b1; error_pattern[40] = 1'b1; end
    12'h14a: begin error_pattern[23] = 1'b1; error_pattern[37] = 1'b1; end
    12'h14b: begin error_pattern[33] = 1'b1; error_pattern[36] = 1'b1; end
    12'h15d: begin error_pattern[7] = 1'b1; error_pattern[14] = 1'b1; end
    12'h161: begin error_pattern[30] = 1'b1; error_pattern[41] = 1'b1; end
    12'h169: begin error_pattern[19] = 1'b1; error_pattern[29] = 1'b1; end
    12'h171: begin error_pattern[22] = 1'b1; error_pattern[35] = 1'b1; end
    12'h173: begin error_pattern[7] = 1'b1; error_pattern[42] = 1'b1; end
    12'h176: begin error_pattern[13] = 1'b1; error_pattern[30] = 1'b1; end
    12'h177: begin error_pattern[11] = 1'b1; error_pattern[38] = 1'b1; end
    12'h17b: begin error_pattern[15] = 1'b1; error_pattern[28] = 1'b1; end
    12'h180: begin error_pattern[7] = 1'b1; error_pattern[8] = 1'b1; end
    12'h182: begin error_pattern[10] = 1'b1; error_pattern[29] = 1'b1; end
    12'h185: begin error_pattern[17] = 1'b1; error_pattern[23] = 1'b1; end
    12'h186: begin error_pattern[24] = 1'b1; error_pattern[41] = 1'b1; end
    12'h189: begin error_pattern[37] = 1'b1; error_pattern[40] = 1'b1; end
    12'h18e: begin error_pattern[13] = 1'b1; error_pattern[27] = 1'b1; end
    12'h191: begin error_pattern[13] = 1'b1; error_pattern[24] = 1'b1; end
    12'h199: begin error_pattern[27] = 1'b1; error_pattern[41] = 1'b1; end
    12'h19b: begin error_pattern[22] = 1'b1; error_pattern[34] = 1'b1; end
    12'h19d: begin error_pattern[6] = 1'b1; error_pattern[14] = 1'b1; end
    12'h19e: begin error_pattern[18] = 1'b1; error_pattern[38] = 1'b1; end
    12'h1b3: begin error_pattern[6] = 1'b1; error_pattern[42] = 1'b1; end
    12'h1b5: begin error_pattern[32] = 1'b1; error_pattern[39] = 1'b1; end
    12'h1ba: begin error_pattern[9] = 1'b1; error_pattern[15] = 1'b1; end
    12'h1cd: begin error_pattern[4] = 1'b1; error_pattern[14] = 1'b1; end
    12'h1ce: begin error_pattern[25] = 1'b1; error_pattern[31] = 1'b1; end
    12'h1d2: begin error_pattern[12] = 1'b1; error_pattern[19] = 1'b1; end
    12'h1d3: begin error_pattern[5] = 1'b1; error_pattern[42] = 1'b1; end
    12'h1d4: begin error_pattern[35] = 1'b1; error_pattern[36] = 1'b1; end
    12'h1d5: begin error_pattern[3] = 1'b1; error_pattern[14] = 1'b1; end
    12'h1d6: begin error_pattern[11] = 1'b1; error_pattern[20] = 1'b1; end
    12'h1d9: begin error_pattern[2] = 1'b1; error_pattern[14] = 1'b1; end
    12'h1dc: begin error_pattern[0] = 1'b1; error_pattern[14] = 1'b1; end
    12'h1dd: error_pattern[14] = 1'b1; // Data Bit 2
    12'h1df: begin error_pattern[1] = 1'b1; error_pattern[14] = 1'b1; end
    12'h1e1: begin error_pattern[16] = 1'b1; error_pattern[21] = 1'b1; end
    12'h1e3: begin error_pattern[4] = 1'b1; error_pattern[42] = 1'b1; end
    12'h1e6: begin error_pattern[9] = 1'b1; error_pattern[43] = 1'b1; end
    12'h1ee: begin error_pattern[22] = 1'b1; error_pattern[33] = 1'b1; end
    12'h1f0: begin error_pattern[28] = 1'b1; error_pattern[31] = 1'b1; end
    12'h1f1: begin error_pattern[1] = 1'b1; error_pattern[42] = 1'b1; end
    12'h1f2: begin error_pattern[0] = 1'b1; error_pattern[42] = 1'b1; end
    12'h1f3: error_pattern[42] = 1'b1; // Data Bit 30
    12'h1f7: begin error_pattern[2] = 1'b1; error_pattern[42] = 1'b1; end
    12'h1fb: begin error_pattern[3] = 1'b1; error_pattern[42] = 1'b1; end
    12'h1fd: begin error_pattern[5] = 1'b1; error_pattern[14] = 1'b1; end
    12'h1fe: begin error_pattern[10] = 1'b1; error_pattern[26] = 1'b1; end
    12'h200: error_pattern[9] = 1'b1; // Check Bit 9
    12'h201: begin error_pattern[0] = 1'b1; error_pattern[9] = 1'b1; end
    12'h202: begin error_pattern[1] = 1'b1; error_pattern[9] = 1'b1; end
    12'h204: begin error_pattern[2] = 1'b1; error_pattern[9] = 1'b1; end
    12'h208: begin error_pattern[3] = 1'b1; error_pattern[9] = 1'b1; end
    12'h210: begin error_pattern[4] = 1'b1; error_pattern[9] = 1'b1; end
    12'h215: begin error_pattern[42] = 1'b1; error_pattern[43] = 1'b1; end
    12'h220: begin error_pattern[5] = 1'b1; error_pattern[9] = 1'b1; end
    12'h221: begin error_pattern[36] = 1'b1; error_pattern[40] = 1'b1; end
    12'h229: begin error_pattern[26] = 1'b1; error_pattern[39] = 1'b1; end
    12'h22a: begin error_pattern[20] = 1'b1; error_pattern[27] = 1'b1; end
    12'h22c: begin error_pattern[17] = 1'b1; error_pattern[33] = 1'b1; end
    12'h231: begin error_pattern[8] = 1'b1; error_pattern[31] = 1'b1; end
    12'h235: begin error_pattern[20] = 1'b1; error_pattern[24] = 1'b1; end
    12'h23b: begin error_pattern[14] = 1'b1; error_pattern[43] = 1'b1; end
    12'h240: begin error_pattern[6] = 1'b1; error_pattern[9] = 1'b1; end
    12'h241: begin error_pattern[7] = 1'b1; error_pattern[28] = 1'b1; end
    12'h247: begin error_pattern[22] = 1'b1; error_pattern[23] = 1'b1; end
    12'h249: begin error_pattern[15] = 1'b1; error_pattern[42] = 1'b1; end
    12'h24d: begin error_pattern[12] = 1'b1; error_pattern[16] = 1'b1; end
    12'h255: begin error_pattern[29] = 1'b1; error_pattern[39] = 1'b1; end
    12'h259: begin error_pattern[17] = 1'b1; error_pattern[34] = 1'b1; end
    12'h262: begin error_pattern[10] = 1'b1; error_pattern[32] = 1'b1; end
    12'h265: begin error_pattern[11] = 1'b1; error_pattern[41] = 1'b1; end
    12'h267: begin error_pattern[14] = 1'b1; error_pattern[15] = 1'b1; end
    12'h272: begin error_pattern[11] = 1'b1; error_pattern[13] = 1'b1; end
    12'h273: begin error_pattern[30] = 1'b1; error_pattern[38] = 1'b1; end
    12'h27c: begin error_pattern[35] = 1'b1; error_pattern[37] = 1'b1; end
    12'h27e: begin error_pattern[19] = 1'b1; error_pattern[21] = 1'b1; end
    12'h27f: begin error_pattern[7] = 1'b1; error_pattern[25] = 1'b1; end
    12'h280: begin error_pattern[7] = 1'b1; error_pattern[9] = 1'b1; end
    12'h281: begin error_pattern[6] = 1'b1; error_pattern[28] = 1'b1; end
    12'h284: begin error_pattern[22] = 1'b1; error_pattern[40] = 1'b1; end
    12'h289: begin error_pattern[19] = 1'b1; error_pattern[32] = 1'b1; end
    12'h28a: begin error_pattern[16] = 1'b1; error_pattern[26] = 1'b1; end
    12'h28b: begin error_pattern[27] = 1'b1; error_pattern[38] = 1'b1; end
    12'h28c: begin error_pattern[18] = 1'b1; error_pattern[41] = 1'b1; end
    12'h294: begin error_pattern[24] = 1'b1; error_pattern[38] = 1'b1; end
    12'h295: begin error_pattern[10] = 1'b1; error_pattern[21] = 1'b1; end
    12'h296: begin error_pattern[34] = 1'b1; error_pattern[37] = 1'b1; end
    12'h29b: begin error_pattern[13] = 1'b1; error_pattern[18] = 1'b1; end
    12'h2b3: begin error_pattern[17] = 1'b1; error_pattern[35] = 1'b1; end
    12'h2ba: begin error_pattern[8] = 1'b1; error_pattern[15] = 1'b1; end
    12'h2bf: begin error_pattern[6] = 1'b1; error_pattern[25] = 1'b1; end
    12'h2c0: begin error_pattern[0] = 1'b1; error_pattern[28] = 1'b1; end
    12'h2c1: error_pattern[28] = 1'b1; // Data Bit 16
    12'h2c2: begin error_pattern[31] = 1'b1; error_pattern[42] = 1'b1; end
    12'h2c3: begin error_pattern[1] = 1'b1; error_pattern[28] = 1'b1; end
    12'h2c5: begin error_pattern[2] = 1'b1; error_pattern[28] = 1'b1; end
    12'h2c9: begin error_pattern[3] = 1'b1; error_pattern[28] = 1'b1; end
    12'h2d1: begin error_pattern[4] = 1'b1; error_pattern[28] = 1'b1; end
    12'h2d2: begin error_pattern[20] = 1'b1; error_pattern[30] = 1'b1; end
    12'h2df: begin error_pattern[5] = 1'b1; error_pattern[25] = 1'b1; end
    12'h2e1: begin error_pattern[5] = 1'b1; error_pattern[28] = 1'b1; end
    12'h2e2: begin error_pattern[23] = 1'b1; error_pattern[36] = 1'b1; end
    12'h2e3: begin error_pattern[33] = 1'b1; error_pattern[37] = 1'b1; end
    12'h2e6: begin error_pattern[8] = 1'b1; error_pattern[43] = 1'b1; end
    12'h2ec: begin error_pattern[14] = 1'b1; error_pattern[31] = 1'b1; end
    12'h2ee: begin error_pattern[12] = 1'b1; error_pattern[39] = 1'b1; end
    12'h2ef: begin error_pattern[4] = 1'b1; error_pattern[25] = 1'b1; end
    12'h2f6: begin error_pattern[16] = 1'b1; error_pattern[29] = 1'b1; end
    12'h2f7: begin error_pattern[3] = 1'b1; error_pattern[25] = 1'b1; end
    12'h2fb: begin error_pattern[2] = 1'b1; error_pattern[25] = 1'b1; end
    12'h2fd: begin error_pattern[1] = 1'b1; error_pattern[25] = 1'b1; end
    12'h2fe: begin error_pattern[0] = 1'b1; error_pattern[25] = 1'b1; end
    12'h2ff: error_pattern[25] = 1'b1; // Data Bit 13
    12'h300: begin error_pattern[8] = 1'b1; error_pattern[9] = 1'b1; end
    12'h304: begin error_pattern[11] = 1'b1; error_pattern[30] = 1'b1; end
    12'h305: begin error_pattern[13] = 1'b1; error_pattern[38] = 1'b1; end
    12'h30a: begin error_pattern[18] = 1'b1; error_pattern[24] = 1'b1; end
    12'h30c: begin error_pattern[25] = 1'b1; error_pattern[42] = 1'b1; end
    12'h30d: begin error_pattern[22] = 1'b1; error_pattern[37] = 1'b1; end
    12'h311: begin error_pattern[5] = 1'b1; error_pattern[31] = 1'b1; end
    12'h312: begin error_pattern[38] = 1'b1; error_pattern[41] = 1'b1; end
    12'h315: begin error_pattern[18] = 1'b1; error_pattern[27] = 1'b1; end
    12'h317: begin error_pattern[21] = 1'b1; error_pattern[29] = 1'b1; end
    12'h31c: begin error_pattern[14] = 1'b1; error_pattern[28] = 1'b1; end
    12'h31f: begin error_pattern[34] = 1'b1; error_pattern[40] = 1'b1; end
    12'h321: begin error_pattern[4] = 1'b1; error_pattern[31] = 1'b1; end
    12'h322: begin error_pattern[14] = 1'b1; error_pattern[25] = 1'b1; end
    12'h330: begin error_pattern[0] = 1'b1; error_pattern[31] = 1'b1; end
    12'h331: error_pattern[31] = 1'b1; // Data Bit 19
    12'h332: begin error_pattern[28] = 1'b1; error_pattern[42] = 1'b1; end
    12'h333: begin error_pattern[1] = 1'b1; error_pattern[31] = 1'b1; end
    12'h335: begin error_pattern[2] = 1'b1; error_pattern[31] = 1'b1; end
    12'h336: begin error_pattern[23] = 1'b1; error_pattern[35] = 1'b1; end
    12'h339: begin error_pattern[3] = 1'b1; error_pattern[31] = 1'b1; end
    12'h33a: begin error_pattern[7] = 1'b1; error_pattern[15] = 1'b1; end
    12'h33c: begin error_pattern[19] = 1'b1; error_pattern[39] = 1'b1; end
    12'h35b: begin error_pattern[12] = 1'b1; error_pattern[32] = 1'b1; end
    12'h366: begin error_pattern[7] = 1'b1; error_pattern[43] = 1'b1; end
    12'h367: begin error_pattern[17] = 1'b1; error_pattern[36] = 1'b1; end
    12'h36a: begin error_pattern[33] = 1'b1; error_pattern[40] = 1'b1; end
    12'h36b: begin error_pattern[21] = 1'b1; error_pattern[26] = 1'b1; end
    12'h371: begin error_pattern[6] = 1'b1; error_pattern[31] = 1'b1; end
    12'h374: begin error_pattern[10] = 1'b1; error_pattern[16] = 1'b1; end
    12'h39a: begin error_pattern[5] = 1'b1; error_pattern[15] = 1'b1; end
    12'h39c: begin error_pattern[26] = 1'b1; error_pattern[32] = 1'b1; end
    12'h39f: begin error_pattern[16] = 1'b1; error_pattern[19] = 1'b1; end
    12'h3a4: begin error_pattern[13] = 1'b1; error_pattern[20] = 1'b1; end
    12'h3a6: begin error_pattern[6] = 1'b1; error_pattern[43] = 1'b1; end
    12'h3a8: begin error_pattern[36] = 1'b1; error_pattern[37] = 1'b1; end
    12'h3a9: begin error_pattern[23] = 1'b1; error_pattern[33] = 1'b1; end
    12'h3aa: begin error_pattern[4] = 1'b1; error_pattern[15] = 1'b1; end
    12'h3ac: begin error_pattern[12] = 1'b1; error_pattern[21] = 1'b1; end
    12'h3b1: begin error_pattern[7] = 1'b1; error_pattern[31] = 1'b1; end
    12'h3b2: begin error_pattern[3] = 1'b1; error_pattern[15] = 1'b1; end
    12'h3b3: begin error_pattern[20] = 1'b1; error_pattern[41] = 1'b1; end
    12'h3b8: begin error_pattern[1] = 1'b1; error_pattern[15] = 1'b1; end
    12'h3ba: error_pattern[15] = 1'b1; // Data Bit 3
    12'h3bb: begin error_pattern[0] = 1'b1; error_pattern[15] = 1'b1; end
    12'h3be: begin error_pattern[2] = 1'b1; error_pattern[15] = 1'b1; end
    12'h3c1: begin error_pattern[8] = 1'b1; error_pattern[28] = 1'b1; end
    12'h3c2: begin error_pattern[17] = 1'b1; error_pattern[22] = 1'b1; end
    12'h3c6: begin error_pattern[5] = 1'b1; error_pattern[43] = 1'b1; end
    12'h3d7: begin error_pattern[10] = 1'b1; error_pattern[39] = 1'b1; end
    12'h3dc: begin error_pattern[23] = 1'b1; error_pattern[34] = 1'b1; end
    12'h3dd: begin error_pattern[9] = 1'b1; error_pattern[14] = 1'b1; end
    12'h3e0: begin error_pattern[29] = 1'b1; error_pattern[32] = 1'b1; end
    12'h3e2: begin error_pattern[2] = 1'b1; error_pattern[43] = 1'b1; end
    12'h3e3: begin error_pattern[11] = 1'b1; error_pattern[24] = 1'b1; end
    12'h3e4: begin error_pattern[1] = 1'b1; error_pattern[43] = 1'b1; end
    12'h3e6: error_pattern[43] = 1'b1; // Data Bit 31
    12'h3e7: begin error_pattern[0] = 1'b1; error_pattern[43] = 1'b1; end
    12'h3ed: begin error_pattern[18] = 1'b1; error_pattern[30] = 1'b1; end
    12'h3ee: begin error_pattern[3] = 1'b1; error_pattern[43] = 1'b1; end
    12'h3f3: begin error_pattern[9] = 1'b1; error_pattern[42] = 1'b1; end
    12'h3f5: begin error_pattern[35] = 1'b1; error_pattern[40] = 1'b1; end
    12'h3f6: begin error_pattern[4] = 1'b1; error_pattern[43] = 1'b1; end
    12'h3fa: begin error_pattern[6] = 1'b1; error_pattern[15] = 1'b1; end
    12'h3fc: begin error_pattern[11] = 1'b1; error_pattern[27] = 1'b1; end
    12'h3ff: begin error_pattern[8] = 1'b1; error_pattern[25] = 1'b1; end
    12'h400: error_pattern[10] = 1'b1; // Check Bit 10
    12'h401: begin error_pattern[0] = 1'b1; error_pattern[10] = 1'b1; end
    12'h402: begin error_pattern[1] = 1'b1; error_pattern[10] = 1'b1; end
    12'h404: begin error_pattern[2] = 1'b1; error_pattern[10] = 1'b1; end
    12'h408: begin error_pattern[3] = 1'b1; error_pattern[10] = 1'b1; end
    12'h40d: begin error_pattern[26] = 1'b1; error_pattern[42] = 1'b1; end
    12'h410: begin error_pattern[4] = 1'b1; error_pattern[10] = 1'b1; end
    12'h420: begin error_pattern[5] = 1'b1; error_pattern[10] = 1'b1; end
    12'h423: begin error_pattern[14] = 1'b1; error_pattern[26] = 1'b1; end
    12'h42d: begin error_pattern[18] = 1'b1; error_pattern[33] = 1'b1; end
    12'h431: begin error_pattern[39] = 1'b1; error_pattern[43] = 1'b1; end
    12'h439: begin error_pattern[8] = 1'b1; error_pattern[12] = 1'b1; end
    12'h440: begin error_pattern[6] = 1'b1; error_pattern[10] = 1'b1; end
    12'h442: begin error_pattern[37] = 1'b1; error_pattern[41] = 1'b1; end
    12'h445: begin error_pattern[16] = 1'b1; error_pattern[31] = 1'b1; end
    12'h44d: begin error_pattern[24] = 1'b1; error_pattern[40] = 1'b1; end
    12'h452: begin error_pattern[27] = 1'b1; error_pattern[40] = 1'b1; end
    12'h454: begin error_pattern[21] = 1'b1; error_pattern[28] = 1'b1; end
    12'h455: begin error_pattern[13] = 1'b1; error_pattern[37] = 1'b1; end
    12'h458: begin error_pattern[18] = 1'b1; error_pattern[34] = 1'b1; end
    12'h459: begin error_pattern[20] = 1'b1; error_pattern[36] = 1'b1; end
    12'h45b: begin error_pattern[11] = 1'b1; error_pattern[35] = 1'b1; end
    12'h45d: begin error_pattern[22] = 1'b1; error_pattern[38] = 1'b1; end
    12'h45f: begin error_pattern[14] = 1'b1; error_pattern[29] = 1'b1; end
    12'h462: begin error_pattern[9] = 1'b1; error_pattern[32] = 1'b1; end
    12'h469: begin error_pattern[23] = 1'b1; error_pattern[30] = 1'b1; end
    12'h46a: begin error_pattern[21] = 1'b1; error_pattern[25] = 1'b1; end
    12'h46b: begin error_pattern[7] = 1'b1; error_pattern[19] = 1'b1; end
    12'h46d: begin error_pattern[15] = 1'b1; error_pattern[39] = 1'b1; end
    12'h471: begin error_pattern[29] = 1'b1; error_pattern[42] = 1'b1; end
    12'h480: begin error_pattern[7] = 1'b1; error_pattern[10] = 1'b1; end
    12'h482: begin error_pattern[8] = 1'b1; error_pattern[29] = 1'b1; end
    12'h48d: begin error_pattern[17] = 1'b1; error_pattern[41] = 1'b1; end
    12'h48e: begin error_pattern[23] = 1'b1; error_pattern[24] = 1'b1; end
    12'h491: begin error_pattern[23] = 1'b1; error_pattern[27] = 1'b1; end
    12'h492: begin error_pattern[16] = 1'b1; error_pattern[43] = 1'b1; end
    12'h495: begin error_pattern[9] = 1'b1; error_pattern[21] = 1'b1; end
    12'h49a: begin error_pattern[13] = 1'b1; error_pattern[17] = 1'b1; end
    12'h49d: begin error_pattern[25] = 1'b1; error_pattern[32] = 1'b1; end
    12'h4a3: begin error_pattern[28] = 1'b1; error_pattern[32] = 1'b1; end
    12'h4aa: begin error_pattern[30] = 1'b1; error_pattern[40] = 1'b1; end
    12'h4ab: begin error_pattern[6] = 1'b1; error_pattern[19] = 1'b1; end
    12'h4b1: begin error_pattern[11] = 1'b1; error_pattern[34] = 1'b1; end
    12'h4b2: begin error_pattern[18] = 1'b1; error_pattern[35] = 1'b1; end
    12'h4c4: begin error_pattern[11] = 1'b1; error_pattern[33] = 1'b1; end
    12'h4ca: begin error_pattern[12] = 1'b1; error_pattern[42] = 1'b1; end
    12'h4cb: begin error_pattern[5] = 1'b1; error_pattern[19] = 1'b1; end
    12'h4ce: begin error_pattern[15] = 1'b1; error_pattern[16] = 1'b1; end
    12'h4e3: begin error_pattern[3] = 1'b1; error_pattern[19] = 1'b1; end
    12'h4e4: begin error_pattern[12] = 1'b1; error_pattern[14] = 1'b1; end
    12'h4e6: begin error_pattern[31] = 1'b1; error_pattern[39] = 1'b1; end
    12'h4e9: begin error_pattern[1] = 1'b1; error_pattern[19] = 1'b1; end
    12'h4ea: begin error_pattern[0] = 1'b1; error_pattern[19] = 1'b1; end
    12'h4eb: error_pattern[19] = 1'b1; // Data Bit 7
    12'h4ef: begin error_pattern[2] = 1'b1; error_pattern[19] = 1'b1; end
    12'h4f8: begin error_pattern[36] = 1'b1; error_pattern[38] = 1'b1; end
    12'h4fb: begin error_pattern[4] = 1'b1; error_pattern[19] = 1'b1; end
    12'h4fc: begin error_pattern[20] = 1'b1; error_pattern[22] = 1'b1; end
    12'h4fe: begin error_pattern[8] = 1'b1; error_pattern[26] = 1'b1; end
    12'h500: begin error_pattern[8] = 1'b1; error_pattern[10] = 1'b1; end
    12'h502: begin error_pattern[7] = 1'b1; error_pattern[29] = 1'b1; end
    12'h508: begin error_pattern[23] = 1'b1; error_pattern[41] = 1'b1; end
    12'h50b: begin error_pattern[17] = 1'b1; error_pattern[24] = 1'b1; end
    12'h512: begin error_pattern[20] = 1'b1; error_pattern[33] = 1'b1; end
    12'h514: begin error_pattern[17] = 1'b1; error_pattern[27] = 1'b1; end
    12'h516: begin error_pattern[28] = 1'b1; error_pattern[39] = 1'b1; end
    12'h518: begin error_pattern[19] = 1'b1; error_pattern[42] = 1'b1; end
    12'h519: begin error_pattern[5] = 1'b1; error_pattern[12] = 1'b1; end
    12'h51f: begin error_pattern[13] = 1'b1; error_pattern[23] = 1'b1; end
    12'h523: begin error_pattern[30] = 1'b1; error_pattern[37] = 1'b1; end
    12'h528: begin error_pattern[25] = 1'b1; error_pattern[39] = 1'b1; end
    12'h529: begin error_pattern[4] = 1'b1; error_pattern[12] = 1'b1; end
    12'h52a: begin error_pattern[11] = 1'b1; error_pattern[22] = 1'b1; end
    12'h52c: begin error_pattern[35] = 1'b1; error_pattern[38] = 1'b1; end
    12'h52f: begin error_pattern[15] = 1'b1; error_pattern[21] = 1'b1; end
    12'h531: begin error_pattern[3] = 1'b1; error_pattern[12] = 1'b1; end
    12'h536: begin error_pattern[14] = 1'b1; error_pattern[19] = 1'b1; end
    12'h538: begin error_pattern[0] = 1'b1; error_pattern[12] = 1'b1; end
    12'h539: error_pattern[12] = 1'b1; // Data Bit 0
    12'h53b: begin error_pattern[1] = 1'b1; error_pattern[12] = 1'b1; end
    12'h53d: begin error_pattern[2] = 1'b1; error_pattern[12] = 1'b1; end
    12'h553: begin error_pattern[31] = 1'b1; error_pattern[32] = 1'b1; end
    12'h566: begin error_pattern[18] = 1'b1; error_pattern[36] = 1'b1; end
    12'h567: begin error_pattern[20] = 1'b1; error_pattern[34] = 1'b1; end
    12'h573: begin error_pattern[21] = 1'b1; error_pattern[43] = 1'b1; end
    12'h574: begin error_pattern[9] = 1'b1; error_pattern[16] = 1'b1; end
    12'h579: begin error_pattern[6] = 1'b1; error_pattern[12] = 1'b1; end
    12'h57e: begin error_pattern[7] = 1'b1; error_pattern[26] = 1'b1; end
    12'h580: begin error_pattern[1] = 1'b1; error_pattern[29] = 1'b1; end
    12'h582: error_pattern[29] = 1'b1; // Data Bit 17
    12'h583: begin error_pattern[0] = 1'b1; error_pattern[29] = 1'b1; end
    12'h584: begin error_pattern[32] = 1'b1; error_pattern[43] = 1'b1; end
    12'h586: begin error_pattern[2] = 1'b1; error_pattern[29] = 1'b1; end
    12'h58a: begin error_pattern[3] = 1'b1; error_pattern[29] = 1'b1; end
    12'h58b: begin error_pattern[16] = 1'b1; error_pattern[25] = 1'b1; end
    12'h58d: begin error_pattern[20] = 1'b1; error_pattern[35] = 1'b1; end
    12'h58f: begin error_pattern[11] = 1'b1; error_pattern[36] = 1'b1; end
    12'h592: begin error_pattern[4] = 1'b1; error_pattern[29] = 1'b1; end
    12'h5a2: begin error_pattern[5] = 1'b1; error_pattern[29] = 1'b1; end
    12'h5a4: begin error_pattern[21] = 1'b1; error_pattern[31] = 1'b1; end
    12'h5b3: begin error_pattern[33] = 1'b1; error_pattern[38] = 1'b1; end
    12'h5b5: begin error_pattern[16] = 1'b1; error_pattern[28] = 1'b1; end
    12'h5b9: begin error_pattern[7] = 1'b1; error_pattern[12] = 1'b1; end
    12'h5be: begin error_pattern[6] = 1'b1; error_pattern[26] = 1'b1; end
    12'h5c2: begin error_pattern[6] = 1'b1; error_pattern[29] = 1'b1; end
    12'h5c3: begin error_pattern[18] = 1'b1; error_pattern[22] = 1'b1; end
    12'h5c4: begin error_pattern[24] = 1'b1; error_pattern[37] = 1'b1; end
    12'h5c6: begin error_pattern[34] = 1'b1; error_pattern[38] = 1'b1; end
    12'h5cb: begin error_pattern[40] = 1'b1; error_pattern[41] = 1'b1; end
    12'h5d7: begin error_pattern[9] = 1'b1; error_pattern[39] = 1'b1; end
    12'h5d8: begin error_pattern[15] = 1'b1; error_pattern[32] = 1'b1; end
    12'h5db: begin error_pattern[27] = 1'b1; error_pattern[37] = 1'b1; end
    12'h5dc: begin error_pattern[13] = 1'b1; error_pattern[40] = 1'b1; end
    12'h5dd: begin error_pattern[10] = 1'b1; error_pattern[14] = 1'b1; end
    12'h5de: begin error_pattern[5] = 1'b1; error_pattern[26] = 1'b1; end
    12'h5eb: begin error_pattern[8] = 1'b1; error_pattern[19] = 1'b1; end
    12'h5ec: begin error_pattern[17] = 1'b1; error_pattern[30] = 1'b1; end
    12'h5ee: begin error_pattern[4] = 1'b1; error_pattern[26] = 1'b1; end
    12'h5f3: begin error_pattern[10] = 1'b1; error_pattern[42] = 1'b1; end
    12'h5f6: begin error_pattern[3] = 1'b1; error_pattern[26] = 1'b1; end
    12'h5fa: begin error_pattern[2] = 1'b1; error_pattern[26] = 1'b1; end
    12'h5fc: begin error_pattern[1] = 1'b1; error_pattern[26] = 1'b1; end
    12'h5fe: error_pattern[26] = 1'b1; // Data Bit 14
    12'h5ff: begin error_pattern[0] = 1'b1; error_pattern[26] = 1'b1; end
    12'h600: begin error_pattern[9] = 1'b1; error_pattern[10] = 1'b1; end
    12'h601: begin error_pattern[17] = 1'b1; error_pattern[18] = 1'b1; end
    12'h608: begin error_pattern[12] = 1'b1; error_pattern[31] = 1'b1; end
    12'h60a: begin error_pattern[14] = 1'b1; error_pattern[39] = 1'b1; end
    12'h614: begin error_pattern[19] = 1'b1; error_pattern[25] = 1'b1; end
    12'h615: begin error_pattern[7] = 1'b1; error_pattern[21] = 1'b1; end
    12'h618: begin error_pattern[26] = 1'b1; error_pattern[43] = 1'b1; end
    12'h61a: begin error_pattern[23] = 1'b1; error_pattern[38] = 1'b1; end
    12'h622: begin error_pattern[6] = 1'b1; error_pattern[32] = 1'b1; end
    12'h624: begin error_pattern[39] = 1'b1; error_pattern[42] = 1'b1; end
    12'h627: begin error_pattern[11] = 1'b1; error_pattern[37] = 1'b1; end
    12'h629: begin error_pattern[13] = 1'b1; error_pattern[35] = 1'b1; end
    12'h62a: begin error_pattern[19] = 1'b1; error_pattern[28] = 1'b1; end
    12'h62e: begin error_pattern[22] = 1'b1; error_pattern[30] = 1'b1; end
    12'h638: begin error_pattern[15] = 1'b1; error_pattern[29] = 1'b1; end
    12'h63e: begin error_pattern[35] = 1'b1; error_pattern[41] = 1'b1; end
    12'h642: begin error_pattern[5] = 1'b1; error_pattern[32] = 1'b1; end
    12'h644: begin error_pattern[15] = 1'b1; error_pattern[26] = 1'b1; end
    12'h660: begin error_pattern[1] = 1'b1; error_pattern[32] = 1'b1; end
    12'h662: error_pattern[32] = 1'b1; // Data Bit 20
    12'h663: begin error_pattern[0] = 1'b1; error_pattern[32] = 1'b1; end
    12'h664: begin error_pattern[29] = 1'b1; error_pattern[43] = 1'b1; end
    12'h666: begin error_pattern[2] = 1'b1; error_pattern[32] = 1'b1; end
    12'h66a: begin error_pattern[3] = 1'b1; error_pattern[32] = 1'b1; end
    12'h66c: begin error_pattern[24] = 1'b1; error_pattern[36] = 1'b1; end
    12'h672: begin error_pattern[4] = 1'b1; error_pattern[32] = 1'b1; end
    12'h673: begin error_pattern[27] = 1'b1; error_pattern[36] = 1'b1; end
    12'h674: begin error_pattern[8] = 1'b1; error_pattern[16] = 1'b1; end
    12'h678: begin error_pattern[20] = 1'b1; error_pattern[40] = 1'b1; end
    12'h683: begin error_pattern[12] = 1'b1; error_pattern[15] = 1'b1; end
    12'h685: begin error_pattern[4] = 1'b1; error_pattern[21] = 1'b1; end
    12'h687: begin error_pattern[16] = 1'b1; error_pattern[42] = 1'b1; end
    12'h68b: begin error_pattern[30] = 1'b1; error_pattern[36] = 1'b1; end
    12'h691: begin error_pattern[2] = 1'b1; error_pattern[21] = 1'b1; end
    12'h694: begin error_pattern[0] = 1'b1; error_pattern[21] = 1'b1; end
    12'h695: error_pattern[21] = 1'b1; // Data Bit 9
    12'h697: begin error_pattern[1] = 1'b1; error_pattern[21] = 1'b1; end
    12'h69d: begin error_pattern[3] = 1'b1; error_pattern[21] = 1'b1; end
    12'h6a1: begin error_pattern[33] = 1'b1; error_pattern[41] = 1'b1; end
    12'h6a9: begin error_pattern[14] = 1'b1; error_pattern[16] = 1'b1; end
    12'h6b3: begin error_pattern[29] = 1'b1; error_pattern[31] = 1'b1; end
    12'h6b5: begin error_pattern[5] = 1'b1; error_pattern[21] = 1'b1; end
    12'h6b6: begin error_pattern[13] = 1'b1; error_pattern[33] = 1'b1; end
    12'h6bb: begin error_pattern[20] = 1'b1; error_pattern[23] = 1'b1; end
    12'h6c1: begin error_pattern[10] = 1'b1; error_pattern[28] = 1'b1; end
    12'h6c3: begin error_pattern[13] = 1'b1; error_pattern[34] = 1'b1; end
    12'h6c9: begin error_pattern[22] = 1'b1; error_pattern[24] = 1'b1; end
    12'h6ce: begin error_pattern[18] = 1'b1; error_pattern[37] = 1'b1; end
    12'h6cf: begin error_pattern[26] = 1'b1; error_pattern[31] = 1'b1; end
    12'h6d4: begin error_pattern[34] = 1'b1; error_pattern[41] = 1'b1; end
    12'h6d5: begin error_pattern[6] = 1'b1; error_pattern[21] = 1'b1; end
    12'h6d6: begin error_pattern[22] = 1'b1; error_pattern[27] = 1'b1; end
    12'h6d7: begin error_pattern[8] = 1'b1; error_pattern[39] = 1'b1; end
    12'h6d9: begin error_pattern[38] = 1'b1; error_pattern[40] = 1'b1; end
    12'h6df: begin error_pattern[12] = 1'b1; error_pattern[43] = 1'b1; end
    12'h6e2: begin error_pattern[7] = 1'b1; error_pattern[32] = 1'b1; end
    12'h6e8: begin error_pattern[11] = 1'b1; error_pattern[17] = 1'b1; end
    12'h6eb: begin error_pattern[9] = 1'b1; error_pattern[19] = 1'b1; end
    12'h6ff: begin error_pattern[10] = 1'b1; error_pattern[25] = 1'b1; end
    12'h701: begin error_pattern[25] = 1'b1; error_pattern[26] = 1'b1; end
    12'h70d: begin error_pattern[19] = 1'b1; error_pattern[43] = 1'b1; end
    12'h727: begin error_pattern[24] = 1'b1; error_pattern[33] = 1'b1; end
    12'h731: begin error_pattern[10] = 1'b1; error_pattern[31] = 1'b1; end
    12'h734: begin error_pattern[6] = 1'b1; error_pattern[16] = 1'b1; end
    12'h738: begin error_pattern[27] = 1'b1; error_pattern[33] = 1'b1; end
    12'h739: begin error_pattern[9] = 1'b1; error_pattern[12] = 1'b1; end
    12'h73e: begin error_pattern[17] = 1'b1; error_pattern[20] = 1'b1; end
    12'h73f: begin error_pattern[26] = 1'b1; error_pattern[28] = 1'b1; end
    12'h743: begin error_pattern[28] = 1'b1; error_pattern[29] = 1'b1; end
    12'h747: begin error_pattern[18] = 1'b1; error_pattern[40] = 1'b1; end
    12'h748: begin error_pattern[14] = 1'b1; error_pattern[21] = 1'b1; end
    12'h74d: begin error_pattern[27] = 1'b1; error_pattern[34] = 1'b1; end
    12'h74f: begin error_pattern[22] = 1'b1; error_pattern[41] = 1'b1; end
    12'h750: begin error_pattern[37] = 1'b1; error_pattern[38] = 1'b1; end
    12'h751: begin error_pattern[15] = 1'b1; error_pattern[19] = 1'b1; end
    12'h752: begin error_pattern[24] = 1'b1; error_pattern[34] = 1'b1; end
    12'h754: begin error_pattern[5] = 1'b1; error_pattern[16] = 1'b1; end
    12'h757: begin error_pattern[7] = 1'b1; error_pattern[39] = 1'b1; end
    12'h758: begin error_pattern[13] = 1'b1; error_pattern[22] = 1'b1; end
    12'h75f: begin error_pattern[30] = 1'b1; error_pattern[35] = 1'b1; end
    12'h762: begin error_pattern[8] = 1'b1; error_pattern[32] = 1'b1; end
    12'h764: begin error_pattern[4] = 1'b1; error_pattern[16] = 1'b1; end
    12'h766: begin error_pattern[21] = 1'b1; error_pattern[42] = 1'b1; end
    12'h76d: begin error_pattern[11] = 1'b1; error_pattern[23] = 1'b1; end
    12'h770: begin error_pattern[2] = 1'b1; error_pattern[16] = 1'b1; end
    12'h774: error_pattern[16] = 1'b1; // Data Bit 4
    12'h775: begin error_pattern[0] = 1'b1; error_pattern[16] = 1'b1; end
    12'h776: begin error_pattern[1] = 1'b1; error_pattern[16] = 1'b1; end
    12'h77c: begin error_pattern[3] = 1'b1; error_pattern[16] = 1'b1; end
    12'h77d: begin error_pattern[25] = 1'b1; error_pattern[29] = 1'b1; end
    12'h782: begin error_pattern[9] = 1'b1; error_pattern[29] = 1'b1; end
    12'h784: begin error_pattern[18] = 1'b1; error_pattern[23] = 1'b1; end
    12'h791: begin error_pattern[32] = 1'b1; error_pattern[42] = 1'b1; end
    12'h795: begin error_pattern[8] = 1'b1; error_pattern[21] = 1'b1; end
    12'h797: begin error_pattern[6] = 1'b1; error_pattern[39] = 1'b1; end
    12'h79f: begin error_pattern[17] = 1'b1; error_pattern[38] = 1'b1; end
    12'h7a7: begin error_pattern[27] = 1'b1; error_pattern[35] = 1'b1; end
    12'h7ae: begin error_pattern[11] = 1'b1; error_pattern[40] = 1'b1; end
    12'h7b5: begin error_pattern[30] = 1'b1; error_pattern[34] = 1'b1; end
    12'h7b8: begin error_pattern[24] = 1'b1; error_pattern[35] = 1'b1; end
    12'h7ba: begin error_pattern[10] = 1'b1; error_pattern[15] = 1'b1; end
    12'h7bf: begin error_pattern[14] = 1'b1; error_pattern[32] = 1'b1; end
    12'h7c0: begin error_pattern[30] = 1'b1; error_pattern[33] = 1'b1; end
    12'h7c6: begin error_pattern[12] = 1'b1; error_pattern[25] = 1'b1; end
    12'h7c7: begin error_pattern[4] = 1'b1; error_pattern[39] = 1'b1; end
    12'h7d3: begin error_pattern[2] = 1'b1; error_pattern[39] = 1'b1; end
    12'h7d5: begin error_pattern[1] = 1'b1; error_pattern[39] = 1'b1; end
    12'h7d6: begin error_pattern[0] = 1'b1; error_pattern[39] = 1'b1; end
    12'h7d7: error_pattern[39] = 1'b1; // Data Bit 27
    12'h7da: begin error_pattern[19] = 1'b1; error_pattern[31] = 1'b1; end
    12'h7df: begin error_pattern[3] = 1'b1; error_pattern[39] = 1'b1; end
    12'h7e6: begin error_pattern[10] = 1'b1; error_pattern[43] = 1'b1; end
    12'h7ea: begin error_pattern[36] = 1'b1; error_pattern[41] = 1'b1; end
    12'h7f1: begin error_pattern[20] = 1'b1; error_pattern[37] = 1'b1; end
    12'h7f4: begin error_pattern[7] = 1'b1; error_pattern[16] = 1'b1; end
    12'h7f7: begin error_pattern[5] = 1'b1; error_pattern[39] = 1'b1; end
    12'h7f8: begin error_pattern[12] = 1'b1; error_pattern[28] = 1'b1; end
    12'h7fd: begin error_pattern[13] = 1'b1; error_pattern[36] = 1'b1; end
    12'h7fe: begin error_pattern[9] = 1'b1; error_pattern[26] = 1'b1; end
    12'h800: error_pattern[11] = 1'b1; // Check Bit 11
    12'h801: begin error_pattern[0] = 1'b1; error_pattern[11] = 1'b1; end
    12'h802: begin error_pattern[1] = 1'b1; error_pattern[11] = 1'b1; end
    12'h804: begin error_pattern[2] = 1'b1; error_pattern[11] = 1'b1; end
    12'h805: begin error_pattern[24] = 1'b1; error_pattern[43] = 1'b1; end
    12'h808: begin error_pattern[3] = 1'b1; error_pattern[11] = 1'b1; end
    12'h80b: begin error_pattern[14] = 1'b1; error_pattern[20] = 1'b1; end
    12'h80d: begin error_pattern[29] = 1'b1; error_pattern[36] = 1'b1; end
    12'h810: begin error_pattern[4] = 1'b1; error_pattern[11] = 1'b1; end
    12'h813: begin error_pattern[12] = 1'b1; error_pattern[22] = 1'b1; end
    12'h819: begin error_pattern[16] = 1'b1; error_pattern[23] = 1'b1; end
    12'h81a: begin error_pattern[27] = 1'b1; error_pattern[43] = 1'b1; end
    12'h820: begin error_pattern[5] = 1'b1; error_pattern[11] = 1'b1; end
    12'h825: begin error_pattern[20] = 1'b1; error_pattern[42] = 1'b1; end
    12'h82f: begin error_pattern[19] = 1'b1; error_pattern[33] = 1'b1; end
    12'h835: begin error_pattern[30] = 1'b1; error_pattern[31] = 1'b1; end
    12'h840: begin error_pattern[6] = 1'b1; error_pattern[11] = 1'b1; end
    12'h845: begin error_pattern[32] = 1'b1; error_pattern[37] = 1'b1; end
    12'h846: begin error_pattern[15] = 1'b1; error_pattern[27] = 1'b1; end
    12'h859: begin error_pattern[15] = 1'b1; error_pattern[24] = 1'b1; end
    12'h85a: begin error_pattern[19] = 1'b1; error_pattern[34] = 1'b1; end
    12'h85b: begin error_pattern[10] = 1'b1; error_pattern[35] = 1'b1; end
    12'h865: begin error_pattern[9] = 1'b1; error_pattern[41] = 1'b1; end
    12'h869: begin error_pattern[7] = 1'b1; error_pattern[18] = 1'b1; end
    12'h871: begin error_pattern[26] = 1'b1; error_pattern[36] = 1'b1; end
    12'h872: begin error_pattern[9] = 1'b1; error_pattern[13] = 1'b1; end
    12'h877: begin error_pattern[8] = 1'b1; error_pattern[38] = 1'b1; end
    12'h879: begin error_pattern[39] = 1'b1; error_pattern[40] = 1'b1; end
    12'h87d: begin error_pattern[17] = 1'b1; error_pattern[21] = 1'b1; end
    12'h880: begin error_pattern[7] = 1'b1; error_pattern[11] = 1'b1; end
    12'h884: begin error_pattern[38] = 1'b1; error_pattern[42] = 1'b1; end
    12'h88a: begin error_pattern[17] = 1'b1; error_pattern[32] = 1'b1; end
    12'h88d: begin error_pattern[13] = 1'b1; error_pattern[25] = 1'b1; end
    12'h89a: begin error_pattern[25] = 1'b1; error_pattern[41] = 1'b1; end
    12'h8a4: begin error_pattern[28] = 1'b1; error_pattern[41] = 1'b1; end
    12'h8a8: begin error_pattern[22] = 1'b1; error_pattern[29] = 1'b1; end
    12'h8a9: begin error_pattern[6] = 1'b1; error_pattern[18] = 1'b1; end
    12'h8aa: begin error_pattern[14] = 1'b1; error_pattern[38] = 1'b1; end
    12'h8b0: begin error_pattern[19] = 1'b1; error_pattern[35] = 1'b1; end
    12'h8b1: begin error_pattern[10] = 1'b1; error_pattern[34] = 1'b1; end
    12'h8b2: begin error_pattern[21] = 1'b1; error_pattern[37] = 1'b1; end
    12'h8b3: begin error_pattern[13] = 1'b1; error_pattern[28] = 1'b1; end
    12'h8b6: begin error_pattern[12] = 1'b1; error_pattern[36] = 1'b1; end
    12'h8ba: begin error_pattern[23] = 1'b1; error_pattern[39] = 1'b1; end
    12'h8be: begin error_pattern[15] = 1'b1; error_pattern[30] = 1'b1; end
    12'h8c4: begin error_pattern[10] = 1'b1; error_pattern[33] = 1'b1; end
    12'h8c9: begin error_pattern[5] = 1'b1; error_pattern[18] = 1'b1; end
    12'h8cd: begin error_pattern[27] = 1'b1; error_pattern[31] = 1'b1; end
    12'h8d2: begin error_pattern[24] = 1'b1; error_pattern[31] = 1'b1; end
    12'h8d4: begin error_pattern[22] = 1'b1; error_pattern[26] = 1'b1; end
    12'h8d6: begin error_pattern[8] = 1'b1; error_pattern[20] = 1'b1; end
    12'h8da: begin error_pattern[16] = 1'b1; error_pattern[40] = 1'b1; end
    12'h8e1: begin error_pattern[3] = 1'b1; error_pattern[18] = 1'b1; end
    12'h8e2: begin error_pattern[30] = 1'b1; error_pattern[43] = 1'b1; end
    12'h8e8: begin error_pattern[0] = 1'b1; error_pattern[18] = 1'b1; end
    12'h8e9: error_pattern[18] = 1'b1; // Data Bit 6
    12'h8eb: begin error_pattern[1] = 1'b1; error_pattern[18] = 1'b1; end
    12'h8ed: begin error_pattern[2] = 1'b1; error_pattern[18] = 1'b1; end
    12'h8f9: begin error_pattern[4] = 1'b1; error_pattern[18] = 1'b1; end
    12'h900: begin error_pattern[8] = 1'b1; error_pattern[11] = 1'b1; end
    12'h903: begin error_pattern[25] = 1'b1; error_pattern[27] = 1'b1; end
    12'h904: begin error_pattern[9] = 1'b1; error_pattern[30] = 1'b1; end
    12'h90f: begin error_pattern[23] = 1'b1; error_pattern[32] = 1'b1; end
    12'h91a: begin error_pattern[18] = 1'b1; error_pattern[42] = 1'b1; end
    12'h91c: begin error_pattern[24] = 1'b1; error_pattern[25] = 1'b1; end
    12'h922: begin error_pattern[24] = 1'b1; error_pattern[28] = 1'b1; end
    12'h92a: begin error_pattern[10] = 1'b1; error_pattern[22] = 1'b1; end
    12'h933: begin error_pattern[29] = 1'b1; error_pattern[34] = 1'b1; end
    12'h934: begin error_pattern[14] = 1'b1; error_pattern[18] = 1'b1; end
    12'h937: begin error_pattern[6] = 1'b1; error_pattern[38] = 1'b1; end
    12'h93a: begin error_pattern[26] = 1'b1; error_pattern[33] = 1'b1; end
    12'h93b: begin error_pattern[21] = 1'b1; error_pattern[40] = 1'b1; end
    12'h93d: begin error_pattern[27] = 1'b1; error_pattern[28] = 1'b1; end
    12'h93f: begin error_pattern[17] = 1'b1; error_pattern[39] = 1'b1; end
    12'h943: begin error_pattern[13] = 1'b1; error_pattern[31] = 1'b1; end
    12'h946: begin error_pattern[29] = 1'b1; error_pattern[33] = 1'b1; end
    12'h94f: begin error_pattern[26] = 1'b1; error_pattern[34] = 1'b1; end
    12'h953: begin error_pattern[16] = 1'b1; error_pattern[37] = 1'b1; end
    12'h954: begin error_pattern[31] = 1'b1; error_pattern[41] = 1'b1; end
    12'h956: begin error_pattern[7] = 1'b1; error_pattern[20] = 1'b1; end
    12'h957: begin error_pattern[5] = 1'b1; error_pattern[38] = 1'b1; end
    12'h962: begin error_pattern[12] = 1'b1; error_pattern[35] = 1'b1; end
    12'h964: begin error_pattern[19] = 1'b1; error_pattern[36] = 1'b1; end
    12'h967: begin error_pattern[4] = 1'b1; error_pattern[38] = 1'b1; end
    12'h973: begin error_pattern[2] = 1'b1; error_pattern[38] = 1'b1; end
    12'h975: begin error_pattern[1] = 1'b1; error_pattern[38] = 1'b1; end
    12'h976: begin error_pattern[0] = 1'b1; error_pattern[38] = 1'b1; end
    12'h977: error_pattern[38] = 1'b1; // Data Bit 26
    12'h97f: begin error_pattern[3] = 1'b1; error_pattern[38] = 1'b1; end
    12'h983: begin error_pattern[41] = 1'b1; error_pattern[43] = 1'b1; end
    12'h988: begin error_pattern[12] = 1'b1; error_pattern[34] = 1'b1; end
    12'h98f: begin error_pattern[10] = 1'b1; error_pattern[36] = 1'b1; end
    12'h994: begin error_pattern[13] = 1'b1; error_pattern[43] = 1'b1; end
    12'h996: begin error_pattern[6] = 1'b1; error_pattern[20] = 1'b1; end
    12'h99c: begin error_pattern[16] = 1'b1; error_pattern[17] = 1'b1; end
    12'h9a5: begin error_pattern[26] = 1'b1; error_pattern[35] = 1'b1; end
    12'h9c1: begin error_pattern[19] = 1'b1; error_pattern[22] = 1'b1; end
    12'h9c5: begin error_pattern[28] = 1'b1; error_pattern[30] = 1'b1; end
    12'h9c6: begin error_pattern[4] = 1'b1; error_pattern[20] = 1'b1; end
    12'h9c8: begin error_pattern[13] = 1'b1; error_pattern[15] = 1'b1; end
    12'h9cc: begin error_pattern[32] = 1'b1; error_pattern[40] = 1'b1; end
    12'h9d2: begin error_pattern[2] = 1'b1; error_pattern[20] = 1'b1; end
    12'h9d4: begin error_pattern[1] = 1'b1; error_pattern[20] = 1'b1; end
    12'h9d6: error_pattern[20] = 1'b1; // Data Bit 8
    12'h9d7: begin error_pattern[0] = 1'b1; error_pattern[20] = 1'b1; end
    12'h9d9: begin error_pattern[29] = 1'b1; error_pattern[35] = 1'b1; end
    12'h9dd: begin error_pattern[11] = 1'b1; error_pattern[14] = 1'b1; end
    12'h9de: begin error_pattern[3] = 1'b1; error_pattern[20] = 1'b1; end
    12'h9df: begin error_pattern[15] = 1'b1; error_pattern[41] = 1'b1; end
    12'h9e3: begin error_pattern[9] = 1'b1; error_pattern[24] = 1'b1; end
    12'h9e9: begin error_pattern[8] = 1'b1; error_pattern[18] = 1'b1; end
    12'h9f0: begin error_pattern[37] = 1'b1; error_pattern[39] = 1'b1; end
    12'h9f3: begin error_pattern[11] = 1'b1; error_pattern[42] = 1'b1; end
    12'h9f6: begin error_pattern[5] = 1'b1; error_pattern[20] = 1'b1; end
    12'h9f7: begin error_pattern[7] = 1'b1; error_pattern[38] = 1'b1; end
    12'h9f8: begin error_pattern[21] = 1'b1; error_pattern[23] = 1'b1; end
    12'h9fb: begin error_pattern[25] = 1'b1; error_pattern[30] = 1'b1; end
    12'h9fc: begin error_pattern[9] = 1'b1; error_pattern[27] = 1'b1; end
    12'h9fd: begin error_pattern[12] = 1'b1; error_pattern[33] = 1'b1; end
    12'ha00: begin error_pattern[9] = 1'b1; error_pattern[11] = 1'b1; end
    12'ha03: begin error_pattern[17] = 1'b1; error_pattern[19] = 1'b1; end
    12'ha04: begin error_pattern[8] = 1'b1; error_pattern[30] = 1'b1; end
    12'ha0f: begin error_pattern[27] = 1'b1; error_pattern[42] = 1'b1; end
    12'ha10: begin error_pattern[24] = 1'b1; error_pattern[42] = 1'b1; end
    12'ha16: begin error_pattern[18] = 1'b1; error_pattern[25] = 1'b1; end
    12'ha21: begin error_pattern[14] = 1'b1; error_pattern[27] = 1'b1; end
    12'ha24: begin error_pattern[21] = 1'b1; error_pattern[34] = 1'b1; end
    12'ha25: begin error_pattern[6] = 1'b1; error_pattern[41] = 1'b1; end
    12'ha27: begin error_pattern[10] = 1'b1; error_pattern[37] = 1'b1; end
    12'ha28: begin error_pattern[18] = 1'b1; error_pattern[28] = 1'b1; end
    12'ha2c: begin error_pattern[29] = 1'b1; error_pattern[40] = 1'b1; end
    12'ha30: begin error_pattern[20] = 1'b1; error_pattern[43] = 1'b1; end
    12'ha32: begin error_pattern[6] = 1'b1; error_pattern[13] = 1'b1; end
    12'ha39: begin error_pattern[32] = 1'b1; error_pattern[35] = 1'b1; end
    12'ha3e: begin error_pattern[14] = 1'b1; error_pattern[24] = 1'b1; end
    12'ha45: begin error_pattern[5] = 1'b1; error_pattern[41] = 1'b1; end
    12'ha46: begin error_pattern[31] = 1'b1; error_pattern[38] = 1'b1; end
    12'ha50: begin error_pattern[26] = 1'b1; error_pattern[40] = 1'b1; end
    12'ha51: begin error_pattern[21] = 1'b1; error_pattern[33] = 1'b1; end
    12'ha52: begin error_pattern[5] = 1'b1; error_pattern[13] = 1'b1; end
    12'ha54: begin error_pattern[12] = 1'b1; error_pattern[23] = 1'b1; end
    12'ha58: begin error_pattern[36] = 1'b1; error_pattern[39] = 1'b1; end
    12'ha5e: begin error_pattern[16] = 1'b1; error_pattern[22] = 1'b1; end
    12'ha61: begin error_pattern[2] = 1'b1; error_pattern[41] = 1'b1; end
    12'ha62: begin error_pattern[4] = 1'b1; error_pattern[13] = 1'b1; end
    12'ha64: begin error_pattern[0] = 1'b1; error_pattern[41] = 1'b1; end
    12'ha65: error_pattern[41] = 1'b1; // Data Bit 29
    12'ha67: begin error_pattern[1] = 1'b1; error_pattern[41] = 1'b1; end
    12'ha6c: begin error_pattern[15] = 1'b1; error_pattern[20] = 1'b1; end
    12'ha6d: begin error_pattern[3] = 1'b1; error_pattern[41] = 1'b1; end
    12'ha70: begin error_pattern[1] = 1'b1; error_pattern[13] = 1'b1; end
    12'ha72: error_pattern[13] = 1'b1; // Data Bit 1
    12'ha73: begin error_pattern[0] = 1'b1; error_pattern[13] = 1'b1; end
    12'ha75: begin error_pattern[4] = 1'b1; error_pattern[41] = 1'b1; end
    12'ha76: begin error_pattern[2] = 1'b1; error_pattern[13] = 1'b1; end
    12'ha7a: begin error_pattern[3] = 1'b1; error_pattern[13] = 1'b1; end
    12'ha91: begin error_pattern[38] = 1'b1; error_pattern[43] = 1'b1; end
    12'ha93: begin error_pattern[23] = 1'b1; error_pattern[26] = 1'b1; end
    12'ha97: begin error_pattern[12] = 1'b1; error_pattern[40] = 1'b1; end
    12'haa6: begin error_pattern[32] = 1'b1; error_pattern[33] = 1'b1; end
    12'hac1: begin error_pattern[11] = 1'b1; error_pattern[28] = 1'b1; end
    12'hacc: begin error_pattern[19] = 1'b1; error_pattern[37] = 1'b1; end
    12'hacd: begin error_pattern[15] = 1'b1; error_pattern[38] = 1'b1; end
    12'hace: begin error_pattern[21] = 1'b1; error_pattern[35] = 1'b1; end
    12'had3: begin error_pattern[32] = 1'b1; error_pattern[34] = 1'b1; end
    12'had9: begin error_pattern[14] = 1'b1; error_pattern[30] = 1'b1; end
    12'hae3: begin error_pattern[8] = 1'b1; error_pattern[24] = 1'b1; end
    12'hae5: begin error_pattern[7] = 1'b1; error_pattern[41] = 1'b1; end
    12'hae7: begin error_pattern[20] = 1'b1; error_pattern[31] = 1'b1; end
    12'hae8: begin error_pattern[10] = 1'b1; error_pattern[17] = 1'b1; end
    12'hae9: begin error_pattern[9] = 1'b1; error_pattern[18] = 1'b1; end
    12'haef: begin error_pattern[23] = 1'b1; error_pattern[29] = 1'b1; end
    12'haf2: begin error_pattern[7] = 1'b1; error_pattern[13] = 1'b1; end
    12'haf7: begin error_pattern[30] = 1'b1; error_pattern[42] = 1'b1; end
    12'hafb: begin error_pattern[16] = 1'b1; error_pattern[36] = 1'b1; end
    12'hafc: begin error_pattern[8] = 1'b1; error_pattern[27] = 1'b1; end
    12'hafd: begin error_pattern[22] = 1'b1; error_pattern[39] = 1'b1; end
    12'haff: begin error_pattern[11] = 1'b1; error_pattern[25] = 1'b1; end
    12'hb00: begin error_pattern[2] = 1'b1; error_pattern[30] = 1'b1; end
    12'hb04: error_pattern[30] = 1'b1; // Data Bit 18
    12'hb05: begin error_pattern[0] = 1'b1; error_pattern[30] = 1'b1; end
    12'hb06: begin error_pattern[1] = 1'b1; error_pattern[30] = 1'b1; end
    12'hb0c: begin error_pattern[3] = 1'b1; error_pattern[30] = 1'b1; end
    12'hb0f: begin error_pattern[18] = 1'b1; error_pattern[43] = 1'b1; end
    12'hb13: begin error_pattern[33] = 1'b1; error_pattern[39] = 1'b1; end
    12'hb14: begin error_pattern[4] = 1'b1; error_pattern[30] = 1'b1; end
    12'hb16: begin error_pattern[17] = 1'b1; error_pattern[26] = 1'b1; end
    12'hb17: begin error_pattern[20] = 1'b1; error_pattern[28] = 1'b1; end
    12'hb1a: begin error_pattern[21] = 1'b1; error_pattern[36] = 1'b1; end
    12'hb1e: begin error_pattern[12] = 1'b1; error_pattern[37] = 1'b1; end
    12'hb24: begin error_pattern[5] = 1'b1; error_pattern[30] = 1'b1; end
    12'hb29: begin error_pattern[20] = 1'b1; error_pattern[25] = 1'b1; end
    12'hb2f: begin error_pattern[16] = 1'b1; error_pattern[35] = 1'b1; end
    12'hb31: begin error_pattern[11] = 1'b1; error_pattern[31] = 1'b1; end
    12'hb44: begin error_pattern[6] = 1'b1; error_pattern[30] = 1'b1; end
    12'hb45: begin error_pattern[19] = 1'b1; error_pattern[40] = 1'b1; end
    12'hb48: begin error_pattern[22] = 1'b1; error_pattern[32] = 1'b1; end
    12'hb53: begin error_pattern[15] = 1'b1; error_pattern[18] = 1'b1; end
    12'hb63: begin error_pattern[7] = 1'b1; error_pattern[24] = 1'b1; end
    12'hb65: begin error_pattern[8] = 1'b1; error_pattern[41] = 1'b1; end
    12'hb66: begin error_pattern[34] = 1'b1; error_pattern[39] = 1'b1; end
    12'hb6a: begin error_pattern[17] = 1'b1; error_pattern[29] = 1'b1; end
    12'hb6d: begin error_pattern[10] = 1'b1; error_pattern[23] = 1'b1; end
    12'hb72: begin error_pattern[8] = 1'b1; error_pattern[13] = 1'b1; end
    12'hb77: begin error_pattern[9] = 1'b1; error_pattern[38] = 1'b1; end
    12'hb7c: begin error_pattern[7] = 1'b1; error_pattern[27] = 1'b1; end
    12'hb81: begin error_pattern[13] = 1'b1; error_pattern[42] = 1'b1; end
    12'hb84: begin error_pattern[7] = 1'b1; error_pattern[30] = 1'b1; end
    12'hb86: begin error_pattern[19] = 1'b1; error_pattern[23] = 1'b1; end
    12'hb88: begin error_pattern[25] = 1'b1; error_pattern[38] = 1'b1; end
    12'hb8c: begin error_pattern[35] = 1'b1; error_pattern[39] = 1'b1; end
    12'hb96: begin error_pattern[41] = 1'b1; error_pattern[42] = 1'b1; end
    12'hba3: begin error_pattern[6] = 1'b1; error_pattern[24] = 1'b1; end
    12'hba5: begin error_pattern[29] = 1'b1; error_pattern[37] = 1'b1; end
    12'hbae: begin error_pattern[10] = 1'b1; error_pattern[40] = 1'b1; end
    12'hbaf: begin error_pattern[13] = 1'b1; error_pattern[14] = 1'b1; end
    12'hbb0: begin error_pattern[16] = 1'b1; error_pattern[33] = 1'b1; end
    12'hbb6: begin error_pattern[28] = 1'b1; error_pattern[38] = 1'b1; end
    12'hbb8: begin error_pattern[14] = 1'b1; error_pattern[41] = 1'b1; end
    12'hbba: begin error_pattern[11] = 1'b1; error_pattern[15] = 1'b1; end
    12'hbbc: begin error_pattern[6] = 1'b1; error_pattern[27] = 1'b1; end
    12'hbbf: begin error_pattern[21] = 1'b1; error_pattern[22] = 1'b1; end
    12'hbc3: begin error_pattern[5] = 1'b1; error_pattern[24] = 1'b1; end
    12'hbc5: begin error_pattern[16] = 1'b1; error_pattern[34] = 1'b1; end
    12'hbd1: begin error_pattern[12] = 1'b1; error_pattern[17] = 1'b1; end
    12'hbd6: begin error_pattern[9] = 1'b1; error_pattern[20] = 1'b1; end
    12'hbd8: begin error_pattern[18] = 1'b1; error_pattern[31] = 1'b1; end
    12'hbd9: begin error_pattern[26] = 1'b1; error_pattern[37] = 1'b1; end
    12'hbdc: begin error_pattern[5] = 1'b1; error_pattern[27] = 1'b1; end
    12'hbe1: begin error_pattern[1] = 1'b1; error_pattern[24] = 1'b1; end
    12'hbe2: begin error_pattern[0] = 1'b1; error_pattern[24] = 1'b1; end
    12'hbe3: error_pattern[24] = 1'b1; // Data Bit 12
    12'hbe6: begin error_pattern[11] = 1'b1; error_pattern[43] = 1'b1; end
    12'hbe7: begin error_pattern[2] = 1'b1; error_pattern[24] = 1'b1; end
    12'hbeb: begin error_pattern[3] = 1'b1; error_pattern[24] = 1'b1; end
    12'hbec: begin error_pattern[4] = 1'b1; error_pattern[27] = 1'b1; end
    12'hbed: begin error_pattern[32] = 1'b1; error_pattern[36] = 1'b1; end
    12'hbf3: begin error_pattern[4] = 1'b1; error_pattern[24] = 1'b1; end
    12'hbf4: begin error_pattern[3] = 1'b1; error_pattern[27] = 1'b1; end
    12'hbf8: begin error_pattern[2] = 1'b1; error_pattern[27] = 1'b1; end
    12'hbfc: error_pattern[27] = 1'b1; // Data Bit 15
    12'hbfd: begin error_pattern[0] = 1'b1; error_pattern[27] = 1'b1; end
    12'hbfe: begin error_pattern[1] = 1'b1; error_pattern[27] = 1'b1; end
    12'hc00: begin error_pattern[10] = 1'b1; error_pattern[11] = 1'b1; end
    12'hc02: begin error_pattern[18] = 1'b1; error_pattern[19] = 1'b1; end
    12'hc07: begin error_pattern[32] = 1'b1; error_pattern[41] = 1'b1; end
    12'hc10: begin error_pattern[13] = 1'b1; error_pattern[32] = 1'b1; end
    12'hc14: begin error_pattern[15] = 1'b1; error_pattern[40] = 1'b1; end
    12'hc17: begin error_pattern[17] = 1'b1; error_pattern[25] = 1'b1; end
    12'hc1b: begin error_pattern[6] = 1'b1; error_pattern[35] = 1'b1; end
    12'hc27: begin error_pattern[9] = 1'b1; error_pattern[37] = 1'b1; end
    12'hc28: begin error_pattern[20] = 1'b1; error_pattern[26] = 1'b1; end
    12'hc29: begin error_pattern[17] = 1'b1; error_pattern[28] = 1'b1; end
    12'hc2a: begin error_pattern[8] = 1'b1; error_pattern[22] = 1'b1; end
    12'hc2b: begin error_pattern[27] = 1'b1; error_pattern[39] = 1'b1; end
    12'hc31: begin error_pattern[7] = 1'b1; error_pattern[34] = 1'b1; end
    12'hc34: begin error_pattern[24] = 1'b1; error_pattern[39] = 1'b1; end
    12'hc44: begin error_pattern[7] = 1'b1; error_pattern[33] = 1'b1; end
    12'hc48: begin error_pattern[40] = 1'b1; error_pattern[43] = 1'b1; end
    12'hc4b: begin error_pattern[4] = 1'b1; error_pattern[35] = 1'b1; end
    12'hc4e: begin error_pattern[12] = 1'b1; error_pattern[38] = 1'b1; end
    12'hc52: begin error_pattern[14] = 1'b1; error_pattern[36] = 1'b1; end
    12'hc53: begin error_pattern[3] = 1'b1; error_pattern[35] = 1'b1; end
    12'hc54: begin error_pattern[20] = 1'b1; error_pattern[29] = 1'b1; end
    12'hc59: begin error_pattern[1] = 1'b1; error_pattern[35] = 1'b1; end
    12'hc5a: begin error_pattern[0] = 1'b1; error_pattern[35] = 1'b1; end
    12'hc5b: error_pattern[35] = 1'b1; // Data Bit 23
    12'hc5c: begin error_pattern[23] = 1'b1; error_pattern[31] = 1'b1; end
    12'hc5f: begin error_pattern[2] = 1'b1; error_pattern[35] = 1'b1; end
    12'hc70: begin error_pattern[16] = 1'b1; error_pattern[30] = 1'b1; end
    12'hc7b: begin error_pattern[5] = 1'b1; error_pattern[35] = 1'b1; end
    12'hc7c: begin error_pattern[36] = 1'b1; error_pattern[42] = 1'b1; end
    12'hc84: begin error_pattern[6] = 1'b1; error_pattern[33] = 1'b1; end
    12'hc88: begin error_pattern[16] = 1'b1; error_pattern[27] = 1'b1; end
    12'hc89: begin error_pattern[26] = 1'b1; error_pattern[38] = 1'b1; end
    12'hc8b: begin error_pattern[23] = 1'b1; error_pattern[43] = 1'b1; end
    12'hc8f: begin error_pattern[8] = 1'b1; error_pattern[36] = 1'b1; end
    12'hc91: begin error_pattern[5] = 1'b1; error_pattern[34] = 1'b1; end
    12'hc97: begin error_pattern[16] = 1'b1; error_pattern[24] = 1'b1; end
    12'hc9f: begin error_pattern[31] = 1'b1; error_pattern[40] = 1'b1; end
    12'hca1: begin error_pattern[4] = 1'b1; error_pattern[34] = 1'b1; end
    12'hcb0: begin error_pattern[0] = 1'b1; error_pattern[34] = 1'b1; end
    12'hcb1: error_pattern[34] = 1'b1; // Data Bit 22
    12'hcb3: begin error_pattern[1] = 1'b1; error_pattern[34] = 1'b1; end
    12'hcb5: begin error_pattern[2] = 1'b1; error_pattern[34] = 1'b1; end
    12'hcb9: begin error_pattern[3] = 1'b1; error_pattern[34] = 1'b1; end
    12'hcc0: begin error_pattern[2] = 1'b1; error_pattern[33] = 1'b1; end
    12'hcc4: error_pattern[33] = 1'b1; // Data Bit 21
    12'hcc5: begin error_pattern[0] = 1'b1; error_pattern[33] = 1'b1; end
    12'hcc6: begin error_pattern[1] = 1'b1; error_pattern[33] = 1'b1; end
    12'hccc: begin error_pattern[3] = 1'b1; error_pattern[33] = 1'b1; end
    12'hcd3: begin error_pattern[30] = 1'b1; error_pattern[39] = 1'b1; end
    12'hcd4: begin error_pattern[4] = 1'b1; error_pattern[33] = 1'b1; end
    12'hcd7: begin error_pattern[15] = 1'b1; error_pattern[23] = 1'b1; end
    12'hcd8: begin error_pattern[25] = 1'b1; error_pattern[37] = 1'b1; end
    12'hcd9: begin error_pattern[22] = 1'b1; error_pattern[42] = 1'b1; end
    12'hcdb: begin error_pattern[7] = 1'b1; error_pattern[35] = 1'b1; end
    12'hce4: begin error_pattern[5] = 1'b1; error_pattern[33] = 1'b1; end
    12'hce6: begin error_pattern[28] = 1'b1; error_pattern[37] = 1'b1; end
    12'hce7: begin error_pattern[13] = 1'b1; error_pattern[21] = 1'b1; end
    12'hce8: begin error_pattern[9] = 1'b1; error_pattern[17] = 1'b1; end
    12'hce9: begin error_pattern[10] = 1'b1; error_pattern[18] = 1'b1; end
    12'hceb: begin error_pattern[11] = 1'b1; error_pattern[19] = 1'b1; end
    12'hcef: begin error_pattern[12] = 1'b1; error_pattern[20] = 1'b1; end
    12'hcf0: begin error_pattern[21] = 1'b1; error_pattern[41] = 1'b1; end
    12'hcf1: begin error_pattern[6] = 1'b1; error_pattern[34] = 1'b1; end
    12'hcf5: begin error_pattern[29] = 1'b1; error_pattern[38] = 1'b1; end
    12'hcf7: begin error_pattern[14] = 1'b1; error_pattern[22] = 1'b1; end
    12'hd06: begin error_pattern[13] = 1'b1; error_pattern[16] = 1'b1; end
    12'hd0a: begin error_pattern[5] = 1'b1; error_pattern[22] = 1'b1; end
    12'hd0e: begin error_pattern[17] = 1'b1; error_pattern[43] = 1'b1; end
    12'hd0f: begin error_pattern[7] = 1'b1; error_pattern[36] = 1'b1; end
    12'hd11: begin error_pattern[16] = 1'b1; error_pattern[41] = 1'b1; end
    12'hd16: begin error_pattern[31] = 1'b1; error_pattern[37] = 1'b1; end
    12'hd17: begin error_pattern[18] = 1'b1; error_pattern[26] = 1'b1; end
    12'hd19: begin error_pattern[14] = 1'b1; error_pattern[33] = 1'b1; end
    12'hd22: begin error_pattern[3] = 1'b1; error_pattern[22] = 1'b1; end
    12'hd28: begin error_pattern[1] = 1'b1; error_pattern[22] = 1'b1; end
    12'hd2a: error_pattern[22] = 1'b1; // Data Bit 10
    12'hd2b: begin error_pattern[0] = 1'b1; error_pattern[22] = 1'b1; end
    12'hd2e: begin error_pattern[2] = 1'b1; error_pattern[22] = 1'b1; end
    12'hd37: begin error_pattern[33] = 1'b1; error_pattern[42] = 1'b1; end
    12'hd39: begin error_pattern[11] = 1'b1; error_pattern[12] = 1'b1; end
    12'hd3a: begin error_pattern[4] = 1'b1; error_pattern[22] = 1'b1; end
    12'hd3d: begin error_pattern[19] = 1'b1; error_pattern[20] = 1'b1; end
    12'hd42: begin error_pattern[34] = 1'b1; error_pattern[42] = 1'b1; end
    12'hd51: begin error_pattern[25] = 1'b1; error_pattern[40] = 1'b1; end
    12'hd52: begin error_pattern[15] = 1'b1; error_pattern[17] = 1'b1; end
    12'hd5b: begin error_pattern[8] = 1'b1; error_pattern[35] = 1'b1; end
    12'hd66: begin error_pattern[30] = 1'b1; error_pattern[32] = 1'b1; end
    12'hd69: begin error_pattern[21] = 1'b1; error_pattern[27] = 1'b1; end
    12'hd6a: begin error_pattern[6] = 1'b1; error_pattern[22] = 1'b1; end
    12'hd6b: begin error_pattern[18] = 1'b1; error_pattern[29] = 1'b1; end
    12'hd6c: begin error_pattern[14] = 1'b1; error_pattern[34] = 1'b1; end
    12'hd6d: begin error_pattern[9] = 1'b1; error_pattern[23] = 1'b1; end
    12'hd6f: begin error_pattern[28] = 1'b1; error_pattern[40] = 1'b1; end
    12'hd76: begin error_pattern[21] = 1'b1; error_pattern[24] = 1'b1; end
    12'hd77: begin error_pattern[10] = 1'b1; error_pattern[38] = 1'b1; end
    12'hd81: begin error_pattern[24] = 1'b1; error_pattern[32] = 1'b1; end
    12'hd82: begin error_pattern[11] = 1'b1; error_pattern[29] = 1'b1; end
    12'hd86: begin error_pattern[14] = 1'b1; error_pattern[35] = 1'b1; end
    12'hd87: begin error_pattern[3] = 1'b1; error_pattern[36] = 1'b1; end
    12'hd8b: begin error_pattern[2] = 1'b1; error_pattern[36] = 1'b1; end
    12'hd8d: begin error_pattern[1] = 1'b1; error_pattern[36] = 1'b1; end
    12'hd8e: begin error_pattern[0] = 1'b1; error_pattern[36] = 1'b1; end
    12'hd8f: error_pattern[36] = 1'b1; // Data Bit 24
    12'hd91: begin error_pattern[21] = 1'b1; error_pattern[30] = 1'b1; end
    12'hd92: begin error_pattern[23] = 1'b1; error_pattern[25] = 1'b1; end
    12'hd9c: begin error_pattern[19] = 1'b1; error_pattern[38] = 1'b1; end
    12'hd9d: begin error_pattern[15] = 1'b1; error_pattern[37] = 1'b1; end
    12'hd9e: begin error_pattern[27] = 1'b1; error_pattern[32] = 1'b1; end
    12'hd9f: begin error_pattern[4] = 1'b1; error_pattern[36] = 1'b1; end
    12'hda5: begin error_pattern[13] = 1'b1; error_pattern[39] = 1'b1; end
    12'hda8: begin error_pattern[35] = 1'b1; error_pattern[42] = 1'b1; end
    12'hdaa: begin error_pattern[7] = 1'b1; error_pattern[22] = 1'b1; end
    12'hdac: begin error_pattern[23] = 1'b1; error_pattern[28] = 1'b1; end
    12'hdae: begin error_pattern[9] = 1'b1; error_pattern[40] = 1'b1; end
    12'hdaf: begin error_pattern[5] = 1'b1; error_pattern[36] = 1'b1; end
    12'hdb1: begin error_pattern[8] = 1'b1; error_pattern[34] = 1'b1; end
    12'hdb2: begin error_pattern[39] = 1'b1; error_pattern[41] = 1'b1; end
    12'hdc1: begin error_pattern[37] = 1'b1; error_pattern[43] = 1'b1; end
    12'hdc4: begin error_pattern[8] = 1'b1; error_pattern[33] = 1'b1; end
    12'hdcf: begin error_pattern[6] = 1'b1; error_pattern[36] = 1'b1; end
    12'hdd0: begin error_pattern[12] = 1'b1; error_pattern[18] = 1'b1; end
    12'hdd6: begin error_pattern[10] = 1'b1; error_pattern[20] = 1'b1; end
    12'hdd9: begin error_pattern[17] = 1'b1; error_pattern[31] = 1'b1; end
    12'hdfe: begin error_pattern[11] = 1'b1; error_pattern[26] = 1'b1; end
    12'he01: begin error_pattern[20] = 1'b1; error_pattern[39] = 1'b1; end
    12'he02: begin error_pattern[26] = 1'b1; error_pattern[27] = 1'b1; end
    12'he03: begin error_pattern[16] = 1'b1; error_pattern[38] = 1'b1; end
    12'he05: begin error_pattern[28] = 1'b1; error_pattern[33] = 1'b1; end
    12'he07: begin error_pattern[5] = 1'b1; error_pattern[37] = 1'b1; end
    12'he1b: begin error_pattern[22] = 1'b1; error_pattern[31] = 1'b1; end
    12'he1d: begin error_pattern[24] = 1'b1; error_pattern[26] = 1'b1; end
    12'he23: begin error_pattern[2] = 1'b1; error_pattern[37] = 1'b1; end
    12'he25: begin error_pattern[1] = 1'b1; error_pattern[37] = 1'b1; end
    12'he26: begin error_pattern[0] = 1'b1; error_pattern[37] = 1'b1; end
    12'he27: error_pattern[37] = 1'b1; // Data Bit 25
    12'he2f: begin error_pattern[3] = 1'b1; error_pattern[37] = 1'b1; end
    12'he35: begin error_pattern[15] = 1'b1; error_pattern[36] = 1'b1; end
    12'he37: begin error_pattern[4] = 1'b1; error_pattern[37] = 1'b1; end
    12'he3b: begin error_pattern[25] = 1'b1; error_pattern[33] = 1'b1; end
    12'he3d: begin error_pattern[12] = 1'b1; error_pattern[30] = 1'b1; end
    12'he4e: begin error_pattern[25] = 1'b1; error_pattern[34] = 1'b1; end
    12'he5b: begin error_pattern[9] = 1'b1; error_pattern[35] = 1'b1; end
    12'he5d: begin error_pattern[40] = 1'b1; error_pattern[42] = 1'b1; end
    12'he61: begin error_pattern[24] = 1'b1; error_pattern[29] = 1'b1; end
    12'he62: begin error_pattern[11] = 1'b1; error_pattern[32] = 1'b1; end
    12'he65: begin error_pattern[10] = 1'b1; error_pattern[41] = 1'b1; end
    12'he67: begin error_pattern[6] = 1'b1; error_pattern[37] = 1'b1; end
    12'he68: begin error_pattern[7] = 1'b1; error_pattern[17] = 1'b1; end
    12'he69: begin error_pattern[36] = 1'b1; error_pattern[43] = 1'b1; end
    12'he6d: begin error_pattern[8] = 1'b1; error_pattern[23] = 1'b1; end
    12'he70: begin error_pattern[28] = 1'b1; error_pattern[34] = 1'b1; end
    12'he72: begin error_pattern[10] = 1'b1; error_pattern[13] = 1'b1; end
    12'he73: begin error_pattern[14] = 1'b1; error_pattern[40] = 1'b1; end
    12'he7c: begin error_pattern[18] = 1'b1; error_pattern[21] = 1'b1; end
    12'he7e: begin error_pattern[27] = 1'b1; error_pattern[29] = 1'b1; end
    12'he86: begin error_pattern[29] = 1'b1; error_pattern[30] = 1'b1; end
    12'he8b: begin error_pattern[18] = 1'b1; error_pattern[32] = 1'b1; end
    12'he8e: begin error_pattern[19] = 1'b1; error_pattern[41] = 1'b1; end
    12'he90: begin error_pattern[15] = 1'b1; error_pattern[22] = 1'b1; end
    12'he95: begin error_pattern[11] = 1'b1; error_pattern[21] = 1'b1; end
    12'he99: begin error_pattern[13] = 1'b1; error_pattern[19] = 1'b1; end
    12'he9a: begin error_pattern[28] = 1'b1; error_pattern[35] = 1'b1; end
    12'he9e: begin error_pattern[23] = 1'b1; error_pattern[42] = 1'b1; end
    12'hea0: begin error_pattern[38] = 1'b1; error_pattern[39] = 1'b1; end
    12'hea2: begin error_pattern[16] = 1'b1; error_pattern[20] = 1'b1; end
    12'hea4: begin error_pattern[25] = 1'b1; error_pattern[35] = 1'b1; end
    12'hea7: begin error_pattern[7] = 1'b1; error_pattern[37] = 1'b1; end
    12'hea8: begin error_pattern[6] = 1'b1; error_pattern[17] = 1'b1; end
    12'heae: begin error_pattern[8] = 1'b1; error_pattern[40] = 1'b1; end
    12'heb0: begin error_pattern[14] = 1'b1; error_pattern[23] = 1'b1; end
    12'heb1: begin error_pattern[9] = 1'b1; error_pattern[34] = 1'b1; end
    12'hebe: begin error_pattern[31] = 1'b1; error_pattern[36] = 1'b1; end
    12'hec4: begin error_pattern[9] = 1'b1; error_pattern[33] = 1'b1; end
    12'hec5: begin error_pattern[12] = 1'b1; error_pattern[27] = 1'b1; end
    12'hec8: begin error_pattern[5] = 1'b1; error_pattern[17] = 1'b1; end
    12'hecc: begin error_pattern[22] = 1'b1; error_pattern[43] = 1'b1; end
    12'heda: begin error_pattern[12] = 1'b1; error_pattern[24] = 1'b1; end
    12'hee0: begin error_pattern[3] = 1'b1; error_pattern[17] = 1'b1; end
    12'hee8: error_pattern[17] = 1'b1; // Data Bit 5
    12'hee9: begin error_pattern[0] = 1'b1; error_pattern[17] = 1'b1; end
    12'heea: begin error_pattern[1] = 1'b1; error_pattern[17] = 1'b1; end
    12'heec: begin error_pattern[2] = 1'b1; error_pattern[17] = 1'b1; end
    12'hef8: begin error_pattern[4] = 1'b1; error_pattern[17] = 1'b1; end
    12'hefa: begin error_pattern[26] = 1'b1; error_pattern[30] = 1'b1; end
    12'hf04: begin error_pattern[10] = 1'b1; error_pattern[30] = 1'b1; end
    12'hf08: begin error_pattern[19] = 1'b1; error_pattern[24] = 1'b1; end
    12'hf0b: begin error_pattern[15] = 1'b1; error_pattern[34] = 1'b1; end
    12'hf15: begin error_pattern[32] = 1'b1; error_pattern[38] = 1'b1; end
    12'hf17: begin error_pattern[19] = 1'b1; error_pattern[27] = 1'b1; end
    12'hf1b: begin error_pattern[17] = 1'b1; error_pattern[42] = 1'b1; end
    12'hf22: begin error_pattern[33] = 1'b1; error_pattern[43] = 1'b1; end
    12'hf27: begin error_pattern[8] = 1'b1; error_pattern[37] = 1'b1; end
    12'hf2a: begin error_pattern[9] = 1'b1; error_pattern[22] = 1'b1; end
    12'hf2d: begin error_pattern[6] = 1'b1; error_pattern[23] = 1'b1; end
    12'hf2e: begin error_pattern[7] = 1'b1; error_pattern[40] = 1'b1; end
    12'hf35: begin error_pattern[14] = 1'b1; error_pattern[17] = 1'b1; end
    12'hf3e: begin error_pattern[18] = 1'b1; error_pattern[39] = 1'b1; end
    12'hf43: begin error_pattern[20] = 1'b1; error_pattern[21] = 1'b1; end
    12'hf4b: begin error_pattern[12] = 1'b1; error_pattern[13] = 1'b1; end
    12'hf4d: begin error_pattern[5] = 1'b1; error_pattern[23] = 1'b1; end
    12'hf4e: begin error_pattern[28] = 1'b1; error_pattern[36] = 1'b1; end
    12'hf57: begin error_pattern[34] = 1'b1; error_pattern[43] = 1'b1; end
    12'hf5c: begin error_pattern[12] = 1'b1; error_pattern[41] = 1'b1; end
    12'hf65: begin error_pattern[3] = 1'b1; error_pattern[23] = 1'b1; end
    12'hf69: begin error_pattern[2] = 1'b1; error_pattern[23] = 1'b1; end
    12'hf6a: begin error_pattern[31] = 1'b1; error_pattern[35] = 1'b1; end
    12'hf6c: begin error_pattern[0] = 1'b1; error_pattern[23] = 1'b1; end
    12'hf6d: error_pattern[23] = 1'b1; // Data Bit 11
    12'hf6f: begin error_pattern[1] = 1'b1; error_pattern[23] = 1'b1; end
    12'hf70: begin error_pattern[25] = 1'b1; error_pattern[36] = 1'b1; end
    12'hf74: begin error_pattern[11] = 1'b1; error_pattern[16] = 1'b1; end
    12'hf7d: begin error_pattern[4] = 1'b1; error_pattern[23] = 1'b1; end
    12'hf7e: begin error_pattern[15] = 1'b1; error_pattern[33] = 1'b1; end
    12'hf80: begin error_pattern[31] = 1'b1; error_pattern[34] = 1'b1; end
    12'hf8c: begin error_pattern[13] = 1'b1; error_pattern[26] = 1'b1; end
    12'hf8e: begin error_pattern[5] = 1'b1; error_pattern[40] = 1'b1; end
    12'hf8f: begin error_pattern[9] = 1'b1; error_pattern[36] = 1'b1; end
    12'hf9b: begin error_pattern[26] = 1'b1; error_pattern[41] = 1'b1; end
    12'hf9d: begin error_pattern[16] = 1'b1; error_pattern[18] = 1'b1; end
    12'hfa6: begin error_pattern[3] = 1'b1; error_pattern[40] = 1'b1; end
    12'hfaa: begin error_pattern[2] = 1'b1; error_pattern[40] = 1'b1; end
    12'hfac: begin error_pattern[1] = 1'b1; error_pattern[40] = 1'b1; end
    12'hfae: error_pattern[40] = 1'b1; // Data Bit 28
    12'hfaf: begin error_pattern[0] = 1'b1; error_pattern[40] = 1'b1; end
    12'hfb4: begin error_pattern[20] = 1'b1; error_pattern[32] = 1'b1; end
    12'hfbd: begin error_pattern[35] = 1'b1; error_pattern[43] = 1'b1; end
    12'hfbe: begin error_pattern[4] = 1'b1; error_pattern[40] = 1'b1; end
    12'hfd4: begin error_pattern[37] = 1'b1; error_pattern[42] = 1'b1; end
    12'hfd5: begin error_pattern[22] = 1'b1; error_pattern[25] = 1'b1; end
    12'hfd7: begin error_pattern[11] = 1'b1; error_pattern[39] = 1'b1; end
    12'hfe1: begin error_pattern[15] = 1'b1; error_pattern[35] = 1'b1; end
    12'hfe2: begin error_pattern[21] = 1'b1; error_pattern[38] = 1'b1; end
    12'hfe3: begin error_pattern[10] = 1'b1; error_pattern[24] = 1'b1; end
    12'hfe7: begin error_pattern[29] = 1'b1; error_pattern[41] = 1'b1; end
    12'hfe8: begin error_pattern[8] = 1'b1; error_pattern[17] = 1'b1; end
    12'hfeb: begin error_pattern[22] = 1'b1; error_pattern[28] = 1'b1; end
    12'hfed: begin error_pattern[7] = 1'b1; error_pattern[23] = 1'b1; end
    12'hfee: begin error_pattern[6] = 1'b1; error_pattern[40] = 1'b1; end
    12'hfef: begin error_pattern[19] = 1'b1; error_pattern[30] = 1'b1; end
    12'hff0: begin error_pattern[13] = 1'b1; error_pattern[29] = 1'b1; end
    12'hff5: begin error_pattern[31] = 1'b1; error_pattern[33] = 1'b1; end
    12'hffa: begin error_pattern[14] = 1'b1; error_pattern[37] = 1'b1; end
    12'hffc: begin error_pattern[10] = 1'b1; error_pattern[27] = 1'b1; end
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
 
