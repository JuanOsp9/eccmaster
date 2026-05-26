module memory_wrapper_fv #(
    parameter int ADDR_WIDTH = 7,
    parameter int DATA_WIDTH = 32,
    parameter int WORDS_BLOCK = 4
) (
    // 1. Primary Interface
    input  logic                    pi_clk,
    input  logic                    pi_cen,  
    input  logic                    pi_wen,  
    input  logic [ADDR_WIDTH-1:0]   pi_addr,
    input  logic [DATA_WIDTH-1:0]   pi_d,
    input  logic [DATA_WIDTH-1:0]   po_q,

    input  logic [(DATA_WIDTH*WORDS_BLOCK + calc_ecc_bits(DATA_WIDTH*WORDS_BLOCK))-1:0] fv_sram_din0,
    input  logic [(DATA_WIDTH*WORDS_BLOCK)-1:0] fv_ecc_enc_data,

    input  logic                    po_sb_corr,            
    input  logic                    po_db_err              
);

	default clocking cb @(posedge pi_clk); endclocking


// Helper function copied from RTL to keep widths consistent 
function automatic int calc_ecc_bits (int k);
    int r = 1;
    while ((2**r) < (k + r + 1)) r++; // Terminate the r++ statement [cite: 21]
    return r + 1; // Includes extra parity bit for SEC-DED [cite: 22, 23]
endfunction
	
	logic [ADDR_WIDTH-1:0] fv_addr_base;
	
	// Use the default clocking block for the assumption
    // This tells OneSpin that fv_addr_base is a synchronous signal
    assume property (
        @(posedge pi_clk) !pi_cen |-> (fv_addr_base[1:0] == 2'b00) ##0 $stable(fv_addr_base)//[*4]
    );
	


    // The width should match the total SRAM word (Data + ECC)
    localparam int TOTAL_BITS = DATA_WIDTH * WORDS_BLOCK + calc_ecc_bits(DATA_WIDTH * WORDS_BLOCK);

    // 1. Declare the symbolic variable
    logic [TOTAL_BITS-1:0] fv_error_mask;

    // 2. Constrain it to be "one-hot" (only one bit high at a time)
    // This forces the values to be 1, 2, 4, 8, 16, etc.
    assume_one_hot_mask: assume property (@(posedge pi_clk) 
        $onehot(fv_error_mask) 
    );

    // This prevents the 'dropping to zero' at the falling edge
    assume_stable_mask: assume property ($stable(fv_data_in_pack));

    logic [K_TOTAL-1:0] fv_data_in_pack;
    logic [DATA_WIDTH-1:0] fv_data_in;
    
    property p_word_packing_error;
		logic [DATA_WIDTH-1:0] fv_data_in;
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({compute_golden_ecc(fv_data_in_pack),fv_data_in_pack} ^ fv_error_mask) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1:DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 ( !pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1)[*2]
		|->
		po_q == fv_data_in
        && !po_db_err
        && po_sb_corr
	;endproperty

    a_word_single_error_pack: assert property(p_word_packing_error);

    property eq_encoder;
    fv_ecc_enc_data == fv_data_in_pack
    |->
    memory_wrapper.ecc_wr == compute_golden_ecc(fv_data_in_pack)
    ;endproperty

    equivalence_ecc: assert property(eq_encoder);

    // 1. Declare the symbolic variable
    logic [TOTAL_BITS-1:0] fv_two_bit_mask;

    // 2. Constrain it to have exactly two bits high
    // This allows values like 3 (0011), 5 (0101), 6 (0110), etc.
    assume_two_hot_mask: assume property (@(posedge pi_clk) 
        $countones(fv_two_bit_mask) == 2
    );

    property p_word_packing_error_two;
		logic [DATA_WIDTH-1:0] fv_data_in;
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({compute_golden_ecc(fv_data_in_pack),fv_data_in_pack} ^ fv_two_bit_mask) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1:DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 ( !pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1)[*2]
		|->
        po_db_err
        && !po_sb_corr
	;endproperty

    a_word_double_error_pack: assert property(p_word_packing_error_two);



    //Auxiliary logic// Enconder

localparam int K_TOTAL = DATA_WIDTH * WORDS_BLOCK;
localparam int ECC_BITS = calc_ecc_bits(K_TOTAL);

function automatic logic [ECC_BITS-1:0] compute_golden_ecc (
    input logic [K_TOTAL-1:0] data
);
    logic [ECC_BITS-2:0] hamming_parity;
    logic [ECC_BITS-1:0] final_ecc;
    int data_bit_ptr;
    
    hamming_parity = '0;
    data_bit_ptr = 0;
    
    // 1. Compute Hamming parity bits using the skipping-power-of-2 logic
    // We iterate through positions 'pos' and only use 'pos' if it's not a power of 2
    for (int pos = 1; data_bit_ptr < K_TOTAL; pos++) begin
        // Check if 'pos' is NOT a power of 2
        if ((pos & (pos - 1)) != 0) begin
            if (data[data_bit_ptr]) begin
                // XOR the position index into the Hamming parity bits
                hamming_parity ^= pos[ECC_BITS-2:0];
            end
            data_bit_ptr++;
        end
        
        // Safety break for formal tools to ensure termination (optional but good practice)
        if (pos > K_TOTAL + ECC_BITS) break; 
    end

    // 2. Add the SEC-DED overall parity bit
    // ecc[ECC_BITS-1] covers all data bits and all calculated Hamming bits
    final_ecc = { (^data) ^ (^hamming_parity), hamming_parity };
    
    return final_ecc;
endfunction

endmodule


    bind memory_wrapper memory_wrapper_fv #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .WORDS_BLOCK(WORDS_BLOCK)
    ) i_memory_wrapper_fv (
        .pi_clk(clk),
        .pi_cen(cen),
        .pi_wen(wen),
        .pi_addr(addr),
        .pi_d(d),
        .po_q(q),
        .fv_sram_din0(u_sram.din0),
        .fv_ecc_enc_data(ecc_enc.data),
        .po_sb_corr(single_bit_corrected),
        .po_db_err(double_bit_error)
    );
