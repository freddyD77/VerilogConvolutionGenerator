module multi_64_33_9_10_16_3(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y, m_valid_y, m_ready_y);

	input 				clk, reset, s_valid_x, m_ready_y;
	input signed [15:0] 		s_data_in_x;
	output logic        		s_ready_x, m_valid_y;
	output logic signed [15:0] m_data_out_y;
	logic 				m_valid_y0, m_valid_y1, m_ready_y0, m_ready_y1;
	logic signed [15:0]		m_data_out_y0, m_data_out_y1;

	layer1_64_33_16_1 conv1(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y0, m_valid_y0, m_ready_y0);
	layer2_32_9_16_1 conv2(clk, reset, m_data_out_y0, m_valid_y0, m_ready_y0, m_data_out_y1, m_valid_y1, m_ready_y1);
	layer3_24_9_16_1 conv3(clk, reset, m_data_out_y1, m_valid_y1, m_ready_y1, m_data_out_y, m_valid_y, m_ready_y);

endmodule

module layer1_64_33_16_1(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y, m_valid_y, m_ready_y);
   // your stuff here!
	input 				clk, reset, s_valid_x, m_ready_y;
	input signed [15:0] 		s_data_in_x;
	output logic        		s_ready_x, m_valid_y;
	output logic signed [15:0] m_data_out_y;
	logic [5:0]		addr_f;
	logic [5:0]		addr_x;
	logic [5:0]		acc_addr;
	logic 					wr_en_x, clear_acc, en_acc, valid_out, bias_addr_x;

	controlpath_64_33_16_1 mycontrolpath(	clk, reset, s_valid_x, s_ready_x, m_valid_y, m_ready_y,
					addr_x, wr_en_x,addr_f, clear_acc, en_acc, acc_addr,
					valid_out, bias_addr_x);

	datapath_64_33_16_1 mydatapath(	clk, reset, s_data_in_x, addr_x, wr_en_x, addr_f, clear_acc, en_acc,
				m_data_out_y, acc_addr, valid_out, bias_addr_x);

endmodule

module controlpath_64_33_16_1(	clk, reset, s_valid_x, s_ready_x,
			m_valid_y, m_ready_y, addr_x, wr_en_x,
			addr_f, clear_acc, en_acc, acc_addr, valid_out, bias_addr_x);

	input 			clk, reset, s_valid_x, m_ready_y, valid_out;
	output logic    	s_ready_x, m_valid_y, wr_en_x, clear_acc, en_acc, bias_addr_x;
		logic [1:0]		x_state, acc_state, acc_state_cntr;
	logic [5:0]	L_cntr;
	logic			pipeline_delay; 
	output logic [5:0]	addr_f;
	output logic [5:0] addr_x;
	output logic [5:0] acc_addr;

	always_ff @(posedge clk) begin
	    if(reset==1) begin
	    	s_ready_x<=1; m_valid_y<=0; addr_x<=0; bias_addr_x<=0;
	    	addr_f<=0; clear_acc<=1; en_acc<=0; x_state<=0;
		acc_state<=0; L_cntr <=0; acc_addr<=0; pipeline_delay<=0;
	    end
	    else begin
	    //////////////////////////////////////////////////////////////x register states
	    	if(x_state==0) begin//state 0 reading valid inputs
		    if(s_valid_x==1) begin
			if(addr_x==63) begin //reached last address
		    	    x_state <= 1;
			    addr_x <= 0;
			    s_ready_x <= 0;
			end else begin
			    addr_x <= addr_x + 1;
			end
		    end
		end
		/////////////////////////////////////////////////////////////acc states
		if(acc_state==0) begin//state 0 waits for new data to finish updating
		    acc_state_cntr <= 0;
		    en_acc <= 0;
		    if(x_state==1) begin
			acc_state <= 1;
			addr_x <= 0; addr_f <= 0;
			L_cntr <= 1;
			bias_addr_x <= 1;
		    end
		end else if(acc_state==1) begin//state 1 gives data to acc and saves result
		    if(acc_addr == 32) begin
			acc_state <= 2;
			acc_addr <= 0;
			en_acc <= 0;
			addr_x <= 0; addr_f <= 0;
			x_state <= 0;
			s_ready_x <= 1;
			bias_addr_x <= 0;
		    end else begin
			en_acc <= 1;
		    	if(pipeline_delay==1) begin//add 1 delay due to xtra pipeline stage
			    addr_f <= 0;
			    addr_x <= 1*L_cntr;
			    L_cntr <= L_cntr + 1;
			    acc_addr <= L_cntr;
			    clear_acc <= 1;
			    pipeline_delay <= 0;
			end else if(addr_f!=32) begin
			    clear_acc <= 0;
			    addr_f <= addr_f + 1;
			    addr_x <= addr_x + 1;
			end else if(valid_out==1)
			    pipeline_delay <= 1;
		    end
		end else if(acc_state==2) begin//state2	sends data
		    if(m_ready_y==1) begin
			if(m_valid_y == 1) begin
			    if(acc_addr == 31) begin
			        acc_addr <= 0;
			        acc_state <= 0;
			        m_valid_y <= 0;
			    end else begin
				acc_addr <= acc_addr + 1;
			    	m_valid_y <= 0;
			    end
			end else
			    m_valid_y <= 1;
		    end
		end
	    end
	end

	always_comb begin
	    if(x_state==0)
		wr_en_x = s_valid_x;
	    else
		wr_en_x = 0;
	end

