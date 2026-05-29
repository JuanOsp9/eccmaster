`timescale 1ns/1ps

module tb_dmc_sram_wrapper;

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
            #10; // Wait for combinational logic to generate ECC bits
            
            // Latch into mock SRAM
            mem_data = sram_d_write;
            mem_h    = sram_h_write;
            mem_v    = sram_v_write;
            $display("WRITE: Data=16'h%0h | Gen_H=10'h%0h | Gen_V=8'h%0h", mem_data, mem_h, mem_v);
            #10;
        end
    endtask

    task read_and_inject_error(input logic [15:0] error_mask, input string test_name);
        begin
            we = 0;
            // Feed the stored ECC bits back to the wrapper
            sram_h_read = mem_h;
            sram_v_read = mem_v;
            
            // Inject the error mask into the stored data during the read
            sram_d_read = mem_data ^ error_mask; 
            
            #10; // Wait for syndrome calculation and correction
            
            $display("--------------------------------------------------");
            $display("TEST: %s", test_name);
            $display("  Injected Mask : 16'b%016b", error_mask);
            $display("  Corrupted Read: 16'h%0h", sram_d_read);
            $display("  Corrected Out : 16'h%0h", data_out);
            
            if (data_out === mem_data)
                $display("  RESULT: PASS");
            else
                $error("  RESULT: FAIL - Expected 16'h%0h, Got 16'h%0h", mem_data, data_out);
            $display("--------------------------------------------------\n");
            #10;
        end
    endtask

    // -------------------------------------------------------------------
    // Test Vectors
    // -------------------------------------------------------------------
    initial begin
        $display("\nStarting DMC SRAM Wrapper Testbench...\n");

        // Initialize
        we = 0;
        data_in = 16'h0000;
        sram_d_read = 16'h0000;
        sram_h_read = 10'h000;
        sram_v_read = 8'h00;
        #20;

        // Perform a clean write
        // Using a recognizable pattern: A = 1010, B = 1011, C = 1100, D = 1101
        write_sram(16'hABCD);

        // Run Error Injection Scenarios targeting Symbol 0 (Bits [3:0])
        read_and_inject_error(16'b0000_0000_0000_0000, "No Errors");
        
        read_and_inject_error(16'b0000_0000_0000_0001, "Single-Bit Error (Bit 0)");
        
        read_and_inject_error(16'b0000_0000_0000_0011, "Double-Bit Error (Bits 1,0 - Adjacent MCU)");
        
        read_and_inject_error(16'b0000_0000_0000_0111, "Triple-Bit Error (Bits 2,1,0)");
        
        read_and_inject_error(16'b0000_0000_0000_1111, "4-Bit Error (Entire Symbol 0 Corrupted)");

        // Run Error Injection targeting Symbol 2 (Bits [11:8])
        read_and_inject_error(16'b0000_0110_0000_0000, "Double-Bit Error in Symbol 2 (Bits 10,9)");

        $display("Testing Complete.");
        $finish;
    end

endmodule