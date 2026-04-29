module memory_wrapper #(
    parameter int ADDR_WIDTH 	= 7,
    parameter int DATA_WIDTH 	= 16,
    parameter int CHECK_WIDTH 	= 14,
    parameter int CODE_WIDTH 	= 78,  // DATA*4 + CHECK
	parameter int WORDS_BLOCK 	= 4
) (
    input  logic                    clk,
    input  logic                    cen,  // chip select (active low)
    input  logic                    wen,  // write enable (1 = write)
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [DATA_WIDTH-1:0]   d,
    output logic [DATA_WIDTH-1:0]   q,
    output logic                    error_corrected
);

    // ---------------------------------------------------
    // ------------  Calculate ECC width   ---------------
    // ---------------------------------------------------
    localparam int ECC_BITS = CHECK_WIDTH;
    localparam int TOTAL_WIDTH = CODE_WIDTH;

    // ------------------------
    // Encode ECC for write
    // ------------------------
    logic [ECC_BITS-1:0] ecc_wr;
    logic [TOTAL_WIDTH-1:0] sram_din;
    logic [TOTAL_WIDTH-1:0] sram_dout;
	

	
	logic[DATA_WIDTH*WORDS_BLOCK-1:0] d_ram;
	
	generate
        if (WORDS_BLOCK == 2) begin : W_B_2
			logic[DATA_WIDTH-1:0] d_split;
            always_ff @(posedge clk) begin
				if (!wen && !cen) begin
					if(addr[0] == 1'b0) begin
						d_split <= d;
					end
				end
			end
		assign d_ram = {d, d_split};
        end else if (WORDS_BLOCK == 4) begin : W_B_4
			logic[DATA_WIDTH-1:0] d_split_3;
            logic[DATA_WIDTH-1:0] d_split_2;
			logic[DATA_WIDTH-1:0] d_split_1;
            always_ff @(posedge clk) begin
				if (!wen && !cen) begin
					if(addr[1:0] == 2'b00) begin
						d_split_1 <= d;
					end
					else if(addr[1:0] == 2'b01) begin
						d_split_2 <= d;
					end
					else if(addr[1:0] == 2'b10) begin
						d_split_3 <= d;
					end
				end
			end
		assign d_ram = {d, d_split_3,d_split_2,d_split_1};
        end
		else assign d_ram = d;
    endgenerate
	
	
	logic [CODE_WIDTH-1:0] encoded_codeword;

	bch_dec_encoder #(
        .DATA_WIDTH (DATA_WIDTH*WORDS_BLOCK), //32*2
        .CHECK_WIDTH(CHECK_WIDTH),
        .CODE_WIDTH (CODE_WIDTH)
    ) encoder_inst (
        .data_i     (d_ram),
        .codeword_o (encoded_codeword)
    );
	
    //assign sram_din = {ecc_wr, 64'd0};
	assign sram_din = encoded_codeword;


	// ---------------------------------------------------
    // ------     SRAM Instance    ----
    // ---------------------------------------------------
    SRAM_32x128_1rw #(
        .DATA_WIDTH(CODE_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH - (WORDS_BLOCK/2))
    ) u_sram (
        .clk0(clk),
        .csb0(cen),
        .web0(wen),       // web0 is active LOW, wen is active HIGH
        .addr0(addr[ADDR_WIDTH-1:WORDS_BLOCK/2]),
        .din0(sram_din),
        .dout0(sram_dout)
    );


	// ---------------------------------------------------
    // ------     ECC Decode after read     ----
    // ---------------------------------------------------'
	logic[DATA_WIDTH*WORDS_BLOCK-1:0] q_out;
	
	generate
        if (WORDS_BLOCK == 2) begin : WB_2
        always_comb
			begin
				if(addr[0]==1'b0) q = q_out[DATA_WIDTH-1:0];
				else q = q_out[(DATA_WIDTH*WORDS_BLOCK)-1:DATA_WIDTH];
			end
        end else if (WORDS_BLOCK == 4) begin : WB_4
		always_comb
			begin
				if(addr[1:0] == 2'b00) q = q_out[DATA_WIDTH-1:0];
				else if(addr[1:0] == 2'b01) q = q_out[(DATA_WIDTH*2)-1:DATA_WIDTH];
				else if(addr[1:0] == 2'b10) q = q_out[(DATA_WIDTH*3)-1:DATA_WIDTH*2];
				else if(addr[1:0] == 2'b11) q = q_out[(DATA_WIDTH*4)-1:DATA_WIDTH*3];
			end
        end
		else assign q = q_out;
    endgenerate
	
	
	bch_dec_decoder #(
        .DATA_WIDTH (DATA_WIDTH*WORDS_BLOCK),
        .CHECK_WIDTH(CHECK_WIDTH),
        .CODE_WIDTH (CODE_WIDTH)
    ) decoder_inst (
        .codeword_i       (sram_dout),
        .data_o           (q_out),
        .error_detected_o (error_corrected),
        .double_error_o   ()
    );


endmodule
