# AXI4-Stream VIP Verification Environment Documentation

## 1. Environment Architecture
The verification environment is a SystemVerilog-based testbench that utilizes Xilinx AXI4-Stream Verification IP (VIP) to validate the CNN accelerator. It adopts a "Black-Box" approach, where software agents simulate system-level data movement without requiring manual signal toggling.

### Key Components
* **Master Agent (`mst_agent`):** Simulates a System DMA. It handles the generation of AXI-Stream transactions and drives the input interface at **250 MHz**.
* **Slave Agent (`slv_agent`):** Simulates a high-speed memory sink. It monitors the output interface and validates that the hardware adheres to the ARM AMBA AXI4-Stream protocol.
* **Dynamic Queue (`received_queue`):** A SystemVerilog software container used to store output pixels in real-time as they emerge from the asynchronous pipeline.

## 2. Initialization & Protocol Setup
The testbench follows a deterministic sequence to ensure the hardware and VIP agents are synchronized across asynchronous clock domains:

1.  **Agent Instantiation:** Connects the software objects to the physical RTL interfaces using hierarchical paths.
2.  **Clock/Reset Synchronization:** Implements a **500ns reset phase** to allow the internal Asynchronous CDC FIFOs and line buffer pointers to settle into a known state before data injection.
3.  **Ready Policy Override:** By default, VIPs introduce random stalls. The environment explicitly configures the Slave to `NO_BACKPRESSURE` mode. This ensures that `TREADY` remains high, allowing the core to be tested at its maximum physical throughput.

## 3. Stimulus Generation Logic
The `send_test_burst` task automates the data ingestion process:
* **Packet Construction:** Creates `axi4stream_transaction` objects containing randomized 32-bit pixel data (RGB).
* **Zero-Delay Driving:** Sets transaction delays to **0**, forcing a continuous data stream that tests the core's ability to handle back-to-back pixels without gaps.
* **TLAST Signaling:** Automatically calculates the final pixel of the input frame (e.g., pixel 256 for a 16x16 image) and asserts the `TLAST` sideband signal to signify frame completion.

## 4. Background Monitoring & Data Capture
To handle the variable latency of the convolution pipeline, the testbench employs an asynchronous monitor:
* **Parallel Execution:** The `run_monitor()` task runs in a background thread using `fork...join_none`.
* **Handshake Monitoring:** It waits for the `item_collected_port` to trigger, which only occurs when a successful `TVALID && TREADY` handshake is detected on the physical wires.
* **Byte-to-Integer Reassembly:** Since the VIP handles data as byte arrays, the monitor reassembles these bytes into 32-bit integers for storage.

## 5. Result Validation (File I/O)
The final phase of the testbench ensures data persistence for post-simulation analysis:
* **Drain Time:** The simulation remains active for **100 microseconds** after the last input pixel is sent, ensuring the deep mathematical pipeline is fully flushed.
* **Automated Dump:** The `dump_queue_to_file` task opens `output_pixels.txt` and writes the hex values of all captured transactions.
* **Final Tally:** Prints the total size of the queue to the console, confirming that the "Shrinkage Math" (e.g., 256 in -> 196 out) is correct.


<img width="1542" height="792" alt="image" src="https://github.com/user-attachments/assets/59716e10-4b87-42fe-b9a9-615b14655177" />


