`timescale 1ns/1ps

module tb_dmc_sram_wrapper_advanced;

    // -------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------
    logic        we;
    logic [15:0] data_in;
    logic [15:0] data_out;

    logic [15:0] sram_d_write, sram_d_read;
    logic [9:0]  sram_h_write, sram_h_read;
    logic [7:0]  sram_v_write, sram_v_read;

    // -------------------------------------------------------------------
    // Mock SRAM Storage Registers
    // -------------------------------------------------------------------
    logic [15:0] mem_data;
    logic [9:0]  mem_h;
    logic [7:0]  mem_v;

    // -------------------------------------------------------------------
    // Device Under Test (DUT)
    // -------------------------------------------------------------------
    dmc_sram_wrapper dut (
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
    task write_sram(input logic [15:0] wdata);
        begin
            we = 1;
            data_in = wdata;
            #10;
            
            mem_data = sram_d_write;
            mem_h    = sram_h_write;
            mem_v    = sram_v_write;
            $display("\n=== WRITE OPERATION ===");
            $display("Data=16'h%0h | Gen_H=10'h%0h | Gen_V=8'h%0h", mem_data, mem_h, mem_v);
            #10;
        end
    endtask

    task read_and_inject_error(
        input logic [15:0] d_mask, 
        input logic [9:0]  h_mask, 
        input logic [7:0]  v_mask, 
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
            $display("  Inj D_Mask: 16'b%016b | Inj H_Mask: 10'b%010b | Inj V_Mask: 8'b%08b", d_mask, h_mask, v_mask);
            
            if ((data_out === mem_data) == expect_pass) begin
                $display("  RESULT: PASS (Behavior matched expectation)");
            end else begin
                $error("  RESULT: FAIL - Expected Pass=%0b, Data_Out=16'h%0h (Original=16'h%0h)", expect_pass, data_out, mem_data);
            end
            #10;
        end
    endtask

    // -------------------------------------------------------------------
    // Test Vectors
    // -------------------------------------------------------------------
    initial begin
        $display("\nStarting Advanced DMC SRAM Verification...\n");
        we = 0; data_in = 0; sram_d_read = 0; sram_h_read = 0; sram_v_read = 0;
        #20;

        // ===================================================================
        // SCENARIO 1: Base Pattern Testing (Alternating Bits)
        // ===================================================================
        write_sram(16'hA5A5);
        
        // Target Symbol 1 (D[7:4])
        read_and_inject_error(16'b0000_0000_0001_0000, 10'h0, 8'h0, "Sym 1: Single-Bit Error (Bit 4)", 1);
        read_and_inject_error(16'b0000_0000_1010_0000, 10'h0, 8'h0, "Sym 1: Double-Bit Error (Bits 7,5)", 1);
        read_and_inject_error(16'b0000_0000_1111_0000, 10'h0, 8'h0, "Sym 1: 4-Bit Error (Entire Symbol Corrupted)", 1);

        // Target Symbol 3 (D[15:12])
        read_and_inject_error(16'b0110_0000_0000_0000, 10'h0, 8'h0, "Sym 3: Double-Bit Error (Bits 14,13)", 1);
        read_and_inject_error(16'b1111_0000_0000_0000, 10'h0, 8'h0, "Sym 3: 4-Bit Error (Entire Symbol Corrupted)", 1);

        // ===================================================================
        // SCENARIO 2: Boundary/Extreme Data Patterns (All 1s, All 0s)
        // ===================================================================
        write_sram(16'hFFFF);
        read_and_inject_error(16'b0000_0000_0000_1111, 10'h0, 8'h0, "All 1s Data -> Sym 0: 4-Bit Error", 1);
        
        write_sram(16'h0000);
        read_and_inject_error(16'b0000_1111_0000_0000, 10'h0, 8'h0, "All 0s Data -> Sym 2: 4-Bit Error", 1);

        // ===================================================================
        // SCENARIO 3: Redundant Memory Cell Strikes (False Positive Testing)
        // Ensures that if the ECC memory itself is hit, the valid data is not corrupted.
        // ===================================================================
        write_sram(16'h1234);
        // Hit only H parity bits
        read_and_inject_error(16'h0000, 10'b00_0001_1111, 8'h00, "ECC Strike: 5-Bit Error in H_read", 1);
        // Hit only V parity bits
        read_and_inject_error(16'h0000, 10'h000, 8'b0000_1111, "ECC Strike: 4-Bit Error in V_read", 1);
        // Hit both H and V parity bits, but data is untouched
        read_and_inject_error(16'h0000, 10'b10_0000_0000, 8'b1000_0000, "ECC Strike: Errors in H and V simultaneously", 1);

        // ===================================================================
        // SCENARIO 4: Uncorrectable Error Boundaries (Negative Testing)
        // DMC can only correct errors strictly contained within a single logical symbol.
        // ===================================================================
        write_sram(16'hBEEF);
        
        // 2-Bit error, but they cross the boundary between Symbol 0 (Bit 3) and Symbol 1 (Bit 4)
        // This causes multiple delta_H and S syndromes to activate erroneously.
        read_and_inject_error(16'b0000_0000_0001_1000, 10'h0, 8'h0, "UNCORRECTABLE: 2-Bit Error crossing Sym 0/1 boundary", 0);

        // Errors in Symbol 0 and Symbol 3 simultaneously
        read_and_inject_error(16'b1111_0000_0000_1111, 10'h0, 8'h0, "UNCORRECTABLE: Errors in Sym 0 and Sym 3", 0);

        $display("\nVerification Complete.\n");
        $finish;
    end

endmodule