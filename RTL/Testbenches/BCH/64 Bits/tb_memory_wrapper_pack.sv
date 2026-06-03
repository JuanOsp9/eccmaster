//`timescale 1ns/1ps
module tb_memory_wrapper;

    // ---------------------------------------------------
    // Parameters
    // ---------------------------------------------------
    localparam int ADDR_WIDTH  = 7;
    localparam int DATA_WIDTH  = 32;
    localparam int WORDS_BLOCK = 2;
    localparam time CLK_PERIOD = 10ns;

    // ---------------------------------------------------
    // Signals
    // ---------------------------------------------------
    logic                  clk;
    logic                  cen; // Active Low
    logic                  wen; // Active High (Read mode)
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] d;
    logic [DATA_WIDTH-1:0] q;
    logic                  error_corrected;
    logic                  double_bit_error;

    // ---------------------------------------------------
    // DUT Instantiation
    // ---------------------------------------------------
    memory_wrapper #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .DATA_WIDTH  (DATA_WIDTH),
        .WORDS_BLOCK (WORDS_BLOCK)
    ) dut (
        .clk                 (clk),
        .cen                 (cen),
        .wen                 (wen),
        .addr                (addr),
        .d                   (d),
        .q                   (q),
        .error_corrected(error_corrected)
    );

    // ---------------------------------------------------
    // Clock Generation
    // ---------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---------------------------------------------------
    // Test Sequence
    // ---------------------------------------------------
    initial begin
        // 1. Initialization
        cen  = 1'b1; // Disable (Active Low)
        wen  = 1'b1; 
        addr = '0;
        d    = '0;

        // Wait for system to settle
        repeat(5) @(posedge clk);
        $display("[%0t] Starting Write Sequence (Addr 0 to 9)...", $time);

        // 2. Loop writes from 0 to 11
        for (int i = 0; i <= 11; i++) begin
            write_word(i, 32'h0000_0000 + i);
        end
        
        repeat(5) @(posedge clk);

        // ---------------------------------------------------
        // 3. ERROR INJECTION (New Step)
        // ---------------------------------------------------
        inject_errors();
        // ---------------------------------------------------

        $display("---------------------------------------------------");
        $display("[%0t] Starting Read Sequence (Addr 0 to 11)...", $time);

        // 4. Loop Reads from 0 to 11
        for (int i = 0; i <= 11; i++) begin
            read_word(i);
        end

        // 5. End simulation
        @(posedge clk);
        cen = 1'b1;
        wen = 1'b1;
        
        repeat(5) @(posedge clk);
        $display("[%0t] Test Finished.", $time);
        $finish;
    end

    // ---------------------------------------------------
    // Tasks
    // ---------------------------------------------------
    task write_word(input int target_addr, input logic [DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            addr <= target_addr[ADDR_WIDTH-1:0];
            d    <= data;
            cen  <= 1'b0; // Chip Enable (Active Low)
            wen  <= 1'b0; // Write Enable (Low for Write)

            @(posedge clk);
            cen  <= 1'b1;
            wen  <= 1'b1; 
        end
    endtask

    task read_word(input int target_addr);
        begin
            // 1. Setup Address and Control
            @(posedge clk);
            addr <= target_addr[ADDR_WIDTH-1:0];
            cen  <= 1'b0; 
            wen  <= 1'b1; // Read Mode
            
            // 2. Wait for RAM access time
            @(posedge clk);
            
            // 3. Sample
            #1; 
            $display("[%0t] Read Addr: %0d | Data: %h | ERR: %b", 
                     $time, target_addr, q, error_corrected);
            
            // 4. Reset
            cen <= 1'b1;
        end
    endtask

    // ---------------------------------------------------
    // NEW TASK: Inject Errors via Backdoor
    // ---------------------------------------------------
    task inject_errors();
        begin
            $display("---------------------------------------------------");
            $display("[%0t] Injecting Errors directly into Memory Array...", $time);
            
            for (int i = 0; i <= 6; i++) begin
                // ---------------------------------------------------------
                // IMPORTANT: Replace 'dut.mem' below with the actual 
                // hierarchical path to the memory array in your design.
                // Example: dut.u_ram.memory_array[i]
                // ---------------------------------------------------------
                
                if (i % 2 == 0) begin
                    // EVEN Address: Inject SINGLE bit error (Flip LSB)
                    // We use XOR to flip the bit without needing to know the value
                    dut.u_sram.mem[i] = dut.u_sram.mem[i] ^ 1'b1; 
                    $display("  -> Addr %0d (Even): Injected Single Bit Error", i);
                end 
                else begin
                    // ODD Address: Inject DOUBLE bit error (Flip 2 LSBs)
                    dut.u_sram.mem[i] = dut.u_sram.mem[i] ^ 2'b11;
                    $display("  -> Addr %0d (Odd) : Injected Double Bit Error", i);
                end
            end
            $display("---------------------------------------------------");
        end
    endtask

endmodule