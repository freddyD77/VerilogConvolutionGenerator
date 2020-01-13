module multi_64_33_9_10_16_14(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y, m_valid_y, m_ready_y);

	input 				clk, reset, s_valid_x, m_ready_y;
	input signed [15:0] 		s_data_in_x;
	output logic        		s_ready_x, m_valid_y;
	output logic signed [15:0] m_data_out_y;
	logic 				m_valid_y0, m_valid_y1, m_ready_y0, m_ready_y1;
	logic signed [15:0]		m_data_out_y0, m_data_out_y1;

	layer1_64_33_16_4 conv1(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y0, m_valid_y0, m_ready_y0);
	layer2_32_9_16_4 conv2(clk, reset, m_data_out_y0, m_valid_y0, m_ready_y0, m_data_out_y1, m_valid_y1, m_ready_y1);
	layer3_24_9_16_3 conv3(clk, reset, m_data_out_y1, m_valid_y1, m_ready_y1, m_data_out_y, m_valid_y, m_ready_y);

endmodule

module layer1_64_33_16_4(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y, m_valid_y, m_ready_y);
   // your stuff here!
	input 				clk, reset, s_valid_x, m_ready_y;
	input signed [15:0] 		s_data_in_x;
	output logic        		s_ready_x, m_valid_y;
	output logic signed [15:0] m_data_out_y;
	logic [5:0]		addr_f;
	logic [5:0]		addr_x;
	logic [5:0]		acc_addr;
	logic 					wr_en_x, clear_acc, en_acc, valid_out, bias_addr_x;

	controlpath_64_33_16_4 mycontrolpath(	clk, reset, s_valid_x, s_ready_x, m_valid_y, m_ready_y,
					addr_x, wr_en_x,addr_f, clear_acc, en_acc, acc_addr,
					valid_out, bias_addr_x);

	datapath_64_33_16_4 mydatapath(	clk, reset, s_data_in_x, addr_x, wr_en_x, addr_f, clear_acc, en_acc,
				m_data_out_y, acc_addr, valid_out, bias_addr_x);

endmodule

