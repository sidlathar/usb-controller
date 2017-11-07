
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

// (input  logic clock, reset_n,
//                 bs_sending,      // BS ready to receive bits
//    input  logic in_bit, // orig packet from protocol handler
//    output logic out_bit,       // bit going to BS
//                 crc_sending);  // telling BS we are sending bits
module CRC16_DECODE_Test;
  logic clock, reset_n,
        bs_sending, in_bit, // inputs
        out_bit, crc_sending; // outputs

  CRC16_Decode dut (.*);

  // TESTING RECEIVING PACKET
  logic [23:0] pkt_received;
  shiftRegister #(24) sr (.D(out_bit), .Q(pkt_received), .load(crc_sending), .*);

  // PACKET TO SEND
  logic [23:0] pkt_in;
  // assign pkt_in = 40'hFFFFFFFFFF;
  //assign pkt_in = 24'b110111111001111110000000;
  assign pkt_in = 24'b110111111001111110111111;

  initial begin
    $monitor ($stime,, "crc_sending: %b, in_bit: %b | out_bit: %b, bs_sending: %b | fc: %d, cs: %s | ns: %s, pkt: %b, crcreg = %h",
                      crc_sending, in_bit, out_bit, bs_sending,  dut.crc_flush_cnt, dut.fsm.currState, dut.fsm.nextState, pkt_received, dut.crc_result);
    clock = 0;
    reset_n = 0;
    reset_n <= #1 1;
    forever #5 clock = ~clock;
  end

  initial begin

    for (int i = 0; i < 19; i++) begin
        bs_sending <= 1;
        in_bit <= pkt_in[i];
      @(posedge clock);
    end
    bs_sending <= 0;
    @(posedge clock);
    

    for (int i = 19; i < 24; i++) begin
        bs_sending <= 1;
        in_bit <= pkt_in[i];
      @(posedge clock);
    end

    @(posedge clock);
    bs_sending <= 0;

    repeat(16) begin
      @(posedge clock);
    end


    #1 $finish;
  end

endmodule : CRC16_DECODE_Test
