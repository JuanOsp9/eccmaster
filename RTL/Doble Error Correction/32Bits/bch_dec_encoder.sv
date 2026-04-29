// -----------------------------------------------------------------------------
// Module: bch_dec_encoder
// Description: Parallel DEC Encoder using XOR trees for low latency.
// Reference: "Parallel Double Error Correcting Code Design...", Section III-A.
// -----------------------------------------------------------------------------
module bch_dec_encoder #(
    parameter DATA_WIDTH = 32,  // k bits [cite: 197]
    parameter CHECK_WIDTH = 12, // r bits [cite: 214]
    parameter CODE_WIDTH = 44   // n bits
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
    P_matrix[31] = 12'h3e6;
    P_matrix[30] = 12'h1f3;
    P_matrix[29] = 12'ha65;
    P_matrix[28] = 12'hfae;
    P_matrix[27] = 12'h7d7;
    P_matrix[26] = 12'h977;
    P_matrix[25] = 12'he27;
    P_matrix[24] = 12'hd8f;
    P_matrix[23] = 12'hc5b;
    P_matrix[22] = 12'hcb1;
    P_matrix[21] = 12'hcc4;
    P_matrix[20] = 12'h662;
    P_matrix[19] = 12'h331;
    P_matrix[18] = 12'hb04;
    P_matrix[17] = 12'h582;
    P_matrix[16] = 12'h2c1;
    P_matrix[15] = 12'hbfc;
    P_matrix[14] = 12'h5fe;
    P_matrix[13] = 12'h2ff;
    P_matrix[12] = 12'hbe3;
    P_matrix[11] = 12'hf6d;
    P_matrix[10] = 12'hd2a;
    P_matrix[9] = 12'h695;
    P_matrix[8] = 12'h9d6;
    P_matrix[7] = 12'h4eb;
    P_matrix[6] = 12'h8e9;
    P_matrix[5] = 12'hee8;
    P_matrix[4] = 12'h774;
    P_matrix[3] = 12'h3ba;
    P_matrix[2] = 12'h1dd;
    P_matrix[1] = 12'ha72;
    P_matrix[0] = 12'h539;
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
