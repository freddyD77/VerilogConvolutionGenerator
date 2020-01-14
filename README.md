# VerilogConvolutionGenerator
C++ file that generates adjustable system verilog code that implements a 3 stage convolution network.

The file will generate verilog based off inputs taken from the command terminal. A testbench for the generated code will also be generated. Note that the code used to generate testbenches was provided by the professor of the course.

To generate a design, a testbench, and run simulation (in ModelSim), type ./testnetwork N M1 M2 M3 T A into the terminal:

N is the amount of numbers to be convolved, M1 is the amount numbers used to perform convolution of the first layer, M2 is similarly for the second layer, and M3 for the third layer. T is the bit length of all numbers. A is the amount of resources that are made available to tge whole network (ex an A of 10 allows for upto 10 multiply-accumulators to be used in the design). An algorithm was developed to optimize parallelism based off resources A.
