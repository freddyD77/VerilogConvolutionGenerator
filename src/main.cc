// ESE 507 Project 3 Handout Code
// Fall 2019

// Getting started:
// The main() function contains the code to read the parameters. 
// For Parts 1 and 2, your code should be in the genLayer() function. Please
// also look at this function to see an example for how to create the ROMs.
//
// For Part 3, your code should be in the genAllLayers() function.



#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <cstdlib>
#include <cstring>
#include <assert.h>
#include <math.h>
using namespace std;

void printUsage();
void genLayer(int N, int M, int T, int P, vector<int>& constvector, string modName, ofstream &os);
void genAllLayers(int N, int M1, int M2, int M3, int T, int A, vector<int>& constVector, string modName, ofstream &os);
void readConstants(ifstream &constStream, vector<int>& constvector);
void genROM(vector<int>& constVector, int bits, string modName, ofstream &os);




int main(int argc, char* argv[]) {

    // If the user runs the program without enough parameters, print a helpful message
    // and quit.
    if (argc < 7) {
        printUsage();
        return 1;
    }

    int mode = atoi(argv[1]);

    ifstream const_file;
    ofstream os;
    vector<int> constVector;

    //----------------------------------------------------------------------
    // Look here for Part 1 and 2
    if ((mode == 1) && (argc == 7)) {
        // Mode 1: Generate one layer with given dimensions and one testbench

        // --------------- read parameters, etc. ---------------
        int N = atoi(argv[2]);
        int M = atoi(argv[3]);
        int T = atoi(argv[4]);
        int P = atoi(argv[5]);
        const_file.open(argv[6]);
        if (const_file.is_open() != true) {
            cout << "ERROR reading constant file " << argv[6] << endl;
            return 1;
        }

        // Read the constants out of the provided file and place them in the constVector vector
        readConstants(const_file, constVector);

        string out_file = "conv_" + to_string(N) + "_" + to_string(M) + "_" + to_string(T) + "_" + to_string(P) + ".sv";

        os.open(out_file);
        if (os.is_open() != true) {
            cout << "ERROR opening " << out_file << " for write." << endl;
            return 1;
        }
        // -------------------------------------------------------------

        // call the genLayer function you will write to generate this layer
        string modName = "conv_" + to_string(N) + "_" + to_string(M) + "_" + to_string(T) + "_" + to_string(P);
        genLayer(N, M, T, P, constVector, modName, os); 

    }
    //--------------------------------------------------------------------


    // ----------------------------------------------------------------
    // Look here for Part 3
    else if ((mode == 2) && (argc == 9)) {
        // Mode 2: Generate three layer with given dimensions and interconnect them

        // --------------- read parameters, etc. ---------------
        int N  = atoi(argv[2]);
        int M1 = atoi(argv[3]);
        int M2 = atoi(argv[4]);
        int M3 = atoi(argv[5]);
        int T  = atoi(argv[6]);
        int A  = atoi(argv[7]);
        const_file.open(argv[8]);
        if (const_file.is_open() != true) {
            cout << "ERROR reading constant file " << argv[8] << endl;
            return 1;
        }
        readConstants(const_file, constVector);

        string out_file = "multi_" + to_string(N) + "_" + to_string(M1) + "_" + to_string(M2) + "_" + to_string(M3) + "_" + to_string(T) + "_" + to_string(A) + ".sv";


        os.open(out_file);
        if (os.is_open() != true) {
            cout << "ERROR opening " << out_file << " for write." << endl;
            return 1;
        }
        // -------------------------------------------------------------

        string mod_name = "multi_" + to_string(N) + "_" + to_string(M1) + "_" + to_string(M2) + "_" + to_string(M3) + "_" + to_string(T) + "_" + to_string(A);

        // call the genAllLayers function
        genAllLayers(N, M1, M2, M3, T, A, constVector, mod_name, os);

    }
    //-------------------------------------------------------

    else {
        printUsage();
        return 1;
    }

    // close the output stream
    os.close();

}

// Read values from the constant file into the vector
void readConstants(ifstream &constStream, vector<int>& constvector) {
    string constLineString;
    while(getline(constStream, constLineString)) {
        int val = atoi(constLineString.c_str());
        constvector.push_back(val);
    }
}

