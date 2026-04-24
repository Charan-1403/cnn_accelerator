`timescale 1ns / 1ps

import axi4stream_vip_pkg::*;
import pipeline_test_axi4stream_vip_1_0_pkg::*; 
import pipeline_test_axi4stream_vip_0_0_pkg::*; 

module tb_sim_datapath();

    logic dma_clk = 0;
    logic core_clk = 0;
    logic dma_resetn = 0;
    logic core_resetn = 0;

    bit [31:0] received_queue [$]; 

    always #2 dma_clk = ~dma_clk;    
    always #5 core_clk = ~core_clk;  

    pipeline_test_wrapper dut (
        .dma_clk(dma_clk),
        .core_clk(core_clk),
        .dma_resetn(dma_resetn),
        .core_resetn(core_resetn)
    );

    pipeline_test_axi4stream_vip_1_0_mst_t master_agent;
    pipeline_test_axi4stream_vip_0_0_slv_t slave_agent;

    initial begin
        master_agent = new("master_agent", dut.pipeline_test_i.axi4stream_vip_1.inst.IF);
        slave_agent  = new("slave_agent",  dut.pipeline_test_i.axi4stream_vip_0.inst.IF);

        master_agent.start_master();
        slave_agent.start_slave();

        fork
            run_monitor();
        join_none

        dma_resetn = 0;
        core_resetn = 0;
        #500;
        dma_resetn = 1;
        core_resetn = 1;
        #500;

        begin
            axi4stream_ready_gen ready_policy;
            ready_policy = slave_agent.driver.create_ready("ideal_ready");
            ready_policy.set_ready_policy(XIL_AXI4STREAM_READY_GEN_NO_BACKPRESSURE);
            slave_agent.driver.send_tready(ready_policy);
        end

        send_test_burst(256);

        #100000; 
        
        $display("TEST FINISHED! Collected %0d pixels in the queue.", received_queue.size());
        dump_queue_to_file();
        $finish;
    end

    task send_test_burst(int num_pixels);
        axi4stream_transaction t;     
        bit [7:0] pixel_bytes [];   
        pixel_bytes = new[4];

        for (int i = 0; i < num_pixels; i++) begin
            t = master_agent.driver.create_transaction("Pixel");
            
            pixel_bytes[3] = 8'h00;
            pixel_bytes[2] = $urandom();
            pixel_bytes[1] = $urandom();
            pixel_bytes[0] = $urandom();
            
            t.set_data(pixel_bytes);
            t.set_delay(0); 

            if (i == num_pixels - 1)
                t.set_last(1);
            else
                t.set_last(0);

            master_agent.driver.send(t);
        end
    endtask

    task run_monitor();
        axi4stream_transaction slv_trans;
        bit [31:0] actual_pixel;
        bit [7:0] caught_data [];
        caught_data = new[4];

        forever begin
            slave_agent.monitor.item_collected_port.get(slv_trans);
            slv_trans.get_data(caught_data);

            actual_pixel = {caught_data[3], 
                            caught_data[2], 
                            caught_data[1], 
                            caught_data[0]};

            received_queue.push_back(actual_pixel);
        end
    endtask

    task dump_queue_to_file();
        int fd;
        fd = $fopen("output_pixels.txt", "w");
        if (fd) begin
            foreach (received_queue[i]) begin
                $fdisplay(fd, "%08x", received_queue[i]);
            end
            $fclose(fd);
            $display("SUCCESS: All pixels saved safely to output_pixels.txt");
        end else begin
            $error("Failed to open file for writing!");
        end
    endtask

endmodule
