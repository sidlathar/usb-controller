`default_nettype none

/* HELPER MODULES BEGIN */

// A Parallel In, Serial Out register for a variable length
module PISO_Register_Right
  #(parameter W=100)
  (input  logic clock, load, shift,
   input  logic [W-1:0] D,
   output logic Q);

  logic [99:0] buff;
  assign Q = buff[0];

  always_ff @(posedge clock) begin
    if (load)
      buff <= D;
    else if (shift) begin
      buff <= (buff >> 1);
    end
  end

endmodule : PISO_Register_Right

// A Parallel In, Serial Out register for a known length
module PISO_Register_Left
  #(parameter W=5)
  (input  logic clock, load, shift,
   input  logic [W-1:0] D,
   output logic Q);

  logic [W-1:0] buff;
  assign Q = buff[W-1];

  always_ff @(posedge clock) begin
    if (load)
      buff <= D;
    else if (shift) begin
      buff <= (buff << 1);
    end
  end

endmodule : PISO_Register_Left

/* HELPER MODULES END */

/* CRC_CALCULATION BEGIN */

module CRC_Calc_FSM
  (input  logic        clock, reset_n,
                       pkt_ready, // coming from protocol handler
                       bs_ready,
   input  logic [31:0] pkt_len, pkt_bit_count, crc_bit_count, crc_flush_cnt,
   output logic        send_it, prl_load, out_sel, crc_do, crc_clr,
                       crc_valid_out, crc_reg_shift);

  enum logic [4:0] {IDLE, WAIT_LOAD, IGNORE_PID, CALC_CRC, FLUSH_CRC,
                    PAUSE_CALC_CRC, PAUSE_EDGE,
                    PAUSE_FLUSH_CRC } currState, nextState;

  always_comb begin
    {send_it, prl_load, out_sel, crc_do, crc_clr, crc_valid_out, crc_reg_shift} = 7'b00_00010;

    unique case (currState)

      IDLE : begin
        if (pkt_ready) begin
          crc_valid_out = 0;

          nextState = WAIT_LOAD;
        end else begin
          crc_valid_out = 0;

          nextState = IDLE;
        end
      end


      WAIT_LOAD : begin
        send_it = 1;
        crc_clr = 1;

        nextState = IGNORE_PID;
      end

      IGNORE_PID : begin
        if (pkt_bit_count != 32'd8) begin
          send_it = 1;

          nextState = IGNORE_PID;
        end else begin
          send_it = 1;
          crc_do = 1;

          nextState = CALC_CRC;
        end
      end


      CALC_CRC : begin
        if (crc_bit_count != (pkt_len - 1) && bs_ready) begin
          send_it = 1;
          crc_do = 1;

          nextState = CALC_CRC;
        end else if (~bs_ready && crc_bit_count != (pkt_len - 1)) begin
          // Don't send any outputs, pause everything!
          nextState = PAUSE_CALC_CRC;
        end else if (~bs_ready && crc_bit_count == (pkt_len - 1)) begin
          prl_load = 1;

          nextState = PAUSE_EDGE;
        end else if (bs_ready && crc_bit_count == (pkt_len - 1)) begin
          prl_load = 1;

          nextState = FLUSH_CRC;
        end
      end

      PAUSE_CALC_CRC : begin
        send_it = 1;
        crc_do = 1;

        nextState = CALC_CRC;
      end

      PAUSE_EDGE : begin

        nextState = FLUSH_CRC;
      end

      FLUSH_CRC : begin
        if (crc_flush_cnt != 32'd4 && bs_ready) begin
          crc_reg_shift = 1;
          out_sel = 1;

          nextState = FLUSH_CRC;
        end else if (crc_flush_cnt != 32'd4 && ~bs_ready) begin

          nextState = PAUSE_FLUSH_CRC;
        end else begin
          crc_reg_shift = 1;
          out_sel = 1;

          crc_valid_out = 0;

          nextState = IDLE;
        end
      end

      PAUSE_FLUSH_CRC : begin
        crc_reg_shift = 1;
        out_sel = 1;

        nextState = FLUSH_CRC;
      end

    endcase // currState

  end // always_comb

  always_ff @ (posedge clock, negedge reset_n) begin
    if (~reset_n)
      currState <= IDLE;
    else
      currState <= nextState;
  end

endmodule : CRC_Calc_FSM

module CRC_Calc
  (input  logic clock, reset_n,
                pkt_ready,     // PH ready to send us a packet
                bs_ready,      // BS ready to receive bits
   input  logic [99:0] pkt_in, // orig packet from protocol handler
   input  logic [31:0] pkt_len,
   output logic out_bit,       // bit going to BS
                crc_valid_out);  // telling BS we are sending bits

  /*********************************** FSM ***********************************/

  logic prl_load, // Load remainder
        out_sel, // 1 is crc_bit, 0 is pkt_bit
        send_it, // Sends pkt bits out serially by shifting PRR
        crc_do, crc_clr, // Tell CRC to do calculation
        crc_reg_shift;
  logic [31:0] pkt_bit_count, crc_bit_count;
  CRC_Calc_FSM fsm (.*);
  // (input  logic        clock, reset_n,
  //                      pkt_ready, // coming from protocol handler
  //  input  logic [31:0] pkt_len, pkt_bit_count, crc_bit_count,
  //  output logic        send_it, prl_load, out_sel, crc_do);

  /************************** PISO STREAM OUT BEGIN **************************/
  logic pkt_bit; // Packet bit going into MUX
  PISO_Register_Right prr (.D(pkt_in), .load(pkt_ready), .shift(send_it),
                           .Q(pkt_bit), .*);
  //   #(parameter W=100)
  //   (input  logic clock, load, shift,
  //    input  logic [W-1:0] D,
  //    output logic Q);

  // Counter for how many packet bits we've sent
  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n)
      pkt_bit_count <= 0;
    else if (send_it)
      pkt_bit_count <= pkt_bit_count + 1;
  end

  /************************** CRC CALCULATION BEGIN **************************/

  // To hold our remainder from CRC calculation
  logic crc_bit;
  logic x0_D, x1_D, x2_D, x3_D, x4_D,
        x0_Q, x1_Q, x2_Q, x3_Q, x4_Q; // Don't forget to complement
  PISO_Register_Left #(5) prl (.D({~x0_Q, ~x1_Q, ~x2_Q, ~x3_Q, ~x4_Q}), // CHANGED ORDER... BUT WE THOUGHT LSB -> MSB
                               .Q(crc_bit), .load(prl_load), .shift(crc_reg_shift),
                               .*);
  // #(parameter W=24)
  // (input  logic clock, load, shift,
  //  input  logic [W-1:0] D,
  //  output logic Q);

  always_comb begin
    x0_D = pkt_bit ^ x4_Q;
    x1_D = x0_Q;
    x2_D = x1_Q ^ x0_D;
    x3_D = x2_Q;
    x4_D = x3_Q;
  end // always_comb


  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      crc_bit_count <= 32'd8; // init to 8 to account for PID

      x0_Q <= 1;
      x1_Q <= 1;
      x2_Q <= 1;
      x3_Q <= 1;
      x4_Q <= 1;
    end else begin
      if (crc_do) begin   
        crc_bit_count <= crc_bit_count + 1;

        x0_Q <= x0_D;
        x1_Q <= x1_D;
        x2_Q <= x2_D;
        x3_Q <= x3_D;
        x4_Q <= x4_D;
      end else if (crc_clr) begin
        crc_bit_count <= 32'd8; // init to 8 to account for PID

        x0_Q <= 1;
        x1_Q <= 1;
        x2_Q <= 1;
        x3_Q <= 1;
        x4_Q <= 1;
      end
    end
  end // always_ff

  logic [31:0] crc_flush_cnt;
  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n)
      crc_flush_cnt <= 0;
    else if (out_sel) // out_sel enabled when flushing CRC out
      crc_flush_cnt <= crc_flush_cnt + 1;
  end

  // MUX OUT THE RIGHT STREAM
  always_comb begin
    if (out_sel)
      out_bit = crc_bit;
    else
      out_bit = pkt_bit;
 end

endmodule : CRC_Calc

/* CRC_CALCULATION END */

/* BITSTUFFER BEGIN */

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
          bs_sending = 1;

          nextState = IDLE;
        end else if (in_bit == 1 && ones_cnt == 32'd5) begin
          bs_ready = 0; // IMPORTANT: TELLS CRC TO STOP AND HOLD VALUE FOR US
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
        sel_stuffbit = 1;
        bs_sending = 1;

        nextState = RESUME_SEND;
      end

      RESUME_SEND : begin
        if (crc_valid_out) begin
          bs_sending = 1;

          nextState = COUNT_ONES;
        end else begin
          bs_sending = 1; // DELETE ?????????????????????????????????????????????????????????????????????????????

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

/* BITSTUFFER END */

/* NRZI BEGIN */

module NRZI_Encoder_FSM
  (input logic clock, reset_n,
               in_bit, bs_sending,
   output logic out_sel, nrzi_sending);

  enum logic {IDLE, WORK} currState, nextState;

  always_comb begin
    {out_sel, nrzi_sending} = 2'b00;

    unique case (currState)

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
  
endmodule : NRZI_Encoder_FSM

module NRZI_Encoder
  (input logic clock, reset_n,
               in_bit, bs_sending,
   output logic out_bit, nrzi_sending);

  // "Flip-flop" to remember the previous bit
  logic prev_bit;
  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
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

  // always_ff @(posedge clock or negedge reset_n) begin
  //   if(~reset_n) begin
  //     NRZI_bit <= 0;
  //   end else begin
  //     NRZI_bit <= (in_bit == 0) ? ~out_bit : out_bit;
  //   end
  // end

  // The FSM
  NRZI_Encoder_FSM fsm (.*);
  // (input logic clock, reset_n,
  //              in_bit, bs_sending
  //  output logic out_sel, nrzi_sending);

endmodule : NRZI_Encoder

/* NRZI END */

/* TESTBENCH BEGIN */

//SIPO left shift register
// module shiftRegister
//   #(parameter WIDTH=8)
//   (input  logic             D,
//    input  logic             load, clock, reset_n,
//    output logic [WIDTH-1:0] Q);
   
//   always_ff @(posedge clock, negedge reset_n) begin
//     if (~reset_n)
//       Q <= 0;
//     else if (load)
//       Q <= {D, Q[WIDTH-1:1]};
//   end
      
// endmodule : shiftRegister

// module CRC_BS_NRZI_top;
//   logic clock, reset_n; // Typical inputs 
 
//   // "TASK" inputs to CRC (should be coming from our Protocol Handler)
//   logic [99:0] pkt_in; // input
//   logic [31:0] pkt_len; // input

//   // CRC MODULE INSTANTIATION
//   logic pkt_ready, bs_ready, // inputs
//         crc_out_bit, crc_valid_out; //output
//   CRC_Calc crc (.out_bit(crc_out_bit), .*);
//   //   (input  logic clock, reset_n,
//   //                 pkt_ready,     // PH ready to send us a packet
//   //                 bs_ready,      // BS ready to receive bits
//   //    input  logic [99:0] pkt_in, // orig packet from protocol handler
//   //    input  logic [31:0] pkt_len,
//   //    output logic out_bit,       // bit going to BS
//   //                 crc_valid_out);  // telling BS we are sending bits

//   // BITSTUFFER MODULE INSTANTIATION
//   logic bs_out_bit, bs_sending;
//   BitStuffer bs (.in_bit(crc_out_bit), .out_bit(bs_out_bit), .*);
//  // module BitStuffer
//  //   (input  logic clock, reset_n,
//  //                 crc_valid_out, in_bit,
//  //    output logic out_bit, bs_ready, bs_sending);

//   // NRZI MODULE INSTANTIATION
//   logic nrzi_out_bit, nrzi_sending;
//   NRZI_Encoder nrzi (.in_bit(bs_out_bit), .out_bit(nrzi_out_bit), .*);
//   // (input logic clock, reset_n,
//   //              in_bit, bs_sending,
//   //  output logic out_bit, nrzi_sending);

//   // TESTING RECEIVING PACKET
//   logic [23:0] pkt_received;
//   logic always_load;
//   assign always_load = 1;
//   shiftRegister #(24) sr (.D(nrzi_out_bit), .Q(pkt_received), .load(always_load), .*);
//   // (input  logic             D,
//   //  input  logic             load, clear, clock, reset_n,
//   //  output logic [WIDTH-1:0] Q);

//   logic [23:0] test_pkt;
//   // assign test_pkt = 19'b0100_0000101_11100001;
//   // assign test_pkt = 19'b0100_1111111_11100001;
//   // assign test_pkt = 19'b0100_0111111_00000001;
//   assign test_pkt = 19'b0100_0000101_11100001; // PRELAB: OUT, addr=5, ENDP=4, crc5=10
//   // assign test_pkt = 19'b1000_0000101_11100001; // OUT, addr=5 endp=8 crc5=0e
//   // assign test_pkt = 19'b1001_0000101_01101001; // IN, addr=5 endp=8 crc5=0e

//   initial begin
//     $monitor ($stime,, "pkt_in: %b | nrzi_sending: %b, nrzi_out_bit: %b,  ANS: %b",
//                       test_pkt, nrzi_sending, nrzi_out_bit, pkt_received);
//     clock = 0;
//     reset_n = 0;
//     reset_n <= #1 1;
//     forever #5 clock = ~clock;
//   end

//   initial begin
//     pkt_in <= test_pkt;
//     pkt_ready <= 1;
//     pkt_len <= 32'd19;
//     @(posedge clock);
//     pkt_ready <= 0;
//     @(posedge clock);

//     repeat(100)
//     @(posedge clock);


//     #1 $finish;
//   end

// endmodule;