// Generate a ROM based on values constVector.
// Values should each be "bits" number of bits.
void genROM(vector<int>& constVector, int bits, string modName, ofstream &os) {

        int numWords = constVector.size();
        int addrBits = ceil(log2(numWords));

        os << "module " << modName << "(clk, addr, z);" << endl;
        os << "   input clk;" << endl;
        os << "   input [" << addrBits-1 << ":0] addr;" << endl;
        os << "   output logic signed [" << bits-1 << ":0] z;" << endl;
        os << "   always_ff @(posedge clk) begin" << endl;
        os << "      case(addr)" << endl;
        int i=0;
        for (vector<int>::iterator it = constVector.begin(); it < constVector.end(); it++, i++) {
            if (*it < 0)
                os << "        " << i << ": z <= -" << bits << "'d" << abs(*it) << ";" << endl;
            else
                os << "        " << i << ": z <= "  << bits << "'d" << *it      << ";" << endl;
        }
        os << "      endcase" << endl << "   end" << endl << "endmodule" << endl << endl;
}


void gen_controlpath(int N, int M, int T, int P, string modName, ofstream &os) {

    int L = N-M+1;
    int addrF = ceil(log2(M));
    int addrX = ceil(log2(N));
    int addrACC = ceil(log2(L));    

    os << "module " << modName << "(	clk, reset, s_valid_x, s_ready_x," << endl;
    os << "			m_valid_y, m_ready_y, addr_x, wr_en_x," << endl;
    os << "			addr_f, clear_acc, en_acc, acc_addr, valid_out, bias_addr_x);" << endl;
    os << endl;
    os << "	input 			clk, reset, s_valid_x, m_ready_y, valid_out;" << endl;
    os << "	output logic    	s_ready_x, m_valid_y, wr_en_x, clear_acc, en_acc, bias_addr_x;" << endl;
    os << "		logic [1:0]		x_state, acc_state, acc_state_cntr;" << endl;
    os << "	logic ["<<addrACC<<":0]	L_cntr;" << endl;
    os << "	logic			pipeline_delay; " << endl;
    os << "	output logic ["<<addrF-1<<":0]	addr_f;" << endl;
    os << "	output logic ["<<addrX-1<<":0] addr_x;" << endl;
    os << "	output logic ["<<addrACC<<":0] acc_addr;" << endl;
    os << endl;
    os << "	always_ff @(posedge clk) begin" << endl;
    os << "	    if(reset==1) begin" << endl;
    os << "	    	s_ready_x<=1; m_valid_y<=0; addr_x<=0; bias_addr_x<=0;" << endl;
    os << "	    	addr_f<=0; clear_acc<=1; en_acc<=0; x_state<=0;" << endl;
    os << "		acc_state<=0; L_cntr <=0; acc_addr<=0; pipeline_delay<=0;" << endl;
    os << "	    end" << endl;
    os << "	    else begin" << endl;
    os << "	    //////////////////////////////////////////////////////////////x register states" << endl;
    os << "	    	if(x_state==0) begin//state 0 reading valid inputs" << endl;
    os << "		    if(s_valid_x==1) begin" << endl;
    os << "			if(addr_x=="<<N-1<<") begin //reached last address" << endl;
    os << "		    	    x_state <= 1;" << endl;
    os << "			    addr_x <= 0;" << endl;
    os << "			    s_ready_x <= 0;" << endl;
    os << "			end else begin" << endl;
    os << "			    addr_x <= addr_x + 1;" << endl;
    os << "			end" << endl;
    os << "		    end" << endl;
    os << "		end" << endl;
    os << "		/////////////////////////////////////////////////////////////acc states" << endl;
    os << "		if(acc_state==0) begin//state 0 waits for new data to finish updating" << endl;
    os << "		    acc_state_cntr <= 0;" << endl;
    os << "		    en_acc <= 0;" << endl;
    os << "		    if(x_state==1) begin" << endl;
    os << "			acc_state <= 1;" << endl;
    os << "			addr_x <= 0; addr_f <= 0;" << endl;
    os << "			L_cntr <= 1;" << endl;
    os << "			bias_addr_x <= 1;" << endl;
    os << "		    end" << endl;
    os << "		end else if(acc_state==1) begin//state 1 gives data to acc and saves result" << endl;
    os << "		    if(acc_addr == "<<L/P<<") begin" << endl;
    os << "			acc_state <= 2;" << endl;
    os << "			acc_addr <= 0;" << endl;
    os << "			en_acc <= 0;" << endl;
    os << "			addr_x <= 0; addr_f <= 0;" << endl;
    os << "			x_state <= 0;" << endl;
    os << "			s_ready_x <= 1;" << endl;
    os << "			bias_addr_x <= 0;" << endl;
    os << "		    end else begin" << endl;
    os << "			en_acc <= 1;" << endl;
    os << "		    	if(pipeline_delay==1) begin//add 1 delay due to xtra pipeline stage" << endl;
    os << "			    addr_f <= 0;" << endl;
    os << "			    addr_x <= "<<P<<"*L_cntr;" << endl;
    os << "			    L_cntr <= L_cntr + 1;" << endl;
    os << "			    acc_addr <= L_cntr;" << endl;
    os << "			    clear_acc <= 1;" << endl;
    os << "			    pipeline_delay <= 0;" << endl;
    os << "			end else if(addr_f!="<<M-1<<") begin" << endl;
    os << "			    clear_acc <= 0;" << endl;
    os << "			    addr_f <= addr_f + 1;" << endl;
    os << "			    addr_x <= addr_x + 1;" << endl;
    os << "			end else if(valid_out==1)" << endl;
    os << "			    pipeline_delay <= 1;" << endl;
    os << "		    end" << endl;
    os << "		end else if(acc_state==2) begin//state2	sends data" << endl;
    os << "		    if(m_ready_y==1) begin" << endl;
    os << "			if(m_valid_y == 1) begin" << endl;
    os << "			    if(acc_addr == "<<L-1<<") begin" << endl;
    os << "			        acc_addr <= 0;" << endl;
    os << "			        acc_state <= 0;" << endl;
    os << "			        m_valid_y <= 0;" << endl;
    os << "			    end else begin" << endl;
    os << "				acc_addr <= acc_addr + 1;" << endl;
    os << "			    	m_valid_y <= 0;" << endl;
    os << "			    end" << endl;
    os << "			end else" << endl;
    os << "			    m_valid_y <= 1;" << endl;
    os << "		    end" << endl;
    os << "		end" << endl;
    os << "	    end" << endl;
    os << "	end" << endl;
    os << endl;
    os << "	always_comb begin" << endl;
    os << "	    if(x_state==0)" << endl;
    os << "		wr_en_x = s_valid_x;" << endl;
    os << "	    else" << endl;
    os << "		wr_en_x = 0;" << endl;
    os << "	end" << endl;
    os << endl;
    os << "endmodule" << endl << endl;




}

