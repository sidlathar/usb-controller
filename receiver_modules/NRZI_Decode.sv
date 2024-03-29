`default_nettype none

module NRZI_decoder_FSM
  (input logic clock, reset_n,
               in_bit, dpdm_sending,
   output logic nrzi_sending, clear);

  enum logic {IDLE, WORK} currState, nextState;

  always_comb begin
    {nrzi_sending, clear} = 2'b00;

    case (currState)

      IDLE : begin //WAIT FOR DPDM SEND DATA
        if (~dpdm_sending)
          nextState = IDLE;
        else begin
          nrzi_sending = 1;

          nextState = WORK;
        end
      end

      WORK : begin  //UN-NRZI-DECODE INCOMING BITSTREAM
        if (dpdm_sending) begin
          nrzi_sending = 1;

          nextState = WORK;
        end else begin
          nrzi_sending = 1;
          clear = 1;

          nextState = IDLE;
        end
      end

    endcase // currState

  end // always_comb

  always_ff @ (posedge clock, negedge reset_n) begin
    if (~reset_n)
      currState <= IDLE;
    else
      currState <= nextState;
  end

endmodule : NRZI_decoder_FSM

module NRZI_decoder
  (input  logic clock, reset_n,
                in_bit, dpdm_sending,
   output logic out_bit, nrzi_sending);

  // "Flip-flop" to remember the previous bit
  logic prev_bit, clear;
  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      prev_bit <= 0;
    end else if (clear) begin
      prev_bit <= 0;
    end else begin
      // Load in_bit every clock edge
      prev_bit <= in_bit; // now prev bit is based on the in_bit
    end
  end

  // Logic for out_bit (ALWAYS NRZI_bit in the decode)
  always_comb begin
    if (in_bit)
      // Same prev bit when input is 1
      out_bit = prev_bit;
    else
      // Flips prev bit when input is 0
      out_bit = ~prev_bit;
  end

  // THE FSM
  NRZI_decoder_FSM fsm (.*);
  // (input logic clock, reset_n,
  //              in_bit, dpdm_sending
  //  output logic out_sel, nrzi_sending);

endmodule : NRZI_decoder
