`default_nettype none

module CRC16_Encode_FSM
  (input  logic        clock, reset_n,
                       pkt_ready, // coming from protocol handler
                       bs_ready,
   input  logic [31:0] pkt_bit_count, crc_bit_count, crc_flush_cnt,
   output logic  [3:0] crc_bit_sel,
   output logic        send_it, out_sel, crc_do, crc_clr,
                       crc_valid_out, crc_flush_cnt_inc, crc_flush_cnt_clr);

  enum logic [4:0] {IDLE, WAIT_LOAD, IGNORE_PID, CALC_CRC, FLUSH_CRC,
                    PAUSE_CALC_CRC, PAUSE_EDGE,
                    PAUSE_FLUSH_CRC } currState, nextState;

  // CONSTANTS
  logic [31:0] PID_LEN, PKT_LEN, CRC16_LEN;
  assign PID_LEN = 32'd8;
  assign PKT_LEN = 32'd72;
  assign CRC16_LEN = 32'd16;

  always_comb begin
    {crc_valid_out, crc_bit_sel, send_it, out_sel, crc_do, crc_clr,
      crc_flush_cnt_inc, crc_flush_cnt_clr} = 11'b1_0000_000000;

    case (currState)

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
        if (pkt_bit_count != PID_LEN) begin
          send_it = 1;

          nextState = IGNORE_PID;
        end else begin
          send_it = 1;
          crc_do = 1;

          nextState = CALC_CRC;
        end
      end

      CALC_CRC : begin
        if (crc_bit_count != (PKT_LEN - 1) && bs_ready) begin
          send_it = 1;
          crc_do = 1;

          nextState = CALC_CRC;
        end else if (~bs_ready && crc_bit_count != (PKT_LEN - 1)) begin
          // Don't send any outputs, pause everything!
          nextState = PAUSE_CALC_CRC;
        end else if (~bs_ready && crc_bit_count == (PKT_LEN - 1)) begin
          
          nextState = PAUSE_EDGE;
        end else if (bs_ready && crc_bit_count == (PKT_LEN - 1)) begin
          crc_do = 1;
          crc_flush_cnt_clr = 1; // NEW

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
        if ((crc_flush_cnt != (CRC16_LEN - 1)) && bs_ready) begin
          crc_bit_sel = crc_flush_cnt;
          out_sel = 1;
          crc_flush_cnt_inc = 1;

          nextState = FLUSH_CRC;
        end else if ((crc_flush_cnt != (CRC16_LEN - 1)) && ~bs_ready) begin
          crc_bit_sel = crc_flush_cnt;
          out_sel = 1;

          nextState = PAUSE_FLUSH_CRC;
        end else begin
          crc_bit_sel = crc_flush_cnt;
          out_sel = 1;
          crc_flush_cnt_inc = 1;

          crc_valid_out = 1; // FIX FROM OUR PAST

          nextState = IDLE;
        end
      end

      PAUSE_FLUSH_CRC : begin
        crc_bit_sel = crc_flush_cnt;
        out_sel = 1;
        crc_flush_cnt_inc = 1;

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

endmodule : CRC16_Encode_FSM

module CRC16_Encode
  (input  logic clock, reset_n,
                pkt_ready,     // PH ready to send us a packet
                bs_ready,      // BS ready to receive bits
   input  logic [71:0] pkt_in, // orig packet from protocol handler
   output logic out_bit,       // bit going to BS
                crc_valid_out);  // telling BS we are sending bits


  /************************** PISO STREAM OUT BEGIN **************************/
  logic pkt_bit, send_it; // Packet bit going into MUX
  PISO_Register_Right prr (.D(pkt_in), .load(pkt_ready), .shift(send_it),
                           .Q(pkt_bit), .*);
  //   #(parameter W=100)
  //   (input  logic clock, load, shift,
  //    input  logic [W-1:0] D,
  //    output logic Q);

  // Counter for how many packet bits we've sent
  logic [31:0] pkt_bit_count;
  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n)
      pkt_bit_count <= 0;
    else if (send_it)
      pkt_bit_count <= pkt_bit_count + 1;
  end

  /************************** CRC CALCULATION BEGIN **************************/

  // To hold our remainder from CRC calculation
  logic crc_bit;
  logic x0_D, x1_D,  x2_D,  x3_D,  x4_D,  x5_D,  x6_D,  x7_D,
        x8_D, x9_D, x10_D, x11_D, x12_D, x13_D, x14_D, x15_D,
        x0_Q, x1_Q,  x2_Q,  x3_Q,  x4_Q,  x5_Q,  x6_Q,  x7_Q,
        x8_Q, x9_Q, x10_Q, x11_Q, x12_Q, x13_Q, x14_Q, x15_Q;

  logic [15:0] crc_result;
  logic [3:0] crc_bit_sel;
  assign crc_result = {~x0_Q, ~x1_Q, ~x2_Q, ~x3_Q, ~x4_Q, ~x5_Q, ~x6_Q, ~x7_Q,
  ~x8_Q, ~x9_Q, ~x10_Q, ~x11_Q, ~x12_Q, ~x13_Q, ~x14_Q, ~x15_Q}; // Complement
  assign crc_bit = crc_result[crc_bit_sel];

  always_comb begin
    x0_D = pkt_bit ^ x15_Q;
    x1_D = x0_Q;
    x2_D = x1_Q ^ x0_D;
    x3_D = x2_Q;
    x4_D = x3_Q;
    x5_D = x4_Q;
    x6_D = x5_Q;
    x7_D = x6_Q;
    x8_D = x7_Q;
    x9_D = x8_Q;
    x10_D = x9_Q;
    x11_D = x10_Q;
    x12_D = x11_Q;
    x13_D = x12_Q;
    x14_D = x13_Q;
    x15_D = x14_Q ^ x0_D;

  end // always_comb

  // CRC Calculation AND counter
  logic crc_do, crc_clr;
  logic [31:0] crc_bit_count;
  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      crc_bit_count <= 32'd8; // init to 8 to account for PID

      x0_Q <= 1;
      x1_Q <= 1;
      x2_Q <= 1;
      x3_Q <= 1;
      x4_Q <= 1;
      x5_Q <= 1;
      x6_Q <= 1;
      x7_Q <= 1;
      x8_Q <= 1;
      x9_Q <= 1;
      x10_Q <= 1;
      x11_Q <= 1;
      x12_Q <= 1;
      x13_Q <= 1;
      x14_Q <= 1;
      x15_Q <= 1;
    end else begin
      if (crc_do) begin   
        crc_bit_count <= crc_bit_count + 1;

        x0_Q <= x0_D;
        x1_Q <= x1_D;
        x2_Q <= x2_D;
        x3_Q <= x3_D;
        x4_Q <= x4_D;
        x5_Q <= x5_D;
        x6_Q <= x6_D;
        x7_Q <= x7_D;
        x8_Q <= x8_D;
        x9_Q <= x9_D;
        x10_Q <= x10_D;
        x11_Q <= x11_D;
        x12_Q <= x12_D;
        x13_Q <= x13_D;
        x14_Q <= x14_D;
        x15_Q <= x15_D;
      end else if (crc_clr) begin
        crc_bit_count <= 32'd8; // init to 8 to account for PID

        x0_Q <= 1;
        x1_Q <= 1;
        x2_Q <= 1;
        x3_Q <= 1;
        x4_Q <= 1;
        x5_Q <= 1;
        x6_Q <= 1;
        x7_Q <= 1;
        x8_Q <= 1;
        x9_Q <= 1;
        x10_Q <= 1;
        x11_Q <= 1;
        x12_Q <= 1;
        x13_Q <= 1;
        x14_Q <= 1;
        x15_Q <= 1;
      end
    end
  end // always_ff

  logic [31:0] crc_flush_cnt;
  logic crc_flush_cnt_inc, crc_flush_cnt_clr;
  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n)
      crc_flush_cnt <= 0;
    else if (crc_flush_cnt_clr)
      crc_flush_cnt <= 0;
    else if (crc_flush_cnt_inc) // out_sel enabled when flushing CRC out
      crc_flush_cnt <= crc_flush_cnt + 1;
  end

  // MUX OUT THE RIGHT STREAM
  logic out_sel;
  always_comb begin
    if (out_sel)
      out_bit = crc_bit;
    else
      out_bit = pkt_bit;
 end

 /*********************************** FSM ***********************************/

 CRC16_Encode_FSM fsm (.*);
 // (input  logic        clock, reset_n,
 //                      pkt_ready, // coming from protocol handler
 //  input  logic [31:0] pkt_len, pkt_bit_count, crc_bit_count,
 //  output logic        send_it, crc_load, out_sel, crc_do);

endmodule : CRC16_Encode