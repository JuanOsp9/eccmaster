module ecc_encoder #(
    parameter int DATA_WIDTH = 32
)(
    input  logic [DATA_WIDTH-1:0] data,
    output logic [calc_ecc_bits(DATA_WIDTH)-1:0] ecc
);

    localparam int ECC_BITS = calc_ecc_bits(DATA_WIDTH);

    // ------------------------------------------
    // Generate ECC bits (Hamming SECDED)
    // ------------------------------------------
    // ECC bit positions: powers of 2 (1, 2, 4, 8...)
    // Last bit = overall parity (for DED capability)
    int bit_position;
    always_comb begin
        ecc = '0;
        // Compute each Hamming parity bit
        for (int i = 0; i < DATA_WIDTH; i++) begin
            bit_position = i + 1; // 1-based indexing
            for (int j = 0; j < ECC_BITS-1; j++) begin
                if ((bit_position >> j) & 1)
                    ecc[j] ^= data[i];
            end
        end

        // Add overall parity bit (XOR of data + other parity bits)
        ecc[ECC_BITS-1] = ^{data, ecc[ECC_BITS-2:0]};
    end

    // Function to calculate ECC bits (r) such that 2^r >= (k + r + 1)
    function automatic int calc_ecc_bits (int k);
        int r = 1;
        while ((2**r) < (k + r + 1)) r++;
        return r + 1; // +1 for overall parity bit
    endfunction

endmodule
