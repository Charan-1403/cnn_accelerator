`timescale 1ns / 1ps

module mac_unit #(parameter DATA_WIDTH = 32, parameter STRIDE = 1, parameter PIXEL_DIM = 418, parameter ADDR_WIDTH = 9)(
        input[DATA_WIDTH-1:0] axi_buf, line_buf0, line_buf1,
        input clk, rst,
        input line_buf0_valid, line_buf1_valid, axi_buf_valid,
        input[143:0] weights_packed,
        input weights_valid, bias_valid,
        input[15:0] bias,
        output reg [DATA_WIDTH-1:0] output_data,
        output reg out_valid
    );
    
    reg[7:0] pixel_regs [0:26];
    reg[31:0] bias_reg;
    reg[15:0] weights[0:26];
    
    reg[ADDR_WIDTH-1:0] row_count, col_count;
    reg[2:0] prime_counter, weight_counter;
    reg[7:0] h_stride_counter, v_stride_counter;
    
    wire capture_mult;
    
    assign capture_mult = (weight_counter == 3 && prime_counter == 3 && axi_buf_valid && h_stride_counter == 0 && col_count >= 2 && v_stride_counter == 0);
    
    always@(posedge clk) if(bias_valid) bias_reg <= {{16{bias[15]}},bias};
    
    always@(posedge clk) begin
        if(rst) h_stride_counter <= 0;
        else begin
            if(axi_buf_valid && h_stride_counter < STRIDE-1) h_stride_counter <= h_stride_counter + 1;
            else h_stride_counter <= 0; 
        end
    end
    
    always@(posedge clk) begin
        if(rst) v_stride_counter <= 0;
        else begin
            if(prime_counter == 3 && col_count == 0 && v_stride_counter <= STRIDE-1) v_stride_counter <= v_stride_counter + 1;
            else v_stride_counter <= 0; 
        end
    end
    
    always@(posedge clk) begin
        if(rst) begin
            prime_counter <= 0;
            col_count <= 0;
            row_count <= 0;
        end
        else begin
            if(axi_buf_valid && line_buf0_valid && line_buf1_valid) begin
                if(prime_counter < 3) prime_counter <= prime_counter + 1;
                else prime_counter <= prime_counter;
                pixel_regs[0] <= pixel_regs[1]; pixel_regs[1] <= pixel_regs[2]; pixel_regs[2] <= line_buf1[23:16];
                pixel_regs[3] <= pixel_regs[4]; pixel_regs[4] <= pixel_regs[5]; pixel_regs[5] <= line_buf0[23:16];
                pixel_regs[6] <= pixel_regs[7]; pixel_regs[7] <= pixel_regs[8]; pixel_regs[8] <= axi_buf[23:16];
                
                pixel_regs[9] <= pixel_regs[10]; pixel_regs[10] <= pixel_regs[11]; pixel_regs[11] <= line_buf1[15:8];
                pixel_regs[12] <= pixel_regs[13]; pixel_regs[13] <= pixel_regs[14]; pixel_regs[14] <= line_buf0[15:8];
                pixel_regs[15] <= pixel_regs[16]; pixel_regs[16] <= pixel_regs[17]; pixel_regs[17] <= axi_buf[15:8];
                
                pixel_regs[18] <= pixel_regs[19]; pixel_regs[19] <= pixel_regs[20]; pixel_regs[20] <= line_buf1[7:0];
                pixel_regs[21] <= pixel_regs[22]; pixel_regs[22] <= pixel_regs[23]; pixel_regs[23] <= line_buf0[7:0];
                pixel_regs[24] <= pixel_regs[25]; pixel_regs[25] <= pixel_regs[26]; pixel_regs[26] <= axi_buf[7:0];
                
                if(col_count < PIXEL_DIM-1) col_count <= col_count + 1;
                else col_count <= 0;
                
            end
        end
    end
    
    always@(posedge clk) begin
        if(rst) begin
            weights[0] <= 0;
            weights[1] <= 0;
            weights[2] <= 0;
            weight_counter <= 0;
        end
        else begin
            if(weights_valid) begin
                if(weight_counter < 3) weight_counter <= weight_counter + 1;
                else weight_counter <= weight_counter;
                weights[0] <= weights[1]; weights[1] <= weights[2]; weights[2] <= weights_packed[15:0];
                weights[3] <= weights[4]; weights[4] <= weights[5]; weights[5] <= weights_packed[31:16];
                weights[6] <= weights[7]; weights[7] <= weights[8]; weights[8] <= weights_packed[47:32];
                
                weights[9] <= weights[10]; weights[10] <= weights[11]; weights[11] <= weights_packed[63:48];
                weights[12] <= weights[13]; weights[13] <= weights[14]; weights[14] <= weights_packed[79:64];
                weights[15] <= weights[16]; weights[16] <= weights[17]; weights[17] <= weights_packed[95:80];
                
                weights[18] <= weights[19]; weights[19] <= weights[20]; weights[20] <= weights_packed[111:96];
                weights[21] <= weights[22]; weights[22] <= weights[23]; weights[23] <= weights_packed[127:112];
                weights[24] <= weights[25]; weights[25] <= weights[26]; weights[26] <= weights_packed[143:128];
            end
        end
    end
    
    reg signed [31:0] mult_res_reg[0:26];
    
    genvar i;
    generate
    for(i = 0; i < 27; i = i + 1) begin
        always@(posedge clk) mult_res_reg[i] <= $signed({1'b0, pixel_regs[i]})*weights[i];
    end
    endgenerate
    
    
    reg signed[31:0] add_stage1[0:13];
    reg signed[31:0] add_stage2[0:6];
    reg signed[31:0] add_stage3[0:3];
    reg signed[31:0] add_stage4[0:1];
    reg signed[31:0] add_stage5;
    reg[5:0] valid_pipe;
    
    always@(posedge clk) begin
        if(rst) begin
            valid_pipe <= 0;
            out_valid <= 0;
            output_data <= 0;
        end
        else begin
        if(axi_buf_valid) begin
                valid_pipe[5] <= capture_mult;
                
                add_stage1[0] <= mult_res_reg[0] + mult_res_reg[1];
                add_stage1[1] <= mult_res_reg[2] + mult_res_reg[3];
                add_stage1[2] <= mult_res_reg[4] + mult_res_reg[5];
                add_stage1[3] <= mult_res_reg[6] + mult_res_reg[7];
                add_stage1[4] <= mult_res_reg[8] + mult_res_reg[9];
                add_stage1[5] <= mult_res_reg[11] + mult_res_reg[10];
                add_stage1[6] <= mult_res_reg[12] + mult_res_reg[13];
                add_stage1[7] <= mult_res_reg[15] + mult_res_reg[14];
                add_stage1[8] <= mult_res_reg[16] + mult_res_reg[17];
                add_stage1[9] <= mult_res_reg[19] + mult_res_reg[18];
                add_stage1[10] <= mult_res_reg[20] + mult_res_reg[21];
                add_stage1[11] <= mult_res_reg[23] + mult_res_reg[22];
                add_stage1[12] <= mult_res_reg[24] + mult_res_reg[25];
                add_stage1[13] <= mult_res_reg[26];
                valid_pipe[4] <= valid_pipe[5];
                
                
                add_stage2[0] <= add_stage1[0] + add_stage1[1];
                add_stage2[1] <= add_stage1[3] + add_stage1[2];
                add_stage2[2] <= add_stage1[4] + add_stage1[5];
                add_stage2[3] <= add_stage1[7] + add_stage1[6];
                add_stage2[4] <= add_stage1[8] + add_stage1[9];
                add_stage2[5] <= add_stage1[11] + add_stage1[10];
                add_stage2[6] <= add_stage1[12] + add_stage1[13];
                valid_pipe[3] <= valid_pipe[4];
                
                add_stage3[0] <= add_stage2[0] + add_stage2[1];
                add_stage3[1] <= add_stage2[2] + add_stage2[3];
                add_stage3[2] <= add_stage2[5] + add_stage2[4];
                add_stage3[3] <= add_stage2[6];
                valid_pipe[2] <= valid_pipe[3];
                
                add_stage4[0] <= add_stage3[0] + add_stage3[1];
                add_stage4[1] <= add_stage3[3] + add_stage3[2];
                valid_pipe[1] <= valid_pipe[2];
                
                add_stage5 <= add_stage4[0] + add_stage4[1] + bias_reg;
                valid_pipe[0] <= valid_pipe[1];
                
                output_data <= (add_stage5[31] == 1)? 32'b0 : add_stage5;
                out_valid <= valid_pipe[0];
            end
            else out_valid <= 0;
        end
    end
    
endmodule
