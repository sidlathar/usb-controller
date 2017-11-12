`default_nettype none

module PH_Receiver_fsm(
  input logic clock, reset_n, crc_sending, crc_valid, fsm_start, ACK_rec, 
        NAK_rec,
  output logic rec_ACK, rec_NAK, rec_DATA0, data_valid);

  enum logic [2:0] {IDLE, RECEIVE, DATA_RECEIVE, EOP_1,
                    EOP_2} currState, nextState;

  
  always_comb begin
    {rec_ACK, rec_NAK, rec_DATA0, data_valid} = 4'b0000;
    case (currState)
      IDLE: begin
        if(~fsm_start) begin

          nextState = IDLE;
        end else begin

          nextState = RECEIVE;
        end
      end

      RECEIVE: begin  //RECEVING A PACKET, ASSERT (rec_*) SIGNALS WHEN PID RECOGNIZED
        if(ACK_rec) begin
          rec_ACK = 1;

          nextState = IDLE;
        end else if(NAK_rec) begin
          rec_NAK = 1;

          nextState = IDLE;
        end else if(crc_sending) begin

          nextState = DATA_RECEIVE;
        end else begin

          nextState = RECEIVE;
        end
      end

      DATA_RECEIVE: begin   //RECEIVE DATA0 UNTIL SE0 IS RECEIVED
        if(crc_valid === 1'bz) begin

          nextState = DATA_RECEIVE;
        end else if (crc_valid == 1'b1)begin
          rec_DATA0 = 1;
          data_valid = 1;

          nextState = IDLE;
        end else if (~crc_valid) begin

          nextState = EOP_1;
        end
      end

      EOP_1 : begin
        // Need to wait to finish receiving the EOP from device

        nextState = EOP_2;
      end

      EOP_2 : begin
        rec_DATA0 = 1;
        data_valid = 0;

        nextState = IDLE;
      end
    endcase
  end

  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      currState <= IDLE;
    end else begin
      currState <= nextState;
    end
  end
  
endmodule: PH_Receiver_fsm


module PH_Receiver
  (input logic clock, reset_n, DP_in, DM_in, host_sending,
  output logic rec_ACK, rec_NAK, rec_DATA0,
  output logic [63:0] data_rec, 
  output logic data_valid, rec_start); //TO READ WRITE FSM

  logic fsm_start;
  always_comb begin
    if ((host_sending) || (DP_in === 1'bz && DM_in === 1'bz)) begin
      fsm_start = 0;
    end else begin
      fsm_start = 1;
    end

  end


  // input logic clock, reset_n,
  // input logic DP_in, DM_in, host_sending
  // output logic out_bit, dpdm_sending, rec_start, load_data,
  // output logic ACK_rec, NAK_rec, DATA0_rec);
  // logic DP_in, DM_in;
  logic dpdm_out_bit, dpdm_sending, load_data,
        ACK_rec, NAK_rec, DATA0_rec;

  DPDM_decode dpdmDecode(.out_bit(dpdm_out_bit),.*);



  // module NRZI_decoder
  //   (input logic clock, reset_n,
  //                in_bit, dpdm_sending,
  //    output logic out_bit, nrzi_sending);
  logic nrzi_out_bit, nrzi_sending;

  NRZI_decoder nrziDecode(.in_bit(dpdm_out_bit), .out_bit(nrzi_out_bit), .*);


  // // module BitStuffer_decode
  // //   (input  logic clock, reset_n,
  // //                 nrzi_sending, in_bit,
  // //    output logic out_bit, bs_sending);

  logic bs_sending, bs_out_bit;

  BitStuffer_decode bsDecode(.in_bit(nrzi_out_bit), .out_bit(bs_out_bit), .*);


  // (input  logic clock, reset_n,
  //          bs_sending, load_data,     
  //  input  logic in_bit,
  //  output logic out_bit, 
  //          crc_sending, crc_valid,
  //  output logic [63:0] data0);  

  logic crc_sending, crc_out_bit, crc_valid;
  logic [63:0] data0;

  CRC16_Decode crc16Decode(.in_bit(bs_out_bit), .out_bit(crc_out_bit), .*);



  assign data_rec = data0;

  PH_Receiver_fsm fsm(.*);

endmodule : PH_Receiver