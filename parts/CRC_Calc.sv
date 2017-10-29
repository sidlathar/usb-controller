`default_nettype none

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
  #(parameter W=24)
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

module CRC_Calc_FSM
  (input  logic        clock, reset_n,
                       pkt_ready, // coming from protocol handler
                       bs_ready,
   input  logic [31:0] pkt_len, pkt_bit_count, crc_bit_count, crc_flush_cnt,
   output logic        send_it, prl_load, out_sel, crc_do, crc_clr,
                       crc_out_valid);

  enum logic [4:0] {IDLE, WAIT_LOAD, IGNORE_PID, CALC_CRC, FLUSH_CRC,
                    PAUSE_CALC_CRC, PAUSE_EDGE,
                    PAUSE_FLUSH_CRC } currState, nextState;

  always_comb begin
    {send_it, prl_load, out_sel, crc_do, crc_clr, crc_out_valid} = 6'b00_0001;

    unique case (currState)

      IDLE : begin
        if (pkt_ready) begin
          crc_out_valid = 0;

          nextState = WAIT_LOAD;
        end else begin
          crc_out_valid = 0;

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
        if (crc_bit_count != pkt_len && bs_ready) begin
          send_it = 1;
          crc_do = 1;

          nextState = CALC_CRC;
        end else if (~bs_ready && crc_bit_count != pkt_len) begin
          // Don't send any outputs, pause everything!
          nextState = PAUSE_CALC_CRC;
        end else if (~bs_ready && crc_bit_count == pkt_len) begin
          prl_load = 1;

          nextState = PAUSE_EDGE;
        end else if (bs_ready && crc_bit_count == pkt_len) begin
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
          out_sel = 1;

          nextState = FLUSH_CRC;
        end else if (crc_flush_cnt != 32'd4 && ~bs_ready) begin

          nextState = PAUSE_FLUSH_CRC;
        end else begin
          crc_out_valid = 0;

          nextState = IDLE;
        end
      end

      PAUSE_FLUSH_CRC : begin
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
                crc_out_valid);  // telling BS we are sending bits

  /*********************************** FSM ***********************************/

  logic prl_load, // Load remainder
        out_sel, // 1 is crc_bit, 0 is pkt_bit
        send_it, // Sends pkt bits out serially by shifting PRR
        crc_do, crc_clr; // Tell CRC to do calculation
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
        x0_Q, x1_Q, x2_Q, x3_Q, x4_Q;
  PISO_Register_Left #(5) prl (.D({x4_Q, x3_Q, x2_Q, x1_Q, x0_Q}),
                               .Q(crc_bit), .load(prl_load), .shift(send_it),
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

module CRC_Calc_test;
  logic clock, reset_n, pkt_ready, bs_ready, // inputs
        out_bit, crc_out_valid; //output
 
 logic [99:0] pkt_in; // input
 logic [31:0] pkt_len; // input


  CRC_Calc dut (.*);

  // TESTING RECEIVING PACKET
  logic [23:0] pkt_received;
  shiftRegister #(24) sr (.D(out_bit), .Q(pkt_received), .load(crc_out_valid), .*);
  // (input  logic             D,
  //  input  logic             load, clear, clock, reset_n,
  //  output logic [WIDTH-1:0] Q);

  initial begin
    $monitor ($stime,, "pkt_bit_cnt: %d, pkt_in: %b, pkt_ready: %b, crc_out_valid: %b, out_bit: %b | cs: %s, ns: %s | rem: %b ||| pkt_out: %b",
                        dut.pkt_bit_count, pkt_in[18:0], pkt_ready, crc_out_valid, out_bit, dut.fsm.currState.name, dut.fsm.nextState.name, dut.prl.D, pkt_received);
    clock = 0;
    reset_n = 0;
    reset_n <= #1 1;
    forever #5 clock = ~clock;
  end

  initial begin
    pkt_in <= 19'b0100_0000101_11100001;
    pkt_ready <= 1;
    bs_ready <= 1;
    pkt_len <= 32'd19;
    @(posedge clock);
    pkt_ready <= 0;
    @(posedge clock);

    // Wait for pid
    repeat(9)
    @ (posedge clock);

    // Wait!!!
    bs_ready <= 0;
    @ (posedge clock);
    bs_ready <= 1;

    repeat(9)
    @ (posedge clock);

    // Wait!!!
    bs_ready <= 0;
    @ (posedge clock);
    bs_ready <= 1;
    @ (posedge clock);

    repeat(3)
    @(posedge clock);

    // Wait!!!
    // bs_ready <= 0;
    // @ (posedge clock);
    // bs_ready <= 1;
    // @ (posedge clock);

    repeat(100)
    @(posedge clock);


    #1 $finish;
  end

endmodule;