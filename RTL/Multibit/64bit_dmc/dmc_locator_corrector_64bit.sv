// -------------------------------------------------------------------
// FILE 2: dmc_locator_corrector_64bit.sv
// -------------------------------------------------------------------
module dmc_locator_corrector_64bit (
    input  logic [63:0] D_in,      
    input  logic [23:0] delta_H,   // Horizontal Syndrome (from ERT Codec)
    input  logic [15:0] S,         // Vertical Syndrome (from ERT Codec)
    
    output logic [63:0] D_out,      // Corrected information bits
	output logic error_corrected
);

    logic [15:0] err_sym; // 1-bit error flag per symbol

    // Error Locator: Intersection of delta_H and S [cite: 173]
    // Row 0
    assign err_sym[0] = (delta_H[5:0] != 0) && (S[3:0]   != 0);
    assign err_sym[1] = (delta_H[5:0] != 0) && (S[7:4]   != 0);
    assign err_sym[2] = (delta_H[5:0] != 0) && (S[11:8]  != 0);
    assign err_sym[3] = (delta_H[5:0] != 0) && (S[15:12] != 0);
    
    // Row 1
    assign err_sym[4] = (delta_H[11:6] != 0) && (S[3:0]   != 0);
    assign err_sym[5] = (delta_H[11:6] != 0) && (S[7:4]   != 0);
    assign err_sym[6] = (delta_H[11:6] != 0) && (S[11:8]  != 0);
    assign err_sym[7] = (delta_H[11:6] != 0) && (S[15:12] != 0);

    // Row 2
    assign err_sym[8]  = (delta_H[17:12] != 0) && (S[3:0]   != 0);
    assign err_sym[9]  = (delta_H[17:12] != 0) && (S[7:4]   != 0);
    assign err_sym[10] = (delta_H[17:12] != 0) && (S[11:8]  != 0);
    assign err_sym[11] = (delta_H[17:12] != 0) && (S[15:12] != 0);

    // Row 3
    assign err_sym[12] = (delta_H[23:18] != 0) && (S[3:0]   != 0);
    assign err_sym[13] = (delta_H[23:18] != 0) && (S[7:4]   != 0);
    assign err_sym[14] = (delta_H[23:18] != 0) && (S[11:8]  != 0);
    assign err_sym[15] = (delta_H[23:18] != 0) && (S[15:12] != 0);

    // Error Corrector: Invert bits using Vertical Syndrome (S) [cite: 173]
    always_comb begin
        D_out = D_in; 
		error_corrected = err_sym[0] || err_sym[1] || err_sym[2] || err_sym[3] || err_sym[4] || err_sym[5] || err_sym[6] || err_sym[7]
							|| err_sym[8] || err_sym[9] || err_sym[10] || err_sym[11] || err_sym[12] || err_sym[13] || err_sym[14] || err_sym[15];
        
        // Col 0 Uses S[3:0]
        if (err_sym[0])  D_out[3:0]   = D_in[3:0]   ^ S[3:0];
        if (err_sym[4])  D_out[19:16] = D_in[19:16] ^ S[3:0];
        if (err_sym[8])  D_out[35:32] = D_in[35:32] ^ S[3:0];
        if (err_sym[12]) D_out[51:48] = D_in[51:48] ^ S[3:0];

        // Col 1 Uses S[7:4]
        if (err_sym[1])  D_out[7:4]   = D_in[7:4]   ^ S[7:4];
        if (err_sym[5])  D_out[23:20] = D_in[23:20] ^ S[7:4];
        if (err_sym[9])  D_out[39:36] = D_in[39:36] ^ S[7:4];
        if (err_sym[13]) D_out[55:52] = D_in[55:52] ^ S[7:4];

        // Col 2 Uses S[11:8]
        if (err_sym[2])  D_out[11:8]  = D_in[11:8]  ^ S[11:8];
        if (err_sym[6])  D_out[27:24] = D_in[27:24] ^ S[11:8];
        if (err_sym[10]) D_out[43:40] = D_in[43:40] ^ S[11:8];
        if (err_sym[14]) D_out[59:56] = D_in[59:56] ^ S[11:8];

        // Col 3 Uses S[15:12]
        if (err_sym[3])  D_out[15:12] = D_in[15:12] ^ S[15:12];
        if (err_sym[7])  D_out[31:28] = D_in[31:28] ^ S[15:12];
        if (err_sym[11]) D_out[47:44] = D_in[47:44] ^ S[15:12];
        if (err_sym[15]) D_out[63:60] = D_in[63:60] ^ S[15:12];
    end

endmodule