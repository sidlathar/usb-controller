`default_nettype none/* TESTBENCH BEGIN */

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

module CRC16_tb;
  logic clock, reset_n; // Typical inputs 
 

  // CRC MODULE INSTANTIATION
  logic [71:0] pkt_in; // input
  logic pkt_ready, bs_ready, // inputs
        crc16_out_bit, crc16_valid_out; //output
  CRC16_Calc crc16 (.out_bit(crc16_out_bit),
                  .crc_valid_out(crc16_valid_out),
                   .*);
  // (input  logic clock, reset_n,
  //               pkt_ready,     // PH ready to send us a packet
  //               bs_ready,      // BS ready to receive bits
  //  input  logic [71:0] pkt_in, // orig packet from protocol handler
  //  output logic out_bit,       // bit going to BS
  //               crc_valid_out);  // telling BS we are sending bits


  logic crc5_valid_out, crc5_in_bit, // not used
        bs_out_bit, bs_sending;
  BitStuffer bs (.out_bit(bs_out_bit),
                 .crc16_in_bit(crc16_out_bit),
                 .*);
  // module BitStuffer
  //   (input  logic clock, reset_n,
  //                 crc5_valid_out, crc5_in_bit,
  //                 crc16_valid_out, crc16_in_bit,
  //    output logic out_bit, bs_ready, bs_sending);

//   // TESTING RECEIVING PACKET
  logic [39:0] pkt_received;
  shiftRegister #(40) sr (.D(bs_out_bit), .Q(pkt_received), .load(bs_sending), .*);
  // (input  logic             D,
  //  input  logic             load, clear, clock, reset_n,
  //  output logic [WIDTH-1:0] Q);  

  logic [71:0] test_pkt;
  // payload=0f21000000000000 crc16=a0e7
  // assign test_pkt = 72'h0f21000000000000_C3;
  // payload=40aa11b7682df6d8 crc16=544a
  // assign test_pkt = 72'h40aa11b7682df6d8_C3;
  assign test_pkt = 72'hffffff0000000000_C3;



  initial begin
    $monitor ($stime,, "bs_out_bit: %b, bs_sending: %b, ANS: %b | CRC16: %h",
                        bs_out_bit, bs_sending, pkt_received, crc16.crc_result);
    clock = 0;
    reset_n = 0;
    reset_n <= #1 1;
    forever #5 clock = ~clock;
  end

  initial begin
    pkt_in <= test_pkt;
    pkt_ready <= 1;
    @(posedge clock);
    pkt_ready <= 0;
    @(posedge clock);

    repeat(100)
    @(posedge clock);


    #1 $finish;
  end

endmodule;