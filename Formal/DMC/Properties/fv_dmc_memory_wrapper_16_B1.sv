module memory_wrapper_fv #(
    parameter int ADDR_WIDTH 		= 7,
    parameter int DATA_WIDTH 		= 16,
    parameter int CHECK_H_WIDTH 	= 10,
	parameter int CHECK_V_WIDTH 	= 8,
    parameter int CODE_WIDTH	 	= 34,  // DATA + CHECK_H + CHECK_V
	parameter int WORDS_BLOCK 		= 1
) (
    // 1. Primary Interface
    input  logic                    pi_clk,
    input  logic                    pi_cen,  
    input  logic                    pi_wen,  
    input  logic [ADDR_WIDTH-1:0]   pi_addr,
    input  logic [DATA_WIDTH-1:0]   pi_d,
    input  logic [DATA_WIDTH-1:0]   po_q,

    //input  logic [(DATA_WIDTH*WORDS_BLOCK + calc_ecc_bits(DATA_WIDTH*WORDS_BLOCK))-1:0] fv_sram_din0,
    //input  logic [(DATA_WIDTH*WORDS_BLOCK)-1:0] fv_ecc_enc_data,

    input  logic                    po_err_corr             
);

	default clocking cb @(posedge pi_clk); endclocking

	
	logic [ADDR_WIDTH-1:0] fv_addr_base;
	
	// Use the default clocking block for the assumption
    // This tells OneSpin that fv_addr_base is a synchronous signal
    assume property (
        @(posedge pi_clk) !pi_cen |-> (fv_addr_base[1:0] == 2'b00) ##0 $stable(fv_addr_base)//[*4]
    );
	
	property p_word_0_packing;
		logic [DATA_WIDTH-1:0] fv_data_in;
        ( !pi_cen && !pi_wen && pi_addr == fv_addr_base)
        ##0 (!pi_cen && !pi_wen, fv_data_in = pi_d)
        ##1 ( !pi_cen && !pi_wen && pi_addr == fv_addr_base + 1)
        ##1 ( !pi_cen && !pi_wen && pi_addr == fv_addr_base + 2)
        ##1 ( !pi_cen && !pi_wen && pi_addr == fv_addr_base + 3 )
        ##1 ( !pi_cen && pi_wen && pi_addr == fv_addr_base )[*2]
		|->
		po_q == fv_data_in
        && !po_err_corr
	;endproperty

    a_word_0_pack: assert property(p_word_0_packing);

	property p_word_1_packing;
		logic [DATA_WIDTH-1:0] fv_data_in;
        ( !pi_cen && !pi_wen && pi_addr == fv_addr_base)
        ##1 ( !pi_cen && !pi_wen && pi_addr == fv_addr_base + 1)
        ##0 (!pi_cen && !pi_wen, fv_data_in = pi_d)
        ##1 ( !pi_cen && !pi_wen && pi_addr == fv_addr_base + 2)
        ##1 ( !pi_cen && !pi_wen && pi_addr == fv_addr_base + 3 )
        ##1 ( !pi_cen && pi_wen && pi_addr == fv_addr_base + 1 )[*2]
		|->
		po_q == fv_data_in
        && !po_err_corr
	;endproperty

    a_word_1_pack: assert property(p_word_1_packing);

    property p_word_2_packing;
		logic [DATA_WIDTH-1:0] fv_data_in;
        ( !pi_cen && !pi_wen && pi_addr == fv_addr_base)
        ##1 ( !pi_cen && !pi_wen && pi_addr == fv_addr_base + 1)
        ##1 ( !pi_cen && !pi_wen && pi_addr == fv_addr_base + 2)
        ##0 (!pi_cen && !pi_wen, fv_data_in = pi_d)
        ##1 ( !pi_cen && !pi_wen && pi_addr == fv_addr_base + 3)
        ##1 ( !pi_cen && pi_wen && pi_addr == fv_addr_base + 2 )[*2]
		|->
		po_q == fv_data_in
        && !po_err_corr
	;endproperty

    a_word_2_pack: assert property(p_word_2_packing);

    property p_word_3_packing;
		logic [DATA_WIDTH-1:0] fv_data_in;
        ( !pi_cen && !pi_wen && pi_addr == fv_addr_base)
        ##1 ( !pi_cen && !pi_wen && pi_addr == fv_addr_base + 1)
        ##1 ( !pi_cen && !pi_wen && pi_addr == fv_addr_base + 2)
        ##1 ( !pi_cen && !pi_wen && pi_addr == fv_addr_base + 3)
        ##0 (!pi_cen && !pi_wen, fv_data_in = pi_d)
        ##1 ( !pi_cen && pi_wen && pi_addr == fv_addr_base + 3 )[*2]
		|->
		po_q == fv_data_in
        && !po_err_corr
	;endproperty

    a_word_3_pack: assert property(p_word_3_packing);


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
        .pi_d(d),
        .po_q(q),
        .po_err_corr(error_corrected)
    );
