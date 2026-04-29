module dmc_codec_16bit (
    input  logic        En,       // Control signal: 1 = Encode (Write), 0 = Decode/ERT (Read)
    input  logic [15:0] D,        // 16-bit Information data (D15 down to D0)
    input  logic [9:0]  H_read,   // Redundant H bits read from SRAM (used in Decode mode)
    input  logic [7:0]  V_read,   // Redundant V bits read from SRAM (used in Decode mode)

    output logic [9:0]  H_out,    // Outputs H redundant bits (Write) or delta H Syndrome (Read)
    output logic [7:0]  V_out     // Outputs V redundant bits (Write) or S Syndrome (Read)
);

    // -------------------------------------------------------------------
    // 1. Divide-Symbol & Arrange-Matrix (Implemented Logically)
    // Dividing N=16 bits into k=4 symbols of m=4 bits.
    // Matrix arrangement (2x2) with interleaving to handle burst MCUs.
    // Row 0: sym0, sym2
    // Row 1: sym1, sym3
    // -------------------------------------------------------------------
    logic [3:0] sym0, sym1, sym2, sym3;
    
    assign sym0 = D[3:0];   // D3:D0
    assign sym1 = D[7:4];   // D7:D4
    assign sym2 = D[11:8];  // D11:D8
    assign sym3 = D[15:12]; // D15:D12

    // -------------------------------------------------------------------
    // 2. Core Encoder Operations
    // -------------------------------------------------------------------
    logic [9:0] H_gen;
    logic [7:0] V_gen;

    // Horizontal Redundant Bits (H): Decimal integer addition of symbols per row
    // Row 0: sym0 + sym2 -> Yields a 5-bit result
    // Row 1: sym1 + sym3 -> Yields a 5-bit result
    assign H_gen[4:0] = sym0 + sym2; 
    assign H_gen[9:5] = sym1 + sym3; 

    // Vertical Redundant Bits (V): Binary XOR of corresponding bits per column
    // Col 0: sym0 XOR sym1 -> Yields a 4-bit result
    // Col 1: sym2 XOR sym3 -> Yields a 4-bit result
    assign V_gen[3:0] = sym0 ^ sym1; 
    assign V_gen[7:4] = sym2 ^ sym3; 

    // -------------------------------------------------------------------
    // 3. Encoder-Reuse Technique (ERT) Multiplexing
    // -------------------------------------------------------------------
    // During Write (En=1): Output the newly generated check bits to store in SRAM.
    // During Read  (En=0): Output the Syndrome bits to feed the Error Locator.
    //   - H Syndrome requires decimal integer subtraction.
    //   - V Syndrome requires binary XOR.
    // -------------------------------------------------------------------
    assign H_out[4:0] = En ? H_gen[4:0] : (H_read[4:0] - H_gen[4:0]);
    assign H_out[9:5] = En ? H_gen[9:5] : (H_read[9:5] - H_gen[9:5]);

    assign V_out[3:0] = En ? V_gen[3:0] : (V_read[3:0] ^ V_gen[3:0]);
    assign V_out[7:4] = En ? V_gen[7:4] : (V_read[7:4] ^ V_gen[7:4]);

endmodule