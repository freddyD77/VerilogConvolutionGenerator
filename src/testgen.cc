// Peter Milder
// Testbench Generator for Project 3, ESE 507 Fall 2019
// This code may not be redistributed

#include <iostream>
#include <fstream>
#include <vector>
#include <time.h>
#include <cstdlib>
#include <cstdio>
#include <bitset>

using namespace std;

void printUsage();
void genRandomVector(vector<long>& v, int size, int bits);
void computeOutputs(vector<long>& B, vector<long>& x, vector<long>& y, int N, int M, int T);
long saturate(long v, int bits);
string hexString(long v, int bits);

int main(int argc, char* argv[]) {

    int approxInputs = 10000;

    srand(time(NULL)); // initialize random number generator

    if (argc < 6) {
        printUsage();
        return 1;
    }

    int mode = atoi(argv[1]);
    int numInputs;
    string constFileName;
    ofstream os;
    string tb_name;
    int T;
    vector<long> outputVals;
    string inFileName, outFileName, dut_name, out_file;



    // Mode 1: for parts 1/2: testbench for a single convolution
    if ((mode == 1) && (argc == 6)) {
        int N = atoi(argv[2]);
        int M = atoi(argv[3]);
        T = atoi(argv[4]);
        int P = atoi(argv[5]);

        numInputs = approxInputs - (approxInputs%N);
        if (numInputs < N) {
            cout << "ERROR: N > numInputs" << endl;
            return 1;
        }

        // step 1: generate M random values (for f vector).
        //         store them in vector here, and also output them to a file
        // We are going to generate all constants to use only (T/2)+1 bits in order to 
        // make saturations relatively rare -- about 20% to 30% of operations
        vector<long> fVector;
        genRandomVector(fVector, M, (T/2)+1);

        // Store the constants to a file named const_N_M_T_P.txt
        constFileName = "const_" + to_string(N) + "_" + to_string(M) + "_" + to_string(T) + "_" + to_string(P) + ".txt";
        os.open(constFileName);
        if (!os.is_open()) {
            cout << "ERROR opening " << constFileName << " for writing." << endl;
            return 1;
        }
        for (int i=0; i<M; i++) {
            os << fVector[i] << endl;
        }
        os.close();

        // step 2: generate random input values
        vector<long> inputVals;
        genRandomVector(inputVals, numInputs, (T/2)+1);

        inFileName = "tb_conv_" + to_string(N) + "_" + to_string(M) + "_" + to_string(T) + "_" + to_string(P) + ".in";
        os.open(inFileName);
        if (!os.is_open()) {
            cout << "ERROR opening " << inFileName << " for writing." << endl;
            return 1;
        }
        for (int i=0; i<numInputs; i++) {
            string s = bitset<32>(inputVals[i]).to_string();         
            os << s.substr(32-T, 32) << endl;
        }
        os.close();

        // step 3: compute expected outputs. output them to a file
        computeOutputs(fVector, inputVals, outputVals, N, M, T);

        outFileName = "tb_conv_" + to_string(N) + "_" + to_string(M) + "_" + to_string(T) + "_" + to_string(P) + ".exp";
        os.open(outFileName);
        if (!os.is_open()) {
            cout << "ERROR opening " << outFileName << " for writing." << endl;
            return 1;
        }
        for (int i=0; i<outputVals.size(); i++) {
            string s = bitset<32>(outputVals[i]).to_string();         
            os << s.substr(32-T, 32) << endl;
        }
        os.close();

        dut_name = "conv_" + to_string(N) + "_" + to_string(M) + "_" + to_string(T) + "_" + to_string(P);
        tb_name = "tb_" + dut_name;
        out_file = tb_name + ".sv";

    }

    else if ((mode == 2) && (argc == 8)) {
        int N  = atoi(argv[2]);
        int M1 = atoi(argv[3]);
        int M2 = atoi(argv[4]);
        int M3 = atoi(argv[5]);
        T = atoi(argv[6]);
        int mult_budget = atoi(argv[7]);

        numInputs = approxInputs - (approxInputs%N);
        if (numInputs < N) {
            cout << "ERROR: N > numInputs" << endl;
            return 1;
        }

        // step 1: generate three vectors for filters
        // store them in vectors and output them to the constant file
        vector<long>  fVector1, fVector2, fVector3;
        genRandomVector(fVector1, M1, (T/2)+1);
        genRandomVector(fVector2, M2, (T/2)+1);
        genRandomVector(fVector3, M3, (T/2)+1);

        constFileName = "const_" + to_string(N) + "_" + to_string(M1) + "_" + to_string(M2) + "_" + to_string(M3) + "_" + to_string(T) + "_" + to_string(mult_budget) + ".txt";

        os.open(constFileName);
        if (!os.is_open()) {
            cout << "ERROR opening " << constFileName << " for writing." << endl;
            return 1;
        }
        for (int i=0; i<M1; i++) 
            os << fVector1[i] << endl;
        for (int i=0; i<M2; i++) 
            os << fVector2[i] << endl;
        for (int i=0; i<M3; i++) 
            os << fVector3[i] << endl;
        os.close();

        // step 2: generate input values
        vector<long> inputVals;
        genRandomVector(inputVals, numInputs, (T/2)+1);

        inFileName = "tb_multi_" + to_string(N) + "_" + to_string(M1) + "_" + to_string(M2) + "_" + to_string(M3) + "_" + to_string(T) + "_" + to_string(mult_budget) + ".in";
        os.open(inFileName);
        if (!os.is_open()) {
            cout << "ERROR opening " << inFileName << " for writing." << endl;
            return 1;
        }
        for (int i=0; i<numInputs; i++) {
            string s = bitset<32>(inputVals[i]).to_string();         
            os << s.substr(32-T, 32) << endl;
        }
        os.close();

        // step 3: compute expected outputs
        vector<long> intermediateVals1, intermediateVals2;
        computeOutputs(fVector1, inputVals,         intermediateVals1, N,  M1, T);
        int L1 = N-M1+1;
        computeOutputs(fVector2, intermediateVals1, intermediateVals2, L1, M2, T);
        int L2 = L1-M2+1;
        computeOutputs(fVector3, intermediateVals2, outputVals,        L2, M3, T);

        outFileName = "tb_multi_" + to_string(N) + "_" + to_string(M1) + "_" + to_string(M2) + "_" + to_string(M3) + "_" + to_string(T) + "_" + to_string(mult_budget) + ".exp";
        os.open(outFileName);
        if (!os.is_open()) {
            cout << "ERROR opening " << outFileName << " for writing." << endl;
            return 1;
        }
        for (int i=0; i<outputVals.size(); i++) {
            string s = bitset<32>(outputVals[i]).to_string();         
            os << s.substr(32-T, 32) << endl;
        }
        os.close();
        dut_name = "multi_" + to_string(N) + "_" + to_string(M1) + "_" + to_string(M2) + "_" + to_string(M3) + "_" + to_string(T) + "_" + to_string(mult_budget);
        tb_name = "tb_" + dut_name;
        out_file = tb_name + ".sv";

    }
    else {
        printUsage();
        return 1;
    }

    // step 4: generate the testbench .sv file
    // To do this, I wrote a template called tbtemplate.txt.
    // This is the .sv file we want but a number of things need to be filled in based on
    // this design. So, we will use the command line tool "sed" to do the substituions.
    // This code could run outside of our program in a shell script, but it's very convenient
    // to include it here.
    string myCmd = "cat tbtemplate.txt";
    myCmd += "| sed 's/<TBMODULENAME>/" + tb_name + "/g; ";
    myCmd += " s/<NUMBITS>/" + to_string(T)  + "/g;";
    myCmd += " s/<NUMINPUTVALS>/" + to_string(numInputs)  + "/g;";
    myCmd += " s/<NUMOUTPUTVALS>/" + to_string(outputVals.size())  + "/g;";
    myCmd += " s/<INFILENAME>/" +  inFileName + "/g;";
    myCmd += " s/<EXPFILENAME>/" +  outFileName + "/g;";
    myCmd += " s/<DUTNAME>/" +  dut_name + "/g;";
    myCmd += "' > " + out_file;
    system(myCmd.c_str());
}


