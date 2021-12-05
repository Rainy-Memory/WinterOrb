rm -rf bin
mkdir bin
iverilog -g2012 -o bin/cpu_build -I src/ src/cpu.v src/ram.v src/riscv_top.v src/hci.v src/common/*/*.v sim/testbench.v
# echo "build finished."
vvp bin/cpu_build
# echo "simulation finished."
