// Code ayour design here
// Code your design here
// -----------------------------------------------------------------------------
// Module: bch_dec_encoder
// Description: Parallel DEC Encoder using XOR trees for low latency.
// Reference: "Parallel Double Error Correcting Code Design...", Section III-A.
// -----------------------------------------------------------------------------
module bch_dec_encoder #(
    parameter DATA_WIDTH = 16,  // k bits [cite: 197]
    parameter CHECK_WIDTH = 10, // r bits [cite: 214]
    parameter CODE_WIDTH = 26   // n bits
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
      P_matrix[15] = 10'h344;
      P_matrix[14] = 10'h1a2;
      P_matrix[13] = 10'h0d1;
      P_matrix[12] = 10'h3dc;
      P_matrix[11] = 10'h1ee;
      P_matrix[10] = 10'h0f7;
      P_matrix[9] = 10'h3cf;
      P_matrix[8] = 10'h253;
      P_matrix[7] = 10'h29d;
      P_matrix[6] = 10'h2fa;
      P_matrix[5] = 10'h17d;
      P_matrix[4] = 10'h30a;
      P_matrix[3] = 10'h185;
      P_matrix[2] = 10'h376;
      P_matrix[1] = 10'h1bb;
      P_matrix[0] = 10'h369;
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