void gen_datapath(int N, int M, int T, int P, string modName, ofstream &os, string memMod, string romMod, string mult_accMod) {

    int L = N-M+1;
    int addrF = ceil(log2(M));
    int addrX = ceil(log2(N));
    int addrACC = ceil(log2(L));


    string addr_xs[1024] = {};
    string addr_x_init = "";
    string data_out_ys[1024] = {};
    string data_out_y_init = "";
    string acc_addrs[1024] = {};
    string acc_addr_init = "";
    for(int x=0; x<=P-1; x++)
    {
	addr_xs[x] = "addr_x" + std::to_string(x);
	addr_x_init = addr_x_init + addr_xs[x] +",";
	data_out_ys[x] = "data_out_y" + std::to_string(x);
	data_out_y_init = data_out_y_init + data_out_ys[x] +",";
	acc_addrs[x] = "acc_addr" + std::to_string(x);
	acc_addr_init = acc_addr_init + acc_addrs[x] +",";
    }
    addr_x_init.pop_back();
    addr_x_init = addr_x_init + ";";
    data_out_y_init.pop_back();
    data_out_y_init = data_out_y_init + ";";
    acc_addr_init.pop_back();
    acc_addr_init = acc_addr_init + ";";


    string dout_xs[1024] = {};
    string dout_x_init = "";
    string din_ys[1024] = {};
    string din_y_init = "";
    string ReLUs[1024] = {};
    string ReLU_init = "";
    string valid_outs[1024] = {};
    string valid_out_init = "";
    if(P>1)
    {
	    for(int x=1; x<=P-1; x++)
	    {
		dout_xs[x] = "dout_x" + std::to_string(x);
		dout_x_init = dout_x_init + dout_xs[x] +",";
		din_ys[x] = "din_y" + std::to_string(x);
		din_y_init = din_y_init + din_ys[x] +",";
		ReLUs[x] = "ReLU" + std::to_string(x);
		ReLU_init = ReLU_init + ReLUs[x] +",";
		valid_outs[x] = "valid_out" + std::to_string(x);
		valid_out_init = valid_out_init + valid_outs[x] +",";
	    }
    
    dout_x_init.pop_back();
    dout_x_init = dout_x_init + ";";
    din_y_init.pop_back();
    din_y_init = din_y_init + ";";
    ReLU_init.pop_back();
    ReLU_init = ReLU_init + ";";
    valid_out_init.pop_back();
    valid_out_init = valid_out_init + ";";
    }


    os << "module " << modName << "(clk, reset, s_data_in_x, " << endl;
    os << "		addr_x, wr_en_x, addr_f, clear_acc, en_acc, " << endl;
    os << "		m_data_out_y, acc_addr, valid_out, bias_addr_x);" << endl;
    os << endl;
    os << "	input 				clk, reset, wr_en_x, clear_acc, en_acc, bias_addr_x;" << endl;
    os << "	input signed ["<<T-1<<":0] 		s_data_in_x;" << endl;
    os << "	input ["<<addrF-1<<":0]		addr_f;" << endl;
    os << "	input ["<<addrX-1<<":0]		addr_x;" << endl;
    os << "	output logic signed ["<<T-1<<":0] m_data_out_y;" << endl;
    os << "	logic ["<<T-1<<":0]			dout_x, dout_f;" << endl;
    os << "	logic signed ["<<T-1<<":0]	din_y, ReLU;" << endl;
    os << "	input ["<<addrACC<<":0]		acc_addr;" << endl;
    os << "	output logic 			valid_out;" << endl;
    if(P>1)
    {
    	os << "	logic ["<<addrX-1<<":0]		"<<addr_x_init<< endl;
    	os << "	logic ["<<T-1<<":0]			"<<dout_x_init<< endl;
    	os << "	logic signed ["<<T-1<<":0]			"<<din_y_init<< endl;
    	os << "	logic signed ["<<T-1<<":0]			"<<ReLU_init<< endl;
	os << "	logic signed ["<<T-1<<":0]			"<<data_out_y_init<< endl;
	os << "	logic ["<<addrACC<<":0]		"<<acc_addr_init << endl;
	os << "	logic 			"<<valid_out_init << endl;
    	os << endl;
    }
    os << endl;

    if(P==1)
    {
    	os << "	"<<memMod<<" #("<<N<<", "<<addrX<<") memX(clk, s_data_in_x, dout_x, addr_x, wr_en_x);" << endl;
    	os << "	"<<romMod<<" my_rom(clk, addr_f, dout_f);" << endl;
    	os << "	"<<memMod<<" #("<<L<<", "<<addrACC+1<<") memY(clk, ReLU, m_data_out_y, acc_addr, valid_out);" << endl;
    	os << "	"<<mult_accMod<<" my_mult_acc(clk, clear_acc, dout_x, dout_f, en_acc, din_y, valid_out);" << endl;
    }
    else
    {
    	os << "	"<<memMod<<" #("<<N<<", "<<addrX<<") memX(clk, s_data_in_x, dout_x, addr_x0, wr_en_x);" << endl;
    	os << "	"<<romMod<<" my_rom(clk, addr_f, dout_f);" << endl;
    	os << "	"<<memMod<<" #("<<L<<", "<<addrACC+1<<") memY(clk, ReLU, data_out_y0, acc_addr0, valid_out);" << endl;
    	os << "	"<<mult_accMod<<" my_mult_acc(clk, clear_acc, dout_x, dout_f, en_acc, din_y, valid_out);" << endl;
	for(int x=1; x <= P-1; x++)
	{
    	    os << "	"<<memMod<<" #("<<N<<", "<<addrX<<") memX"<<x<<"(clk, s_data_in_x,"<<dout_xs[x]<<","<<addr_xs[x]<<", wr_en_x);" << endl;
    	    os << "	"<<memMod<<" #("<<L<<", "<<addrACC+1<<") memY"<<x<<"(clk,"<<ReLUs[x]<<","<<data_out_ys[x]<<","<<acc_addrs[x]<<","<<valid_outs[x]<<");" << endl;
    	    os << "	"<<mult_accMod<<" my_mult_acc"<<x<<"(clk, clear_acc,"<<dout_xs[x]<<", dout_f, en_acc,"<<din_ys[x]<<","<<valid_outs[x]<<");" << endl;
	}
    }
    os << endl;

    if(P==1)
    {
    	os << "	always_comb begin" << endl;
    	os << "	    if(din_y < 0)" << endl;
    	os << "		ReLU = 0;" << endl;
    	os << "	    else" << endl;
    	os << "		ReLU = din_y;" << endl;
    	os << "    end" << endl;
    	os << endl;
    }
    else
    {
    	os << "	always_comb begin" << endl;
    	os << "	    if(din_y < 0)" << endl;
    	os << "		ReLU = 0;" << endl;
    	os << "	    else" << endl;
    	os << "		ReLU = din_y;" << endl;
	for(int x=1; x<=P-1; x++)
	{
    	    os << "	    if("<<din_ys[x]<<" < 0)" << endl;
    	    os << "		"<<ReLUs[x]<<" = 0;" << endl;
    	    os << "	    else" << endl;
    	    os << "		"<<ReLUs[x]<<" = "<<din_ys[x]<<";" << endl;	    
	}
    	os << "	    if(en_acc == 1 || bias_addr_x == 1) begin" << endl;
	for(int x=0; x<=P-1; x++)
	{
    	    os << "	   	"<<addr_xs[x]<<" = addr_x+"<<x<<";" << endl;
    	    os << "	        "<<acc_addrs[x]<<" = ("<<P<<"*acc_addr)+"<<x<<";" << endl;
    	}
    	os << "	    end else begin" << endl;
	for(int x=0; x<=P-1; x++)
	{
    	    os << "	   	"<<addr_xs[x]<<" = addr_x;" << endl;
    	    os << "	        "<<acc_addrs[x]<<" = acc_addr;" << endl;
    	}
    	os << "    	end" << endl;
    	os << "	    case(acc_addr % "<<P<<")" << endl;
	for(int x=0; x<=P-1; x++)
	{
    	    os << "		"<<ceil(log2(P))<<"'d"<<x<<": m_data_out_y = "<<data_out_ys[x]<<";" << endl;
    	}
    	os << "	    endcase" << endl;//end f case
    	os << "    	end" << endl;//end of always comb
    	os << endl;
    }
	
    	os << "endmodule" << endl << endl;//end of mod

}

