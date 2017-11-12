`default_nettype none


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

// input logic clock, reset_n,
//   input logic DP_in, DM_in, rec_start,
//   output logic out_bit);

module DPDM_decoder_Test;
  logic clock, reset_n;
  logic DP_in, DM_in, rec_start, out_bit, dpdm_sending;

  DPDM_decode dut (.*);


  // TEST VECTORS

  //logic [25:0] DP, DM;
                //JXX_0001_0100_0010_1010;
  // assign DP = 26'b100_111000_0001_0100_0010_1010;  //D0
  // assign DM = 26'b000_000111_1110_1011_1101_0101;  //D0


logic [18:0] DP, DM;
                //jXX_0001_1011_0010_1010
  // assign DP = 19'b100_0001_1011_0010_1010;  //ACK
  // assign DM = 19'b000_1110_0100_1101_0101;  //ACK

                //JXX_0110_0011_0010_1010
  assign DP = 19'b100_0110_0011_0010_1010;  //NAK
  assign DM = 19'b000_1001_1100_1101_0101;  //NAk



  // TESTING RECEIVING PACKET
  logic [23:0] pkt_received;
  shiftRegister #(24) sr (.D(out_bit), .Q(pkt_received), .load(dpdm_sending), .*);
  // (input  logic             D,
  //  input  logic             load, clear, clock, reset_n,
  //  output logic [WIDTH-1:0] Q);


  initial begin
    $monitor ($stime,, "DP: %b, DM: %b, dpdm_sending: %b | ack: %b | nak: %b | data0: %b | out_bit: %b | PID_rec = %b | se0_rec: %b | match_val = %b | cs: %s | ns: %s | pkt_received: %b",
                       DP_in, DM_in, dut.fsm.dpdm_sending, dut.fsm.ACK_rec, dut.fsm.NAK_rec, dut.fsm.DATA0_rec, out_bit, dut.PID_rec, dut.se0_rec, dut.match_val, dut.fsm.currState.name, dut.fsm.nextState.name, pkt_received);
    clock = 0;
    reset_n = 0;
    reset_n <= #1 1;
    forever #5 clock = ~clock;
  end

  initial begin
    rec_start = 0;
    @(posedge clock);
    rec_start = 1;
    @(posedge clock);

    for (int i = 0; i < 19; i ++) begin
      DP_in <= DP[i];
      DM_in <= DM[i];
      @(posedge clock);
    end

    @(posedge clock);
    repeat(10)
    @(posedge clock);

    #1 $finish;
  end

endmodule : DPDM_decoder_Test
