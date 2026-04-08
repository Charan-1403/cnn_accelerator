`timescale 1ns / 1ps

module conv_core_top #(
    parameter DATA_WIDTH = 32,
    parameter PIXEL_DIM = 418, // The padded dimension!
    parameter STRIDE = 1
)(
    input  wire                  clk,
    input  wire                  rst,
    
    // AXI Stream Input (from DMA)
    input  wire [DATA_WIDTH-1:0] s_axis_data,
    input  wire                  s_axis_valid,
    
    // Weights & Bias Configuration
    input  wire [143:0]          weights_packed,
    input  wire                  weights_valid,
    input  wire [15:0]           bias,
    input  wire                  bias_valid,
    
    // AXI Stream Output (to DMA)
    output wire [DATA_WIDTH-1:0] m_axis_data,
    output wire                  m_axis_valid
);

    // -------------------------------------------------------------------------
    // INTERNAL PLUMBING WIRES
    // -------------------------------------------------------------------------
    wire [DATA_WIDTH-1:0] lb0_data_out;
    wire                  lb0_valid_out;
    
    wire [DATA_WIDTH-1:0] lb1_data_out;
    wire                  lb1_valid_out;

    // -------------------------------------------------------------------------
    // MODULE INSTANTIATIONS
    // -------------------------------------------------------------------------

    // Line Buffer 0: Delays the raw input stream by exactly 1 image row
    line_buffer #(
        .DATA_WIDTH(DATA_WIDTH), 
        .PIXEL_ROWS(PIXEL_DIM)
    ) LB0 (
        .clk(clk),
        .rst(rst),
        .ip_pixel_data_valid(s_axis_valid),
        .ip_pixel_data(s_axis_data),
        .buf_pixel_data(lb0_data_out),
        .buf_pixel_data_valid(lb0_valid_out)
    );

    // Line Buffer 1: Delays the output of LB0 by exactly 1 image row
    line_buffer #(
        .DATA_WIDTH(DATA_WIDTH), 
        .PIXEL_ROWS(PIXEL_DIM)
    ) LB1 (
        .clk(clk),
        .rst(rst),
        .ip_pixel_data_valid(lb0_valid_out), // Note: Driven by LB0's valid!
        .ip_pixel_data(lb0_data_out),        // Note: Driven by LB0's data!
        .buf_pixel_data(lb1_data_out),
        .buf_pixel_data_valid(lb1_valid_out)
    );

    // The Convolution MAC Engine: Does the actual math
    mac_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .STRIDE(STRIDE),
        .PIXEL_DIM(PIXEL_DIM)
    ) MAC (
        .clk(clk),
        .rst(rst),
        
        // The 3 Parallel Row Streams
        .axi_buf(s_axis_data),
        .line_buf0(lb0_data_out),
        .line_buf1(lb1_data_out),
        
        // The 3 Parallel Valid Signals
        .axi_buf_valid(s_axis_valid),
        .line_buf0_valid(lb0_valid_out),
        .line_buf1_valid(lb1_valid_out),
        
        // Configuration
        .weights_packed(weights_packed),
        .weights_valid(weights_valid),
        .bias(bias),
        .bias_valid(bias_valid),
        
        // The Output Stream
        .output_data(m_axis_data),
        .out_valid(m_axis_valid)
    );

endmodule