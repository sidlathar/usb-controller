`default_nettype none

module DPDM_decode_FSM(
	input logic sync_rec, se0_rec, in_bit, rec_start,
	input logic [2:0] PID_rec,
	input logic [31:0] bit_count,
	output logic dpdm_sending, rec_failed, clr_cnt, ACK_rec, NAK_rec, DATA0_rec);

	enum logic [4:0] {DEAD, WAITSYNC, WAITPID, ACK_R, NAK_R, 
						DATA0_R, EOP0, EOP1, EOP2} currState, nextState;


	logic [2:0] ACK_PID, NAK_PID, DATA0_PID;

	assign ACK_PID = 3'b001;
	assign NAK_PID = 3'b010;
	assign DATA0_PID = 3'b100;

	always_comb begin
    {dpdm_sending, rec_failed, clr_cnt, ACK_rec, NAK_rec} = 5'b00000;

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
    			clr_cnt = 1;

    			nextState = WAITPID;
    		end
    	end

    	WAITPID: begin 
    		if(~(PID_rec) && (bit_count != 8)) begin 

    			nextState = WAITPID;
    		end
    		else if ((~PID_rec) && (bit_count == 8)) begin 
    			rec_failed = 1;

    			nextState = DEAD;
    		end
    		else if ((PID_rec == ACK_PID) && (bit_count == 8)) begin 
    			ACK_rec = 1;

    			nextState = ACK_R;
    		end
    		else if ((PID_rec == NAK_PID) && (bit_count == 8)) begin 
    			NAK_rec = 1;

    			nextState = NAK_R;
    		end
    		else if ((PID_rec == DATA0_PID) && (bit_count == 8)) begin 
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


module DPDM_decode(
	);