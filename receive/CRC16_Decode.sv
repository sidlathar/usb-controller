`default_nettype none

module DATA0_REG
  #(parameter WIDTH=80)
  (input  logic             D,
   input  logic             load, clock, reset_n,
   output logic [WIDTH-1:0] Q);

  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n)
      Q <= 0;
    else if (load)
      Q <= {D, Q[WIDTH-1:1]};
  end

endmodule : DATA0_REG


module CRC16_Decode_FSM
  (input  logic        clock, reset_n,
   input  logic bs_sending,
   input logic [31:0] crc_flush_cnt,
   input logic [15:0] capture_residue,
   output logic crc_do, out_sel, crc_flush_cnt_inc, 
   output logic crc_flush_cnt_clr, crc_sending, crc_clr, crc_valid,
   output logic [31:0] crc_bit_sel);

  enum logic [3:0] {IDLE,  CALC_CRC, PAUSE_CALC_CRC, FLUSH_CRC} currState, 
                  nextState;

  // CONSTANTS
  logic [31:0] PID_LEN, PKT_LEN, CRC16_LEN;
  assign PID_LEN = 32'd8;
  assign PKT_LEN = 32'd72;
  assign CRC16_LEN = 32'd16;

  always_comb begin
    {crc_do, out_sel, crc_flush_cnt_inc, 
          crc_flush_cnt_clr, crc_sending,
                 crc_bit_sel, crc_clr, crc_valid} = 36'b0z;

    case (currState)
      
      IDLE: begin 
        if(~bs_sending) begin
          nextState = IDLE;
        end else begin
          crc_do = 1;
          out_sel = 0;
          crc_sending = 1;
          crc_flush_cnt_clr = 1;

          nextState = CALC_CRC;
        end
      end

      CALC_CRC: begin
        if(bs_sending) begin
          crc_do = 1;
          out_sel = 0;
          crc_sending = 1;

          nextState = CALC_CRC;
        end else begin
          nextState = PAUSE_CALC_CRC;
        end
      end

      PAUSE_CALC_CRC: begin 
        if(bs_sending) begin
          crc_do = 1;
          out_sel = 0;
          crc_sending = 1;

          nextState = CALC_CRC;
        end else begin
          crc_flush_cnt_inc = 1;
          out_sel = 1;
          crc_bit_sel = crc_flush_cnt;
          //crc_sending = 1;
          crc_valid = (capture_residue == 16'h800d);
          
          
          nextState = IDLE;
        end
      end

      // FLUSH_CRC: begin 
      //   if(crc_flush_cnt != 32'd15) begin
      //     crc_flush_cnt_inc = 1;
      //     out_sel = 1;
      //     crc_bit_sel = crc_flush_cnt;
      //     crc_sending = 1;

      //     nextState = FLUSH_CRC;
      //   end else begin
      //     nextState = IDLE;
      //     crc_clr = 1;
      //     crc_flush_cnt_clr = 1;
      //   end
      // end
      
    endcase // currState

  end // always_comb

  always_ff @ (posedge clock, negedge reset_n) begin
    if (~reset_n)
      currState <= IDLE;
    else
      currState <= nextState;
  end

endmodule : CRC16_Decode_FSM


  /************************** CRC CALCULATION BEGIN **************************/

module CRC16_Decode
  (input  logic clock, reset_n,
                bs_sending, load_data,     
   input  logic in_bit,
   output logic out_bit, 
                crc_sending, crc_valid,
   output logic [63:0] data0);  

  // To hold our remainder from CRC calculation
  logic crc_bit;
  logic x0_D, x1_D,  x2_D,  x3_D,  x4_D,  x5_D,  x6_D,  x7_D,
        x8_D, x9_D, x10_D, x11_D, x12_D, x13_D, x14_D, x15_D,
        x0_Q, x1_Q,  x2_Q,  x3_Q,  x4_Q,  x5_Q,  x6_Q,  x7_Q,
        x8_Q, x9_Q, x10_Q, x11_Q, x12_Q, x13_Q, x14_Q, x15_Q;

  logic [15:0] crc_result;
  logic [31:0] crc_bit_sel;
  assign crc_result = {x15_Q, x14_Q, x13_Q, x12_Q, x11_Q, x10_Q, x9_Q, x8_Q,
  x7_Q, x6_Q, x5_Q, x4_Q, x3_Q, x2_Q, x1_Q, x0_Q};
  assign crc_bit = crc_result[crc_bit_sel];


  logic [79:0] data0_plus_crc;

  always_comb begin
    if(load_data) begin
      data0 = data0_plus_crc[63:0];
    end
    else begin
      data0 = data0;
    end
  end

  always_comb begin
    x0_D = in_bit ^ x15_Q;
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
      out_bit = in_bit;
 end

  logic [15:0] capture_residue;
  // assign capture_residue = (bs_sending)? crc_result: capture_residue;
  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n)
      capture_residue <= 16'bz;
    else if (bs_sending)
      capture_residue <= crc_result;
  end

 /*********************************** FSM ***********************************/
 
 CRC16_Decode_FSM fsm (.crc_valid(crc_valid), .*);
 DATA0_REG d0reg(.D(out_bit), .Q(data0_plus_crc), .load(crc_sending), .*); //W = 64
 // (input  logic        clock, reset_n,
 //                      pkt_ready, // coming from protocol handler
 //  input  logic [31:0] pkt_len, pkt_bit_count, crc_bit_count,
 //  output logic        send_it, crc_load, out_sel, crc_do);

endmodule : CRC16_Decode