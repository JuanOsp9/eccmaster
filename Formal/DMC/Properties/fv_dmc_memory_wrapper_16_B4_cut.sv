module memory_wrapper_fv #(
    parameter int ADDR_WIDTH 		= 7,
    parameter int DATA_WIDTH 		= 16,
    parameter int CHECK_H_WIDTH 	= 24,
	parameter int CHECK_V_WIDTH 	= 16,
    parameter int CODE_WIDTH	 	= 104,  // DATA*4 + CHECK_H + CHECK_V
	parameter int WORDS_BLOCK 		= 4
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
        ##1 ( !pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16_B4.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
		|->
		po_q == fv_data_in
        //&& po_err_corr
	;endproperty

    a_word_single_error_pack: assert property(p_word_packing_error);

    property eq_encoder;
    fv_ecc_enc_data == fv_data_in_pack
    && !pi_wen
    |->
    {fv_ecc_enc_data, memory_wrapper_16_B4.encoder_inst.V_out, memory_wrapper_16_B4.encoder_inst.H_out} == {fv_data_in_pack,check_bits}
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
        ##1 ( !pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16_B4.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
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
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16_B4.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
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
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16_B4.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
        |->
        po_q == fv_data_in
    endproperty

    a_word_quad_error_pack: assert property(p_word_packing_error_four);