endmodule

module datapath_64_33_16_1(clk, reset, s_data_in_x, 
		addr_x, wr_en_x, addr_f, clear_acc, en_acc, 
		m_data_out_y, acc_addr, valid_out, bias_addr_x);

	input 				clk, reset, wr_en_x, clear_acc, en_acc, bias_addr_x;
	input signed [15:0] 		s_data_in_x;
	input [5:0]		addr_f;
	input [5:0]		addr_x;
	output logic signed [15:0] m_data_out_y;
	logic [15:0]			dout_x, dout_f;
	logic signed [15:0]	din_y, ReLU;
	input [5:0]		acc_addr;
	output logic 			valid_out;

	memory_64_33_16_1 #(64, 6) memX(clk, s_data_in_x, dout_x, addr_x, wr_en_x);
	layer1_64_33_16_1_f_rom my_rom(clk, addr_f, dout_f);
	memory_64_33_16_1 #(32, 6) memY(clk, ReLU, m_data_out_y, acc_addr, valid_out);
	mult_acc_64_33_16_1 my_mult_acc(clk, clear_acc, dout_x, dout_f, en_acc, din_y, valid_out);

	always_comb begin
	    if(din_y < 0)
		ReLU = 0;
	    else
		ReLU = din_y;
    end

endmodule

