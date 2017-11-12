`default_nettype none

module NRZI_Encode_FSM
  (input logic clock, reset_n,
               in_bit, bs_sending,
   output logic out_sel, nrzi_sending, clear);

  enum logic {IDLE, WORK} currState, nextState;

  always_comb begin
    {out_sel, nrzi_sending, clear} = 3'b000;

    case (currState)

      IDLE : begin
        if (~bs_sending)
          nextState = IDLE;
        else begin
          out_sel = 0;
          nrzi_sending = 1;

          nextState = WORK;
        end
      end

      WORK : begin
        if (bs_sending) begin
          out_sel = 1;
          nrzi_sending = 1;

          nextState = WORK;
        end else begin
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
  
endmodule : NRZI_Encode_FSM

module NRZI_Encode
  (input logic clock, reset_n,
               in_bit, bs_sending,
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
      prev_bit <= out_bit;
    end
  end

  // Logic for NRZI_bit
  logic NRZI_bit;
  always_comb begin
    if (in_bit)
      // Same prev bit when input is 1
      NRZI_bit = prev_bit;
    else
      // Flips prev bit when input is 0
      NRZI_bit = ~prev_bit;
  end

  // Mux the in_bit (need the first bit to be same) and NRZI_bit
  logic out_sel;
  always_comb begin
    if (out_sel)
      out_bit = NRZI_bit;
    else
      out_bit = prev_bit;
  end

  // THE FSM
  NRZI_Encode_FSM fsm (.*);
  // (input logic clock, reset_n,
  //              in_bit, bs_sending
  //  output logic out_sel, nrzi_sending);

endmodule : NRZI_Encode