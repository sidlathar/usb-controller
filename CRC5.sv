`default_nettype none

module CRC_Calc_FSM
  (input  logic        clock, reset_n,
                       pkt_ready, // coming from protocol handler
                       bs_ready,
   input  logic [31:0] pkt_len, pkt_bit_count, crc_bit_count, crc_flush_cnt,
   output logic  [2:0] crc_bit_sel,
   output logic        send_it, crc_load, out_sel, crc_do, crc_clr,
                       crc_valid_out);

  enum logic [4:0] {IDLE, WAIT_LOAD, IGNORE_PID, CALC_CRC, FLUSH_CRC,
                    PAUSE_CALC_CRC, PAUSE_EDGE,
                    PAUSE_FLUSH_CRC } currState, nextState;

  always_comb begin
    {send_it, crc_load, out_sel, crc_do, crc_clr, crc_valid_out,
     crc_bit_sel} = 9'b00_0001000;

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

          crc_load = 1;

          nextState = CALC_CRC;
        end else if (~bs_ready && crc_bit_count != (pkt_len - 1)) begin
          // Don't send any outputs, pause everything!
          nextState = PAUSE_CALC_CRC;
        end else if (~bs_ready && crc_bit_count == (pkt_len - 1)) begin
          crc_load = 1;

          nextState = PAUSE_EDGE;
        end else if (bs_ready && crc_bit_count == (pkt_len - 1)) begin
          crc_do = 1;

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
          crc_bit_sel = crc_flush_cnt;
          out_sel = 1;

          nextState = FLUSH_CRC;
        end else if (crc_flush_cnt != 32'd4 && ~bs_ready) begin

          nextState = PAUSE_FLUSH_CRC;
        end else begin
          crc_bit_sel = crc_flush_cnt;
          out_sel = 1;

          crc_valid_out = 0;

          nextState = IDLE;
        end
      end

      PAUSE_FLUSH_CRC : begin
        crc_bit_sel = crc_flush_cnt;
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

  logic crc_load, // Load remainder
        out_sel, // 1 is crc_bit, 0 is pkt_bit
        send_it, // Sends pkt bits out serially by shifting PRR
        crc_do, crc_clr, // Tell CRC to do calculation
        crc_reg_shift;
  logic [2:0] crc_bit_sel;
  logic [31:0] pkt_bit_count, crc_bit_count;
  CRC_Calc_FSM fsm (.*);
  // (input  logic        clock, reset_n,
  //                      pkt_ready, // coming from protocol handler
  //  input  logic [31:0] pkt_len, pkt_bit_count, crc_bit_count,
  //  output logic        send_it, crc_load, out_sel, crc_do);

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
        x0_Q, x1_Q, x2_Q, x3_Q, x4_Q;

  logic [4:0] crc_result;
  assign crc_result = {~x0_Q, ~x1_Q, ~x2_Q, ~x3_Q, ~x4_Q}; // Complement
  assign crc_bit = crc_result[crc_bit_sel];

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