module dmc_sram_wrapper (
    // System Interface
    input  logic        we,          // Write Enable (1 = Write, 0 = Read)
    input  logic [15:0] data_in,     // 16-bit Information data from system
    output logic [15:0] data_out,    // 16-bit Corrected data to system

    // Physical SRAM Macro Interface
    output logic [15:0] sram_d_write, // Data to write to SRAM
    output logic [9:0]  sram_h_write, // H redundant bits to write to SRAM
    output logic [7:0]  sram_v_write, // V redundant bits to write to SRAM
    
    input  logic [15:0] sram_d_read,  // Data read from SRAM
    input  logic [9:0]  sram_h_read,  // H redundant bits read from SRAM
    input  logic [7:0]  sram_v_read   // V redundant bits read from SRAM
);

    // -------------------------------------------------------------------
    // Internal Interconnect Signals
    // -------------------------------------------------------------------
    logic [9:0] codec_h_out;
    logic [7:0] codec_v_out;
    logic [15:0] active_data_in;

    // Multiplex the input data to the codec based on the operation:
    // Write: Feed system data to generate redundancy bits.
    // Read:  Feed SRAM read data to generate syndrome bits.
    assign active_data_in = we ? data_in : sram_d_read;

    // -------------------------------------------------------------------
    // 1. DMC Codec (Encoder / Syndrome Calculator)
    // -------------------------------------------------------------------
    // Reuses the encoder hardware to calculate the syndrome during read[cite: 176].
    dmc_codec_16bit u_dmc_codec (
        .En     (we),              // we=1 configures as Encoder, we=0 as Syndrome Calc [cite: 179]
        .D      (active_data_in),  
        .H_read (sram_h_read),     
        .V_read (sram_v_read),     
        .H_out  (codec_h_out),     
        .V_out  (codec_v_out)      
    );

    // -------------------------------------------------------------------
    // SRAM Write Assignments
    // -------------------------------------------------------------------
    // Directly pass the system data and generated redundancy bits to the SRAM write ports.
    assign sram_d_write = data_in;
    assign sram_h_write = codec_h_out;
    assign sram_v_write = codec_v_out;

    // -------------------------------------------------------------------
    // 2. Error Locator and Corrector
    // -------------------------------------------------------------------
    // Processes the syndrome vectors to flip erroneous bits during a read cycle.
    dmc_locator_corrector u_dmc_corrector (
        .D_in     (sram_d_read),
        .delta_H0 (codec_h_out[4:0]),   // Lower 5 bits of H syndrome
        .delta_H1 (codec_h_out[9:5]),   // Upper 5 bits of H syndrome
        .S0       (codec_v_out[3:0]),   // Lower 4 bits of V syndrome
        .S1       (codec_v_out[7:4]),   // Upper 4 bits of V syndrome
        .D_out    (data_out)            // Final corrected output to system
    );

endmodule