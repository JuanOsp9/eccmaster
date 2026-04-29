module memory_wrapper_16bit_B2 #(
    parameter int ADDR_WIDTH 		= 7,
    parameter int DATA_WIDTH 		= 16,
    parameter int CHECK_H_WIDTH 	= 20,
	parameter int CHECK_V_WIDTH 	= 16,
    parameter int CODE_WIDTH	 	= 52,  // DATA*2 + CHECK_H + CHECK_V
	parameter int WORDS_BLOCK 		= 2
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
    localparam int ECC_BITS = CHECK_H_WIDTH + CHECK_V_WIDTH;
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
	
	logic [CHECK_H_WIDTH-1:0] codec_h_out;
    logic [CHECK_V_WIDTH-1:0] codec_v_out;

	logic[DATA_WIDTH*WORDS_BLOCK-1:0] out_bus;
	
	assign out_bus = wen ? d_ram : sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0];
	dmc_codec_32bit #(
    ) encoder_inst (
        .En     (wen),
        .D (out_bus),
		.H_read (sram_dout[(DATA_WIDTH*WORDS_BLOCK)+CHECK_H_WIDTH-1:DATA_WIDTH*WORDS_BLOCK]),
		.V_read (sram_dout[(DATA_WIDTH*WORDS_BLOCK)+CHECK_H_WIDTH+CHECK_V_WIDTH-1:DATA_WIDTH*WORDS_BLOCK+CHECK_H_WIDTH]),
		.H_out  (codec_h_out),
		.V_out  (codec_v_out)
		
    );
	
	

	
    //assign sram_din = {ecc_wr, 64'd0};
	assign sram_din = {codec_v_out, codec_h_out, d_ram};


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

	dmc_locator_corrector_32bit #(
    ) decoder_inst (
        .D_in       		(sram_dout[DATA_WIDTH*WORDS_BLOCK-1:0]),
        .delta_H           	(codec_h_out),
        .S 					(codec_v_out),
        .D_out   			(q_out),
		.error_corrected	(error_corrected)
    );


endmodule
