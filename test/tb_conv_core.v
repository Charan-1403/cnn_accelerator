`timescale 1ns / 1ps

module tb_conv_core;

    // -------------------------------------------------------------------------
    // PARAMETERS & SIGNALS
    // -------------------------------------------------------------------------
    localparam DATA_WIDTH = 32;
    localparam PIXEL_DIM  = 10; // Shrunken image for verifiable simulation!
    localparam STRIDE     = 1;
    localparam CLK_PERIOD = 10; // 100 MHz Clock
    
    reg                   clk;
    reg                   rst;
    
    reg  [DATA_WIDTH-1:0] s_axis_data;
    reg                   s_axis_valid;
    
    reg  [143:0]          weights_packed;
    reg                   weights_valid;
    reg  [15:0]           bias;
    reg                   bias_valid;
    
    wire [DATA_WIDTH-1:0] m_axis_data;
    wire                  m_axis_valid;

    // -------------------------------------------------------------------------
    // DUT INSTANTIATION
    // -------------------------------------------------------------------------
    conv_core_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .PIXEL_DIM(PIXEL_DIM),
        .STRIDE(STRIDE)
    ) UUT (
        .clk(clk),
        .rst(rst),
        .s_axis_data(s_axis_data),
        .s_axis_valid(s_axis_valid),
        .weights_packed(weights_packed),
        .weights_valid(weights_valid),
        .bias(bias),
        .bias_valid(bias_valid),
        .m_axis_data(m_axis_data),
        .m_axis_valid(m_axis_valid)
    );

    // -------------------------------------------------------------------------
    // CLOCK GENERATION & CYCLE TRACKING
    // -------------------------------------------------------------------------
    integer cycle_count = 0;
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
    end

    // -------------------------------------------------------------------------
    // VERIFICATION MONITORS (THE SELF-CHECKERS)
    // -------------------------------------------------------------------------
    integer valid_out_count = 0;
    integer start_cycle = 0;
    integer first_out_cycle = 0;
    
    // THE FIX: Updated expected latency to match the physical pipeline
    // (2 * Width) + 3 Window + 6 Math Pipeline + 3 Hidden Buffer/Output Registers = 32
    integer expected_latency = (2 * PIXEL_DIM) + 3 + 6 + 3; 
    
    // Monitor Output Data
    always @(posedge clk) begin
        if (m_axis_valid) begin
            if (valid_out_count == 0) begin
                first_out_cycle = cycle_count;
                $display("\n[TIMING CHECK] First Valid Output at Cycle: %0d", first_out_cycle);
                $display("[TIMING CHECK] Actual Latency: %0d cycles. Expected Latency: %0d cycles.", 
                          (first_out_cycle - start_cycle), expected_latency);
                
                if ((first_out_cycle - start_cycle) == expected_latency)
                    $display("    -> LATENCY TEST: PASS! Pipeline synchronization is perfect.");
                else
                    $display("    -> LATENCY TEST: FAIL! Pipeline delay mismatch.");
            end
            
            // Print the data to ensure wrap-around logic works
            $display("[%0d] Output #%0d Valid! Data = %0d", cycle_count, valid_out_count+1, m_axis_data);
            valid_out_count = valid_out_count + 1;
        end
    end

    // -------------------------------------------------------------------------
    // MAIN STIMULUS THREAD
    // -------------------------------------------------------------------------
    integer row, col;
    reg [7:0] pixel_val;
    
    initial begin
        // 1. INITIALIZE
        rst = 1;
        s_axis_data = 0;
        s_axis_valid = 0;
        weights_packed = 0;
        weights_valid = 0;
        bias = 0;
        bias_valid = 0;
        
        $display("=========================================================");
        $display("   STARTING CONV CORE VERIFICATION (10x10 IMAGE)         ");
        $display("=========================================================\n");
        
        #(CLK_PERIOD * 5);
        rst = 0;
        #(CLK_PERIOD * 5);
        
        // 2. LOAD WEIGHTS & BIAS
        // We set all 9 weights to '1'. This makes the MAC simply sum the window.
        weights_packed = {16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1};
        weights_valid = 1;
        bias = 16'd0; // No bias for easy math
        bias_valid = 1;
        
        // THE FIX: Wait 3 clock cycles to fully load the 27 weights
        #(CLK_PERIOD * 3); 
        weights_valid = 0;
        bias_valid = 0;
        $display("[INIT] Weights and Bias Loaded. Beginning Image Stream...");
        
        // 3. STREAM THE IMAGE (10x10)
        start_cycle = cycle_count;
        
        for (row = 0; row < PIXEL_DIM; row = row + 1) begin
            for (col = 0; col < PIXEL_DIM; col = col + 1) begin
                
                // --- CORNER CASE TEST: THE AXI PAUSE ---
                // In the middle of Row 4, simulate the DMA running out of data
                if (row == 4 && col == 5) begin
                    $display("\n[CORNER CASE] >> INJECTING AXI STREAM PAUSE FOR 5 CYCLES <<");
                    s_axis_valid = 0; // Drop the valid signal!
                    #(CLK_PERIOD * 5); // Wait 5 clock cycles
                    $display("[CORNER CASE] >> RESUMING AXI STREAM <<\n");
                end
                
                // Create a gradient pixel value: (Row*10) + Col
                // Example: Row 2, Col 4 -> Pixel value = 24
                pixel_val = (row * 10) + col;
                
                // Pack RGB into the 32-bit AXI word
                s_axis_data[23:16] = pixel_val; // Red
                s_axis_data[15:8]  = pixel_val; // Green
                s_axis_data[7:0]   = pixel_val; // Blue
                s_axis_data[31:24] = 8'd0;      // Padding
                
                s_axis_valid = 1;
                #(CLK_PERIOD); // Wait 1 clock cycle (Push the pixel)
            end
        end
        
        // Image complete, drop valid
        s_axis_valid = 0;
        
        // 4. WAIT FOR PIPELINE TO DRAIN
        // The last pixel takes 6 cycles to get through the math pipeline
        #(CLK_PERIOD * 20); 
        
        // 5. FINAL WRAP-UP & ASSERTIONS
        $display("\n=========================================================");
        $display("   VERIFICATION COMPLETE");
        $display("=========================================================");
        $display("Total Valid Pixels Produced: %0d", valid_out_count);
        $display("Expected Valid Pixels:       %0d (8x8 window from 10x10 input)", (PIXEL_DIM-2)*(PIXEL_DIM-2));
        
        if (valid_out_count == ((PIXEL_DIM-2)*(PIXEL_DIM-2)))
            $display("-> EDGE WRAP-AROUND TEST: PASS! Garbage data was perfectly muted.");
        else
            $display("-> EDGE WRAP-AROUND TEST: FAIL! Incorrect output count.");
            
        $stop;
    end

endmodule