`timescale 1ns / 1ps

module line_buffer #(parameter DATA_WIDTH = 32, parameter PIXEL_ROWS = 416, parameter ADDR_WIDTH = 9)(
        input clk, rst, ip_pixel_data_valid,
        input[DATA_WIDTH-1:0] ip_pixel_data,
        output reg [DATA_WIDTH-1:0] buf_pixel_data,
        output reg buf_pixel_data_valid
    );
    
    reg[DATA_WIDTH-1:0] line_buf [0:PIXEL_ROWS-1];
    
    reg[ADDR_WIDTH-1:0] pointer;
    
    reg buf_full;
    
    always@(posedge clk) begin
            if(rst) begin
                pointer <= 0;
                buf_full <= 0;
                buf_pixel_data_valid <= 0;
            end
            else begin
                if(ip_pixel_data_valid) begin
                    if(pointer >= PIXEL_ROWS-1) begin 
                        pointer <= 0;
                        buf_full <= 1;
                    end
                    else pointer <= pointer + 1;
                end
                else pointer <= pointer;
                
                if(ip_pixel_data_valid) line_buf[pointer] <= ip_pixel_data;
                if(ip_pixel_data_valid && buf_full) begin
                    buf_pixel_data <= line_buf[pointer];
                    buf_pixel_data_valid <= 1;
                end
                else buf_pixel_data_valid <= 0;
            end
    end
    
    
endmodule
