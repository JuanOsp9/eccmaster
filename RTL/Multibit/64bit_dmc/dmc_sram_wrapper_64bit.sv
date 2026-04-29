// -------------------------------------------------------------------
// FILE 3: dmc_sram_wrapper_64bit.sv
// -------------------------------------------------------------------
module dmc_sram_wrapper_64bit (
    input  logic        we,          
    input  logic [63:0] data_in,     
    output logic [63:0] data_out,    

    output logic [63:0] sram_d_write, 
    output logic [23:0] sram_h_write, 
    output logic [15:0] sram_v_write, 
    
    input  logic [63:0] sram_d_read,  
    input  logic [23:0] sram_h_read,  
    input  logic [15:0] sram_v_read   
);

    logic [23:0] codec_h_out;
    logic [15:0] codec_v_out;
    logic [63:0] active_data_in;

    assign active_data_in = we ? data_in : sram_d_read;

    dmc_codec_64bit u_dmc_codec (
        .En     (we),              
        .D      (active_data_in),  
        .H_read (sram_h_read),     
        .V_read (sram_v_read),     
        .H_out  (codec_h_out),     
        .V_out  (codec_v_out)      
    );

    assign sram_d_write = data_in;
    assign sram_h_write = codec_h_out;
    assign sram_v_write = codec_v_out;

    dmc_locator_corrector_64bit u_dmc_corrector (
        .D_in    (sram_d_read),
        .delta_H (codec_h_out),   
        .S       (codec_v_out),   
        .D_out   (data_out)       
    );

endmodule