// Compute the expected output values 
void computeOutputs(vector<long>& f, vector<long>& x, vector<long>& y, int N, int M, int T) {
    int iterations = x.size()/N;
    int L = N-M+1;
    for (int i=0; i<iterations; i++) {
        for (int n=0; n<L; n++) {
            y.push_back(0);
            for (int k=0; k<M; k++) {
                long prod = saturate(f[k]*x[n+k+i*N], T);
                y[n+i*L] = saturate(y[n+i*L] + prod, T);
            }
            y[n+i*L] = (y[n+i*L] < 0) ? 0 : y[n+i*L]; // ReLU
        }
    }
}

// Check to see if v will saturate, and if so, return the appropriate saturation value
long saturate(long v, int bits) {
    long maxVal = ((long)1<<(bits-1))-1;
    long minVal = -1*((long)1<<(bits-1));
    long ovVal = ((long)1 << bits);
  
    if (v > maxVal) {
        return maxVal;
    }
    if (v < minVal) {
        return minVal;
    }
    return v;
}


// Generate a random vector of given size with the given number of bits
void genRandomVector(vector<long>& v, int size, int bits) {
    for (int i=0; i<size; i++)
        v.push_back(rand()%(1<<bits)-(1<<(bits-1)));     
}

void printUsage() {
    cout << "usage: ./testgen mode ARGS" << endl;
    cout << "   Mode 1: Testbench for Mode 1 designs (Part 1 and Part 2)" << endl;
    cout << "      ./testgen 1 N M T P" << endl;
    cout << "      Example: produce a testbench for given parameters" << endl;
    cout << "      Note that P does not affect the testbench, but we need it so the" << endl;
    cout << "      testbench's instantiation of your system matches the specification" << endl; 

    cout << "   Mode 2: Testbench for three interconnected layers (Part 3)" << endl;
    cout << "      Arguments: N, M1, M2, M3, T, A (multiplier budget), const_file" << endl;
    cout << "              e.g.: ./testgen 16 4 5 6 7 15 16" << endl << endl;
}
