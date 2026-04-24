# AXI4-Stream CNN Hardware Accelerator

## Overview
This repository contains a high-performance hardware accelerator for 2D Convolutional Neural Network (CNN) layers, implemented in Verilog. The design is optimized for FPGA deployment, featuring a modular architecture that separates high-speed DMA data ingestion from core processing logic via asynchronous clock domain crossing.

## System Architecture

### 1. Dual-Clock Domain Pipeline
The system is partitioned into two distinct clock domains to maximize throughput and reliability:
* **DMA Domain (250 MHz):** Handles high-speed AXI-Stream transactions, interface handshaking, and external data movement.
* **Core Domain (100 MHz):** Dedicated to the computational intensity of the convolution math, ensuring timing closure for complex MAC operations.

### 2. Clock Domain Crossing (CDC)
Data integrity between the asynchronous domains is maintained using dual-clock (asynchronous) FIFOs. This architectural choice prevents metastability and allows the core to process data at its natural rate while the DMA domain burst-transfers pixels at peak bus speeds.

### 3. Convolution Core Implementation
The core computational engine utilizes a sliding window architecture to perform real-time convolution.

* **Line Buffer Strategy:** Instead of storing the entire image in memory, the design implements an internal row-caching mechanism. For a 3x3 kernel, two full rows are buffered, allowing the MAC unit to access a 3x3 pixel window simultaneously every clock cycle once the pipeline is primed.
* **MAC (Multiply-Accumulate) Unit:** A parallel execution unit that computes the weighted sum of the 3x3 window in a single clock cycle. It features parameterized bit-widths to support various dynamic ranges.
* **Shrinkage Handling:** The core implements 'Valid' padding math, where an N x N input results in an (N - K + 1) x (N - K + 1) output. This avoids the complexity of zero-padding hardware while maintaining mathematical accuracy.

## Interface Specifications
The IP is wrapped in a standard AXI4-Stream interface, making it 'Plug-and-Play' for Xilinx Vivado IP Integrator environments:
* **S_AXIS:** Slave interface receiving raw pixel data.
* **M_AXIS:** Master interface streaming out filtered results.
* **TLAST Generation:** The core autonomously calculates the end of a frame and asserts TLAST on the final valid output pixel to signal downstream DMA engines.

## Verification Methodology

### Xilinx Verification IP (VIP) Suite
The design was verified using a SystemVerilog UVM-style testbench leveraging Xilinx AXI4-Stream VIPs.

* **Master VIP:** Acts as a virtual DMA, injecting randomized pixel traffic into the core at 250 MHz.
* **Slave VIP:** Acts as a downstream sink, monitoring output transactions for protocol compliance and data accuracy.
* **Performance Benchmarking:** The VIP was programmed with a 'Zero-Delay' policy to measure the physical throughput limits of the silicon.

### Automated Result Collection
The verification environment utilizes a SystemVerilog monitor that captures every output transaction into a dynamic queue. At the end of the simulation, these results are automatically dumped into an 'output_pixels.txt' file, allowing for bit-perfect comparison against golden software models.
