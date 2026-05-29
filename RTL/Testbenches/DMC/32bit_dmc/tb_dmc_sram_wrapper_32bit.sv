`timescale 1ns/1ps

module tb_dmc_sram_wrapper_32bit;

    // -------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------
    logic        we;
    logic [31:0] data_in;
    logic [31:0] data_out;

    logic [31:0] sram_d_write, sram_d_read;
    logic [19:0] sram_h_write, sram_h_read;
    logic [15:0] sram_v_write, sram_v_read;

    // -------------------------------------------------------------------
    // Mock SRAM Storage Registers
    // -------------------------------------------------------------------
    logic [31:0] mem_data;
    logic [19:0] mem_h;
    logic [15:0] mem_v;

    // -------------------------------------------------------------------
    // Device Under Test (DUT)
    // -------------------------------------------------------------------
    dmc_sram_wrapper_32bit dut (
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
    task write_sram(input logic [31:0] wdata);
        begin
            we = 1;
            data_in = wdata;
            #10;
            
            mem_data = sram_d_write;
            mem_h    = sram_h_write;
            mem_v    = sram_v_write;
            $display("\n=== WRITE OPERATION ===");
            $display("Data=32'h%08h | Gen_H=20'h%05h | Gen_V=16'h%04h", mem_data, mem_h, mem_v);
            #10;
        end
    endtask

    task read_and_inject_error(
        input logic [31:0] d_mask, 
        input logic [19:0] h_mask, 
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
            $display("  Inj D_Mask: 32'h%08h", d_mask);
            
            if ((data_out === mem_data) == expect_pass) begin
                $display("  RESULT: PASS (Behavior matched expectation)");
            end else begin
                $error("  RESULT: FAIL - Expected Pass=%0b, Data_Out=32'h%08h (Original=32'h%08h)", expect_pass, data_out, mem_data);
            end
            #10;
        end
    endtask

    // -------------------------------------------------------------------
    // Test Vectors
    // -------------------------------------------------------------------
    initial begin
        $display("\nStarting 32-Bit DMC SRAM Verification...\n");
        we = 0; data_in = 0; sram_d_read = 0; sram_h_read = 0; sram_v_read = 0;
        #20;

        // ===================================================================
        // SCENARIO 1: Base Pattern Testing (Alternating Bits)
        // ===================================================================
        write_sram(32'hA5A5_5A5A);
        
        // Target Symbol 0 (D[3:0])
        read_and_inject_error(32'h0000_0001, 20'h0, 16'h0, "Sym 0: Single-Bit Error (Bit 0)", 1);
        read_and_inject_error(32'h0000_0003, 20'h0, 16'h0, "Sym 0: Double-Bit Error (Bits 1,0)", 1);
        read_and_inject_error(32'h0000_000F, 20'h0, 16'h0, "Sym 0: 4-Bit Error (Entire Symbol Corrupted)", 1);

        // Target Symbol 7 (D[31:28])
        read_and_inject_error(32'h3000_0000, 20'h0, 16'h0, "Sym 7: Double-Bit Error (Bits 29,28)", 1);
        read_and_inject_error(32'hF000_0000, 20'h0, 16'h0, "Sym 7: 4-Bit Error (Entire Symbol Corrupted)", 1);

        // ===================================================================
        // SCENARIO 2: Boundary/Extreme Data Patterns
        // ===================================================================
        write_sram(32'hFFFF_FFFF);
        read_and_inject_error(32'h000F_0000, 20'h0, 16'h0, "All 1s Data -> Sym 4 (D[19:16]): 4-Bit Error", 1);
        
        write_sram(32'h0000_0000);
        read_and_inject_error(32'h0000_0F00, 20'h0, 16'h0, "All 0s Data -> Sym 2 (D[11:8]): 4-Bit Error", 1);

        // ===================================================================
        // SCENARIO 3: Redundant Memory Cell Strikes (False Positives)
        // ===================================================================
        write_sram(32'hDEAD_BEEF);
        read_and_inject_error(32'h0, 20'h0001F, 16'h0000, "ECC Strike: 5-Bit Error in H_read[4:0]", 1);
        read_and_inject_error(32'h0, 20'h00000, 16'h000F, "ECC Strike: 4-Bit Error in V_read[3:0]", 1);

        // ===================================================================
        // SCENARIO 4: Uncorrectable Error Boundaries (Negative Testing)
        // ===================================================================
        write_sram(32'h1234_5678);
        
        // Error crossing Symbol 0 and Symbol 1 boundary
        read_and_inject_error(32'h0000_0018, 20'h0, 16'h0, "UNCORRECTABLE: Error crossing Sym 0/1 boundary", 0);

        // Errors in Symbol 0 and Symbol 4 simultaneously (Vertical XOR cancellation)
        read_and_inject_error(32'h0001_0001, 20'h0, 16'h0, "UNCORRECTABLE: Vertical XOR Cancellation (Sym 0 & Sym 4)", 0);

        $display("\nVerification Complete.\n");
        $finish;
    end

endmodule