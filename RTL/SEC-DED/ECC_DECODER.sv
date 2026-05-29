module ecc_decoder #(
    parameter int DATA_WIDTH = 32
)(
    input  logic [DATA_WIDTH-1:0] 					d_in,
    input  logic [calc_ecc_bits(DATA_WIDTH)-1:0] 	ecc_in,
    output logic [DATA_WIDTH-1:0] 					d_out,
    output logic                  					single_bit_corrected,
    output logic                  					double_bit_error
);

    localparam int ECC_BITS = calc_ecc_bits(DATA_WIDTH);

    logic [ECC_BITS-2:0] 	syndrome;
    logic                	overall_parity;
    logic [DATA_WIDTH-1:0] 	corrected_data;

    // ------------------------------------------
    // Syndrome computation (recompute parity)
    // ------------------------------------------
    always_comb begin
        syndrome = '0;
        for (int i = 0; i < DATA_WIDTH; i++) begin
            int bit_position = i + 1;
            for (int j = 0; j < ECC_BITS-1; j++) begin
                if ((bit_position >> j) & 1)
                    syndrome[j] ^= d_in[i];
            end
        end
        // XOR with stored ECC to form syndrome
        syndrome ^= ecc_in[ECC_BITS-2:0];

        // Compute overall parity (data + ECC)
        overall_parity = ^{d_in, ecc_in};
    end

    // ------------------------------------------
    // Error detection/correction
    // ------------------------------------------
    always_comb begin
        int error_pos; 
        corrected_data = d_in;
        single_bit_corrected = 1'b0;
        double_bit_error     = 1'b0;

        if (syndrome != 0) begin
            if (overall_parity) begin
                // Single-bit error -> correct it
                //int error_pos = syndrome_to_position(syndrome);
                error_pos = syndrome;
                if (error_pos >= 1 && error_pos <= DATA_WIDTH)
                    corrected_data[error_pos-1] = ~corrected_data[error_pos-1];
                single_bit_corrected = 1'b1;
            end else begin
                // Double-bit error detected
                double_bit_error = 1'b1;
            end
        end
    end

    assign d_out = corrected_data;

    // ------------------------------------------
    // Convert syndrome to bit position
    // ------------------------------------------
	
	/*function automatic int syndrome_to_position(logic [ECC_BITS-2:0] pos);
		return int pos;
	endfunction*/
	
	// -----------------------------------------------------------------
	// Function to calculate ECC bits (r) such that 2^r >= (k + r + 1)
	// ----------------------------------------------------------------
    function automatic int calc_ecc_bits (int k);
        int r = 1;
        while ((2**r) < (k + r + 1)) r++;
        return r + 1; // +1 for overall parity bit
    endfunction
    
    endmodule
