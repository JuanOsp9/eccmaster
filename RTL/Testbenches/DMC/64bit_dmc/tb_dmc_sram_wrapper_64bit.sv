`timescale 1ns/1ps

module tb_dmc_sram_wrapper_64bit;

    // -------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------
    logic        we;
    logic [63:0] data_in;
    logic [63:0] data_out;

    logic [63:0] sram_d_write, sram_d_read;
    logic [23:0] sram_h_write, sram_h_read;
    logic [15:0] sram_v_write, sram_v_read;

    // -------------------------------------------------------------------
    // Mock SRAM Storage Registers
    // -------------------------------------------------------------------
    logic [63:0] mem_data;
    logic [23:0] mem_h;
    logic [15:0] mem_v;

    // -------------------------------------------------------------------
    // Device Under Test (DUT)
    // -------------------------------------------------------------------
    dmc_sram_wrapper_64bit dut (
        .we           (we),
        .data_in      (data_in),
        .data_out     (data_out),
        .sram_d_write (sram_d_write),
        .sram_h_write (sram_h_write),
        .sram_v_write (sram_v_write),
        .sram_d_read  (sram_d_read),
        .sram_h_read  (sram_h_read),
        .sram_v_read  (sram_v_read)
    );

    // -------------------------------------------------------------------
    // Tasks for Bus Operations
    // -------------------------------------------------------------------
    task write_sram(input logic [63:0] wdata);
        begin
            we = 1;
            data_in = wdata;
            #10;
            
            mem_data = sram_d_write;
            mem_h    = sram_h_write;
            mem_v    = sram_v_write;
            $display("\n=== WRITE OPERATION ===");
            $display("Data=64'h%016h | Gen_H=24'h%06h | Gen_V=16'h%04h", mem_data, mem_h, mem_v);
            #10;
        end
    endtask

    task read_and_inject_error(
        input logic [63:0] d_mask, 
        input logic [23:0] h_mask, 
        input logic [15:0] v_mask, 
        input string test_name,
        input bit expect_pass
    );
        begin
            we = 0;
            
            // Inject errors into Data, H, and V buses
            sram_d_read = mem_data ^ d_mask; 
            sram_h_read = mem_h    ^ h_mask;
            sram_v_read = mem_v    ^ v_mask;
            
            #10; 
            
            $display("TEST: %s", test_name);
            $display("  Inj D_Mask: 64'h%016h", d_mask);
            
            if ((data_out === mem_data) == expect_pass) begin
                $display("  RESULT: PASS (Behavior matched expectation)");
            end else begin
                $error("  RESULT: FAIL - Expected Pass=%0b, Data_Out=64'h%016h (Original=64'h%016h)", expect_pass, data_out, mem_data);
            end
            #10;
        end
    endtask

    // -------------------------------------------------------------------
    // Test Vectors
    // -------------------------------------------------------------------
    initial begin
        $display("\nStarting 64-Bit DMC SRAM Verification...\n");
        we = 0; data_in = 0; sram_d_read = 0; sram_h_read = 0; sram_v_read = 0;
        #20;

        // ===================================================================
        // SCENARIO 1: Base Pattern Testing & Multi-Bit Burst Constraints
        // ===================================================================
        write_sram(64'hA5A5_5A5A_1234_5678);
        
        // Target Symbol 0 (D[3:0])
        read_and_inject_error(64'h0000_0000_0000_0001, 24'h0, 16'h0, "Sym 0: Single-Bit Error (Bit 0)", 1);
        read_and_inject_error(64'h0000_0000_0000_000F, 24'h0, 16'h0, "Sym 0: 4-Bit Error (Entire Symbol Corrupted)", 1);

        // Target Symbol 15 (D[63:60])
        read_and_inject_error(64'hC000_0000_0000_0000, 24'h0, 16'h0, "Sym 15: Double-Bit Error (Bits 63,62)", 1);
        read_and_inject_error(64'hF000_0000_0000_0000, 24'h0, 16'h0, "Sym 15: 4-Bit Error (Entire Symbol Corrupted)", 1);

        // ===================================================================
        // SCENARIO 2: Boundary/Extreme Data Patterns
        // ===================================================================
        write_sram(64'hFFFF_FFFF_FFFF_FFFF);
        read_and_inject_error(64'h0000_0000_0000_0F00, 24'h0, 16'h0, "All 1s Data -> Sym 2 (D[11:8]): 4-Bit Error", 1);
        
        write_sram(64'h0000_0000_0000_0000);
        read_and_inject_error(64'h00F0_0000_0000_0000, 24'h0, 16'h0, "All 0s Data -> Sym 13 (D[55:52]): 4-Bit Error", 1);

        // ===================================================================
        // SCENARIO 3: Redundant Memory Cell Strikes (False Positives)
        // ===================================================================
        write_sram(64'hCAFE_BABE_DEAD_BEEF);
        // Hit H parity bits (Row 3, H[23:18])
        read_and_inject_error(64'h0, 24'h3F_0000, 16'h0000, "ECC Strike: 6-Bit Error in H_read[23:18]", 1);
        // Hit V parity bits (Col 1, V[7:4])
        read_and_inject_error(64'h0, 24'h00_0000, 16'h00F0, "ECC Strike: 4-Bit Error in V_read[7:4]", 1);

        // ===================================================================
        // SCENARIO 4: Uncorrectable Error Boundaries (Negative Testing)
        // ===================================================================
        write_sram(64'h1111_2222_3333_4444);
        
        // Error crossing Symbol 0 and Symbol 1 boundary
        read_and_inject_error(64'h0000_0000_0000_0018, 24'h0, 16'h0, "UNCORRECTABLE: Error crossing Sym 0/1 boundary", 0);

        // Errors in Symbol 0 (D[3:0]) and Symbol 4 (D[19:16]) simultaneously (Vertical XOR cancellation)
        // Both are in Column 0, so their XOR syndromes cancel out.
        read_and_inject_error(64'h0000_0000_0001_0001, 24'h0, 16'h0, "UNCORRECTABLE: Vertical XOR Cancellation (Sym 0 & Sym 4)", 0);

        $display("\nVerification Complete.\n");
        $finish;
    end

endmodule