`default_nettype none

module BitStuffer_FSM
  (input  logic        clock, reset_n,
                       crc_valid_out, in_bit,
   input  logic [31:0] ones_cnt, bit_cnt,
   output logic        bs_ready, oc_inc, oc_clr, bc_inc, bc_clr, sel_stuffbit,
                       bs_sending);

  enum logic [2:0] {IDLE, IGNORE_PID, COUNT_ONES, SEND_ZERO,
                    RESUME_SEND} currState, nextState;

  always_comb begin
    {bs_ready, oc_inc, oc_clr, bc_inc, bc_clr, sel_stuffbit,
     bs_sending} = 7'b10_0000_0;
    // NOTE : bs_ready DEFAULTED TO 1

    unique case (currState)

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
          bs_sending = 1; // DELETE????????????????????????????????????????????????????

          nextState = IDLE;
        end else if (in_bit == 1 && ones_cnt == 32'd5) begin
          bs_ready = 0; // IMPORTANT: TELLS CRC TO STOP AND HOLD VALUE FOR US
          sel_stuffbit = 1;
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
        bs_sending = 1;

        nextState = RESUME_SEND;
      end

      RESUME_SEND : begin
        if (crc_valid_out) begin
          bs_sending = 1;

          nextState = COUNT_ONES;
        end else begin
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

endmodule : BitStuffer_FSM

module BitStuffer
  (input  logic clock, reset_n,
                crc_valid_out, in_bit,
   output logic out_bit, bs_ready, bs_sending);

  logic [31:0] ones_cnt, bit_cnt;
  logic oc_inc, oc_clr, bc_inc, bc_clr, sel_stuffbit;

  BitStuffer_FSM fsm (.*);
  // (input  logic        clock, reset_n,
  //                      crc_valid_out, in_bit,
  //  input  logic [31:0] ones_cnt, bit_cnt,
  //  output logic        bs_ready, oc_inc, oc_clr, bc_inc, bc_clr, sel_stuffbit,
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

endmodule : BitStuffer

/* TESTBENCH BEGIN */

//SIPO left shift register
module shiftRegister
  #(parameter WIDTH=8)
  (input  logic             D,
   input  logic             load, clock, reset_n,
   output logic [WIDTH-1:0] Q);
   
  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n)
      Q <= 0;
    else if (load)
      Q <= {D, Q[WIDTH-1:1]};
  end
      
endmodule : shiftRegister
module BitStuffer_Test;
  logic clock, reset_n,
        crc_valid_out, in_bit, // inputs
        out_bit, bs_ready, bs_sending; // outputs

  BitStuffer dut (.*);

  // TESTING RECEIVING PACKET
  logic [15:0] pkt_received;
  shiftRegister #(16) sr (.D(out_bit), .Q(pkt_received), .load(bs_sending), .*);

  // PACKET TO SEND
  logic [15:0] pkt_in;
  // assign pkt_in = 40'hFFFFFFFFFF;
  assign pkt_in = 16'b111111110111111_1000_0000;

  initial begin
    $monitor ($stime,, "crc_valid_out: %b, in_bit: %b | out_bit: %b, bs_ready: %b, bs_sending: %b | oc: %d, bc: %d, cs: %s | pkt: %b",
                      crc_valid_out, in_bit, out_bit, bs_ready, bs_sending, dut.ones_cnt, dut.bit_cnt, dut.fsm.currState, pkt_received);
    clock = 0;
    reset_n = 0;
    reset_n <= #1 1;
    forever #5 clock = ~clock;
  end

  initial begin

    for (int i = 0; i < 20; i++) begin
        crc_valid_out <= 1;
        in_bit <= pkt_in[i];
      @(posedge clock);
    end

    #1 $finish;
  end

endmodule : BitStuffer_Test