`default_nettype none

module BS_Encode_FSM
  (input  logic        clock, reset_n,
                       crc_valid_out, in_bit,
   input  logic [31:0] ones_cnt, bit_cnt,
   output logic        bs_ready, oc_inc, oc_clr, bc_inc, bc_clr, sel_stuffbit,
                       bs_sending);

  enum logic [2:0] {IDLE, IGNORE_PID, COUNT_ONES, SEND_ZERO,
                    RESUME_SEND, SEND_LAST} currState, nextState;

  always_comb begin
    {bs_ready, oc_inc, oc_clr, bc_inc, bc_clr, sel_stuffbit,
     bs_sending} = 7'b10_0000_0;
    // NOTE : bs_ready DEFAULTED TO 1

    case (currState)

      IDLE : begin
        if (~crc_valid_out) begin
          nextState = IDLE;
        end else begin
          oc_clr = 1;
          bc_clr = 1;
          bs_sending = 1;

          nextState = IGNORE_PID;
        end
      end

      IGNORE_PID : begin
        if (bit_cnt != 32'd7) begin
          bc_inc = 1;
          bs_sending = 1;

          nextState = IGNORE_PID;
        end else if (bit_cnt == 32'd7 && in_bit == 0) begin
          bs_sending = 1;

          nextState = COUNT_ONES;
        end else if (bit_cnt == 32'd7 && in_bit == 1) begin
          oc_inc = 1;
          bs_sending = 1;

          nextState = COUNT_ONES;
        end
      end

      COUNT_ONES : begin
        if (in_bit == 1 && ones_cnt != 32'd5 && crc_valid_out) begin
          oc_inc = 1;
          bs_sending = 1;

          nextState = COUNT_ONES;
        end else if (in_bit == 0 && ones_cnt != 32'd5 && crc_valid_out) begin
          oc_clr = 1;
          bs_sending = 1;

          nextState = COUNT_ONES;
        end else if (~crc_valid_out) begin
          // bs_sending = 1;

          nextState = IDLE;
        end else if (in_bit == 1 && ones_cnt == 32'd5) begin
          oc_clr = 1;
          bs_sending = 1;

          nextState = SEND_ZERO;
        end else if (in_bit == 0 && ones_cnt == 32'd5) begin
          oc_clr = 1;
          bs_sending = 1;

          nextState = COUNT_ONES;
        end
      end

      SEND_ZERO : begin
        if (crc_valid_out) begin
          bs_ready = 0; // IMPORTANT: TELLS CRC TO STOP AND HOLD VALUE FOR US
          sel_stuffbit = 1;
          bs_sending = 1;

          nextState = RESUME_SEND;
        end else begin
          bs_ready = 0; // IMPORTANT: TELLS CRC TO STOP AND HOLD VALUE FOR US
          sel_stuffbit = 1;
          bs_sending = 1;

          nextState = IDLE;
        end
      end

      RESUME_SEND : begin
        if (crc_valid_out && in_bit == 0) begin
          oc_clr = 1;
          bs_sending = 1;

          nextState = COUNT_ONES;
        end else if (crc_valid_out && in_bit == 1) begin
          oc_inc = 1; // Need to count this bit, too
          bs_sending = 1;

          nextState = COUNT_ONES;
        end else if (~crc_valid_out) begin
          // bs_sending = 1;

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

endmodule : BS_Encode_FSM

module BS_Encode
  (input  logic clock, reset_n,
                crc5_valid_out, crc5_in_bit,
                crc16_valid_out, crc16_in_bit,                
   output logic out_bit, bs_ready, bs_sending);

  // HANDLING CRC5 / CRC 16 SMOOTHLY
  logic crc_valid_out, in_bit;
  always_comb begin
    {crc_valid_out, in_bit} = 2'b00; // default values

    if (crc5_valid_out) begin
      crc_valid_out = 1;
      in_bit = crc5_in_bit;
    end else if (crc16_valid_out) begin
      crc_valid_out = 1;
      in_bit = crc16_in_bit;
    end

  end

  logic [31:0] ones_cnt, bit_cnt;
  logic oc_inc, oc_clr, bc_inc, bc_clr, sel_stuffbit;

  BS_Encode_FSM fsm (.*);
  // (input  logic       clock, reset_n,
  //                     crc_valid_out, in_bit,
  // input  logic [31:0] ones_cnt, bit_cnt,
  //  utput logic        bs_ready, oc_inc, oc_clr, bc_inc, bc_clr, sel_stuffbit,
  //                     bs_sending);

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

  // COUNT THE BITS FOR IGNORING PID
  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      bit_cnt <= 0;
    end else if (bc_clr) begin
      bit_cnt <= 0;
    end else if (bc_inc) begin
      bit_cnt <= bit_cnt + 1;
    end
  end

  // MUX THE BITSTREAM, OR CHOOSE TO SEND A BITSTUFF (0)
  always_comb begin
    if (sel_stuffbit)
      out_bit = 0;
    else
      out_bit = in_bit;
  end // always_comb

endmodule : BS_Encode