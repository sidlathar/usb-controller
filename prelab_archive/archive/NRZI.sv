`default_nettype none

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
  always_ff @(posedge clock or negedge reset_n) begin
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
      out_bit = in_bit;
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

module NRZI_Encoder_Test;
  logic clock, reset_n,
        in_bit, bs_sending,    // inputs
        out_bit, nrzi_sending; // outputs

  NRZI_Encoder dut (.*);
  // (input logic clock, reset_n,
  //              in_bit, bs_sending,
  //  output logic out_bit, nrzi_sending);

  // TEST VECTOR
  logic [23:0] in_pkt;
  assign in_pkt = 24'b00001_0100_0000101_11100001; // Output from CRC_BS.sv from, PREPLAB: OUT, addr=5, ENDP=4, crc5=10

  // TESTING RECEIVING PACKET
  logic [23:0] pkt_received;
  shiftRegister #(24) sr (.D(out_bit), .Q(pkt_received), .load(nrzi_sending), .*);
  // (input  logic             D,
  //  input  logic             load, clear, clock, reset_n,
  //  output logic [WIDTH-1:0] Q);


  initial begin
    $monitor ($stime,, "in_bit: %b, bs_sending: %b | out_bit: %b, nrzi_sending: %b | pkt_received: %b",
                        in_bit, bs_sending, out_bit, nrzi_sending, pkt_received);
    clock = 0;
    reset_n = 0;
    reset_n <= #1 1;
    forever #5 clock = ~clock;
  end

  initial begin
    bs_sending <= 1;
    in_bit <= in_pkt[0];
    @(posedge clock);

    for (int i = 1; i < 24; i ++) begin
      in_bit <= in_pkt[i];
      @(posedge clock);
    end

    bs_sending <= 0;
    @(posedge clock);
    repeat(10)
    @(posedge clock);

    #1 $finish;
  end

endmodule : NRZI_Encoder_Test