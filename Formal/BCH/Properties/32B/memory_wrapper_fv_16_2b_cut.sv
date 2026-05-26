module memory_wrapper_fv #(
    parameter int ADDR_WIDTH 	= 7,
    parameter int DATA_WIDTH 	= 16,
    parameter int CHECK_WIDTH 	= 12,
    parameter int CODE_WIDTH 	= 44,  // DATA*2 + CHECK
	parameter int WORDS_BLOCK 	= 2
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
 
    assign P_matrix[31] = 12'h3e6;
    assign P_matrix[30] = 12'h1f3;
    assign P_matrix[29] = 12'ha65;
    assign P_matrix[28] = 12'hfae;
    assign P_matrix[27] = 12'h7d7;
    assign P_matrix[26] = 12'h977;
    assign P_matrix[25] = 12'he27;
    assign P_matrix[24] = 12'hd8f;
    assign P_matrix[23] = 12'hc5b;
    assign P_matrix[22] = 12'hcb1;
    assign P_matrix[21] = 12'hcc4;
    assign P_matrix[20] = 12'h662;
    assign P_matrix[19] = 12'h331;
    assign P_matrix[18] = 12'hb04;
    assign P_matrix[17] = 12'h582;
    assign P_matrix[16] = 12'h2c1;
    assign P_matrix[15] = 12'hbfc;
    assign P_matrix[14] = 12'h5fe;
    assign P_matrix[13] = 12'h2ff;
    assign P_matrix[12] = 12'hbe3;
    assign P_matrix[11] = 12'hf6d;
    assign P_matrix[10] = 12'hd2a;
    assign P_matrix[9] = 12'h695;
    assign P_matrix[8] = 12'h9d6;
    assign P_matrix[7] = 12'h4eb;
    assign P_matrix[6] = 12'h8e9;
    assign P_matrix[5] = 12'hee8;
    assign P_matrix[4] = 12'h774;
    assign P_matrix[3] = 12'h3ba;
    assign P_matrix[2] = 12'h1dd;
    assign P_matrix[1] = 12'ha72;
    assign P_matrix[0] = 12'h539;

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
