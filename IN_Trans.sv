`default_nettype none

module IN_Trans
  (input  logic clock, reset_n,
  // RW_FSM signals
  input  logic        start,
  output logic        done, success, failure
  // PH_Sender signals
  input  logic sent,
  output logic send_IN, send_ACK, send_NAK,
  // PH_Receiver signals
  input  logic        rec_DATA0, data_valid, rec_start,
  input  logic [63:0] data_rec);

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

  // INVALID COUNTER
  logic [31:0] invalid_cnt;
  logic invalid_cnt_inc, invalid_cnt_clr;
  always_ff @(posedge clock, posedge ~reset_n) begin
    if(~reset_n) begin
      invalid_cnt <= 0;
    end else if (invalid_cnt_clr) begin
      invalid_cnt <= 0;
    end else if (invalid_cnt_inc) begin
      invalid_cnt <= invalid_cnt + 1;
    end
  end

  // REGISTER TO HOLD DATA RECEIVED
  logic [63:0] data_reg_Q;
  always_ff @(posedge clock, negedge reset_n) begin
      if (~reset_n) begin
        data_reg_Q <= 64'd0;
      end else if (data_reg_clr) begin
        data_reg_Q <= 64'd0;
      end else if (data_reg_ld) begin
        data_reg_Q <= data_rec;
      end
  end

  /************************************ FSM ***********************************/

  enum logic [2:0] {IDLE, WAIT_SEND_IN, WAIT_RESPONSE,
                    WAIT_SEND_NAK} currState, nextState;

  // NS and output logic
  always_comb begin
    {send_IN, send_ACK, send_NAK, clk_cnt_inc, clk_cnt_clr, to_cnt_inc,
     to_cnt_clr, invalid_cnt_inc, invalid_cnt_clr, data_reg_ld, data_reg_clr,
     done, success, failure} = 14'b0;

    case (currState) begin
      IDLE : begin
        if (~start) begin
          nextState = IDLE;
        end else begin
          send_IN = 1;

          nextState = WAIT_SEND_IN;
        end
      end

      WAIT_SEND_IN : begin
        if (~sent) begin
          // Wait for PH_Sender to finish sending
          nextState = WAIT_SEND_IN;
        end else begin
          // Now we wait for a response
          clk_cnt_clr = 1;
          to_cnt_clr = 1;
          invalid_cnt_clr = 1;
          data_reg_clr = 1;

          nextState = WAIT_RESPONSE;
        end
      end

      WAIT_RESPONSE : begin
        if (rec_start) begin
          // Need to "stop" clock counting for timeout
          // Only works b/c we'll get an ACK/NAK before 255 cycles is up
          clk_cnt_clr = 1; 

          nextState = WAIT_RESPONSE;
        end else if (to_cnt == 32'd8 || invalid_cnt == 32'd8) begin
          // Transaction failed
          done = 1;
          failure = 1;

          nextState = IDLE;
        end else if (clk_cnt == 32'd255) begin
          // Timed out, send a NAK and wait again
          send_NAK = 1;
          to_cnt_inc;

          nextState = WAIT_SEND_NAK;
        end else if (rec_DATA0 && ~data_valid) begin
          // Data invalid, send a NAK and wait again
          send_NAK = 1;
          invalid_cnt_inc = 1;
          data_reg_ld = 1; // Load result for the testbench ?

          nextState = WAIT_SEND_NAK;
        end else if (rec_DATA0 && data_valid) begin
          // Transaction succeeded
          send_ACK = 1;
          done = 1;
          success = 1;
          data_reg_ld = 1; // Load result for the testbench ?

          nextState = IDLE;
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


endmodule : IN_Trans