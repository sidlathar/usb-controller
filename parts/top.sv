`default_nettype none

module top;
  logic clock, reset_n; // Typical inputs 
 
  // "TASK" inputs to CRC (should be coming from our Protocol Handler)
  logic [99:0] pkt_in; // input
  logic [31:0] pkt_len; // input

  // CRC MODULE INSTANTIATION
  logic pkt_ready, bs_ready, // inputs
        crc_out_bit, crc_valid_out; //output
  CRC_Calc crc (.out_bit(crc_out_bit), .*);
  //   (input  logic clock, reset_n,
  //                 pkt_ready,     // PH ready to send us a packet
  //                 bs_ready,      // BS ready to receive bits
  //    input  logic [99:0] pkt_in, // orig packet from protocol handler
  //    input  logic [31:0] pkt_len,
  //    output logic out_bit,       // bit going to BS
  //                 crc_valid_out);  // telling BS we are sending bits

  // BITSTUFFER MODULE INSTANTIATION
  logic bs_out_bit, bs_sending;
  BitStuffer bs (.in_bit(crc_out_bit), .out_bit(bs_out_bit), .*);
 // module BitStuffer
 //   (input  logic clock, reset_n,
 //                 crc_valid_out, in_bit,
 //    output logic out_bit, bs_ready, bs_sending);

  // NRZI MODULE INSTANTIATION
  logic nrzi_out_bit, nrzi_sending;
  NRZI_Encoder nrzi (.in_bit(bs_out_bit), .out_bit(nrzi_out_bit), .*);
  // (input logic clock, reset_n,
  //              in_bit, bs_sending,
  //  output logic out_bit, nrzi_sending);

  // DPDM MODULE INSTANTIATION
  logic DP, DM, out_done;
  DPDM dpdm (.in_bit(nrzi_out_bit), .*);
  // (input  logic clock, reset_n,
  //               in_bit, nrzi_sending,
  //  output logic DP, DM, out_done);


  // TESTING RECEIVING PACKET
  logic [39:0] pkt_received; // Just making it very big
  logic always_load;
  assign always_load = 1;
  shiftRegister #(40) sr (.D(nrzi_out_bit), .Q(pkt_received), .load(always_load), .*);
  // (input  logic             D,
  //  input  logic             load, clear, clock, reset_n,
  //  output logic [WIDTH-1:0] Q);

  logic [23:0] test_pkt;
  // assign test_pkt = 19'b0100_0000101_11100001;
  // assign test_pkt = 19'b0100_1111111_11100001;
  // assign test_pkt = 19'b0100_0111111_00000001;
  assign test_pkt = 19'b0100_0000101_11100001; // PRELAB: OUT, addr=5, ENDP=4, crc5=10
  // FINAL ANSWER ALL WAY THRU DPDPM (the cycle after out_done = 1): 100_101011001010100111110101_0010101000000
  // assign test_pkt = 19'b1000_0000101_11100001; // OUT, addr=5 endp=8 crc5=0e
  // assign test_pkt = 19'b1001_0000101_01101001; // IN, addr=5 endp=8 crc5=0e

  initial begin
    $monitor ($stime,, "pkt_in: %b | out_done: %b,  ANS: %b",
                      test_pkt, out_done, pkt_received);
    clock = 0;
    reset_n = 0;
    reset_n <= #1 1;
    forever #5 clock = ~clock;
  end

  initial begin
    pkt_in <= test_pkt;
    pkt_ready <= 1;
    pkt_len <= 32'd19;
    @(posedge clock);
    pkt_ready <= 0;
    @(posedge clock);

    repeat(100)
    @(posedge clock);


    #1 $finish;
  end

endmodule;