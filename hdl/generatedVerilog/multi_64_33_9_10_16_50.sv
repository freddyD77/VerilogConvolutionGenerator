module multi_64_33_9_10_16_50(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y, m_valid_y, m_ready_y);

	input 				clk, reset, s_valid_x, m_ready_y;
	input signed [15:0] 		s_data_in_x;
	output logic        		s_ready_x, m_valid_y;
	output logic signed [15:0] m_data_out_y;
	logic 				m_valid_y0, m_valid_y1, m_ready_y0, m_ready_y1;
	logic signed [15:0]		m_data_out_y0, m_data_out_y1;

	layer1_64_33_16_16 conv1(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y0, m_valid_y0, m_ready_y0);
	layer2_32_9_16_12 conv2(clk, reset, m_data_out_y0, m_valid_y0, m_ready_y0, m_data_out_y1, m_valid_y1, m_ready_y1);
	layer3_24_9_16_15 conv3(clk, reset, m_data_out_y1, m_valid_y1, m_ready_y1, m_data_out_y, m_valid_y, m_ready_y);

endmodule

module layer1_64_33_16_16(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y, m_valid_y, m_ready_y);
   // your stuff here!
	input 				clk, reset, s_valid_x, m_ready_y;
	input signed [15:0] 		s_data_in_x;
	output logic        		s_ready_x, m_valid_y;
	output logic signed [15:0] m_data_out_y;
	logic [5:0]		addr_f;
	logic [5:0]		addr_x;
	logic [5:0]		acc_addr;
	logic 					wr_en_x, clear_acc, en_acc, valid_out, bias_addr_x;

	controlpath_64_33_16_16 mycontrolpath(	clk, reset, s_valid_x, s_ready_x, m_valid_y, m_ready_y,
					addr_x, wr_en_x,addr_f, clear_acc, en_acc, acc_addr,
					valid_out, bias_addr_x);

	datapath_64_33_16_16 mydatapath(	clk, reset, s_data_in_x, addr_x, wr_en_x, addr_f, clear_acc, en_acc,
				m_data_out_y, acc_addr, valid_out, bias_addr_x);

endmodule

