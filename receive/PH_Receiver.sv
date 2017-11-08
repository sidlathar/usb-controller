`default_nettype none

module PH_Receiver_fsm(
	input logic crc_sending, crc_valid, rec_start, ACK_rec, 
				NAK_rec,
	output logic rec_ACK, rec_NAK, rec_DATA0, data_valid);

	enum logic [2:0] {IDLE, RECEIVE, DATA_RECEIVE} currState, nextState;

	
	always_comb begin
		{rec_ACK, rec_NAK, rec_DATA0, data_valid} = 4'b0000;
		unique case (currState)
			IDLE: begin
				if(~rec_start) begin
					nextState = IDLE;
				end
				else begin
					nextState = RECEIVE;
				end
			end

			RECEIVE: begin
				if(ACK_rec) begin
					rec_ACK = 1;

					nextState = IDLE;
				end
				else if(NAK_rec) begin
					rec_NAK = 1;

					nextState = IDLE;
				end
				else if(crc_sending) begin

					nextState = DATA_RECEIVE;
				end
				else begin

					nextState = RECEIVE;
				end
			end

			DATA_RECEIVE: begin
				if(crc_valid == 1'bz) begin
					nextState = DATA_RECEIVE;
				end
				else if(crc_valid == 1'b1)begin
					rec_DATA0 = 1;
					data_valid = 1;

					nextState = IDLE;
				end
				else if(~crc_valid) begin
					rec_DATA0 = 1;
					data_valid = 0;

					nextState = IDLE;
				end
			end
		endcase
	end
endmodule: PH_Receiver_fsm


module PH_Receiver
	(input logic clock, reset_n, rec_start, crc_sending,
	 input logic crc_valid, ACK_rec, NAK_rec, DATA0_rec,
	 input logic [63:0] data0,
	output logic rec_ACK, rec_NAK, rec_DATA0,
	output logic [63:0] data, data_valid);


	assign data = (data_valid)? data0: 64'bZ;



endmodule: PH_Receiver // PH_Receiver