// -------------------------------------------------------------------
// FILE 2: dmc_locator_corrector_32bit.sv
// -------------------------------------------------------------------
module dmc_locator_corrector_32bit (
    input  logic [31:0] D_in,      
    input  logic [19:0] delta_H,   // Horizontal Syndrome (from ERT Codec)
    input  logic [15:0] S,         // Vertical Syndrome (from ERT Codec)
    
    output logic [31:0] D_out,      // Corrected information bits
	output logic error_corrected
);

    logic err_s0, err_s1, err_s2, err_s3, err_s4, err_s5, err_s6, err_s7;

    // Error Locator: Intersection of delta_H and S
    assign err_s0 = (delta_H[4:0]   != 0) && (S[3:0]   != 0);
    assign err_s1 = (delta_H[9:5]   != 0) && (S[7:4]   != 0);
    assign err_s2 = (delta_H[4:0]   != 0) && (S[11:8]  != 0);
    assign err_s3 = (delta_H[9:5]   != 0) && (S[15:12] != 0);
    
    assign err_s4 = (delta_H[14:10] != 0) && (S[3:0]   != 0);
    assign err_s5 = (delta_H[19:15] != 0) && (S[7:4]   != 0);
    assign err_s6 = (delta_H[14:10] != 0) && (S[11:8]  != 0);
    assign err_s7 = (delta_H[19:15] != 0) && (S[15:12] != 0);

    // Error Corrector: Invert bits using Vertical Syndrome (S)
    always_comb begin
        D_out = D_in; 
		
		//error corrected flag
		error_corrected = err_s0 || err_s1 || err_s2 || err_s3 || err_s4 || err_s5 || err_s6 || err_s7;
        
        if (err_s0) D_out[3:0]   = D_in[3:0]   ^ S[3:0];
        if (err_s1) D_out[7:4]   = D_in[7:4]   ^ S[7:4];
        if (err_s2) D_out[11:8]  = D_in[11:8]  ^ S[11:8];
        if (err_s3) D_out[15:12] = D_in[15:12] ^ S[15:12];
        
        if (err_s4) D_out[19:16] = D_in[19:16] ^ S[3:0];
        if (err_s5) D_out[23:20] = D_in[23:20] ^ S[7:4];
        if (err_s6) D_out[27:24] = D_in[27:24] ^ S[11:8];
        if (err_s7) D_out[31:28] = D_in[31:28] ^ S[15:12];
    end

endmodule