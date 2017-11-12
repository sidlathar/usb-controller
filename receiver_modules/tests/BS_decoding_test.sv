
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
module BitStuffer_DECODE_Test;
  logic clock, reset_n,
        nrzi_sending, in_bit, // inputs
        out_bit, bs_sending; // outputs

  BitStuffer_decode dut (.*);

  // TESTING RECEIVING PACKET
  logic [23:0] pkt_received;
  shiftRegister #(24) sr (.D(out_bit), .Q(pkt_received), .load(bs_sending), .*);

  // PACKET TO SEND
  logic [23:0] pkt_in;
  // assign pkt_in = 40'hFFFFFFFFFF;
  //assign pkt_in = 24'b110111111001111110000000;
  assign pkt_in = 24'b110111111001111110111111;

  initial begin
    $monitor ($stime,, "nrzi_sending: %b, in_bit: %b | out_bit: %b, bs_sending: %b | oc: %d, bc: %d, cs: %s | ns: %s, pkt: %b",
                      nrzi_sending, in_bit, out_bit, bs_sending, dut.ones_cnt, dut.bit_cnt, dut.fsm.currState, dut.fsm.nextState, pkt_received);
    clock = 0;
    reset_n = 0;
    reset_n <= #1 1;
    forever #5 clock = ~clock;
  end

  initial begin

    for (int i = 0; i < 24; i++) begin
        nrzi_sending <= 1;
        in_bit <= pkt_in[i];
      @(posedge clock);
    end

    #1 $finish;
  end

endmodule : BitStuffer_DECODE_Test
