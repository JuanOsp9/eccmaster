module dmc_locator_corrector (
    input  logic [15:0] D_in,      // Received information bits from SRAM
    input  logic [4:0]  delta_H0,  // Horizontal Syndrome H0 (Row 0)
    input  logic [4:0]  delta_H1,  // Horizontal Syndrome H1 (Row 1)
    input  logic [3:0]  S0,        // Vertical Syndrome V0 (Col 0)
    input  logic [3:0]  S1,        // Vertical Syndrome V1 (Col 1)
    
    output logic [15:0] D_out,      // Corrected information bits
	output logic error_corrected
);

    // -------------------------------------------------------------------
    // 1. Error Locator
    // Identifies which 4-bit symbol contains the error based on row/col intersections.
    // -------------------------------------------------------------------
    logic err_sym0, err_sym1, err_sym2, err_sym3;

    // A non-zero horizontal syndrome indicates an error in that row.
    // A non-zero vertical syndrome indicates an error in that column.
    // The intersection isolates the faulty symbol.
    assign err_sym0 = (delta_H0 != 0) && (S0 != 0); // Intersection: Row 0, Col 0
    assign err_sym1 = (delta_H1 != 0) && (S0 != 0); // Intersection: Row 1, Col 0
    assign err_sym2 = (delta_H0 != 0) && (S1 != 0); // Intersection: Row 0, Col 1
    assign err_sym3 = (delta_H1 != 0) && (S1 != 0); // Intersection: Row 1, Col 1

    // -------------------------------------------------------------------
    // 2. Error Corrector
    // Inverts the erroneous bits using the Vertical Syndrome (S) as an error mask.
    // -------------------------------------------------------------------
    always_comb begin
        // Default assignment: pass through the data unmodified
        D_out = D_in; 

		//mark output if there is an Error
		
		error_corrected = err_sym0 || err_sym1 || err_sym2 || err_sym3;

        // If an error is located in a specific symbol, XOR the symbol with its 
        // corresponding vertical syndrome to flip the corrupted bits back to original.
        if (err_sym0) D_out[3:0]   = D_in[3:0]   ^ S0;
        if (err_sym1) D_out[7:4]   = D_in[7:4]   ^ S0;
        if (err_sym2) D_out[11:8]  = D_in[11:8]  ^ S1;
        if (err_sym3) D_out[15:12] = D_in[15:12] ^ S1;
    end

endmodule