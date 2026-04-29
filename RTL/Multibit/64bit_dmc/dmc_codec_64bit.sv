// -------------------------------------------------------------------
// FILE 1: dmc_codec_64bit.sv
// -------------------------------------------------------------------
module dmc_codec_64bit (
    input  logic        En,       // 1 = Encode (Write), 0 = Decode/ERT (Read)
    input  logic [63:0] D,        // 64-bit Information data
    input  logic [23:0] H_read,   // 24-bit H redundant bits from SRAM
    input  logic [15:0] V_read,   // 16-bit V redundant bits from SRAM

    output logic [23:0] H_out,    // Generated H bits (Write) or delta_H (Read)
    output logic [15:0] V_out     // Generated V bits (Write) or S (Read)
);

    logic [3:0] s [0:15]; // Array of 16 symbols, each 4 bits wide
    logic [23:0] H_gen;
    logic [15:0] V_gen;

    // Divide 64-bit word into 16 symbols of 4 bits each
    genvar i;
    generate
        for (i = 0; i < 16; i++) begin : gen_symbols
            assign s[i] = D[(i*4)+3 : i*4];
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
    assign H_gen[5:0]   = s[0]  + s[1]  + s[2]  + s[3]; 
    assign H_gen[11:6]  = s[4]  + s[5]  + s[6]  + s[7]; 
    assign H_gen[17:12] = s[8]  + s[9]  + s[10] + s[11];
    assign H_gen[23:18] = s[12] + s[13] + s[14] + s[15];

    // Vertical Redundant Bits: Binary XOR
    assign V_gen[3:0]   = s[0] ^ s[4] ^ s[8]  ^ s[12];
    assign V_gen[7:4]   = s[1] ^ s[5] ^ s[9]  ^ s[13];
    assign V_gen[11:8]  = s[2] ^ s[6] ^ s[10] ^ s[14];
    assign V_gen[15:12] = s[3] ^ s[7] ^ s[11] ^ s[15];

    // Encoder-Reuse Technique (ERT) Multiplexer [cite: 174, 175]
    assign H_out[5:0]   = En ? H_gen[5:0]   : (H_read[5:0]   - H_gen[5:0]);
    assign H_out[11:6]  = En ? H_gen[11:6]  : (H_read[11:6]  - H_gen[11:6]);
    assign H_out[17:12] = En ? H_gen[17:12] : (H_read[17:12] - H_gen[17:12]);
    assign H_out[23:18] = En ? H_gen[23:18] : (H_read[23:18] - H_gen[23:18]);

    assign V_out = En ? V_gen : (V_read ^ V_gen);

endmodule