// 1. Declare the mask
    logic [CODE_WIDTH-1:0] fv_two_bit_mask_free;

    // 2. Define the target range (Next 24 bits down from the top 16)
    // WIDTH is 24 bits
    // RANGE_L starts after the bottom (Data) and ends before the top (V_parity)
    localparam int WIDTH_H  = 24;
    localparam int WIDTH_V  = 16; 
    
    // RANGE_L = CODE_WIDTH - 16 (V bits) - 24 (H bits) = CODE_WIDTH - 40
    localparam int RANGE_L_H = CODE_WIDTH - (WIDTH_V + WIDTH_H); 
    localparam int RANGE_H_H = CODE_WIDTH - WIDTH_V - 1;

    // 3. Create the constant gate mask for the 24-bit window
    // This creates a 24-bit wide block of 1s at the correct offset
    localparam [CODE_WIDTH-1:0] MASK_GATE_H = (( {CODE_WIDTH{1'b1}} >> (CODE_WIDTH - WIDTH_H) ) << RANGE_L_H);

    // 4. Constraints
    // Exactly 2 bits are high
    assume_count_is_two_h: assume property (@(posedge pi_clk) 
        $countones(fv_two_bit_mask_free) == 2
    );

    // Force errors to land only in the 24-bit Horizontal window
    assume_inside_next_24_only: assume property (@(posedge pi_clk)
        (fv_two_bit_mask_free & ~MASK_GATE_H) == '0
    );

    // 4. Property
    property p_word_packing_error_two_free_v;
        logic [DATA_WIDTH-1:0] fv_data_in;
        
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits, fv_data_in_pack} ^ fv_two_bit_mask_free) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1 : DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16_B4.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
        |->
        po_q == fv_data_in
    endproperty

    a_word_double_error_pack_free_v: assert property(p_word_packing_error_two_free_v);


// 1. Declare the mask
    logic [CODE_WIDTH-1:0] fv_two_bit_mask_free_h;

    // 2. Define the target range (Last 16 bits)
    // For CODE_WIDTH = 104: RANGE_L = 88, RANGE_H = 103
    localparam int RANGE_L = CODE_WIDTH - 16; 
    localparam int RANGE_H = CODE_WIDTH - 1;  
    localparam int WIDTH   = 16; // Explicit width to avoid math errors

    // 3. Create a constant gate mask
    // We create a string of 16 ones and shift them to the top
    localparam [CODE_WIDTH-1:0] MASK_GATE = (( {CODE_WIDTH{1'b1}} >> (CODE_WIDTH - WIDTH) ) << RANGE_L);

    // 4. Constraints
    assume_count_is_two_a: assume property (@(posedge pi_clk) 
        $countones(fv_two_bit_mask_free_h) == 2
    );

    // This forces the errors into the last 16 bits
    // If fv_two_bit_mask_last16 has bits outside MASK_GATE, this fails
    assume_inside_last_16_only_a: assume property (@(posedge pi_clk)
        (fv_two_bit_mask_free_h & ~MASK_GATE) == '0
    );

    // 4. Property
    property p_word_packing_error_two_free_h;
        logic [DATA_WIDTH-1:0] fv_data_in;
        
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits, fv_data_in_pack} ^ fv_two_bit_mask_free_h) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1 : DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16_B4.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
        |->
        po_q == fv_data_in
    endproperty

    a_word_double_error_pack_free_h: assert property(p_word_packing_error_two_free_h);


// --- VERTICAL RANGE (TOP 16) PARAMETERS ---
    localparam int V_WIDTH = 16;
    localparam int V_START = CODE_WIDTH - V_WIDTH;
    localparam [CODE_WIDTH-1:0] V_MASK_GATE = (( {CODE_WIDTH{1'b1}} >> (CODE_WIDTH - V_WIDTH) ) << V_START);

    // --- TRIPLE ERROR VERTICAL ---
    logic [CODE_WIDTH-1:0] fv_3bit_mask_v;
    assume_3bit_v: assume property (@(posedge pi_clk) 
        $countones(fv_3bit_mask_v) == 3 && (fv_3bit_mask_v & ~V_MASK_GATE) == '0
    );

    property p_error_3bit_v;
        logic [DATA_WIDTH-1:0] fv_data_in;
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits, fv_data_in_pack} ^ fv_3bit_mask_v) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1 : DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16_B4.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
        |-> po_q == fv_data_in;
    endproperty
    a_error_3bit_v: assert property(p_error_3bit_v);

    // --- QUAD ERROR VERTICAL ---
    logic [CODE_WIDTH-1:0] fv_4bit_mask_v;
    assume_4bit_v: assume property (@(posedge pi_clk) 
        $countones(fv_4bit_mask_v) == 4 && (fv_4bit_mask_v & ~V_MASK_GATE) == '0
    );

    property p_error_4bit_v;
        logic [DATA_WIDTH-1:0] fv_data_in;
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits, fv_data_in_pack} ^ fv_4bit_mask_v) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1 : DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16_B4.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
        |-> po_q == fv_data_in;
    endproperty
    a_error_4bit_v: assert property(p_error_4bit_v);

    // --- HORIZONTAL RANGE (NEXT 24) PARAMETERS ---
    localparam int H_WIDTH = 24;
    localparam int H_START = CODE_WIDTH - V_WIDTH - H_WIDTH; // CODE_WIDTH - 40
    localparam [CODE_WIDTH-1:0] H_MASK_GATE = (( {CODE_WIDTH{1'b1}} >> (CODE_WIDTH - H_WIDTH) ) << H_START);

    // --- TRIPLE ERROR HORIZONTAL ---
    logic [CODE_WIDTH-1:0] fv_3bit_mask_h;
    assume_3bit_h: assume property (@(posedge pi_clk) 
        $countones(fv_3bit_mask_h) == 3 && (fv_3bit_mask_h & ~H_MASK_GATE) == '0
    );

    property p_error_3bit_h;
        logic [DATA_WIDTH-1:0] fv_data_in;
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits, fv_data_in_pack} ^ fv_3bit_mask_h) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1 : DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16_B4.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
        |-> po_q == fv_data_in;
    endproperty
    a_error_3bit_h: assert property(p_error_3bit_h);

    // --- QUAD ERROR HORIZONTAL ---
    logic [CODE_WIDTH-1:0] fv_4bit_mask_h;
    assume_4bit_h: assume property (@(posedge pi_clk) 
        $countones(fv_4bit_mask_h) == 4 && (fv_4bit_mask_h & ~H_MASK_GATE) == '0
    );

    property p_error_4bit_h;
        logic [DATA_WIDTH-1:0] fv_data_in;
        ##0 (!pi_cen && !pi_wen && fv_sram_din0 == ({check_bits, fv_data_in_pack} ^ fv_4bit_mask_h) && pi_addr == fv_addr_base + WORDS_BLOCK-1 )
        ##0 (!pi_cen && !pi_wen, fv_data_in = fv_data_in_pack[DATA_WIDTH*WORDS_BLOCK-1 : DATA_WIDTH*(WORDS_BLOCK-1)])
        ##0 fv_ecc_enc_data == fv_data_in_pack
        ##1 (!pi_cen && pi_wen && pi_addr == fv_addr_base + WORDS_BLOCK - 1 && fv_ecc_enc_data == memory_wrapper_16_B4.sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0])[*2]
        |-> po_q == fv_data_in;
    endproperty
    a_error_4bit_h: assert property(p_error_4bit_h);

    //Auxiliary logic// Enconder

// Direct Parallel Parity Logic derived from your P_Matrix
logic [CHECK_H_WIDTH+CHECK_V_WIDTH-1:0] check_bits;

    // -------------------------------------------------------------------
    // 2. Core Encoder Operations
    // -------------------------------------------------------------------
    logic [CHECK_H_WIDTH-1:0] H_out;
    logic [CHECK_V_WIDTH-1:0] V_out;
    
    logic [3:0] s [0:15]; // Array of 16 symbols, each 4 bits wide

    // Divide 64-bit word into 16 symbols of 4 bits each
    genvar i;
    generate
        for (i = 0; i < 16; i++) begin : gen_symbols
            assign s[i] = fv_data_in_pack[(i*4)+3 : i*4];
        end
    endgenerate 

    // -------------------------------------------------------------------
    // Matrix Organization: k = 4x4 (16 symbols)
    // Row 0: s0,  s1,  s2,  s3
    // Row 1: s4,  s5,  s6,  s7
    // Row 2: s8,  s9,  s10, s11
    // Row 3: s12, s13, s14, s15
    // -------------------------------------------------------------------

    // Horizontal Redundant Bits: Decimal integer addition
    // The maximum sum of four 4-bit values (15+15+15+15 = 60) requires 6 bits.
    assign H_out[5:0]   = s[0]  + s[1]  + s[2]  + s[3]; 
    assign H_out[11:6]  = s[4]  + s[5]  + s[6]  + s[7]; 
    assign H_out[17:12] = s[8]  + s[9]  + s[10] + s[11];
    assign H_out[23:18] = s[12] + s[13] + s[14] + s[15];

    // Vertical Redundant Bits: Binary XOR
    assign V_out[3:0]   = s[0] ^ s[4] ^ s[8]  ^ s[12];
    assign V_out[7:4]   = s[1] ^ s[5] ^ s[9]  ^ s[13];
    assign V_out[11:8]  = s[2] ^ s[6] ^ s[10] ^ s[14];
    assign V_out[15:12] = s[3] ^ s[7] ^ s[11] ^ s[15];

    assign check_bits = {V_out, H_out};

endmodule


    bind memory_wrapper_16_B4 memory_wrapper_fv #(
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


