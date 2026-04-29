// -------------------------------------------------------------------
// FILE 1: dmc_codec_32bit.sv
// -------------------------------------------------------------------
module dmc_codec_32bit (
    input  logic        En,       // 1 = Encode (Write), 0 = Decode/ERT (Read)
    input  logic [31:0] D,        // 32-bit Information data
    input  logic [19:0] H_read,   // 20-bit H redundant bits from SRAM
    input  logic [15:0] V_read,   // 16-bit V redundant bits from SRAM

    output logic [19:0] H_out,    // Generated H bits (Write) or delta_H (Read)
    output logic [15:0] V_out     // Generated V bits (Write) or S (Read)
);

    logic [3:0] s0, s1, s2, s3, s4, s5, s6, s7;
    logic [19:0] H_gen;
    logic [15:0] V_gen;

    // Divide 32-bit word into 8 symbols of 4 bits each
    assign s0 = D[3:0];   assign s1 = D[7:4];
    assign s2 = D[11:8];  assign s3 = D[15:12];
    assign s4 = D[19:16]; assign s5 = D[23:20];
    assign s6 = D[27:24]; assign s7 = D[31:28];

    // Horizontal Redundant Bits: Decimal integer addition
    assign H_gen[4:0]   = s0 + s2; 
    assign H_gen[9:5]   = s1 + s3; 
    assign H_gen[14:10] = s4 + s6;
    assign H_gen[19:15] = s5 + s7;

    // Vertical Redundant Bits: Binary XOR
    assign V_gen[3:0]   = s0 ^ s4;
    assign V_gen[7:4]   = s1 ^ s5;
    assign V_gen[11:8]  = s2 ^ s6;
    assign V_gen[15:12] = s3 ^ s7;

    // Encoder-Reuse Technique (ERT) Multiplexer
    assign H_out[4:0]   = En ? H_gen[4:0]   : (H_read[4:0]   - H_gen[4:0]);
    assign H_out[9:5]   = En ? H_gen[9:5]   : (H_read[9:5]   - H_gen[9:5]);
    assign H_out[14:10] = En ? H_gen[14:10] : (H_read[14:10] - H_gen[14:10]);
    assign H_out[19:15] = En ? H_gen[19:15] : (H_read[19:15] - H_gen[19:15]);

    assign V_out = En ? V_gen : (V_read ^ V_gen);

endmodule