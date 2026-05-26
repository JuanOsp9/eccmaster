module memory_wrapper_fv #(
    parameter int ADDR_WIDTH 	= 7,
    parameter int DATA_WIDTH 	= 64,
    parameter int CHECK_WIDTH 	= 14,
    parameter int CODE_WIDTH 	= 78,  // DATA*4 + CHECK
	parameter int WORDS_BLOCK 	= 4
) (
    // 1. Primary Interface
    input  logic                                pi_clk,
    input  logic                                pi_cen,  
    input  logic                                pi_wen,  
    input  logic [ADDR_WIDTH-1:0]               pi_addr,
    input  logic [DATA_WIDTH-1:0]               pi_d,
    input  logic [DATA_WIDTH-1:0]               po_q,

    input  logic [CODE_WIDTH-1:0]               fv_sram_din0,
    input  logic [(DATA_WIDTH*WORDS_BLOCK)-1:0] fv_ecc_enc_data,

    input  logic                                po_err_corr             
);

	default clocking cb @(posedge pi_clk); endclocking

	
logic [ADDR_WIDTH-1:0] fv_addr_base;
	
	// Use the default clocking block for the assumption
    // This tells OneSpin that fv_addr_base is a synchronous signal
    assume property (
        @(posedge pi_clk) !pi_cen |-> (fv_addr_base[1:0] == 2'b00) ##0 $stable(fv_addr_base)//[*4]
    );
	


    // The width should match the total SRAM word (Data + ECC)
    localparam int TOTAL_BITS = CODE_WIDTH;
    localparam int K_TOTAL = DATA_WIDTH*WORDS_BLOCK;

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
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({fv_data_in_pack,check_bits} ^ fv_error_mask) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1:DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 ( !pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1)[*2]
		|->
		po_q == fv_data_in
        && po_err_corr
	;endproperty

    a_word_single_error_pack: assert property(p_word_packing_error);

    property eq_encoder;
    fv_ecc_enc_data == fv_data_in_pack
    |->
    memory_wrapper.encoded_codeword == {fv_data_in_pack,check_bits}
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
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({fv_data_in_pack,check_bits}  ^ fv_two_bit_mask) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1:DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 ( !pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1)[*2]
		|->
		po_q == fv_data_in
        && po_err_corr
	;endproperty

    a_word_double_error_pack: assert property(p_word_packing_error_two);



    //Auxiliary logic// Enconder

// Direct Parallel Parity Logic derived from your P_Matrix
logic [CHECK_WIDTH-1:0] check_bits;

    logic [CHECK_WIDTH-1:0] P_matrix [0:(DATA_WIDTH*WORDS_BLOCK)-1];
 
  // Parity Matrix assignments for Data Width 16
 
    assign P_matrix[63] = 14'h2b6c;
    assign P_matrix[62] = 14'h15b6;
    assign P_matrix[61] = 14'hadb;
    assign P_matrix[60] = 14'h24d6;
    assign P_matrix[59] = 14'h126b;
    assign P_matrix[58] = 14'h288e;
    assign P_matrix[57] = 14'h1447;
    assign P_matrix[56] = 14'h2b98;
    assign P_matrix[55] = 14'h15cc;
    assign P_matrix[54] = 14'hae6;
    assign P_matrix[53] = 14'h573;
    assign P_matrix[52] = 14'h2302;
    assign P_matrix[51] = 14'h1181;
    assign P_matrix[50] = 14'h297b;
    assign P_matrix[49] = 14'h3506;
    assign P_matrix[48] = 14'h1a83;
    assign P_matrix[47] = 14'h2cfa;
    assign P_matrix[46] = 14'h167d;
    assign P_matrix[45] = 14'h2a85;
    assign P_matrix[44] = 14'h34f9;
    assign P_matrix[43] = 14'h3bc7;
    assign P_matrix[42] = 14'h3c58;
    assign P_matrix[41] = 14'h1e2c;
    assign P_matrix[40] = 14'hf16;
    assign P_matrix[39] = 14'h78b;
    assign P_matrix[38] = 14'h227e;
    assign P_matrix[37] = 14'h113f;
    assign P_matrix[36] = 14'h2924;
    assign P_matrix[35] = 14'h1492;
    assign P_matrix[34] = 14'ha49;
    assign P_matrix[33] = 14'h249f;
    assign P_matrix[32] = 14'h33f4;
    assign P_matrix[31] = 14'h19fa;
    assign P_matrix[30] = 14'hcfd;
    assign P_matrix[29] = 14'h27c5;
    assign P_matrix[28] = 14'h3259;
    assign P_matrix[27] = 14'h3897;
    assign P_matrix[26] = 14'h3df0;
    assign P_matrix[25] = 14'h1ef8;
    assign P_matrix[24] = 14'hf7c;
    assign P_matrix[23] = 14'h7be;
    assign P_matrix[22] = 14'h3df;
    assign P_matrix[21] = 14'h2054;
    assign P_matrix[20] = 14'h102a;
    assign P_matrix[19] = 14'h815;
    assign P_matrix[18] = 14'h25b1;
    assign P_matrix[17] = 14'h3363;
    assign P_matrix[16] = 14'h380a;
    assign P_matrix[15] = 14'h1c05;
    assign P_matrix[14] = 14'h2fb9;
    assign P_matrix[13] = 14'h3667;
    assign P_matrix[12] = 14'h3a88;
    assign P_matrix[11] = 14'h1d44;
    assign P_matrix[10] = 14'hea2;
    assign P_matrix[9] = 14'h751;
    assign P_matrix[8] = 14'h2213;
    assign P_matrix[7] = 14'h30b2;
    assign P_matrix[6] = 14'h1859;
    assign P_matrix[5] = 14'h2d97;
    assign P_matrix[4] = 14'h3770;
    assign P_matrix[3] = 14'h1bb8;
    assign P_matrix[2] = 14'hddc;
    assign P_matrix[1] = 14'h6ee;
    assign P_matrix[0] = 14'h377;

always_comb begin
    check_bits = '0;
    for (int i = 0; i < CHECK_WIDTH; i++) begin
        for (int j = 0; j < DATA_WIDTH*WORDS_BLOCK; j++) begin
            // This is the functional "Golden" definition of your matrix logic
            if (P_matrix[j][i]) begin
                check_bits[i] ^= fv_data_in_pack[j];
            end
        end
    end
end

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
        .fv_sram_din0(u_sram.din0),
        .fv_ecc_enc_data(encoder_inst.data_i),
        .pi_d(d),
        .po_q(q),
        .po_err_corr(error_corrected)
    );