module controlpath_64_33_16_4(	clk, reset, s_valid_x, s_ready_x,
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
		    if(acc_addr == 8) begin
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
			    addr_x <= 4*L_cntr;
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

module datapath_64_33_16_4(clk, reset, s_data_in_x, 
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
	logic [5:0]		addr_x0,addr_x1,addr_x2,addr_x3;
	logic [15:0]			dout_x1,dout_x2,dout_x3;
	logic signed [15:0]			din_y1,din_y2,din_y3;
	logic signed [15:0]			ReLU1,ReLU2,ReLU3;
	logic signed [15:0]			data_out_y0,data_out_y1,data_out_y2,data_out_y3;
	logic [5:0]		acc_addr0,acc_addr1,acc_addr2,acc_addr3;
	logic 			valid_out1,valid_out2,valid_out3;


	memory_64_33_16_4 #(64, 6) memX(clk, s_data_in_x, dout_x, addr_x0, wr_en_x);
	layer1_64_33_16_4_f_rom my_rom(clk, addr_f, dout_f);
	memory_64_33_16_4 #(32, 6) memY(clk, ReLU, data_out_y0, acc_addr0, valid_out);
	mult_acc_64_33_16_4 my_mult_acc(clk, clear_acc, dout_x, dout_f, en_acc, din_y, valid_out);
	memory_64_33_16_4 #(64, 6) memX1(clk, s_data_in_x,dout_x1,addr_x1, wr_en_x);
	memory_64_33_16_4 #(32, 6) memY1(clk,ReLU1,data_out_y1,acc_addr1,valid_out1);
	mult_acc_64_33_16_4 my_mult_acc1(clk, clear_acc,dout_x1, dout_f, en_acc,din_y1,valid_out1);
	memory_64_33_16_4 #(64, 6) memX2(clk, s_data_in_x,dout_x2,addr_x2, wr_en_x);
	memory_64_33_16_4 #(32, 6) memY2(clk,ReLU2,data_out_y2,acc_addr2,valid_out2);
	mult_acc_64_33_16_4 my_mult_acc2(clk, clear_acc,dout_x2, dout_f, en_acc,din_y2,valid_out2);
	memory_64_33_16_4 #(64, 6) memX3(clk, s_data_in_x,dout_x3,addr_x3, wr_en_x);
	memory_64_33_16_4 #(32, 6) memY3(clk,ReLU3,data_out_y3,acc_addr3,valid_out3);
	mult_acc_64_33_16_4 my_mult_acc3(clk, clear_acc,dout_x3, dout_f, en_acc,din_y3,valid_out3);

	always_comb begin
	    if(din_y < 0)
		ReLU = 0;
	    else
		ReLU = din_y;
	    if(din_y1 < 0)
		ReLU1 = 0;
	    else
		ReLU1 = din_y1;
	    if(din_y2 < 0)
		ReLU2 = 0;
	    else
		ReLU2 = din_y2;
	    if(din_y3 < 0)
		ReLU3 = 0;
	    else
		ReLU3 = din_y3;
	    if(en_acc == 1 || bias_addr_x == 1) begin
	   	addr_x0 = addr_x+0;
	        acc_addr0 = (4*acc_addr)+0;
	   	addr_x1 = addr_x+1;
	        acc_addr1 = (4*acc_addr)+1;
	   	addr_x2 = addr_x+2;
	        acc_addr2 = (4*acc_addr)+2;
	   	addr_x3 = addr_x+3;
	        acc_addr3 = (4*acc_addr)+3;
	    end else begin
	   	addr_x0 = addr_x;
	        acc_addr0 = acc_addr;
	   	addr_x1 = addr_x;
	        acc_addr1 = acc_addr;
	   	addr_x2 = addr_x;
	        acc_addr2 = acc_addr;
	   	addr_x3 = addr_x;
	        acc_addr3 = acc_addr;
    	end
	    case(acc_addr % 4)
		2'd0: m_data_out_y = data_out_y0;
		2'd1: m_data_out_y = data_out_y1;
		2'd2: m_data_out_y = data_out_y2;
		2'd3: m_data_out_y = data_out_y3;
	    endcase
    	end

endmodule

module layer1_64_33_16_4_f_rom(clk, addr, z);
   input clk;
   input [5:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd159;
        1: z <= -16'd86;
        2: z <= 16'd62;
        3: z <= -16'd61;
        4: z <= 16'd17;
        5: z <= 16'd116;
        6: z <= -16'd14;
        7: z <= -16'd180;
        8: z <= -16'd98;
        9: z <= 16'd37;
        10: z <= 16'd241;
        11: z <= -16'd173;
        12: z <= -16'd228;
        13: z <= -16'd175;
        14: z <= -16'd142;
        15: z <= 16'd196;
        16: z <= 16'd98;
        17: z <= -16'd68;
        18: z <= -16'd69;
        19: z <= -16'd40;
        20: z <= -16'd184;
        21: z <= -16'd146;
        22: z <= -16'd247;
        23: z <= -16'd171;
        24: z <= 16'd245;
        25: z <= 16'd167;
        26: z <= -16'd49;
        27: z <= -16'd82;
        28: z <= 16'd26;
        29: z <= 16'd102;
        30: z <= -16'd84;
        31: z <= 16'd123;
        32: z <= -16'd240;
      endcase
   end
endmodule

module memory_64_33_16_4(clk, data_in, data_out, addr, wr_en);
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

module mult_acc_64_33_16_4(clk, reset, a, b, valid_in, f, valid_out);
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

module layer2_32_9_16_4(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y, m_valid_y, m_ready_y);
   // your stuff here!
	input 				clk, reset, s_valid_x, m_ready_y;
	input signed [15:0] 		s_data_in_x;
	output logic        		s_ready_x, m_valid_y;
	output logic signed [15:0] m_data_out_y;
	logic [3:0]		addr_f;
	logic [4:0]		addr_x;
	logic [5:0]		acc_addr;
	logic 					wr_en_x, clear_acc, en_acc, valid_out, bias_addr_x;

	controlpath_32_9_16_4 mycontrolpath(	clk, reset, s_valid_x, s_ready_x, m_valid_y, m_ready_y,
					addr_x, wr_en_x,addr_f, clear_acc, en_acc, acc_addr,
					valid_out, bias_addr_x);

	datapath_32_9_16_4 mydatapath(	clk, reset, s_data_in_x, addr_x, wr_en_x, addr_f, clear_acc, en_acc,
				m_data_out_y, acc_addr, valid_out, bias_addr_x);

endmodule

module controlpath_32_9_16_4(	clk, reset, s_valid_x, s_ready_x,
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
		    if(acc_addr == 6) begin
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
			    addr_x <= 4*L_cntr;
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

module datapath_32_9_16_4(clk, reset, s_data_in_x, 
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
	logic [4:0]		addr_x0,addr_x1,addr_x2,addr_x3;
	logic [15:0]			dout_x1,dout_x2,dout_x3;
	logic signed [15:0]			din_y1,din_y2,din_y3;
	logic signed [15:0]			ReLU1,ReLU2,ReLU3;
	logic signed [15:0]			data_out_y0,data_out_y1,data_out_y2,data_out_y3;
	logic [5:0]		acc_addr0,acc_addr1,acc_addr2,acc_addr3;
	logic 			valid_out1,valid_out2,valid_out3;


	memory_32_9_16_4 #(32, 5) memX(clk, s_data_in_x, dout_x, addr_x0, wr_en_x);
	layer2_32_9_16_4_f_rom my_rom(clk, addr_f, dout_f);
	memory_32_9_16_4 #(24, 6) memY(clk, ReLU, data_out_y0, acc_addr0, valid_out);
	mult_acc_32_9_16_4 my_mult_acc(clk, clear_acc, dout_x, dout_f, en_acc, din_y, valid_out);
	memory_32_9_16_4 #(32, 5) memX1(clk, s_data_in_x,dout_x1,addr_x1, wr_en_x);
	memory_32_9_16_4 #(24, 6) memY1(clk,ReLU1,data_out_y1,acc_addr1,valid_out1);
	mult_acc_32_9_16_4 my_mult_acc1(clk, clear_acc,dout_x1, dout_f, en_acc,din_y1,valid_out1);
	memory_32_9_16_4 #(32, 5) memX2(clk, s_data_in_x,dout_x2,addr_x2, wr_en_x);
	memory_32_9_16_4 #(24, 6) memY2(clk,ReLU2,data_out_y2,acc_addr2,valid_out2);
	mult_acc_32_9_16_4 my_mult_acc2(clk, clear_acc,dout_x2, dout_f, en_acc,din_y2,valid_out2);
	memory_32_9_16_4 #(32, 5) memX3(clk, s_data_in_x,dout_x3,addr_x3, wr_en_x);
	memory_32_9_16_4 #(24, 6) memY3(clk,ReLU3,data_out_y3,acc_addr3,valid_out3);
	mult_acc_32_9_16_4 my_mult_acc3(clk, clear_acc,dout_x3, dout_f, en_acc,din_y3,valid_out3);

	always_comb begin
	    if(din_y < 0)
		ReLU = 0;
	    else
		ReLU = din_y;
	    if(din_y1 < 0)
		ReLU1 = 0;
	    else
		ReLU1 = din_y1;
	    if(din_y2 < 0)
		ReLU2 = 0;
	    else
		ReLU2 = din_y2;
	    if(din_y3 < 0)
		ReLU3 = 0;
	    else
		ReLU3 = din_y3;
	    if(en_acc == 1 || bias_addr_x == 1) begin
	   	addr_x0 = addr_x+0;
	        acc_addr0 = (4*acc_addr)+0;
	   	addr_x1 = addr_x+1;
	        acc_addr1 = (4*acc_addr)+1;
	   	addr_x2 = addr_x+2;
	        acc_addr2 = (4*acc_addr)+2;
	   	addr_x3 = addr_x+3;
	        acc_addr3 = (4*acc_addr)+3;
	    end else begin
	   	addr_x0 = addr_x;
	        acc_addr0 = acc_addr;
	   	addr_x1 = addr_x;
	        acc_addr1 = acc_addr;
	   	addr_x2 = addr_x;
	        acc_addr2 = acc_addr;
	   	addr_x3 = addr_x;
	        acc_addr3 = acc_addr;
    	end
	    case(acc_addr % 4)
		2'd0: m_data_out_y = data_out_y0;
		2'd1: m_data_out_y = data_out_y1;
		2'd2: m_data_out_y = data_out_y2;
		2'd3: m_data_out_y = data_out_y3;
	    endcase
    	end

endmodule

module layer2_32_9_16_4_f_rom(clk, addr, z);
   input clk;
   input [3:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= 16'd234;
        1: z <= -16'd194;
        2: z <= 16'd33;
        3: z <= 16'd94;
        4: z <= 16'd48;
        5: z <= 16'd109;
        6: z <= 16'd252;
        7: z <= -16'd171;
        8: z <= 16'd95;
      endcase
   end
endmodule

module memory_32_9_16_4(clk, data_in, data_out, addr, wr_en);
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

module mult_acc_32_9_16_4(clk, reset, a, b, valid_in, f, valid_out);
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

module layer3_24_9_16_3(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y, m_valid_y, m_ready_y);
   // your stuff here!
	input 				clk, reset, s_valid_x, m_ready_y;
	input signed [15:0] 		s_data_in_x;
	output logic        		s_ready_x, m_valid_y;
	output logic signed [15:0] m_data_out_y;
	logic [3:0]		addr_f;
	logic [4:0]		addr_x;
	logic [4:0]		acc_addr;
	logic 					wr_en_x, clear_acc, en_acc, valid_out, bias_addr_x;

	controlpath_24_10_16_3 mycontrolpath(	clk, reset, s_valid_x, s_ready_x, m_valid_y, m_ready_y,
					addr_x, wr_en_x,addr_f, clear_acc, en_acc, acc_addr,
					valid_out, bias_addr_x);

	datapath_24_10_16_3 mydatapath(	clk, reset, s_data_in_x, addr_x, wr_en_x, addr_f, clear_acc, en_acc,
				m_data_out_y, acc_addr, valid_out, bias_addr_x);

endmodule

module controlpath_24_10_16_3(	clk, reset, s_valid_x, s_ready_x,
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
		    if(acc_addr == 5) begin
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
			    addr_x <= 3*L_cntr;
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

module datapath_24_10_16_3(clk, reset, s_data_in_x, 
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
	logic [4:0]		addr_x0,addr_x1,addr_x2;
	logic [15:0]			dout_x1,dout_x2;
	logic signed [15:0]			din_y1,din_y2;
	logic signed [15:0]			ReLU1,ReLU2;
	logic signed [15:0]			data_out_y0,data_out_y1,data_out_y2;
	logic [4:0]		acc_addr0,acc_addr1,acc_addr2;
	logic 			valid_out1,valid_out2;


	memory_24_10_16_3 #(24, 5) memX(clk, s_data_in_x, dout_x, addr_x0, wr_en_x);
	layer3_24_9_16_3_f_rom my_rom(clk, addr_f, dout_f);
	memory_24_10_16_3 #(15, 5) memY(clk, ReLU, data_out_y0, acc_addr0, valid_out);
	mult_acc_24_10_16_3 my_mult_acc(clk, clear_acc, dout_x, dout_f, en_acc, din_y, valid_out);
	memory_24_10_16_3 #(24, 5) memX1(clk, s_data_in_x,dout_x1,addr_x1, wr_en_x);
	memory_24_10_16_3 #(15, 5) memY1(clk,ReLU1,data_out_y1,acc_addr1,valid_out1);
	mult_acc_24_10_16_3 my_mult_acc1(clk, clear_acc,dout_x1, dout_f, en_acc,din_y1,valid_out1);
	memory_24_10_16_3 #(24, 5) memX2(clk, s_data_in_x,dout_x2,addr_x2, wr_en_x);
	memory_24_10_16_3 #(15, 5) memY2(clk,ReLU2,data_out_y2,acc_addr2,valid_out2);
	mult_acc_24_10_16_3 my_mult_acc2(clk, clear_acc,dout_x2, dout_f, en_acc,din_y2,valid_out2);

	always_comb begin
	    if(din_y < 0)
		ReLU = 0;
	    else
		ReLU = din_y;
	    if(din_y1 < 0)
		ReLU1 = 0;
	    else
		ReLU1 = din_y1;
	    if(din_y2 < 0)
		ReLU2 = 0;
	    else
		ReLU2 = din_y2;
	    if(en_acc == 1 || bias_addr_x == 1) begin
	   	addr_x0 = addr_x+0;
	        acc_addr0 = (3*acc_addr)+0;
	   	addr_x1 = addr_x+1;
	        acc_addr1 = (3*acc_addr)+1;
	   	addr_x2 = addr_x+2;
	        acc_addr2 = (3*acc_addr)+2;
	    end else begin
	   	addr_x0 = addr_x;
	        acc_addr0 = acc_addr;
	   	addr_x1 = addr_x;
	        acc_addr1 = acc_addr;
	   	addr_x2 = addr_x;
	        acc_addr2 = acc_addr;
    	end
	    case(acc_addr % 3)
		2'd0: m_data_out_y = data_out_y0;
		2'd1: m_data_out_y = data_out_y1;
		2'd2: m_data_out_y = data_out_y2;
	    endcase
    	end

endmodule

module layer3_24_9_16_3_f_rom(clk, addr, z);
   input clk;
   input [3:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd176;
        1: z <= -16'd142;
        2: z <= 16'd176;
        3: z <= -16'd62;
        4: z <= -16'd202;
        5: z <= 16'd18;
        6: z <= 16'd126;
        7: z <= -16'd15;
        8: z <= 16'd234;
        9: z <= 16'd198;
      endcase
   end
endmodule

module memory_24_10_16_3(clk, data_in, data_out, addr, wr_en);
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

module mult_acc_24_10_16_3(clk, reset, a, b, valid_in, f, valid_out);
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

