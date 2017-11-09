`default_nettype none

module OUT_Trans
  (input  logic clock, reset_n,
  // RW_FSM signals
  input  logic        start,
  output logic        sending, done, success, failure,
  // PH_Sender signals
  input  logic sent,
  output logic send_OUT, send_DATA0,
  // PH_Receiver signals
  input  logic rec_ACK, rec_NAK, rec_start);

  /********************************* DATAPATH *********************************/

  // CLOCK COUNTER
  logic [31:0] clk_cnt;
  logic clk_cnt_inc, clk_cnt_clr;
  always_ff @(posedge clock, posedge ~reset_n) begin
    if(~reset_n) begin
      clk_cnt <= 0;
    end else if (clk_cnt_clr) begin
      clk_cnt <= 0;
    end else begin
      clk_cnt <= clk_cnt + 1;
    end
  end

  // TIMEOUT COUNTER
  logic [31:0] to_cnt;
  logic to_cnt_inc, to_cnt_clr;
  always_ff @(posedge clock, posedge ~reset_n) begin
    if(~reset_n) begin
      to_cnt <= 0;
    end else if (to_cnt_clr) begin
      to_cnt <= 0;
    end else if (to_cnt_inc) begin
      to_cnt <= to_cnt + 1;
    end
  end

  // NAK RECEIVED COUNTER
  logic [31:0] nak_cnt;
  logic nak_cnt_inc, nak_cnt_clr;
  always_ff @(posedge clock, posedge ~reset_n) begin
    if(~reset_n) begin
      nak_cnt <= 0;
    end else if (nak_cnt_clr) begin
      nak_cnt <= 0;
    end else if (nak_cnt_inc) begin
      nak_cnt <= nak_cnt + 1;
    end
  end

  /************************************ FSM ***********************************/

  enum logic [2:0] {IDLE, WAIT_SEND_OUT,
                    WAIT_SEND_DATA0, WAIT_RESPONSE} currState, nextState;

  // NS and output logic
  always_comb begin
    {send_OUT, send_DATA0, clk_cnt_inc, clk_cnt_clr, to_cnt_inc, to_cnt_clr,
     nak_cnt_inc, nak_cnt_clr, sending, done, success, failure} = 12'b0;

    case (currState)
      IDLE : begin
        if (~start) begin
          nextState = IDLE;
        end else begin
          send_OUT = 1;

          nextState = WAIT_SEND_OUT;
        end
      end

      WAIT_SEND_OUT : begin
        if (~sent) begin
          // Wait for PH_Sender to finish sending
          sending = 1;

          nextState = WAIT_SEND_OUT;
        end else begin
          // Now we can send DATA0
          send_DATA0 = 1;
          to_cnt_clr = 1;
          nak_cnt_clr = 1;

          nextState = WAIT_SEND_DATA0;
        end
      end

      WAIT_SEND_DATA0 : begin
        if (~sent) begin
          // Wait for PH_Sender to finish sending
          sending = 1;

          nextState = WAIT_SEND_DATA0;
        end else begin
          // Now we start counting for timeout
          clk_cnt_clr = 1;

          nextState = WAIT_RESPONSE;
        end
      end

      WAIT_RESPONSE : begin
        if (rec_start) begin
          // Need to "stop" clock counting for timeout
          // Only works b/c we'll get an ACK/NAK before 255 cycles is up
          clk_cnt_clr = 1; 

          nextState = WAIT_RESPONSE;
        end else if (to_cnt == 32'd8 || nak_cnt == 32'd8) begin
          // Transaction failed
          done = 1;
          failure = 1;

          nextState = IDLE;
        end else if (rec_ACK) begin
          // Transaction succeeded
          done = 1;
          success = 1;

          nextState = IDLE;
        end else if (rec_NAK) begin
          // NAK received, try sending DATA0 again
          send_DATA0 = 1;
          nak_cnt_inc = 1;

          nextState = WAIT_SEND_DATA0;
        end else if (clk_cnt == 32'd255) begin
          // Timed out, try sending DATA0 again
          send_DATA0 = 1;
          to_cnt_inc = 1;

          nextState = WAIT_SEND_DATA0;
        end
      end
    endcase // currState
  end

  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      currState <= IDLE;
    end else begin
      currState <= nextState;
    end
  end


endmodule : OUT_Trans