void gen_memory(int N, int M, int T, int P, string modName, ofstream &os) {

	os << "module " << modName << "(clk, data_in, data_out, addr, wr_en);" << endl;
        os << "    parameter                   		SIZE=64, LOGSIZE=6;" << endl;
        os << "    input ["<<T-1<<":0]			data_in;" << endl;
        os << "    output logic ["<<T-1<<":0]   	data_out;" << endl;
        os << "    input [LOGSIZE-1:0]         		addr;" << endl;
        os << "    input                       		clk, wr_en;" << endl;
        os << "    logic [SIZE-1:0]["<<T-1<<":0]	mem;" << endl;
	os << endl;
        os << "    always_ff @(posedge clk) begin" << endl;
        os << "	    data_out <= mem[addr];" << endl;
        os << "	    if (wr_en)" << endl;
        os << "		mem[addr] <= data_in;" << endl;
        os << "    end" << endl;
    	os << "endmodule" << endl << endl;

}

void gen_mult_acc(int N, int M, int T, int P, string modName, ofstream &os) {

    int bigWidth = (2*T)+(ceil(log2(M)));
    long negBound = -pow(2, T-1)+1;
    long posBound = pow(2, T-1);

    os << "module " << modName << "(clk, reset, a, b, valid_in, f, valid_out);" << endl;
    os << "    input 				clk, reset, valid_in;" << endl;
    os << "    input signed ["<<T-1<<":0] 		a, b; " << endl;
    os << "    output logic signed ["<<T-1<<":0] 	f;" << endl;
    os << "    output logic 			valid_out;" << endl;
    os << "    logic signed ["<<bigWidth-1<<":0] 		sum, product;" << endl;
    os << "    logic ["<<M-1<<":0]			sum_count;" << endl;
    os << "    logic				pipeline_delay;" << endl;
    os << endl;
    os << "    localparam signed ["<<bigWidth-1<<":0] MAXVAL = "<<bigWidth<<"'d"<<posBound-1<<"; " << endl;
    os << "    localparam signed ["<<bigWidth-1<<":0] MINVAL = -"<<bigWidth<<"'d"<<posBound<<"; " << endl;
    os << endl;
    os << "    always_ff @(posedge clk) begin" << endl;
    os << "        if(reset == 1) begin" << endl;
    os << "	    f <= 0;" << endl;
    os << "	    valid_out <= 0;" << endl;
    os << "	    sum_count <= 0;" << endl;
    os << "	    product <= 0;" << endl;
    os << "	    pipeline_delay <= 0;" << endl;
    os << "	end" << endl;
    os << "	else begin" << endl;
    os << "	    if(valid_in == 1) begin" << endl;
    os << "		if( sum < MINVAL )" << endl;
    os << "		    f <= -"<<T<<"'d"<<posBound<<"; " << endl;
    os << "		else if ( sum > MAXVAL )" << endl;
    os << "		    f <= "<<T<<"'d"<<posBound-1<<"; " << endl;
    os << "		else" << endl;
    os << "	    	    f <= sum;" << endl;
    os << "		if( a*b < MINVAL )" << endl;
    os << "		    product <= -"<<T<<"'d"<<posBound<<"; " << endl;
    os << "		else if ( a*b > MAXVAL)" << endl;
    os << "		    product <= "<<T<<"'d"<<posBound-1<<"; " << endl;
    os << "		else" << endl;
    os << "	    	    product <= a*b;" << endl;
    os << "		if(pipeline_delay == 1) begin" << endl;
    os << "	    	    valid_out <= 1;" << endl;
    os << "		    sum_count <= 0;" << endl;
    os << "		    pipeline_delay <= 0;" << endl;
    os << "		end else if(sum_count == "<<M-1<<")" << endl;
    os << "		    pipeline_delay <= 1;" << endl;
    os << "	    	else begin" << endl;
    os << "		    valid_out <= 0;" << endl;
    os << "		    sum_count <= sum_count + 1;" << endl;
    os << "		end" << endl;
    os << "	    end" << endl;
    os << "	end" << endl;
    os << "    end" << endl;
    os << endl;
    os << "    always_comb begin" << endl;
    os << "	sum = product+f;" << endl;
    os << "    end " << endl;
    os << "endmodule" << endl << endl;




}