module layer1_64_33_16_1_f_rom(clk, addr, z);
   input clk;
   input [5:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd65;
        1: z <= 16'd6;
        2: z <= -16'd72;
        3: z <= -16'd157;
        4: z <= -16'd196;
        5: z <= 16'd198;
        6: z <= -16'd111;
        7: z <= 16'd193;
        8: z <= -16'd256;
        9: z <= 16'd43;
        10: z <= 16'd187;
        11: z <= 16'd74;
        12: z <= -16'd71;
        13: z <= 16'd207;
        14: z <= 16'd203;
        15: z <= -16'd246;
        16: z <= -16'd208;
        17: z <= -16'd194;
        18: z <= 16'd111;
        19: z <= -16'd12;
        20: z <= 16'd17;
        21: z <= -16'd223;
        22: z <= 16'd135;
        23: z <= -16'd165;
        24: z <= 16'd216;
        25: z <= -16'd242;
        26: z <= -16'd238;
        27: z <= -16'd198;
        28: z <= 16'd181;
        29: z <= 16'd45;
        30: z <= 16'd136;
        31: z <= -16'd139;
        32: z <= -16'd205;
      endcase
   end
endmodule

module memory_64_33_16_1(clk, data_in, data_out, addr, wr_en);
    parameter                   		SIZE=64, LOGSIZE=6;
    input [15:0]			data_in;
    output logic [15:0]   	data_out;
    input [LOGSIZE-1:0]         		addr;
    input                       		clk, wr_en;
    logic [SIZE-1:0][15:0]	mem;

    always_ff @(posedge clk) begin
	    data_out <= mem[addr];
	    if (wr_en)
		mem[addr] <= data_in;
    end
endmodule

module mult_acc_64_33_16_1(clk, reset, a, b, valid_in, f, valid_out);
    input 				clk, reset, valid_in;
    input signed [15:0] 		a, b; 
    output logic signed [15:0] 	f;
    output logic 			valid_out;
    logic signed [37:0] 		sum, product;
    logic [32:0]			sum_count;
    logic				pipeline_delay;

    localparam signed [37:0] MAXVAL = 38'd32767; 
    localparam signed [37:0] MINVAL = -38'd32768; 

    always_ff @(posedge clk) begin
        if(reset == 1) begin
	    f <= 0;
	    valid_out <= 0;
	    sum_count <= 0;
	    product <= 0;
	    pipeline_delay <= 0;
	end
	else begin
	    if(valid_in == 1) begin
		if( sum < MINVAL )
		    f <= -16'd32768; 
		else if ( sum > MAXVAL )
		    f <= 16'd32767; 
		else
	    	    f <= sum;
		if( a*b < MINVAL )
		    product <= -16'd32768; 
		else if ( a*b > MAXVAL)
		    product <= 16'd32767; 
		else
	    	    product <= a*b;
		if(pipeline_delay == 1) begin
	    	    valid_out <= 1;
		    sum_count <= 0;
		    pipeline_delay <= 0;
		end else if(sum_count == 32)
		    pipeline_delay <= 1;
	    	else begin
		    valid_out <= 0;
		    sum_count <= sum_count + 1;
		end
	    end
	end
    end

    always_comb begin
	sum = product+f;
    end 
endmodule

module layer2_32_9_16_1(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y, m_valid_y, m_ready_y);
   // your stuff here!
	input 				clk, reset, s_valid_x, m_ready_y;
	input signed [15:0] 		s_data_in_x;
	output logic        		s_ready_x, m_valid_y;
	output logic signed [15:0] m_data_out_y;
	logic [3:0]		addr_f;
	logic [4:0]		addr_x;
	logic [5:0]		acc_addr;
	logic 					wr_en_x, clear_acc, en_acc, valid_out, bias_addr_x;

	controlpath_32_9_16_1 mycontrolpath(	clk, reset, s_valid_x, s_ready_x, m_valid_y, m_ready_y,
					addr_x, wr_en_x,addr_f, clear_acc, en_acc, acc_addr,
					valid_out, bias_addr_x);

	datapath_32_9_16_1 mydatapath(	clk, reset, s_data_in_x, addr_x, wr_en_x, addr_f, clear_acc, en_acc,
				m_data_out_y, acc_addr, valid_out, bias_addr_x);

endmodule

module controlpath_32_9_16_1(	clk, reset, s_valid_x, s_ready_x,
			m_valid_y, m_ready_y, addr_x, wr_en_x,
			addr_f, clear_acc, en_acc, acc_addr, valid_out, bias_addr_x);

	input 			clk, reset, s_valid_x, m_ready_y, valid_out;
	output logic    	s_ready_x, m_valid_y, wr_en_x, clear_acc, en_acc, bias_addr_x;
		logic [1:0]		x_state, acc_state, acc_state_cntr;
	logic [5:0]	L_cntr;
	logic			pipeline_delay; 
	output logic [3:0]	addr_f;
	output logic [4:0] addr_x;
	output logic [5:0] acc_addr;

	always_ff @(posedge clk) begin
	    if(reset==1) begin
	    	s_ready_x<=1; m_valid_y<=0; addr_x<=0; bias_addr_x<=0;
	    	addr_f<=0; clear_acc<=1; en_acc<=0; x_state<=0;
		acc_state<=0; L_cntr <=0; acc_addr<=0; pipeline_delay<=0;
	    end
	    else begin
	    //////////////////////////////////////////////////////////////x register states
	    	if(x_state==0) begin//state 0 reading valid inputs
		    if(s_valid_x==1) begin
			if(addr_x==31) begin //reached last address
		    	    x_state <= 1;
			    addr_x <= 0;
			    s_ready_x <= 0;
			end else begin
			    addr_x <= addr_x + 1;
			end
		    end
		end
		/////////////////////////////////////////////////////////////acc states
		if(acc_state==0) begin//state 0 waits for new data to finish updating
		    acc_state_cntr <= 0;
		    en_acc <= 0;
		    if(x_state==1) begin
			acc_state <= 1;
			addr_x <= 0; addr_f <= 0;
			L_cntr <= 1;
			bias_addr_x <= 1;
		    end
		end else if(acc_state==1) begin//state 1 gives data to acc and saves result
		    if(acc_addr == 24) begin
			acc_state <= 2;
			acc_addr <= 0;
			en_acc <= 0;
			addr_x <= 0; addr_f <= 0;
			x_state <= 0;
			s_ready_x <= 1;
			bias_addr_x <= 0;
		    end else begin
			en_acc <= 1;
		    	if(pipeline_delay==1) begin//add 1 delay due to xtra pipeline stage
			    addr_f <= 0;
			    addr_x <= 1*L_cntr;
			    L_cntr <= L_cntr + 1;
			    acc_addr <= L_cntr;
			    clear_acc <= 1;
			    pipeline_delay <= 0;
			end else if(addr_f!=8) begin
			    clear_acc <= 0;
			    addr_f <= addr_f + 1;
			    addr_x <= addr_x + 1;
			end else if(valid_out==1)
			    pipeline_delay <= 1;
		    end
		end else if(acc_state==2) begin//state2	sends data
		    if(m_ready_y==1) begin
			if(m_valid_y == 1) begin
			    if(acc_addr == 23) begin
			        acc_addr <= 0;
			        acc_state <= 0;
			        m_valid_y <= 0;
			    end else begin
				acc_addr <= acc_addr + 1;
			    	m_valid_y <= 0;
			    end
			end else
			    m_valid_y <= 1;
		    end
		end
	    end
	end

	always_comb begin
	    if(x_state==0)
		wr_en_x = s_valid_x;
	    else
		wr_en_x = 0;
	end

endmodule

module datapath_32_9_16_1(clk, reset, s_data_in_x, 
		addr_x, wr_en_x, addr_f, clear_acc, en_acc, 
		m_data_out_y, acc_addr, valid_out, bias_addr_x);

	input 				clk, reset, wr_en_x, clear_acc, en_acc, bias_addr_x;
	input signed [15:0] 		s_data_in_x;
	input [3:0]		addr_f;
	input [4:0]		addr_x;
	output logic signed [15:0] m_data_out_y;
	logic [15:0]			dout_x, dout_f;
	logic signed [15:0]	din_y, ReLU;
	input [5:0]		acc_addr;
	output logic 			valid_out;

	memory_32_9_16_1 #(32, 5) memX(clk, s_data_in_x, dout_x, addr_x, wr_en_x);
	layer2_32_9_16_1_f_rom my_rom(clk, addr_f, dout_f);
	memory_32_9_16_1 #(24, 6) memY(clk, ReLU, m_data_out_y, acc_addr, valid_out);
	mult_acc_32_9_16_1 my_mult_acc(clk, clear_acc, dout_x, dout_f, en_acc, din_y, valid_out);

	always_comb begin
	    if(din_y < 0)
		ReLU = 0;
	    else
		ReLU = din_y;
    end

endmodule

module layer2_32_9_16_1_f_rom(clk, addr, z);
   input clk;
   input [3:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd192;
        1: z <= -16'd40;
        2: z <= -16'd144;
        3: z <= -16'd250;
        4: z <= 16'd105;
        5: z <= -16'd207;
        6: z <= -16'd250;
        7: z <= -16'd107;
        8: z <= 16'd236;
      endcase
   end
endmodule

module memory_32_9_16_1(clk, data_in, data_out, addr, wr_en);
    parameter                   		SIZE=64, LOGSIZE=6;
    input [15:0]			data_in;
    output logic [15:0]   	data_out;
    input [LOGSIZE-1:0]         		addr;
    input                       		clk, wr_en;
    logic [SIZE-1:0][15:0]	mem;

    always_ff @(posedge clk) begin
	    data_out <= mem[addr];
	    if (wr_en)
		mem[addr] <= data_in;
    end
endmodule

module mult_acc_32_9_16_1(clk, reset, a, b, valid_in, f, valid_out);
    input 				clk, reset, valid_in;
    input signed [15:0] 		a, b; 
    output logic signed [15:0] 	f;
    output logic 			valid_out;
    logic signed [35:0] 		sum, product;
    logic [8:0]			sum_count;
    logic				pipeline_delay;

    localparam signed [35:0] MAXVAL = 36'd32767; 
    localparam signed [35:0] MINVAL = -36'd32768; 

    always_ff @(posedge clk) begin
        if(reset == 1) begin
	    f <= 0;
	    valid_out <= 0;
	    sum_count <= 0;
	    product <= 0;
	    pipeline_delay <= 0;
	end
	else begin
	    if(valid_in == 1) begin
		if( sum < MINVAL )
		    f <= -16'd32768; 
		else if ( sum > MAXVAL )
		    f <= 16'd32767; 
		else
	    	    f <= sum;
		if( a*b < MINVAL )
		    product <= -16'd32768; 
		else if ( a*b > MAXVAL)
		    product <= 16'd32767; 
		else
	    	    product <= a*b;
		if(pipeline_delay == 1) begin
	    	    valid_out <= 1;
		    sum_count <= 0;
		    pipeline_delay <= 0;
		end else if(sum_count == 8)
		    pipeline_delay <= 1;
	    	else begin
		    valid_out <= 0;
		    sum_count <= sum_count + 1;
		end
	    end
	end
    end

    always_comb begin
	sum = product+f;
    end 
endmodule

module layer3_24_9_16_1(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y, m_valid_y, m_ready_y);
   // your stuff here!
	input 				clk, reset, s_valid_x, m_ready_y;
	input signed [15:0] 		s_data_in_x;
	output logic        		s_ready_x, m_valid_y;
	output logic signed [15:0] m_data_out_y;
	logic [3:0]		addr_f;
	logic [4:0]		addr_x;
	logic [4:0]		acc_addr;
	logic 					wr_en_x, clear_acc, en_acc, valid_out, bias_addr_x;

	controlpath_24_10_16_1 mycontrolpath(	clk, reset, s_valid_x, s_ready_x, m_valid_y, m_ready_y,
					addr_x, wr_en_x,addr_f, clear_acc, en_acc, acc_addr,
					valid_out, bias_addr_x);

	datapath_24_10_16_1 mydatapath(	clk, reset, s_data_in_x, addr_x, wr_en_x, addr_f, clear_acc, en_acc,
				m_data_out_y, acc_addr, valid_out, bias_addr_x);

endmodule

module controlpath_24_10_16_1(	clk, reset, s_valid_x, s_ready_x,
			m_valid_y, m_ready_y, addr_x, wr_en_x,
			addr_f, clear_acc, en_acc, acc_addr, valid_out, bias_addr_x);

	input 			clk, reset, s_valid_x, m_ready_y, valid_out;
	output logic    	s_ready_x, m_valid_y, wr_en_x, clear_acc, en_acc, bias_addr_x;
		logic [1:0]		x_state, acc_state, acc_state_cntr;
	logic [4:0]	L_cntr;
	logic			pipeline_delay; 
	output logic [3:0]	addr_f;
	output logic [4:0] addr_x;
	output logic [4:0] acc_addr;

	always_ff @(posedge clk) begin
	    if(reset==1) begin
	    	s_ready_x<=1; m_valid_y<=0; addr_x<=0; bias_addr_x<=0;
	    	addr_f<=0; clear_acc<=1; en_acc<=0; x_state<=0;
		acc_state<=0; L_cntr <=0; acc_addr<=0; pipeline_delay<=0;
	    end
	    else begin
	    //////////////////////////////////////////////////////////////x register states
	    	if(x_state==0) begin//state 0 reading valid inputs
		    if(s_valid_x==1) begin
			if(addr_x==23) begin //reached last address
		    	    x_state <= 1;
			    addr_x <= 0;
			    s_ready_x <= 0;
			end else begin
			    addr_x <= addr_x + 1;
			end
		    end
		end
		/////////////////////////////////////////////////////////////acc states
		if(acc_state==0) begin//state 0 waits for new data to finish updating
		    acc_state_cntr <= 0;
		    en_acc <= 0;
		    if(x_state==1) begin
			acc_state <= 1;
			addr_x <= 0; addr_f <= 0;
			L_cntr <= 1;
			bias_addr_x <= 1;
		    end
		end else if(acc_state==1) begin//state 1 gives data to acc and saves result
		    if(acc_addr == 15) begin
			acc_state <= 2;
			acc_addr <= 0;
			en_acc <= 0;
			addr_x <= 0; addr_f <= 0;
			x_state <= 0;
			s_ready_x <= 1;
			bias_addr_x <= 0;
		    end else begin
			en_acc <= 1;
		    	if(pipeline_delay==1) begin//add 1 delay due to xtra pipeline stage
			    addr_f <= 0;
			    addr_x <= 1*L_cntr;
			    L_cntr <= L_cntr + 1;
			    acc_addr <= L_cntr;
			    clear_acc <= 1;
			    pipeline_delay <= 0;
			end else if(addr_f!=9) begin
			    clear_acc <= 0;
			    addr_f <= addr_f + 1;
			    addr_x <= addr_x + 1;
			end else if(valid_out==1)
			    pipeline_delay <= 1;
		    end
		end else if(acc_state==2) begin//state2	sends data
		    if(m_ready_y==1) begin
			if(m_valid_y == 1) begin
			    if(acc_addr == 14) begin
			        acc_addr <= 0;
			        acc_state <= 0;
			        m_valid_y <= 0;
			    end else begin
				acc_addr <= acc_addr + 1;
			    	m_valid_y <= 0;
			    end
			end else
			    m_valid_y <= 1;
		    end
		end
	    end
	end

	always_comb begin
	    if(x_state==0)
		wr_en_x = s_valid_x;
	    else
		wr_en_x = 0;
	end

endmodule

module datapath_24_10_16_1(clk, reset, s_data_in_x, 
		addr_x, wr_en_x, addr_f, clear_acc, en_acc, 
		m_data_out_y, acc_addr, valid_out, bias_addr_x);

	input 				clk, reset, wr_en_x, clear_acc, en_acc, bias_addr_x;
	input signed [15:0] 		s_data_in_x;
	input [3:0]		addr_f;
	input [4:0]		addr_x;
	output logic signed [15:0] m_data_out_y;
	logic [15:0]			dout_x, dout_f;
	logic signed [15:0]	din_y, ReLU;
	input [4:0]		acc_addr;
	output logic 			valid_out;

	memory_24_10_16_1 #(24, 5) memX(clk, s_data_in_x, dout_x, addr_x, wr_en_x);
	layer3_24_9_16_1_f_rom my_rom(clk, addr_f, dout_f);
	memory_24_10_16_1 #(15, 5) memY(clk, ReLU, m_data_out_y, acc_addr, valid_out);
	mult_acc_24_10_16_1 my_mult_acc(clk, clear_acc, dout_x, dout_f, en_acc, din_y, valid_out);

	always_comb begin
	    if(din_y < 0)
		ReLU = 0;
	    else
		ReLU = din_y;
    end

endmodule

module layer3_24_9_16_1_f_rom(clk, addr, z);
   input clk;
   input [3:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= 16'd80;
        1: z <= 16'd78;
        2: z <= 16'd187;
        3: z <= 16'd27;
        4: z <= 16'd88;
        5: z <= 16'd236;
        6: z <= 16'd90;
        7: z <= -16'd57;
        8: z <= -16'd32;
        9: z <= -16'd149;
      endcase
   end
endmodule

module memory_24_10_16_1(clk, data_in, data_out, addr, wr_en);
    parameter                   		SIZE=64, LOGSIZE=6;
    input [15:0]			data_in;
    output logic [15:0]   	data_out;
    input [LOGSIZE-1:0]         		addr;
    input                       		clk, wr_en;
    logic [SIZE-1:0][15:0]	mem;

    always_ff @(posedge clk) begin
	    data_out <= mem[addr];
	    if (wr_en)
		mem[addr] <= data_in;
    end
endmodule

module mult_acc_24_10_16_1(clk, reset, a, b, valid_in, f, valid_out);
    input 				clk, reset, valid_in;
    input signed [15:0] 		a, b; 
    output logic signed [15:0] 	f;
    output logic 			valid_out;
    logic signed [35:0] 		sum, product;
    logic [9:0]			sum_count;
    logic				pipeline_delay;

    localparam signed [35:0] MAXVAL = 36'd32767; 
    localparam signed [35:0] MINVAL = -36'd32768; 

    always_ff @(posedge clk) begin
        if(reset == 1) begin
	    f <= 0;
	    valid_out <= 0;
	    sum_count <= 0;
	    product <= 0;
	    pipeline_delay <= 0;
	end
	else begin
	    if(valid_in == 1) begin
		if( sum < MINVAL )
		    f <= -16'd32768; 
		else if ( sum > MAXVAL )
		    f <= 16'd32767; 
		else
	    	    f <= sum;
		if( a*b < MINVAL )
		    product <= -16'd32768; 
		else if ( a*b > MAXVAL)
		    product <= 16'd32767; 
		else
	    	    product <= a*b;
		if(pipeline_delay == 1) begin
	    	    valid_out <= 1;
		    sum_count <= 0;
		    pipeline_delay <= 0;
		end else if(sum_count == 9)
		    pipeline_delay <= 1;
	    	else begin
		    valid_out <= 0;
		    sum_count <= sum_count + 1;
		end
	    end
	end
    end

    always_comb begin
	sum = product+f;
    end 
endmodule

