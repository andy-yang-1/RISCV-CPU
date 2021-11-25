iverilog common/block_ram/block_ram.v common/fifo/fifo.v common/uart/uart_baud_clk.v common/uart/uart.v common/uart/uart_rx.v common/uart/uart_tx.v hci.v ram.v fetch.v decode.v dispatch.v alu.v regFile.v RS.v LSB.v ROB.v mem_ctrl.v predictor.v cpu.v riscv_top.v ../sim/testbench.v -o cpu_run
vvp cpu_run
