import os
import sys

riscv_prefix = "/opt/riscv/"
rpath = "{}bin/".format(riscv_prefix)

def exe(cmd):
    os.system(cmd)

def clear_bin():
    exe("rm bin/*.txt")

def generate_testcase(name, disable_opt_flag):
    # clearing test dir
    exe("rm -rf test")
    exe("mkdir test")
    # compiling rom
    exe("{}riscv32-unknown-elf-as -o ./sys/rom.o -march=rv32i ./sys/rom.s".format(rpath))
    # compiling testcase
    exe("cp ./testcase/{}.c ./test/test.c".format(name))
    opt_arg = "-O2"
    if disable_opt_flag:
        opt_arg = "-O0"
    exe("{}riscv32-unknown-elf-gcc -o ./test/test.o -I ./sys -c ./test/test.c {} -march=rv32i -mabi=ilp32 -Wall".format(rpath, opt_arg))
    # linking
    exe("{rpa}riscv32-unknown-elf-ld -T ./sys/memory.ld ./sys/rom.o ./test/test.o -L {pre}/riscv32-unknown-elf/lib/ -L {pre}/lib/gcc/riscv32-unknown-elf/10.2.0/ -lc -lgcc -lm -lnosys -o ./test/test.om".format(rpa=rpath, pre=riscv_prefix))
    # converting to verilog format
    exe("{}riscv32-unknown-elf-objcopy -O verilog ./test/test.om ./test/test.data".format(rpath))
    # converting to binary format (for ram uploading)
    exe("{}riscv32-unknown-elf-objcopy -O binary ./test/test.om ./test/test.bin".format(rpath))
    # decompile (for debugging)
    exe("{}riscv32-unknown-elf-objdump -D ./test/test.om > ./test/test.dump".format(rpath))

def gen_reg_status(gen):
    if not gen:
        return
    # standard register status cpp program powered by was_n
    print("start generate standard register status...")
    exe("g++ tools/ws_cpu/CPU.cpp -std=c++2a -o std -O0")
    exe("./std < test/test.data > bin/std_register_status.txt")
    exe("rm std")
    print("generate standard register status finished.")

def iverilog_run(out_file, disable_fev_flag):
    testbench_name = "testbench"
    if disable_fev_flag:
        testbench_name = "testbench_disable_forever"
    exe("iverilog -g2012 -o bin/cpu_build -I src/ src/cpu.v src/ram.v src/riscv_top.v src/hci.v src/common/*/*.v sim/{}.v".format(testbench_name))
    print("start running cpu...")
    if out_file == "":
        exe("vvp bin/cpu_build")
    else:
        exe("vvp bin/cpu_build > {}".format(out_file))
    print("")
    print("cpu run finished.")

def run():
    # exe("set -e")
    testcase_name = "test"
    output_file = ""
    reg_gen_flag = False
    only_reg_gen_flag = False
    disable_optimize_flag = False
    disable_forever_flag = False
    i = 1
    # parse command line arguments
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg == "-o":
            if (i == len(sys.argv)):
                print("error: -o without argument")
                exit(1)
            i = i + 1
            output_file = "bin/" + sys.argv[i]
        elif arg == "-case":
            if (i == len(sys.argv)):
                print("error: -case without argument")
                exit(1)
            i = i + 1
            testcase_name = sys.argv[i]
        elif arg == "--gen-reg":
            reg_gen_flag = True
        elif arg == "--gen-reg-only":
            reg_gen_flag = True
            only_reg_gen_flag = True
        elif arg == "--disable-opt":
            disable_optimize_flag = True
        elif arg == "--disable-forever":
            disable_forever_flag = True
        else:
            print("error: unknown argument")
            exit(1)
        i = i + 1
    # execute
    if not only_reg_gen_flag:
        clear_bin()
    generate_testcase(testcase_name, disable_optimize_flag)
    gen_reg_status(reg_gen_flag)
    if only_reg_gen_flag:
        return
    iverilog_run(output_file, disable_forever_flag)

run()