// Parts 1 and 2
// Here is where you add your code to produce a neural network layer.
void genLayer(int N, int M, int T, int P, vector<int>& constVector, string modName, ofstream &os) {

    string controlpathModName = "controlpath_" + to_string(N) + "_" + to_string(M) + "_" + to_string(T) + "_" + to_string(P);
    string datapathModName = "datapath_" + to_string(N) + "_" + to_string(M) + "_" + to_string(T) + "_" + to_string(P);
    string memModName = "memory_" + to_string(N) + "_" + to_string(M) + "_" + to_string(T) + "_" + to_string(P);
    string romModName = modName + "_f_rom";
    string mult_accModName = "mult_acc_" + to_string(N) + "_" + to_string(M) + "_" + to_string(T) + "_" + to_string(P);

    int L = N-M+1;
    int addrF = ceil(log2(M));
    int addrX = ceil(log2(N));
    int addrACC = ceil(log2(L));

    os << "module " << modName << "(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y, m_valid_y, m_ready_y);" << endl;
    os << "   // your stuff here!" << endl;
    os << "	input 				clk, reset, s_valid_x, m_ready_y;" << endl;
    os << "	input signed ["<<T-1<<":0] 		s_data_in_x;" << endl;
    os << "	output logic        		s_ready_x, m_valid_y;" << endl;
    os << "	output logic signed ["<<T-1<<":0] m_data_out_y;" << endl;
    os << "	logic ["<<addrF-1<<":0]		addr_f;" << endl;
    os << "	logic ["<<addrX-1<<":0]		addr_x;" << endl;
    os << "	logic ["<<addrACC<<":0]		acc_addr;" << endl;
    os << "	logic 					wr_en_x, clear_acc, en_acc, valid_out, bias_addr_x;" << endl;
    os << endl;
    os << "	"<<controlpathModName<<" mycontrolpath(	clk, reset, s_valid_x, s_ready_x, m_valid_y, m_ready_y," << endl;
    os << "					addr_x, wr_en_x,addr_f, clear_acc, en_acc, acc_addr," << endl;
    os << "					valid_out, bias_addr_x);" << endl;
    os << endl;
    os << "	"<<datapathModName<<" mydatapath(	clk, reset, s_data_in_x, addr_x, wr_en_x, addr_f, clear_acc, en_acc," << endl;
    os << "				m_data_out_y, acc_addr, valid_out, bias_addr_x);" << endl;
    os << endl;
    os << "endmodule" << endl << endl;

    // At some point you will want to generate a ROM with values from the pre-stored constant values.
    // Here is code that demonstrates how to do this for the simple case where you want to put all of
    // the matrix values W in one ROM, and all of the bias values B into another ROM. (This is probably)
    // all that you will need for the ROMs.

    // Check there are enough values in the constant file.
    if (M > constVector.size()) {
        cout << "ERROR: constVector does not contain enough data for the requested design" << endl;
        cout << "The design parameters requested require " << M << " numbers, but the provided data only have " << constVector.size() << " constants" << endl;
        assert(false);
    }

    // Generate a ROM for f with constants in constVector, T bits, and the given name

    gen_controlpath(N, M, T, P, controlpathModName, os);
    gen_datapath(N, M, T, P, datapathModName, os, memModName, romModName, mult_accModName);
    genROM(constVector, T, romModName, os);
    gen_memory(N, M, T, P, memModName, os);
    gen_mult_acc(N, M, T, P, mult_accModName, os);



}




