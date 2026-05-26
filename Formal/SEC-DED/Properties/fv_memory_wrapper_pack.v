module memory_wrapper_fv #(
    parameter int ADDR_WIDTH = 7,
    parameter int DATA_WIDTH = 16,
    parameter int WORDS_BLOCK = 2
) (
    // 1. Primary Interface
    input  logic                    pi_clk,
    input  logic                    pi_cen,  // chip select (active low)
    input  logic                    pi_wen,  // write enable (0 = write)
    input  logic [ADDR_WIDTH-1:0]   pi_addr,
    input  logic [DATA_WIDTH-1:0]   pi_d,
    input  logic [DATA_WIDTH-1:0]   po_q,


    // 2. Word Packing & Encoder (Write Path)
    //input  logic [DATA_WIDTH*WORDS_BLOCK-1:0] d_ram,    // Concatenated data [cite: 9]
    //input  logic [calc_ecc_bits(DATA_WIDTH*WORDS_BLOCK)-1:0] ecc_wr, // Encoder output [cite: 3, 10]
    //input  logic [(DATA_WIDTH*WORDS_BLOCK + calc_ecc_bits(DATA_WIDTH*WORDS_BLOCK))-1:0] sram_din, // Cut-point [cite: 11]

    // 3. Decoder & Unpacking (Read Path)
    //input  logic [(DATA_WIDTH*WORDS_BLOCK + calc_ecc_bits(DATA_WIDTH*WORDS_BLOCK))-1:0] sram_dout, // SRAM output [cite: 13]
    input  logic [DATA_WIDTH*WORDS_BLOCK-1:0] po_q_out,    // Decoder output [cite: 14, 19]
    input  logic                    po_sb_corr,            // [cite: 2]
    input  logic                    po_db_err              // [cite: 2]
);

	default clocking cb @(posedge pi_clk); endclocking

    // Helper function copied from RTL to keep widths consistent [cite: 20]
    function automatic int calc_ecc_bits (int k);
        int r = 1;
        while ((2**r) < (k + r + 1)) r++
        return r + 1; // Includes extra parity bit [cite: 22, 23]
    endfunction
	
	logic [ADDR_WIDTH-1:0] fv_addr_base;
	stable_base_addr: assume property (fv_addr_base);
	
	// Constraint: Force the last two bits of the address to be 00 
	// whenever a valid transaction starts (cen is active low)
	property p_address_alignment;
		(fv_addr_base[1:0] == 2'b00)
	;endproperty

	assume_base_address_aligned: assume property (p_address_alignment);
	
	property p_word_0_packing;
		logic [DATA_WIDTH-1:0] fv_data_in;
		##0 !pi_cen && !pi_wen
		##0 (1, pi_addr = fv_addr_base)
		##0 (fv_data_in = pi_d)
		##1 (!pi_cen && !pi_wen, pi_addr == fv_addr_base + 1)
		##1 (!pi_cen && pi_wen, pi_addr == fv_addr_base)
		|->
		po_q == fv_data_in
	;endproperty


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
        // Design signals
        //.sram_din(sram_din),   
        //.sram_dout(sram_dout),
        // Internal ECC hooks for direct verification
        //.ecc_enc_out(ecc_wr),  // Output of the encoder [cite: 4]
        //.dec_data_out(q_out),  // Output of the decoder [cite: 14, 19]
        .po_sb_corr(single_bit_corrected),
        .po_db_err(double_bit_error)
    );
