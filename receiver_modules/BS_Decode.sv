`default_nettype none

module BitStuffer_Decode_FSM
  (input  logic        clock, reset_n,
                       nrzi_sending, in_bit,
   input  logic [31:0] ones_cnt, bit_cnt,
   output logic        oc_inc, oc_clr, bs_sending);

  enum logic [2:0] {IDLE, COUNT_ONES, REMOVE_ZERO,
                    RESUME_SEND} currState, nextState;

  always_comb begin
    {oc_inc, oc_clr, bs_sending} = 3'b000;

    case (currState)

      IDLE : begin   //WAIT FOR NRZI TO SEND DATA
        if (~nrzi_sending) begin
          nextState = IDLE;
        end
        else begin
          if(in_bit == 1) begin     // Start bit is important
            oc_inc = 1;
          end
          bs_sending = 1;
          nextState = COUNT_ONES;
        end
      end

      COUNT_ONES : begin   //COUNT ONES AND REMOVE 0 AFTER SIX 1s
        if(~nrzi_sending) begin
          bs_sending  = 0;

          nextState = IDLE;
        end
          //FIVE 1s AND WE SEE A ONE MEANS NEXT 0 SHOULD BE REMOVED
        else if (in_bit == 1 && ones_cnt == 32'd5 && nrzi_sending) begin
          oc_clr = 1;
          bs_sending = 1;

          nextState = REMOVE_ZERO;
        end
        else if(in_bit == 1 && ones_cnt != 32'd5 && nrzi_sending) begin
          bs_sending = 1;
          oc_inc = 1;

          nextState = COUNT_ONES;
        end
        else begin
          bs_sending = 1;
          oc_clr = 1;

          nextState = COUNT_ONES;
        end
      end

      REMOVE_ZERO : begin   // REMOVE ZERO AND PAUSE SENDING
        bs_sending = 0;

        nextState = RESUME_SEND;
      end

      RESUME_SEND : begin
        if (nrzi_sending) begin
          bs_sending = 1;
          //WHEN COMING BACK FROM REMOVING ZERO KEEP IN MIND OF THE BIT JUST RECIEVE
          if (in_bit) 
            oc_inc = 1;

          nextState = COUNT_ONES;
        end
        else begin
          oc_clr = 1;

          nextState = IDLE;
        end
      end
    endcase
  end

  always_ff @ (posedge clock, negedge reset_n) begin
    if (~reset_n)
      currState <= IDLE;
    else
      currState <= nextState;
  end

endmodule : BitStuffer_Decode_FSM

module BitStuffer_decode
  (input  logic clock, reset_n,
                nrzi_sending, in_bit,
   output logic out_bit, bs_sending);

  logic [31:0] ones_cnt, bit_cnt;
  logic oc_inc, oc_clr;

  BitStuffer_Decode_FSM fsm (.*);
  // (input  logic        clock, reset_n,
  //                      nrzi_sending, in_bit,
  //  input  logic [31:0] ones_cnt, bit_cnt,
  //  output logic        oc_inc, oc_clr,
  //                      bs_sending);

  // COUNT THE ONES WE SEE
  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      ones_cnt <= 0;
    end else if (oc_clr) begin
      ones_cnt <= 0;
    end else if (oc_inc) begin
      ones_cnt <= ones_cnt + 1;
    end
  end

  // MUX THE BITSTREAM, OR CHOOSE TO SEND A BITSTUFF (0)
  always_comb begin
    if (~bs_sending)
      out_bit = 1'bz;
    else
      out_bit = in_bit;
  end // always_comb

endmodule : BitStuffer_decode