// Part 3: Generate a hardware system with three layers interconnected.
// Layer 1: Input length: N, filter length: M1, output length: L1 = N-M1+1
// Layer 2: Input length: L1, filter length: M2, output length: L2 = L1-M2+1
// Layer 3: Input length: M2, filter length: M3, output length: L3 = L2-M3+1
// T is the number of bits
// A is the number of multipliers your overall design may use.
// Your goal is to build the highest-throughput design that uses A or fewer multipliers
// constVector holds all the constants for your system (all three layers, in order)
void genAllLayers(int N, int M1, int M2, int M3, int T, int A, vector<int>& constVector, string modName, ofstream &os) {

    // Here you will write code to figure out the best values to use for P1, P2, and P3, given
    // mult_budget. 
    int P1 = 1; // replace this with your optimized value
    int P2 = 1; // replace this with your optimized value
    int P3 = 1; // replace this with your optimized value
    int L1 = N-M1+1;
    int L2 = L1-M2+1;
    int L3 = L2-M3+1;
    int resources = A-3;//we start out with 3 multiply-adders already
    int speed1 = L1;
    int speed2 = L2;
    int speed3 = L3;
    int count1 = 2;
    int count2 = 2;
    int count3 = 2;
    int B = A;
    
    cout << "while loop started"<<endl;
    while(resources >= P1 || resources >= P2 || resources >= P3)
    {
	while(speed1 >= speed2 && speed1 >= speed3)
	{
	    while(L1%count1!=0)
	    {
		count1++;
	    }
	    if(resources+P1-count1<0 || speed1==1)
		break;
	    P1 = count1++;
	    resources = B-(P3+P2+P1);
	    speed1 = L1/P1;
	    cout << resources<<" "<<P1<<" "<<P2<<" "<<P3<<" L1spot"<<endl;
	}
	if((speed1 >= speed3 && speed1 >= speed2) && (resources+P1-count1<0  || speed1==1))
	    break;

	while(speed2 >= speed1 && speed2 >= speed3)
	{
	    while(L2%count2!=0)
	    {
		count2++;
	    }
	    if(resources+P2-count2<0 || speed2==1)
		break;
	    P2 = count2++;
	    resources = B-(P3+P2+P1);
	    speed2 = L2/P2;
	    cout << resources<<" "<<P1<<" "<<P2<<" "<<P3<<" L2spot"<<endl;
	}
	if((speed2 >= speed1 && speed2 >= speed3) && (resources+P2-count2<0  || speed2==1))
	    break;

	while(speed3 >= speed1 && speed3 >= speed2)
	{
	    while(L3%count3!=0)
	    {
		count3++;
	    }
	    if(resources+P3-count3<0  || speed3==1)
		break;
	    P3 = count3++;
	    resources = B-(P3+P2+P1);
	    speed3 = L3/P3;
	    cout << resources<<" "<<P1<<" "<<P2<<" "<<P3<<" L3spot"<<endl;
	}
	if((speed3 >= speed1 && speed3 >= speed2) && (resources+P3-count3<0  || speed3==1))
	    break;

	if(speed1==1 && speed2==1 && speed3==1)
	    break;
    }
    cout << "while loop ended"<<endl;
    cout << resources<<" "<<P1<<" "<<P2<<" "<<P3<<" optimized Ps"<<endl;


    string subModName1 = "layer1_" + to_string(N) + "_" + to_string(M1) + "_" + to_string(T) + "_" + to_string(P1);
    string subModName2 = "layer2_" + to_string(L1) + "_" + to_string(M2) + "_" + to_string(T) + "_" + to_string(P2);
    string subModName3 = "layer3_" + to_string(L2) + "_" + to_string(M2) + "_" + to_string(T) + "_" + to_string(P3);

    // output top-level module


    os << "module " << modName << "(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y, m_valid_y, m_ready_y);" << endl;
    os << endl;
    os << "	input 				clk, reset, s_valid_x, m_ready_y;" << endl;
    os << "	input signed ["<<T-1<<":0] 		s_data_in_x;" << endl;
    os << "	output logic        		s_ready_x, m_valid_y;" << endl;
    os << "	output logic signed ["<<T-1<<":0] m_data_out_y;" << endl;
    os << "	logic 				m_valid_y0, m_valid_y1, m_ready_y0, m_ready_y1;" << endl;
    os << "	logic signed ["<<T-1<<":0]		m_data_out_y0, m_data_out_y1;" << endl;
    os << endl;
    os << "	"<<subModName1<<" conv1(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y0, m_valid_y0, m_ready_y0);" << endl;
    os << "	"<<subModName2<<" conv2(clk, reset, m_data_out_y0, m_valid_y0, m_ready_y0, m_data_out_y1, m_valid_y1, m_ready_y1);" << endl;
    os << "	"<<subModName3<<" conv3(clk, reset, m_data_out_y1, m_valid_y1, m_ready_y1, m_data_out_y, m_valid_y, m_ready_y);" << endl;
    os << endl;
    os << "endmodule" << endl << endl;





    // -------------------------------------------------------------------------
    // Split up constVector for the three layers
    int start = 0;
    int stop = M1;
    vector<int> constVector1(&constVector[start], &constVector[stop]);

    // layer 2's W matrix is M2 x M1 and its B vector has size M2
    start = stop;
    stop = start+M2;
    vector<int> constVector2(&constVector[start], &constVector[stop]);

    // layer 3's W matrix is M3 x M2 and its B vector has size M3
    start = stop;
    stop = start+M3;
    vector<int> constVector3(&constVector[start], &constVector[stop]);

    if (stop > constVector.size()) {
        cout << "ERROR: constVector does not contain enough data for the requested design" << endl;
        cout << "The design parameters requested require " << stop << " numbers, but the provided data only have " << constVector.size() << " constants" << endl;
        assert(false);
    }
    // --------------------------------------------------------------------------


    // generate the three layer modules

    genLayer(N, M1, T, P1, constVector1, subModName1, os);
    


    genLayer(L1, M2, T, P2, constVector2, subModName2, os);



    genLayer(L2, M3, T, P3, constVector3, subModName3, os);

    // You will need to add code in the module at the top of this function to stitch together insantiations of these three modules

}



void printUsage() {
    cout << "Usage: ./gen MODE ARGS" << endl << endl;

    cout << "   Mode 1: Produce one convolution module (Part 1 and Part 2)" << endl;
    cout << "      ./gen 1 N M T P const_file" << endl;
    cout << "      See project description for explanation of parameters." << endl;
    cout << "      Example: produce a convolution with input vector of length 16, filter of length 4, parallelism 1" << endl;
    cout << "               and 16 bit words, with constants stored in file const.txt" << endl;
    cout << "                   ./gen 1 16 4 16 1 const.txt" << endl << endl;

    cout << "   Mode 2: Produce a system with three interconnected convolution module (Part 3)" << endl;
    cout << "      Arguments: N, M1, M2, M3, T, A, const_file" << endl;
    cout << "      See project description for explanation of parameters." << endl;
    cout << "              e.g.: ./gen 2 16 4 5 6 15 16 const.txt" << endl << endl;
}
