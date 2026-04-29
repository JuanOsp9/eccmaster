// -----------------------------------------------------------------------------
// Module: bch_dec_encoder
// Description: Parallel DEC Encoder using XOR trees for low latency.
// Reference: "Parallel Double Error Correcting Code Design...", Section III-A.
// -----------------------------------------------------------------------------
module bch_dec_encoder #(
    parameter DATA_WIDTH = 64,  // k bits [cite: 197]
    parameter CHECK_WIDTH = 14, // r bits [cite: 214]
    parameter CODE_WIDTH = 78   // n bits
) (
    input  logic [DATA_WIDTH-1:0]  data_i,
    output logic [CODE_WIDTH-1:0]  codeword_o
);

    // The Generator Matrix G [k x n] is systematic: G = [I_k | P_k,r]
    // The Parity Sub-matrix P [k x r] determines the XOR connections.
    // This array acts as the connection map for the XOR trees[cite: 105].
    // NOTE: These values must be generated based on your specific g(x).
    // This is a placeholder example for connection logic.
    logic [CHECK_WIDTH-1:0] P_matrix [0:DATA_WIDTH-1];
 
  // Parity Matrix assignments for Data Width 16
  initial begin
P_matrix[63] = 14'h2b6c;
    P_matrix[62] = 14'h15b6;
    P_matrix[61] = 14'hadb;
    P_matrix[60] = 14'h24d6;
    P_matrix[59] = 14'h126b;
    P_matrix[58] = 14'h288e;
    P_matrix[57] = 14'h1447;
    P_matrix[56] = 14'h2b98;
    P_matrix[55] = 14'h15cc;
    P_matrix[54] = 14'hae6;
    P_matrix[53] = 14'h573;
    P_matrix[52] = 14'h2302;
    P_matrix[51] = 14'h1181;
    P_matrix[50] = 14'h297b;
    P_matrix[49] = 14'h3506;
    P_matrix[48] = 14'h1a83;
    P_matrix[47] = 14'h2cfa;
    P_matrix[46] = 14'h167d;
    P_matrix[45] = 14'h2a85;
    P_matrix[44] = 14'h34f9;
    P_matrix[43] = 14'h3bc7;
    P_matrix[42] = 14'h3c58;
    P_matrix[41] = 14'h1e2c;
    P_matrix[40] = 14'hf16;
    P_matrix[39] = 14'h78b;
    P_matrix[38] = 14'h227e;
    P_matrix[37] = 14'h113f;
    P_matrix[36] = 14'h2924;
    P_matrix[35] = 14'h1492;
    P_matrix[34] = 14'ha49;
    P_matrix[33] = 14'h249f;
    P_matrix[32] = 14'h33f4;
    P_matrix[31] = 14'h19fa;
    P_matrix[30] = 14'hcfd;
    P_matrix[29] = 14'h27c5;
    P_matrix[28] = 14'h3259;
    P_matrix[27] = 14'h3897;
    P_matrix[26] = 14'h3df0;
    P_matrix[25] = 14'h1ef8;
    P_matrix[24] = 14'hf7c;
    P_matrix[23] = 14'h7be;
    P_matrix[22] = 14'h3df;
    P_matrix[21] = 14'h2054;
    P_matrix[20] = 14'h102a;
    P_matrix[19] = 14'h815;
    P_matrix[18] = 14'h25b1;
    P_matrix[17] = 14'h3363;
    P_matrix[16] = 14'h380a;
    P_matrix[15] = 14'h1c05;
    P_matrix[14] = 14'h2fb9;
    P_matrix[13] = 14'h3667;
    P_matrix[12] = 14'h3a88;
    P_matrix[11] = 14'h1d44;
    P_matrix[10] = 14'hea2;
    P_matrix[9] = 14'h751;
    P_matrix[8] = 14'h2213;
    P_matrix[7] = 14'h30b2;
    P_matrix[6] = 14'h1859;
    P_matrix[5] = 14'h2d97;
    P_matrix[4] = 14'h3770;
    P_matrix[3] = 14'h1bb8;
    P_matrix[2] = 14'hddc;
    P_matrix[1] = 14'h6ee;
    P_matrix[0] = 14'h377;
  end
  // ----------------------------------

    // Combinational logic for check bit generation (Parallel XOR Trees) [cite: 103]
    logic [CHECK_WIDTH-1:0] check_bits;

    always_comb begin
        // Initialize check bits to 0
        check_bits = '0;
       
        // Compute parity bits: p = d * P_matrix
        // Each check bit is the XOR sum of data bits where P_matrix entry is 1
        for (int i = 0; i < CHECK_WIDTH; i++) begin
            for (int j = 0; j < DATA_WIDTH; j++) begin
                if (P_matrix[j][i]) begin
                    check_bits[i] = check_bits[i] ^ data_i[j];
                end
            end
        end
    end

    // Systematic Output: Data bits concatenated with Check bits [cite: 102]
    assign codeword_o = {data_i, check_bits};

endmodule