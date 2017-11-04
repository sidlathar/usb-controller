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

module NRZI_decoder_Test;
  logic clock, reset_n,
        in_bit, dpdm_sending,    // inputs
        out_bit, nrzi_sending; // outputs

  NRZI_decoder dut (.*);
  // (input logic clock, reset_n,
  //              in_bit, bs_sending,
  //  output logic out_bit, nrzi_sending);

  // TEST VECTOR
  logic [23:0] in_pkt;
  assign in_pkt = 24'b101011001010100111110101; // Output from CRC_BS.sv from, PREPLAB: OUT, addr=5, ENDP=4, crc5=10

  // TESTING RECEIVING PACKET
  logic [23:0] pkt_received;
  shiftRegister #(24) sr (.D(out_bit), .Q(pkt_received), .load(nrzi_sending), .*);
  // (input  logic             D,
  //  input  logic             load, clear, clock, reset_n,
  //  output logic [WIDTH-1:0] Q);


  initial begin
    $monitor ($stime,, "in_bit: %b, dpdm_sending: %b | out_bit: %b, nrzi_sending: %b | pkt_received: %b",
                        in_bit, dpdm_sending, out_bit, nrzi_sending, pkt_received);
    clock = 0;
    reset_n = 0;
    reset_n <= #1 1;
    forever #5 clock = ~clock;
  end

  initial begin
    dpdm_sending <= 1;
    in_bit <= in_pkt[0];
    @(posedge clock);

    for (int i = 1; i < 24; i ++) begin
      in_bit <= in_pkt[i];
      @(posedge clock);
    end

    dpdm_sending <= 0;
    @(posedge clock);
    repeat(10)
    @(posedge clock);

    #1 $finish;
  end

endmodule : NRZI_decoder_Test
