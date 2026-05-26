module memory_wrapper_fv #(
    parameter int ADDR_WIDTH 		= 7,
    parameter int DATA_WIDTH 		= 16,
    parameter int CHECK_H_WIDTH 	= 10,
	parameter int CHECK_V_WIDTH 	= 8,
    parameter int CODE_WIDTH	 	= 34,  // DATA + CHECK_H + CHECK_V
	parameter int WORDS_BLOCK 		= 1
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
    //logic [K_TOTAL-1:0] fv_error_mask;

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
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits,fv_data_in_pack} ^ fv_error_mask) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1:DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 ( !pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16bit_B1.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
		|->
		po_q == fv_data_in
        //&& po_err_corr
	;endproperty

    a_word_single_error_pack: assert property(p_word_packing_error);

    property eq_encoder;
    fv_ecc_enc_data == fv_data_in_pack
    && !pi_wen
    |->
    {fv_ecc_enc_data, memory_wrapper_16bit_B1.encoder_inst.V_out, memory_wrapper_16bit_B1.encoder_inst.H_out} == {fv_data_in_pack,check_bits}
    ;endproperty

    equivalence_ecc: assert property(eq_encoder);

// 1. Declare the mask
    logic [K_TOTAL-1:0] fv_two_bit_mask;

    // 2. Create a wire that is high only if the errors are in a valid 4-bit group
    logic [ (K_TOTAL/4)-1 : 0 ] group_is_valid;

    genvar i;
    generate
        for (i = 0; i < K_TOTAL/4; i = i + 1) begin : segment_check
            // A group is valid if:
            // - It contains exactly 2 bits
            // - AND the rest of the entire mask is 0
            assign group_is_valid[i] = ($countones(fv_two_bit_mask[i*4 +: 4]) == 2) && 
                                       ($countones(fv_two_bit_mask) == 2);
        end
    endgenerate

    // 3. The final constraint
    // The mask is only valid if exactly one of these groups caught the error
    assume_aligned_window: assume property (@(posedge pi_clk) 
        |group_is_valid 
    );

    property p_word_packing_error_two;
    	logic [DATA_WIDTH-1:0] fv_data_in;
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits,fv_data_in_pack}  ^ fv_two_bit_mask) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1:DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 ( !pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16bit_B1.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
		|->
		po_q == fv_data_in
        //&& po_err_corr
	;endproperty

    a_word_double_error_pack: assert property(p_word_packing_error_two);



// 1. Declare the mask
    logic [K_TOTAL-1:0] fv_three_bit_mask;

    // 2. Create a wire that is high only if the errors are in a valid 4-bit group
    logic [ (K_TOTAL/4)-1 : 0 ] group_is_valid;

    genvar i;
    generate
        for (i = 0; i < K_TOTAL/4; i = i + 1) begin : segment_check_3
            // A group is valid if:
            // - That specific 4-bit segment contains exactly 3 bits
            // - AND the total mask count is exactly 3 (ensures no bits elsewhere)
            assign group_is_valid[i] = ($countones(fv_three_bit_mask[i*4 +: 4]) == 3) && 
                                       ($countones(fv_three_bit_mask) == 3);
        end
    endgenerate

    // 3. The final constraint
    assume_aligned_window_3bit: assume property (@(posedge pi_clk) 
        |group_is_valid 
    );

    // 4. Updated Property for Triple Error
    property p_word_packing_error_three;
        logic [DATA_WIDTH-1:0] fv_data_in;
        // Injecting the 3-bit mask here
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits, fv_data_in_pack} ^ fv_three_bit_mask) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1 : DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16bit_B1.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
        |->
        po_q == fv_data_in 
    endproperty

    a_word_triple_error_pack: assert property(p_word_packing_error_three);

        // 1. Declare the mask
    logic [K_TOTAL-1:0] fv_four_bit_mask;

    // 2. Create a wire that is high only if the errors are in a valid 4-bit group
    logic [ (K_TOTAL/4)-1 : 0 ] group_is_valid;

    genvar i;
    generate
        for (i = 0; i < K_TOTAL/4; i = i + 1) begin : segment_check_4
            // A group is valid if:
            // - That specific 4-bit segment is all 1s (4'b1111)
            // - AND the total mask count is exactly 4
            assign group_is_valid[i] = (fv_four_bit_mask[i*4 +: 4] == 4'b1111) && 
                                       ($countones(fv_four_bit_mask) == 4);
        end
    endgenerate

    // 3. The final constraint
    assume_aligned_window_4bit: assume property (@(posedge pi_clk) 
        |group_is_valid 
    );

    // 4. Property for Quadruple Error
    property p_word_packing_error_four;
        logic [DATA_WIDTH-1:0] fv_data_in;
        
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits, fv_data_in_pack} ^ fv_four_bit_mask) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1 : DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16bit_B1.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
        |->
        po_q == fv_data_in
    endproperty

    a_word_quad_error_pack: assert property(p_word_packing_error_four);



    // 1. Declare the mask
    logic [CODE_WIDTH-1:0] fv_four_bit_mask_free;

    // 2. Define the target range 
    localparam int RANGE_START = CODE_WIDTH - 18; // The lower index
    localparam int RANGE_END   = CODE_WIDTH - 9;  // The higher index

    // 3. Constraints
    // Constraint A: Exactly 4 bits are high anywhere in the mask
    assume_count_is_four: assume property (@(posedge pi_clk) 
        $countones(fv_four_bit_mask_free) == 4
    );

    // Constraint B: All bits outside the 9-18 range must be zero
    // This forces the 4 bits to "land" inside your 10-bit window
    assume_inside_range_9_to_18: assume property (@(posedge pi_clk)
        (fv_four_bit_mask_free & ~(( { (CODE_WIDTH){1'b1} } >> (CODE_WIDTH - (RANGE_END - RANGE_START + 1)) ) << RANGE_START)) == '0
    );

    // 4. Property
    property p_word_packing_error_four_free_v;
        logic [DATA_WIDTH-1:0] fv_data_in;
        
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits, fv_data_in_pack} ^ fv_four_bit_mask_free) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1 : DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16bit_B1.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
        |->
        po_q == fv_data_in
    endproperty

    a_word_quad_error_pack_free_v: assert property(p_word_packing_error_four_free_v);

    // 1. Declare the mask
    logic [CODE_WIDTH-1:0] fv_three_bit_mask_free;

    // 2. Define the target range relative to CODE_WIDTH
    // If CODE_WIDTH is 40: Range is [31:22]
    localparam int RANGE_END   = CODE_WIDTH - 9;  // Higher index
    localparam int RANGE_START = CODE_WIDTH - 18; // Lower index

    // 3. Constraints
    // Constraint A: Exactly 3 bits are high
    assume_count_is_three: assume property (@(posedge pi_clk) 
        $countones(fv_three_bit_mask_free) == 3
    );

    // Constraint B: Bits outside the target 10-bit window must be zero
    // This uses a bitmask to isolate the range [RANGE_END : RANGE_START]
    assume_inside_range_rel: assume property (@(posedge pi_clk)
        (fv_three_bit_mask_free & ~(( { (CODE_WIDTH){1'b1} } >> (CODE_WIDTH - (RANGE_END - RANGE_START + 1)) ) << RANGE_START)) == '0
    );

    // 4. Property
    property p_word_packing_error_three_free_v;
        logic [DATA_WIDTH-1:0] fv_data_in;
        
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits, fv_data_in_pack} ^ fv_three_bit_mask_free) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1 : DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16bit_B1.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
        |->
        po_q == fv_data_in
    endproperty

    a_word_triple_error_pack_free_v: assert property(p_word_packing_error_three_free_v);

    // 1. Declare the mask
    logic [CODE_WIDTH-1:0] fv_two_bit_mask_free;

    // 2. Define the target range relative to CODE_WIDTH
    // Example: If CODE_WIDTH is 40, Range is bits 22 to 31
    localparam int RANGE_END   = CODE_WIDTH - 9;  // Higher index
    localparam int RANGE_START = CODE_WIDTH - 18; // Lower index

    // 3. Constraints
    // Constraint A: Exactly 2 bits are high
    assume_count_is_two: assume property (@(posedge pi_clk) 
        $countones(fv_two_bit_mask_free) == 2
    );

    // Constraint B: All bits outside the RANGE_START to RANGE_END must be zero
    // This mask clears everything except the 10-bit target window
    assume_inside_range_free_2b: assume property (@(posedge pi_clk)
        (fv_two_bit_mask_free & ~(( { (CODE_WIDTH){1'b1} } >> (CODE_WIDTH - (RANGE_END - RANGE_START + 1)) ) << RANGE_START)) == '0
    );

    // 4. Property
    property p_word_packing_error_two_free_v;
        logic [DATA_WIDTH-1:0] fv_data_in;
        
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits, fv_data_in_pack} ^ fv_two_bit_mask_free) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1 : DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16bit_B1.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
        |->
        po_q == fv_data_in
    endproperty

    a_word_double_error_pack_free_v: assert property(p_word_packing_error_two_free_v);


    // 1. Declare the mask
    logic [CODE_WIDTH-1:0] fv_two_bit_mask_free_h;

    // 2. Define the target range relative to CODE_WIDTH
    localparam int RANGE_END   = CODE_WIDTH - 1;  // Higher index
    localparam int RANGE_START = CODE_WIDTH - 8; // Lower index

    // 3. Constraints
    // Constraint A: Exactly 2 bits are high
    assume_count_is_two_h: assume property (@(posedge pi_clk) 
        $countones(fv_two_bit_mask_free_h) == 2
    );

    // Constraint B: All bits outside the RANGE_START to RANGE_END must be zero
    // This mask clears everything except the 10-bit target window
    assume_inside_range_free_2b_h: assume property (@(posedge pi_clk)
        (fv_two_bit_mask_free_h & ~(( { (CODE_WIDTH){1'b1} } >> (CODE_WIDTH - (RANGE_END - RANGE_START + 1)) ) << RANGE_START)) == '0
    );

    // 4. Property
    property p_word_packing_error_two_free_h;
        logic [DATA_WIDTH-1:0] fv_data_in;
        
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits, fv_data_in_pack} ^ fv_two_bit_mask_free_h) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1 : DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16bit_B1.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
        |->
        po_q == fv_data_in
    endproperty

    a_word_double_error_pack_free_h: assert property(p_word_packing_error_two_free_h);

        // 1. Declare the mask
    logic [CODE_WIDTH-1:0] fv_three_bit_mask_free_h;

    // 2. Define the target range relative to CODE_WIDTH
    // If CODE_WIDTH is 40: Range is [31:22]
    localparam int RANGE_END   = CODE_WIDTH - 1;  // Higher index
    localparam int RANGE_START = CODE_WIDTH - 8; // Lower index

    // 3. Constraints
    // Constraint A: Exactly 3 bits are high
    assume_count_is_three_h: assume property (@(posedge pi_clk) 
        $countones(fv_three_bit_mask_free_h) == 3
    );

    // Constraint B: Bits outside the target 10-bit window must be zero
    // This uses a bitmask to isolate the range [RANGE_END : RANGE_START]
    assume_inside_range_rel_h: assume property (@(posedge pi_clk)
        (fv_three_bit_mask_free_h & ~(( { (CODE_WIDTH){1'b1} } >> (CODE_WIDTH - (RANGE_END - RANGE_START + 1)) ) << RANGE_START)) == '0
    );

    // 4. Property
    property p_word_packing_error_three_free_h;
        logic [DATA_WIDTH-1:0] fv_data_in;
        
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits, fv_data_in_pack} ^ fv_three_bit_mask_free_h) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1 : DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16bit_B1.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
        |->
        po_q == fv_data_in
    endproperty

    a_word_triple_error_pack_free_h: assert property(p_word_packing_error_three_free_h);

        // 1. Declare the mask
    logic [CODE_WIDTH-1:0] fv_four_bit_mask_free_h;

    // 2. Define the target range (10 bits total: 18, 17, 16, 15, 14, 13, 12, 11, 10, 9)
    localparam int RANGE_START = CODE_WIDTH - 1; // The lower index
    localparam int RANGE_END   = CODE_WIDTH - 8;  // The higher index

    // 3. Constraints
    // Constraint A: Exactly 4 bits are high anywhere in the mask
    assume_count_is_four_h: assume property (@(posedge pi_clk) 
        $countones(fv_four_bit_mask_free_h) == 4
    );

    // Constraint B: All bits outside the 9-18 range must be zero
    // This forces the 4 bits to "land" inside your 10-bit window
    assume_inside_range_1_to_8_h: assume property (@(posedge pi_clk)
        (fv_four_bit_mask_free_h & ~(( { (CODE_WIDTH){1'b1} } >> (CODE_WIDTH - (RANGE_END - RANGE_START + 1)) ) << RANGE_START)) == '0
    );

    // 4. Property
    property p_word_packing_error_four_free_h;
        logic [DATA_WIDTH-1:0] fv_data_in;
        
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits, fv_data_in_pack} ^ fv_four_bit_mask_free_h) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1 : DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16bit_B1.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
        |->
        po_q == fv_data_in
    endproperty

    a_word_quad_error_pack_free_h: assert property(p_word_packing_error_four_free_h);

    //Auxiliary logic// Enconder

// Direct Parallel Parity Logic derived from your P_Matrix
logic [CHECK_H_WIDTH+CHECK_V_WIDTH-1:0] check_bits;

    logic [3:0] sym0, sym1, sym2, sym3;
    
    assign sym0 = fv_data_in_pack[3:0];   // D3:D0
    assign sym1 = fv_data_in_pack[7:4];   // D7:D4
    assign sym2 = fv_data_in_pack[11:8];  // D11:D8
    assign sym3 = fv_data_in_pack[15:12]; // D15:D12

    // -------------------------------------------------------------------
    // 2. Core Encoder Operations
    // -------------------------------------------------------------------
    logic [CHECK_H_WIDTH-1:0] H_out;
    logic [CHECK_V_WIDTH-1:0] V_out;
    
    assign H_out[4:0] = sym0 + sym2;
    assign H_out[9:5] = sym1 + sym3;

    assign V_out[3:0] = sym0 ^ sym1;
    assign V_out[7:4] = sym2 ^ sym3;
    assign check_bits = {V_out, H_out};

endmodule


    bind memory_wrapper_16bit_B1 memory_wrapper_fv #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .WORDS_BLOCK(WORDS_BLOCK)
    ) i_memory_wrapper_fv (
        .pi_clk(clk),
        .pi_cen(cen),
        .pi_wen(wen),
        .pi_addr(addr),
        .fv_sram_din0(u_sram.din0),
        .fv_ecc_enc_data(encoder_inst.D),
        .pi_d(d),
        .po_q(q),
        .po_err_corr(error_corrected)
    );