module controlpath_64_33_16_16(	clk, reset, s_valid_x, s_ready_x,
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
		    if(acc_addr == 2) begin
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
			    addr_x <= 16*L_cntr;
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

module datapath_64_33_16_16(clk, reset, s_data_in_x, 
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
	logic [5:0]		addr_x0,addr_x1,addr_x2,addr_x3,addr_x4,addr_x5,addr_x6,addr_x7,addr_x8,addr_x9,addr_x10,addr_x11,addr_x12,addr_x13,addr_x14,addr_x15;
	logic [15:0]			dout_x1,dout_x2,dout_x3,dout_x4,dout_x5,dout_x6,dout_x7,dout_x8,dout_x9,dout_x10,dout_x11,dout_x12,dout_x13,dout_x14,dout_x15;
	logic signed [15:0]			din_y1,din_y2,din_y3,din_y4,din_y5,din_y6,din_y7,din_y8,din_y9,din_y10,din_y11,din_y12,din_y13,din_y14,din_y15;
	logic signed [15:0]			ReLU1,ReLU2,ReLU3,ReLU4,ReLU5,ReLU6,ReLU7,ReLU8,ReLU9,ReLU10,ReLU11,ReLU12,ReLU13,ReLU14,ReLU15;
	logic signed [15:0]			data_out_y0,data_out_y1,data_out_y2,data_out_y3,data_out_y4,data_out_y5,data_out_y6,data_out_y7,data_out_y8,data_out_y9,data_out_y10,data_out_y11,data_out_y12,data_out_y13,data_out_y14,data_out_y15;
	logic [5:0]		acc_addr0,acc_addr1,acc_addr2,acc_addr3,acc_addr4,acc_addr5,acc_addr6,acc_addr7,acc_addr8,acc_addr9,acc_addr10,acc_addr11,acc_addr12,acc_addr13,acc_addr14,acc_addr15;
	logic 			valid_out1,valid_out2,valid_out3,valid_out4,valid_out5,valid_out6,valid_out7,valid_out8,valid_out9,valid_out10,valid_out11,valid_out12,valid_out13,valid_out14,valid_out15;


	memory_64_33_16_16 #(64, 6) memX(clk, s_data_in_x, dout_x, addr_x0, wr_en_x);
	layer1_64_33_16_16_f_rom my_rom(clk, addr_f, dout_f);
	memory_64_33_16_16 #(32, 6) memY(clk, ReLU, data_out_y0, acc_addr0, valid_out);
	mult_acc_64_33_16_16 my_mult_acc(clk, clear_acc, dout_x, dout_f, en_acc, din_y, valid_out);
	memory_64_33_16_16 #(64, 6) memX1(clk, s_data_in_x,dout_x1,addr_x1, wr_en_x);
	memory_64_33_16_16 #(32, 6) memY1(clk,ReLU1,data_out_y1,acc_addr1,valid_out1);
	mult_acc_64_33_16_16 my_mult_acc1(clk, clear_acc,dout_x1, dout_f, en_acc,din_y1,valid_out1);
	memory_64_33_16_16 #(64, 6) memX2(clk, s_data_in_x,dout_x2,addr_x2, wr_en_x);
	memory_64_33_16_16 #(32, 6) memY2(clk,ReLU2,data_out_y2,acc_addr2,valid_out2);
	mult_acc_64_33_16_16 my_mult_acc2(clk, clear_acc,dout_x2, dout_f, en_acc,din_y2,valid_out2);
	memory_64_33_16_16 #(64, 6) memX3(clk, s_data_in_x,dout_x3,addr_x3, wr_en_x);
	memory_64_33_16_16 #(32, 6) memY3(clk,ReLU3,data_out_y3,acc_addr3,valid_out3);
	mult_acc_64_33_16_16 my_mult_acc3(clk, clear_acc,dout_x3, dout_f, en_acc,din_y3,valid_out3);
	memory_64_33_16_16 #(64, 6) memX4(clk, s_data_in_x,dout_x4,addr_x4, wr_en_x);
	memory_64_33_16_16 #(32, 6) memY4(clk,ReLU4,data_out_y4,acc_addr4,valid_out4);
	mult_acc_64_33_16_16 my_mult_acc4(clk, clear_acc,dout_x4, dout_f, en_acc,din_y4,valid_out4);
	memory_64_33_16_16 #(64, 6) memX5(clk, s_data_in_x,dout_x5,addr_x5, wr_en_x);
	memory_64_33_16_16 #(32, 6) memY5(clk,ReLU5,data_out_y5,acc_addr5,valid_out5);
	mult_acc_64_33_16_16 my_mult_acc5(clk, clear_acc,dout_x5, dout_f, en_acc,din_y5,valid_out5);
	memory_64_33_16_16 #(64, 6) memX6(clk, s_data_in_x,dout_x6,addr_x6, wr_en_x);
	memory_64_33_16_16 #(32, 6) memY6(clk,ReLU6,data_out_y6,acc_addr6,valid_out6);
	mult_acc_64_33_16_16 my_mult_acc6(clk, clear_acc,dout_x6, dout_f, en_acc,din_y6,valid_out6);
	memory_64_33_16_16 #(64, 6) memX7(clk, s_data_in_x,dout_x7,addr_x7, wr_en_x);
	memory_64_33_16_16 #(32, 6) memY7(clk,ReLU7,data_out_y7,acc_addr7,valid_out7);
	mult_acc_64_33_16_16 my_mult_acc7(clk, clear_acc,dout_x7, dout_f, en_acc,din_y7,valid_out7);
	memory_64_33_16_16 #(64, 6) memX8(clk, s_data_in_x,dout_x8,addr_x8, wr_en_x);
	memory_64_33_16_16 #(32, 6) memY8(clk,ReLU8,data_out_y8,acc_addr8,valid_out8);
	mult_acc_64_33_16_16 my_mult_acc8(clk, clear_acc,dout_x8, dout_f, en_acc,din_y8,valid_out8);
	memory_64_33_16_16 #(64, 6) memX9(clk, s_data_in_x,dout_x9,addr_x9, wr_en_x);
	memory_64_33_16_16 #(32, 6) memY9(clk,ReLU9,data_out_y9,acc_addr9,valid_out9);
	mult_acc_64_33_16_16 my_mult_acc9(clk, clear_acc,dout_x9, dout_f, en_acc,din_y9,valid_out9);
	memory_64_33_16_16 #(64, 6) memX10(clk, s_data_in_x,dout_x10,addr_x10, wr_en_x);
	memory_64_33_16_16 #(32, 6) memY10(clk,ReLU10,data_out_y10,acc_addr10,valid_out10);
	mult_acc_64_33_16_16 my_mult_acc10(clk, clear_acc,dout_x10, dout_f, en_acc,din_y10,valid_out10);
	memory_64_33_16_16 #(64, 6) memX11(clk, s_data_in_x,dout_x11,addr_x11, wr_en_x);
	memory_64_33_16_16 #(32, 6) memY11(clk,ReLU11,data_out_y11,acc_addr11,valid_out11);
	mult_acc_64_33_16_16 my_mult_acc11(clk, clear_acc,dout_x11, dout_f, en_acc,din_y11,valid_out11);
	memory_64_33_16_16 #(64, 6) memX12(clk, s_data_in_x,dout_x12,addr_x12, wr_en_x);
	memory_64_33_16_16 #(32, 6) memY12(clk,ReLU12,data_out_y12,acc_addr12,valid_out12);
	mult_acc_64_33_16_16 my_mult_acc12(clk, clear_acc,dout_x12, dout_f, en_acc,din_y12,valid_out12);
	memory_64_33_16_16 #(64, 6) memX13(clk, s_data_in_x,dout_x13,addr_x13, wr_en_x);
	memory_64_33_16_16 #(32, 6) memY13(clk,ReLU13,data_out_y13,acc_addr13,valid_out13);
	mult_acc_64_33_16_16 my_mult_acc13(clk, clear_acc,dout_x13, dout_f, en_acc,din_y13,valid_out13);
	memory_64_33_16_16 #(64, 6) memX14(clk, s_data_in_x,dout_x14,addr_x14, wr_en_x);
	memory_64_33_16_16 #(32, 6) memY14(clk,ReLU14,data_out_y14,acc_addr14,valid_out14);
	mult_acc_64_33_16_16 my_mult_acc14(clk, clear_acc,dout_x14, dout_f, en_acc,din_y14,valid_out14);
	memory_64_33_16_16 #(64, 6) memX15(clk, s_data_in_x,dout_x15,addr_x15, wr_en_x);
	memory_64_33_16_16 #(32, 6) memY15(clk,ReLU15,data_out_y15,acc_addr15,valid_out15);
	mult_acc_64_33_16_16 my_mult_acc15(clk, clear_acc,dout_x15, dout_f, en_acc,din_y15,valid_out15);

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
	    if(din_y4 < 0)
		ReLU4 = 0;
	    else
		ReLU4 = din_y4;
	    if(din_y5 < 0)
		ReLU5 = 0;
	    else
		ReLU5 = din_y5;
	    if(din_y6 < 0)
		ReLU6 = 0;
	    else
		ReLU6 = din_y6;
	    if(din_y7 < 0)
		ReLU7 = 0;
	    else
		ReLU7 = din_y7;
	    if(din_y8 < 0)
		ReLU8 = 0;
	    else
		ReLU8 = din_y8;
	    if(din_y9 < 0)
		ReLU9 = 0;
	    else
		ReLU9 = din_y9;
	    if(din_y10 < 0)
		ReLU10 = 0;
	    else
		ReLU10 = din_y10;
	    if(din_y11 < 0)
		ReLU11 = 0;
	    else
		ReLU11 = din_y11;
	    if(din_y12 < 0)
		ReLU12 = 0;
	    else
		ReLU12 = din_y12;
	    if(din_y13 < 0)
		ReLU13 = 0;
	    else
		ReLU13 = din_y13;
	    if(din_y14 < 0)
		ReLU14 = 0;
	    else
		ReLU14 = din_y14;
	    if(din_y15 < 0)
		ReLU15 = 0;
	    else
		ReLU15 = din_y15;
	    if(en_acc == 1 || bias_addr_x == 1) begin
	   	addr_x0 = addr_x+0;
	        acc_addr0 = (16*acc_addr)+0;
	   	addr_x1 = addr_x+1;
	        acc_addr1 = (16*acc_addr)+1;
	   	addr_x2 = addr_x+2;
	        acc_addr2 = (16*acc_addr)+2;
	   	addr_x3 = addr_x+3;
	        acc_addr3 = (16*acc_addr)+3;
	   	addr_x4 = addr_x+4;
	        acc_addr4 = (16*acc_addr)+4;
	   	addr_x5 = addr_x+5;
	        acc_addr5 = (16*acc_addr)+5;
	   	addr_x6 = addr_x+6;
	        acc_addr6 = (16*acc_addr)+6;
	   	addr_x7 = addr_x+7;
	        acc_addr7 = (16*acc_addr)+7;
	   	addr_x8 = addr_x+8;
	        acc_addr8 = (16*acc_addr)+8;
	   	addr_x9 = addr_x+9;
	        acc_addr9 = (16*acc_addr)+9;
	   	addr_x10 = addr_x+10;
	        acc_addr10 = (16*acc_addr)+10;
	   	addr_x11 = addr_x+11;
	        acc_addr11 = (16*acc_addr)+11;
	   	addr_x12 = addr_x+12;
	        acc_addr12 = (16*acc_addr)+12;
	   	addr_x13 = addr_x+13;
	        acc_addr13 = (16*acc_addr)+13;
	   	addr_x14 = addr_x+14;
	        acc_addr14 = (16*acc_addr)+14;
	   	addr_x15 = addr_x+15;
	        acc_addr15 = (16*acc_addr)+15;
	    end else begin
	   	addr_x0 = addr_x;
	        acc_addr0 = acc_addr;
	   	addr_x1 = addr_x;
	        acc_addr1 = acc_addr;
	   	addr_x2 = addr_x;
	        acc_addr2 = acc_addr;
	   	addr_x3 = addr_x;
	        acc_addr3 = acc_addr;
	   	addr_x4 = addr_x;
	        acc_addr4 = acc_addr;
	   	addr_x5 = addr_x;
	        acc_addr5 = acc_addr;
	   	addr_x6 = addr_x;
	        acc_addr6 = acc_addr;
	   	addr_x7 = addr_x;
	        acc_addr7 = acc_addr;
	   	addr_x8 = addr_x;
	        acc_addr8 = acc_addr;
	   	addr_x9 = addr_x;
	        acc_addr9 = acc_addr;
	   	addr_x10 = addr_x;
	        acc_addr10 = acc_addr;
	   	addr_x11 = addr_x;
	        acc_addr11 = acc_addr;
	   	addr_x12 = addr_x;
	        acc_addr12 = acc_addr;
	   	addr_x13 = addr_x;
	        acc_addr13 = acc_addr;
	   	addr_x14 = addr_x;
	        acc_addr14 = acc_addr;
	   	addr_x15 = addr_x;
	        acc_addr15 = acc_addr;
    	end
	    case(acc_addr % 16)
		4'd0: m_data_out_y = data_out_y0;
		4'd1: m_data_out_y = data_out_y1;
		4'd2: m_data_out_y = data_out_y2;
		4'd3: m_data_out_y = data_out_y3;
		4'd4: m_data_out_y = data_out_y4;
		4'd5: m_data_out_y = data_out_y5;
		4'd6: m_data_out_y = data_out_y6;
		4'd7: m_data_out_y = data_out_y7;
		4'd8: m_data_out_y = data_out_y8;
		4'd9: m_data_out_y = data_out_y9;
		4'd10: m_data_out_y = data_out_y10;
		4'd11: m_data_out_y = data_out_y11;
		4'd12: m_data_out_y = data_out_y12;
		4'd13: m_data_out_y = data_out_y13;
		4'd14: m_data_out_y = data_out_y14;
		4'd15: m_data_out_y = data_out_y15;
	    endcase
    	end

endmodule

module layer1_64_33_16_16_f_rom(clk, addr, z);
   input clk;
   input [5:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd191;
        1: z <= -16'd232;
        2: z <= -16'd44;
        3: z <= -16'd172;
        4: z <= -16'd139;
        5: z <= 16'd245;
        6: z <= -16'd79;
        7: z <= 16'd10;
        8: z <= 16'd78;
        9: z <= 16'd200;
        10: z <= 16'd95;
        11: z <= -16'd55;
        12: z <= -16'd180;
        13: z <= 16'd100;
        14: z <= -16'd11;
        15: z <= -16'd207;
        16: z <= 16'd22;
        17: z <= 16'd181;
        18: z <= -16'd71;
        19: z <= 16'd153;
        20: z <= -16'd219;
        21: z <= -16'd57;
        22: z <= 16'd170;
        23: z <= -16'd234;
        24: z <= 16'd238;
        25: z <= -16'd171;
        26: z <= -16'd121;
        27: z <= 16'd48;
        28: z <= -16'd94;
        29: z <= -16'd252;
        30: z <= 16'd13;
        31: z <= -16'd29;
        32: z <= -16'd227;
      endcase
   end
endmodule

module memory_64_33_16_16(clk, data_in, data_out, addr, wr_en);
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

module mult_acc_64_33_16_16(clk, reset, a, b, valid_in, f, valid_out);
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

module layer2_32_9_16_12(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y, m_valid_y, m_ready_y);
   // your stuff here!
	input 				clk, reset, s_valid_x, m_ready_y;
	input signed [15:0] 		s_data_in_x;
	output logic        		s_ready_x, m_valid_y;
	output logic signed [15:0] m_data_out_y;
	logic [3:0]		addr_f;
	logic [4:0]		addr_x;
	logic [5:0]		acc_addr;
	logic 					wr_en_x, clear_acc, en_acc, valid_out, bias_addr_x;

	controlpath_32_9_16_12 mycontrolpath(	clk, reset, s_valid_x, s_ready_x, m_valid_y, m_ready_y,
					addr_x, wr_en_x,addr_f, clear_acc, en_acc, acc_addr,
					valid_out, bias_addr_x);

	datapath_32_9_16_12 mydatapath(	clk, reset, s_data_in_x, addr_x, wr_en_x, addr_f, clear_acc, en_acc,
				m_data_out_y, acc_addr, valid_out, bias_addr_x);

endmodule

module controlpath_32_9_16_12(	clk, reset, s_valid_x, s_ready_x,
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
		    if(acc_addr == 2) begin
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
			    addr_x <= 12*L_cntr;
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

module datapath_32_9_16_12(clk, reset, s_data_in_x, 
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
	logic [4:0]		addr_x0,addr_x1,addr_x2,addr_x3,addr_x4,addr_x5,addr_x6,addr_x7,addr_x8,addr_x9,addr_x10,addr_x11;
	logic [15:0]			dout_x1,dout_x2,dout_x3,dout_x4,dout_x5,dout_x6,dout_x7,dout_x8,dout_x9,dout_x10,dout_x11;
	logic signed [15:0]			din_y1,din_y2,din_y3,din_y4,din_y5,din_y6,din_y7,din_y8,din_y9,din_y10,din_y11;
	logic signed [15:0]			ReLU1,ReLU2,ReLU3,ReLU4,ReLU5,ReLU6,ReLU7,ReLU8,ReLU9,ReLU10,ReLU11;
	logic signed [15:0]			data_out_y0,data_out_y1,data_out_y2,data_out_y3,data_out_y4,data_out_y5,data_out_y6,data_out_y7,data_out_y8,data_out_y9,data_out_y10,data_out_y11;
	logic [5:0]		acc_addr0,acc_addr1,acc_addr2,acc_addr3,acc_addr4,acc_addr5,acc_addr6,acc_addr7,acc_addr8,acc_addr9,acc_addr10,acc_addr11;
	logic 			valid_out1,valid_out2,valid_out3,valid_out4,valid_out5,valid_out6,valid_out7,valid_out8,valid_out9,valid_out10,valid_out11;


	memory_32_9_16_12 #(32, 5) memX(clk, s_data_in_x, dout_x, addr_x0, wr_en_x);
	layer2_32_9_16_12_f_rom my_rom(clk, addr_f, dout_f);
	memory_32_9_16_12 #(24, 6) memY(clk, ReLU, data_out_y0, acc_addr0, valid_out);
	mult_acc_32_9_16_12 my_mult_acc(clk, clear_acc, dout_x, dout_f, en_acc, din_y, valid_out);
	memory_32_9_16_12 #(32, 5) memX1(clk, s_data_in_x,dout_x1,addr_x1, wr_en_x);
	memory_32_9_16_12 #(24, 6) memY1(clk,ReLU1,data_out_y1,acc_addr1,valid_out1);
	mult_acc_32_9_16_12 my_mult_acc1(clk, clear_acc,dout_x1, dout_f, en_acc,din_y1,valid_out1);
	memory_32_9_16_12 #(32, 5) memX2(clk, s_data_in_x,dout_x2,addr_x2, wr_en_x);
	memory_32_9_16_12 #(24, 6) memY2(clk,ReLU2,data_out_y2,acc_addr2,valid_out2);
	mult_acc_32_9_16_12 my_mult_acc2(clk, clear_acc,dout_x2, dout_f, en_acc,din_y2,valid_out2);
	memory_32_9_16_12 #(32, 5) memX3(clk, s_data_in_x,dout_x3,addr_x3, wr_en_x);
	memory_32_9_16_12 #(24, 6) memY3(clk,ReLU3,data_out_y3,acc_addr3,valid_out3);
	mult_acc_32_9_16_12 my_mult_acc3(clk, clear_acc,dout_x3, dout_f, en_acc,din_y3,valid_out3);
	memory_32_9_16_12 #(32, 5) memX4(clk, s_data_in_x,dout_x4,addr_x4, wr_en_x);
	memory_32_9_16_12 #(24, 6) memY4(clk,ReLU4,data_out_y4,acc_addr4,valid_out4);
	mult_acc_32_9_16_12 my_mult_acc4(clk, clear_acc,dout_x4, dout_f, en_acc,din_y4,valid_out4);
	memory_32_9_16_12 #(32, 5) memX5(clk, s_data_in_x,dout_x5,addr_x5, wr_en_x);
	memory_32_9_16_12 #(24, 6) memY5(clk,ReLU5,data_out_y5,acc_addr5,valid_out5);
	mult_acc_32_9_16_12 my_mult_acc5(clk, clear_acc,dout_x5, dout_f, en_acc,din_y5,valid_out5);
	memory_32_9_16_12 #(32, 5) memX6(clk, s_data_in_x,dout_x6,addr_x6, wr_en_x);
	memory_32_9_16_12 #(24, 6) memY6(clk,ReLU6,data_out_y6,acc_addr6,valid_out6);
	mult_acc_32_9_16_12 my_mult_acc6(clk, clear_acc,dout_x6, dout_f, en_acc,din_y6,valid_out6);
	memory_32_9_16_12 #(32, 5) memX7(clk, s_data_in_x,dout_x7,addr_x7, wr_en_x);
	memory_32_9_16_12 #(24, 6) memY7(clk,ReLU7,data_out_y7,acc_addr7,valid_out7);
	mult_acc_32_9_16_12 my_mult_acc7(clk, clear_acc,dout_x7, dout_f, en_acc,din_y7,valid_out7);
	memory_32_9_16_12 #(32, 5) memX8(clk, s_data_in_x,dout_x8,addr_x8, wr_en_x);
	memory_32_9_16_12 #(24, 6) memY8(clk,ReLU8,data_out_y8,acc_addr8,valid_out8);
	mult_acc_32_9_16_12 my_mult_acc8(clk, clear_acc,dout_x8, dout_f, en_acc,din_y8,valid_out8);
	memory_32_9_16_12 #(32, 5) memX9(clk, s_data_in_x,dout_x9,addr_x9, wr_en_x);
	memory_32_9_16_12 #(24, 6) memY9(clk,ReLU9,data_out_y9,acc_addr9,valid_out9);
	mult_acc_32_9_16_12 my_mult_acc9(clk, clear_acc,dout_x9, dout_f, en_acc,din_y9,valid_out9);
	memory_32_9_16_12 #(32, 5) memX10(clk, s_data_in_x,dout_x10,addr_x10, wr_en_x);
	memory_32_9_16_12 #(24, 6) memY10(clk,ReLU10,data_out_y10,acc_addr10,valid_out10);
	mult_acc_32_9_16_12 my_mult_acc10(clk, clear_acc,dout_x10, dout_f, en_acc,din_y10,valid_out10);
	memory_32_9_16_12 #(32, 5) memX11(clk, s_data_in_x,dout_x11,addr_x11, wr_en_x);
	memory_32_9_16_12 #(24, 6) memY11(clk,ReLU11,data_out_y11,acc_addr11,valid_out11);
	mult_acc_32_9_16_12 my_mult_acc11(clk, clear_acc,dout_x11, dout_f, en_acc,din_y11,valid_out11);

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
	    if(din_y4 < 0)
		ReLU4 = 0;
	    else
		ReLU4 = din_y4;
	    if(din_y5 < 0)
		ReLU5 = 0;
	    else
		ReLU5 = din_y5;
	    if(din_y6 < 0)
		ReLU6 = 0;
	    else
		ReLU6 = din_y6;
	    if(din_y7 < 0)
		ReLU7 = 0;
	    else
		ReLU7 = din_y7;
	    if(din_y8 < 0)
		ReLU8 = 0;
	    else
		ReLU8 = din_y8;
	    if(din_y9 < 0)
		ReLU9 = 0;
	    else
		ReLU9 = din_y9;
	    if(din_y10 < 0)
		ReLU10 = 0;
	    else
		ReLU10 = din_y10;
	    if(din_y11 < 0)
		ReLU11 = 0;
	    else
		ReLU11 = din_y11;
	    if(en_acc == 1 || bias_addr_x == 1) begin
	   	addr_x0 = addr_x+0;
	        acc_addr0 = (12*acc_addr)+0;
	   	addr_x1 = addr_x+1;
	        acc_addr1 = (12*acc_addr)+1;
	   	addr_x2 = addr_x+2;
	        acc_addr2 = (12*acc_addr)+2;
	   	addr_x3 = addr_x+3;
	        acc_addr3 = (12*acc_addr)+3;
	   	addr_x4 = addr_x+4;
	        acc_addr4 = (12*acc_addr)+4;
	   	addr_x5 = addr_x+5;
	        acc_addr5 = (12*acc_addr)+5;
	   	addr_x6 = addr_x+6;
	        acc_addr6 = (12*acc_addr)+6;
	   	addr_x7 = addr_x+7;
	        acc_addr7 = (12*acc_addr)+7;
	   	addr_x8 = addr_x+8;
	        acc_addr8 = (12*acc_addr)+8;
	   	addr_x9 = addr_x+9;
	        acc_addr9 = (12*acc_addr)+9;
	   	addr_x10 = addr_x+10;
	        acc_addr10 = (12*acc_addr)+10;
	   	addr_x11 = addr_x+11;
	        acc_addr11 = (12*acc_addr)+11;
	    end else begin
	   	addr_x0 = addr_x;
	        acc_addr0 = acc_addr;
	   	addr_x1 = addr_x;
	        acc_addr1 = acc_addr;
	   	addr_x2 = addr_x;
	        acc_addr2 = acc_addr;
	   	addr_x3 = addr_x;
	        acc_addr3 = acc_addr;
	   	addr_x4 = addr_x;
	        acc_addr4 = acc_addr;
	   	addr_x5 = addr_x;
	        acc_addr5 = acc_addr;
	   	addr_x6 = addr_x;
	        acc_addr6 = acc_addr;
	   	addr_x7 = addr_x;
	        acc_addr7 = acc_addr;
	   	addr_x8 = addr_x;
	        acc_addr8 = acc_addr;
	   	addr_x9 = addr_x;
	        acc_addr9 = acc_addr;
	   	addr_x10 = addr_x;
	        acc_addr10 = acc_addr;
	   	addr_x11 = addr_x;
	        acc_addr11 = acc_addr;
    	end
	    case(acc_addr % 12)
		4'd0: m_data_out_y = data_out_y0;
		4'd1: m_data_out_y = data_out_y1;
		4'd2: m_data_out_y = data_out_y2;
		4'd3: m_data_out_y = data_out_y3;
		4'd4: m_data_out_y = data_out_y4;
		4'd5: m_data_out_y = data_out_y5;
		4'd6: m_data_out_y = data_out_y6;
		4'd7: m_data_out_y = data_out_y7;
		4'd8: m_data_out_y = data_out_y8;
		4'd9: m_data_out_y = data_out_y9;
		4'd10: m_data_out_y = data_out_y10;
		4'd11: m_data_out_y = data_out_y11;
	    endcase
    	end

endmodule

module layer2_32_9_16_12_f_rom(clk, addr, z);
   input clk;
   input [3:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= 16'd225;
        1: z <= 16'd56;
        2: z <= -16'd110;
        3: z <= 16'd214;
        4: z <= 16'd233;
        5: z <= 16'd156;
        6: z <= 16'd37;
        7: z <= 16'd177;
        8: z <= -16'd5;
      endcase
   end
endmodule

module memory_32_9_16_12(clk, data_in, data_out, addr, wr_en);
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

module mult_acc_32_9_16_12(clk, reset, a, b, valid_in, f, valid_out);
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

module layer3_24_9_16_15(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y, m_valid_y, m_ready_y);
   // your stuff here!
	input 				clk, reset, s_valid_x, m_ready_y;
	input signed [15:0] 		s_data_in_x;
	output logic        		s_ready_x, m_valid_y;
	output logic signed [15:0] m_data_out_y;
	logic [3:0]		addr_f;
	logic [4:0]		addr_x;
	logic [4:0]		acc_addr;
	logic 					wr_en_x, clear_acc, en_acc, valid_out, bias_addr_x;

	controlpath_24_10_16_15 mycontrolpath(	clk, reset, s_valid_x, s_ready_x, m_valid_y, m_ready_y,
					addr_x, wr_en_x,addr_f, clear_acc, en_acc, acc_addr,
					valid_out, bias_addr_x);

	datapath_24_10_16_15 mydatapath(	clk, reset, s_data_in_x, addr_x, wr_en_x, addr_f, clear_acc, en_acc,
				m_data_out_y, acc_addr, valid_out, bias_addr_x);

endmodule

module controlpath_24_10_16_15(	clk, reset, s_valid_x, s_ready_x,
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
		    if(acc_addr == 1) begin
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
			    addr_x <= 15*L_cntr;
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

module datapath_24_10_16_15(clk, reset, s_data_in_x, 
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
	logic [4:0]		addr_x0,addr_x1,addr_x2,addr_x3,addr_x4,addr_x5,addr_x6,addr_x7,addr_x8,addr_x9,addr_x10,addr_x11,addr_x12,addr_x13,addr_x14;
	logic [15:0]			dout_x1,dout_x2,dout_x3,dout_x4,dout_x5,dout_x6,dout_x7,dout_x8,dout_x9,dout_x10,dout_x11,dout_x12,dout_x13,dout_x14;
	logic signed [15:0]			din_y1,din_y2,din_y3,din_y4,din_y5,din_y6,din_y7,din_y8,din_y9,din_y10,din_y11,din_y12,din_y13,din_y14;
	logic signed [15:0]			ReLU1,ReLU2,ReLU3,ReLU4,ReLU5,ReLU6,ReLU7,ReLU8,ReLU9,ReLU10,ReLU11,ReLU12,ReLU13,ReLU14;
	logic signed [15:0]			data_out_y0,data_out_y1,data_out_y2,data_out_y3,data_out_y4,data_out_y5,data_out_y6,data_out_y7,data_out_y8,data_out_y9,data_out_y10,data_out_y11,data_out_y12,data_out_y13,data_out_y14;
	logic [4:0]		acc_addr0,acc_addr1,acc_addr2,acc_addr3,acc_addr4,acc_addr5,acc_addr6,acc_addr7,acc_addr8,acc_addr9,acc_addr10,acc_addr11,acc_addr12,acc_addr13,acc_addr14;
	logic 			valid_out1,valid_out2,valid_out3,valid_out4,valid_out5,valid_out6,valid_out7,valid_out8,valid_out9,valid_out10,valid_out11,valid_out12,valid_out13,valid_out14;


	memory_24_10_16_15 #(24, 5) memX(clk, s_data_in_x, dout_x, addr_x0, wr_en_x);
	layer3_24_9_16_15_f_rom my_rom(clk, addr_f, dout_f);
	memory_24_10_16_15 #(15, 5) memY(clk, ReLU, data_out_y0, acc_addr0, valid_out);
	mult_acc_24_10_16_15 my_mult_acc(clk, clear_acc, dout_x, dout_f, en_acc, din_y, valid_out);
	memory_24_10_16_15 #(24, 5) memX1(clk, s_data_in_x,dout_x1,addr_x1, wr_en_x);
	memory_24_10_16_15 #(15, 5) memY1(clk,ReLU1,data_out_y1,acc_addr1,valid_out1);
	mult_acc_24_10_16_15 my_mult_acc1(clk, clear_acc,dout_x1, dout_f, en_acc,din_y1,valid_out1);
	memory_24_10_16_15 #(24, 5) memX2(clk, s_data_in_x,dout_x2,addr_x2, wr_en_x);
	memory_24_10_16_15 #(15, 5) memY2(clk,ReLU2,data_out_y2,acc_addr2,valid_out2);
	mult_acc_24_10_16_15 my_mult_acc2(clk, clear_acc,dout_x2, dout_f, en_acc,din_y2,valid_out2);
	memory_24_10_16_15 #(24, 5) memX3(clk, s_data_in_x,dout_x3,addr_x3, wr_en_x);
	memory_24_10_16_15 #(15, 5) memY3(clk,ReLU3,data_out_y3,acc_addr3,valid_out3);
	mult_acc_24_10_16_15 my_mult_acc3(clk, clear_acc,dout_x3, dout_f, en_acc,din_y3,valid_out3);
	memory_24_10_16_15 #(24, 5) memX4(clk, s_data_in_x,dout_x4,addr_x4, wr_en_x);
	memory_24_10_16_15 #(15, 5) memY4(clk,ReLU4,data_out_y4,acc_addr4,valid_out4);
	mult_acc_24_10_16_15 my_mult_acc4(clk, clear_acc,dout_x4, dout_f, en_acc,din_y4,valid_out4);
	memory_24_10_16_15 #(24, 5) memX5(clk, s_data_in_x,dout_x5,addr_x5, wr_en_x);
	memory_24_10_16_15 #(15, 5) memY5(clk,ReLU5,data_out_y5,acc_addr5,valid_out5);
	mult_acc_24_10_16_15 my_mult_acc5(clk, clear_acc,dout_x5, dout_f, en_acc,din_y5,valid_out5);
	memory_24_10_16_15 #(24, 5) memX6(clk, s_data_in_x,dout_x6,addr_x6, wr_en_x);
	memory_24_10_16_15 #(15, 5) memY6(clk,ReLU6,data_out_y6,acc_addr6,valid_out6);
	mult_acc_24_10_16_15 my_mult_acc6(clk, clear_acc,dout_x6, dout_f, en_acc,din_y6,valid_out6);
	memory_24_10_16_15 #(24, 5) memX7(clk, s_data_in_x,dout_x7,addr_x7, wr_en_x);
	memory_24_10_16_15 #(15, 5) memY7(clk,ReLU7,data_out_y7,acc_addr7,valid_out7);
	mult_acc_24_10_16_15 my_mult_acc7(clk, clear_acc,dout_x7, dout_f, en_acc,din_y7,valid_out7);
	memory_24_10_16_15 #(24, 5) memX8(clk, s_data_in_x,dout_x8,addr_x8, wr_en_x);
	memory_24_10_16_15 #(15, 5) memY8(clk,ReLU8,data_out_y8,acc_addr8,valid_out8);
	mult_acc_24_10_16_15 my_mult_acc8(clk, clear_acc,dout_x8, dout_f, en_acc,din_y8,valid_out8);
	memory_24_10_16_15 #(24, 5) memX9(clk, s_data_in_x,dout_x9,addr_x9, wr_en_x);
	memory_24_10_16_15 #(15, 5) memY9(clk,ReLU9,data_out_y9,acc_addr9,valid_out9);
	mult_acc_24_10_16_15 my_mult_acc9(clk, clear_acc,dout_x9, dout_f, en_acc,din_y9,valid_out9);
	memory_24_10_16_15 #(24, 5) memX10(clk, s_data_in_x,dout_x10,addr_x10, wr_en_x);
	memory_24_10_16_15 #(15, 5) memY10(clk,ReLU10,data_out_y10,acc_addr10,valid_out10);
	mult_acc_24_10_16_15 my_mult_acc10(clk, clear_acc,dout_x10, dout_f, en_acc,din_y10,valid_out10);
	memory_24_10_16_15 #(24, 5) memX11(clk, s_data_in_x,dout_x11,addr_x11, wr_en_x);
	memory_24_10_16_15 #(15, 5) memY11(clk,ReLU11,data_out_y11,acc_addr11,valid_out11);
	mult_acc_24_10_16_15 my_mult_acc11(clk, clear_acc,dout_x11, dout_f, en_acc,din_y11,valid_out11);
	memory_24_10_16_15 #(24, 5) memX12(clk, s_data_in_x,dout_x12,addr_x12, wr_en_x);
	memory_24_10_16_15 #(15, 5) memY12(clk,ReLU12,data_out_y12,acc_addr12,valid_out12);
	mult_acc_24_10_16_15 my_mult_acc12(clk, clear_acc,dout_x12, dout_f, en_acc,din_y12,valid_out12);
	memory_24_10_16_15 #(24, 5) memX13(clk, s_data_in_x,dout_x13,addr_x13, wr_en_x);
	memory_24_10_16_15 #(15, 5) memY13(clk,ReLU13,data_out_y13,acc_addr13,valid_out13);
	mult_acc_24_10_16_15 my_mult_acc13(clk, clear_acc,dout_x13, dout_f, en_acc,din_y13,valid_out13);
	memory_24_10_16_15 #(24, 5) memX14(clk, s_data_in_x,dout_x14,addr_x14, wr_en_x);
	memory_24_10_16_15 #(15, 5) memY14(clk,ReLU14,data_out_y14,acc_addr14,valid_out14);
	mult_acc_24_10_16_15 my_mult_acc14(clk, clear_acc,dout_x14, dout_f, en_acc,din_y14,valid_out14);

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
	    if(din_y4 < 0)
		ReLU4 = 0;
	    else
		ReLU4 = din_y4;
	    if(din_y5 < 0)
		ReLU5 = 0;
	    else
		ReLU5 = din_y5;
	    if(din_y6 < 0)
		ReLU6 = 0;
	    else
		ReLU6 = din_y6;
	    if(din_y7 < 0)
		ReLU7 = 0;
	    else
		ReLU7 = din_y7;
	    if(din_y8 < 0)
		ReLU8 = 0;
	    else
		ReLU8 = din_y8;
	    if(din_y9 < 0)
		ReLU9 = 0;
	    else
		ReLU9 = din_y9;
	    if(din_y10 < 0)
		ReLU10 = 0;
	    else
		ReLU10 = din_y10;
	    if(din_y11 < 0)
		ReLU11 = 0;
	    else
		ReLU11 = din_y11;
	    if(din_y12 < 0)
		ReLU12 = 0;
	    else
		ReLU12 = din_y12;
	    if(din_y13 < 0)
		ReLU13 = 0;
	    else
		ReLU13 = din_y13;
	    if(din_y14 < 0)
		ReLU14 = 0;
	    else
		ReLU14 = din_y14;
	    if(en_acc == 1 || bias_addr_x == 1) begin
	   	addr_x0 = addr_x+0;
	        acc_addr0 = (15*acc_addr)+0;
	   	addr_x1 = addr_x+1;
	        acc_addr1 = (15*acc_addr)+1;
	   	addr_x2 = addr_x+2;
	        acc_addr2 = (15*acc_addr)+2;
	   	addr_x3 = addr_x+3;
	        acc_addr3 = (15*acc_addr)+3;
	   	addr_x4 = addr_x+4;
	        acc_addr4 = (15*acc_addr)+4;
	   	addr_x5 = addr_x+5;
	        acc_addr5 = (15*acc_addr)+5;
	   	addr_x6 = addr_x+6;
	        acc_addr6 = (15*acc_addr)+6;
	   	addr_x7 = addr_x+7;
	        acc_addr7 = (15*acc_addr)+7;
	   	addr_x8 = addr_x+8;
	        acc_addr8 = (15*acc_addr)+8;
	   	addr_x9 = addr_x+9;
	        acc_addr9 = (15*acc_addr)+9;
	   	addr_x10 = addr_x+10;
	        acc_addr10 = (15*acc_addr)+10;
	   	addr_x11 = addr_x+11;
	        acc_addr11 = (15*acc_addr)+11;
	   	addr_x12 = addr_x+12;
	        acc_addr12 = (15*acc_addr)+12;
	   	addr_x13 = addr_x+13;
	        acc_addr13 = (15*acc_addr)+13;
	   	addr_x14 = addr_x+14;
	        acc_addr14 = (15*acc_addr)+14;
	    end else begin
	   	addr_x0 = addr_x;
	        acc_addr0 = acc_addr;
	   	addr_x1 = addr_x;
	        acc_addr1 = acc_addr;
	   	addr_x2 = addr_x;
	        acc_addr2 = acc_addr;
	   	addr_x3 = addr_x;
	        acc_addr3 = acc_addr;
	   	addr_x4 = addr_x;
	        acc_addr4 = acc_addr;
	   	addr_x5 = addr_x;
	        acc_addr5 = acc_addr;
	   	addr_x6 = addr_x;
	        acc_addr6 = acc_addr;
	   	addr_x7 = addr_x;
	        acc_addr7 = acc_addr;
	   	addr_x8 = addr_x;
	        acc_addr8 = acc_addr;
	   	addr_x9 = addr_x;
	        acc_addr9 = acc_addr;
	   	addr_x10 = addr_x;
	        acc_addr10 = acc_addr;
	   	addr_x11 = addr_x;
	        acc_addr11 = acc_addr;
	   	addr_x12 = addr_x;
	        acc_addr12 = acc_addr;
	   	addr_x13 = addr_x;
	        acc_addr13 = acc_addr;
	   	addr_x14 = addr_x;
	        acc_addr14 = acc_addr;
    	end
	    case(acc_addr % 15)
		4'd0: m_data_out_y = data_out_y0;
		4'd1: m_data_out_y = data_out_y1;
		4'd2: m_data_out_y = data_out_y2;
		4'd3: m_data_out_y = data_out_y3;
		4'd4: m_data_out_y = data_out_y4;
		4'd5: m_data_out_y = data_out_y5;
		4'd6: m_data_out_y = data_out_y6;
		4'd7: m_data_out_y = data_out_y7;
		4'd8: m_data_out_y = data_out_y8;
		4'd9: m_data_out_y = data_out_y9;
		4'd10: m_data_out_y = data_out_y10;
		4'd11: m_data_out_y = data_out_y11;
		4'd12: m_data_out_y = data_out_y12;
		4'd13: m_data_out_y = data_out_y13;
		4'd14: m_data_out_y = data_out_y14;
	    endcase
    	end

endmodule

module layer3_24_9_16_15_f_rom(clk, addr, z);
   input clk;
   input [3:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= 16'd238;
        1: z <= 16'd254;
        2: z <= -16'd161;
        3: z <= -16'd28;
        4: z <= -16'd209;
        5: z <= 16'd117;
        6: z <= -16'd103;
        7: z <= -16'd24;
        8: z <= 16'd15;
        9: z <= -16'd66;
      endcase
   end
endmodule

module memory_24_10_16_15(clk, data_in, data_out, addr, wr_en);
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

module mult_acc_24_10_16_15(clk, reset, a, b, valid_in, f, valid_out);
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

