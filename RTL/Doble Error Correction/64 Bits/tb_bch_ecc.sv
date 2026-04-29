`timescale 1ns / 1ps

module tb_bch_ecc;

    // -------------------------------------------------------------------------
    // 1. Parameters (UPDATED FOR 64-BIT)
    // -------------------------------------------------------------------------
    parameter DATA_WIDTH  = 64;      
    parameter CHECK_WIDTH = 14;      // 78 - 64 = 14 bits for t=2
    parameter CODE_WIDTH  = 78;      // 64 Data + 14 Check

    // -------------------------------------------------------------------------
    // 2. Signals
    // -------------------------------------------------------------------------
    logic [DATA_WIDTH-1:0]  data_i;
    logic [CODE_WIDTH-1:0]  force_error_vector;
   
    logic [DATA_WIDTH-1:0]  data_o;
    logic                   error_detected;
    logic                   double_error;

    // Test Statistics
    integer pass_count = 0;
    integer fail_count = 0;

    // -------------------------------------------------------------------------
    // 3. Instantiate the Top Module (DUT)
    // -------------------------------------------------------------------------
    bch_ecc_top #(
        .DATA_WIDTH (DATA_WIDTH),
        .CHECK_WIDTH(CHECK_WIDTH),
        .CODE_WIDTH (CODE_WIDTH)
    ) dut (
        .data_i               (data_i),
        .data_o               (data_o),
        .error_detected_o     (error_detected),
        .double_error_o       (double_error),
        .force_error_vector_i (force_error_vector)
    );

    // -------------------------------------------------------------------------
    // 4. Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        $display("-------------------------------------------------------------");
        $display("STARTING SIMULATION: BCH(%0d, %0d)", CODE_WIDTH, DATA_WIDTH);
        $display("-------------------------------------------------------------");

        // Initialization (64-bit Pattern)
        data_i = 64'hAAAA_BBBB_CCCC_DDDD;
        force_error_vector = '0;
        #10;

        // =====================================================================
        // TEST CASE 1: No Errors (Golden Run)
        // =====================================================================
        $display("\nTest 1: No Errors (Golden Run)");
       
        if (data_o === data_i && error_detected === 0) begin
            $display("  [PASS] Data In: %h | Data Out: %h", data_i, data_o);
            pass_count++;
        end else begin
            $display("  [FAIL] Corruption without errors! In: %h Out: %h", data_i, data_o);
            fail_count++;
        end

        // =====================================================================
        // TEST CASE 2: Single Bit Upsets (SBU) - Exhaustive
        // =====================================================================
        $display("\nTest 2: Injecting Single Bit Errors (Iterating %0d positions)...", CODE_WIDTH);
       
        for (int i = 0; i < CODE_WIDTH; i++) begin
            force_error_vector = '0;
            force_error_vector[i] = 1'b1; // Flip bit i
            #10;

            if (data_o === data_i && error_detected === 1) begin
                pass_count++;
            end else begin
                $display("  [FAIL] SBU at bit %0d failed. Out: %h (Expected: %h)", i, data_o, data_i);
                fail_count++;
            end
        end
        $display("  SBU Test Complete.");

        // =====================================================================
        // TEST CASE 3: Double Bit Upsets (DBU) - Exhaustive
        // =====================================================================
        $display("\nTest 3: Injecting Double Bit Errors (Iterating all pairs)...");
        $display("  (Note: This will check approx 3,000 cases)");
       
        for (int i = 0; i < CODE_WIDTH; i++) begin
            for (int j = i + 1; j < CODE_WIDTH; j++) begin
                force_error_vector = '0;
                force_error_vector[i] = 1'b1;
                force_error_vector[j] = 1'b1; // Flip bits i AND j
                #10;

                if (data_o === data_i) begin
                    pass_count++;
                end else begin
                    $display("  [FAIL] DBU at bits %0d & %0d failed. Out: %h", i, j, data_o);
                    fail_count++;
                end
            end
        end
        $display("  DBU Test Complete.");

        // =====================================================================
        // TEST CASE 4: Triple Bit Error
        // =====================================================================
        $display("\nTest 4: Triple Bit Error Check");
        force_error_vector = '0;
        force_error_vector[CODE_WIDTH - 1] = 1;
        force_error_vector[CODE_WIDTH - 2] = 1;
        force_error_vector[CODE_WIDTH - 3] = 1;
        #10;
       
        if (data_o !== data_i)
            $display("  [PASS] Triple error caused data corruption (Expected behavior).");
        else
            $display("  [INFO] Lucky triple error was corrected.");

        // -------------------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------------------
        $display("-------------------------------------------------------------");
        $display("SIMULATION COMPLETE");
        $display("Passed Cases: %0d", pass_count);
        $display("Failed Cases: %0d", fail_count);
        $display("-------------------------------------------------------------");
       
        if (fail_count == 0) $display("SUCCESS: Design is fully verified!");
        else $display("FAILURE: Design has bugs.");
       
        $stop;
    end

endmodule