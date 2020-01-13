ESE-507 Fall 2019
Project 3 
Handout Code with Testbench Generator

Please see comments in main.cc for information about how this code is structured.

To compile your code, run: 
      make

------------------------------------------------------

For Part 1 and Part 2, run the generator with:
      ./gen 1 N N T P const_file

As an example, you can try this with N=16, M=4, T=20, P=1, and const_file = const.txt:
      ./gen 1 16 4 20 1 const.txt

Then see the result in conv_16_4_20_1.sv

However you will need to create a const.txt file. A simple way to do this is to use our test scripts.
See below.


------------------------------------------------------

For Part 3, run the generator with:
      ./gen 2 N M1 M2 M3 T A const_file

As an example, you can try this with N=64, M1 = 33, M2=9, M3=10, T=16 bits, A=14, and 
const_file = const.txt, you would run:

      ./gen 2 33 9 10 16 14 const.txt

Then see the result in multi_64_33_9_10_16_14.sv

However you will need to create a const.txt file. A simple way to do this is to use our test scripts.
See below.

------------------------------------

Testing:

The testbench generator produces a .sv testbench file as well as three data files
that specify the input values to test, the expected output values, and the
constants for f.

The testbench produces output files whose names are related to parameters you 
pick.

For mode 1: run the testbench generator with:
    ./testgen 1 N M T P
where you replace M N P and T with your values for those parameters.

This will produce four files:
- tb_conv_N_M_T_P.sv  - the testbench file
- tb_conv_N_M_T_P.in  - the inputs to test
- tb_conv_N_M_T_P.exp - the expected results
- const_N_M_T_P.txt    - the constants to give your generator

Then, you would generate the accompanying code with:
   ./gen 1 N M T P const_N_M_T_P.txt
This will produce your conv_N_M_T_P.sv file.

Then, to simulate:
   vlog conv_N_M_T_P.sv tb_conv_N_M_T_P.sv
   vsim tb_conv_N_M_T_P

The simulation will report any errors.


For mode 2: everything works similarly, except you run the test with
   ./testgen 2 N M1 M2 M3 T A
where N, M1, M2, and M3 control the dimensions of the convolutions (see the
project specification), A is the multiplier budget, and T is the bit-width.


-------------------------

Test scripts:

To test your designs, we have provided you with two test scripts. You will
give a test script your parameters, and it will generate the testbench,
generate the design, and simulate it for you. 

To test, run:

./testmodeone N M T P

or 

./testmodetwo N M1 M2 M3 T A
