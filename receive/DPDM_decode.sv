`default_nettype none

module DPDM_decode_FSM(
	input logic clock, reset_n,
	input logic sync_rec, se0_rec, in_bit, rec_start,
	input logic [2:0] PID_rec,
	output logic dpdm_sending, ACK_rec, NAK_rec, DATA0_rec);

	enum logic [4:0] {DEAD, WAITSYNC, WAITPID, ACK_R, NAK_R, 
						DATA0_R, EOP0, EOP1, EOP2} currState, nextState;


	logic [2:0] ACK_PID, NAK_PID, DATA0_PID;

	assign ACK_PID = 3'b001;
	assign NAK_PID = 3'b010;
	assign DATA0_PID = 3'b100;

	always_comb begin
    {dpdm_sending, ACK_rec, NAK_rec, DATA0_rec} = 4'b0000;

    unique case (currState)
    	DEAD: begin
    		if(~rec_start) begin

    			nextState = DEAD;
    		end
    		else begin

    			nextState = WAITSYNC;
    		end
    	end

    	WAITSYNC: begin
    		if(~sync_rec) begin

    			nextState = WAITSYNC;
    		end
    		else begin

    			nextState = WAITPID;
    		end
    	end

    	WAITPID: begin 
    		if(PID_rec == 3'b000) begin 

    			nextState = WAITPID;
    		end
    		else if ((PID_rec == ACK_PID)) begin 
    			ACK_rec = 1;

    			nextState = ACK_R;
    		end
    		else if ((PID_rec == NAK_PID)) begin 
    			NAK_rec = 1;

    			nextState = NAK_R;
    		end
    		else if ((PID_rec == DATA0_PID)) begin 
    			DATA0_rec = 1;
    			dpdm_sending = 1;

    			nextState = DATA0_R;
    		end
    	end

    	ACK_R: begin 
    		if(se0_rec) begin

    			nextState = EOP0;
    		end
    	end

    	NAK_R: begin 
    		if(se0_rec) begin

    			nextState = EOP0;
    		end
    	end

    	DATA0_R: begin 
    		if(se0_rec) begin 

    			nextState = EOP0;
    		end 
    		else begin 
    			dpdm_sending = 1;

    			nextState = DATA0_R;
    		end
    	end

    	EOP0: begin
    		if(se0_rec) begin 

    			nextState = EOP1;
    		end 
    	end

    	EOP1: begin
    		if(in_bit) begin 

    			nextState = EOP2;
    		end 
    	end

    	EOP2: begin

    		nextState  = DEAD;
    	end

    endcase
  end

  always_ff @ (posedge clock, negedge reset_n) begin
    if (~reset_n)
      currState <= DEAD;
    else
      currState <= nextState;
  end

endmodule : DPDM_decode_FSM

//BEGIN DATAPATH

// input logic clock, reset_n,
// 	input logic sync_rec, se0_rec, in_bit, rec_start,
// 	input logic [2:0] PID_rec,
// 	input logic [31:0] bit_count,
// 	output logic dpdm_sending, clr_cnt, ACK_rec, NAK_rec, DATA0_rec
module DPDM_decode(
	input logic clock, reset_n,
	input logic DP_in, DM_in, rec_start,
	output logic out_bit, dpdm_sending);

	logic sync_rec, se0_rec;
	logic [2:0] PID_rec;
	logic load_matchReg;
	logic [7:0] match_val;
    logic clr_cnt, ACK_rec, NAK_rec, DATA0_rec;

	DPDM_decode_FSM fsm (.in_bit(out_bit), .*);

	SIPO_Register_Right matchReg (.D(out_bit), .load(load_matchReg), 
									.Q(match_val),  .*);


	always_ff @(posedge clock, negedge reset_n) begin
		if(~reset_n) begin
			 load_matchReg <= 0;
		end else begin
			 load_matchReg <= 1;
		end
	end


	always_comb begin
		{out_bit, se0_rec} = 2'bz0;
		unique case({DP_in, DM_in})
			2'b10: out_bit = 1'b1;
			2'b01: out_bit = 1'b0;
			2'b00: begin
				out_bit = 1'bz;
				se0_rec = 1'b1;
			end
			2'bzz: out_bit = 1'bz;
		endcase
	end

	always_comb begin
		{PID_rec,sync_rec} = 4'b0000;
		case (match_val)
			8'b0010_1010: sync_rec = 1;  //SYNC
			8'b0001_1011: PID_rec = 3'b001;  //ACK
			8'b0110_0011: PID_rec = 3'b010; //NAK
			8'b0001_0100: PID_rec = 3'b100; //DATA0
		endcase
	end

endmodule: DPDM_decode