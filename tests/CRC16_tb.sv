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

module CRC16_tb;
  logic clock, reset_n; // Typical inputs 
 
  // "TASK" inputs to CRC (should be coming from our Protocol Handler)
  logic [71:0] pkt_in; // input

  // CRC MODULE INSTANTIATION
  logic pkt_ready, bs_ready, // inputs
        crc_out_bit, crc_valid_out; //output
  CRC16_Encode dut (.out_bit(crc_out_bit), .*);
  // (input  logic clock, reset_n,
  //               pkt_ready,     // PH ready to send us a packet
  //               bs_ready,      // BS ready to receive bits
  //  input  logic [71:0] pkt_in, // orig packet from protocol handler
  //  output logic out_bit,       // bit going to BS
  //               crc_valid_out);  // telling BS we are sending bits

//   // TESTING RECEIVING PACKET
  logic [79:0] pkt_received;
  logic always_load;
  assign always_load = 1;
  shiftRegister #(80) sr (.D(crc_out_bit), .Q(pkt_received), .load(always_load), .*);
  // (input  logic             D,
  //  input  logic             load, clear, clock, reset_n,
  //  output logic [WIDTH-1:0] Q);  

  logic [71:0] test_pkt;
  // payload=0f21000000000000 crc16=a0e7
  assign test_pkt = 72'h0f21000000000000_C3;
  // payload=40aa11b7682df6d8 crc16=544a
  // assign test_pkt = 72'h40aa11b7682df6d8_C3;

  initial begin
    $monitor ($stime,, "pkt_in: %h | crc_valid_out: %b, crc_out_bit: %b | ANS: %h | CRC_result: %h, : %d",
                      test_pkt, crc_valid_out, crc_out_bit, pkt_received, dut.crc_result, dut.crc_flush_cnt);
    clock = 0;
    reset_n = 0;
    reset_n <= #1 1;
    forever #5 clock = ~clock;
  end

  initial begin
    pkt_in <= test_pkt;
    pkt_ready <= 1;
    bs_ready <= 1;
    @(posedge clock);
    pkt_ready <= 0;
    @(posedge clock);

    repeat(100)
    @(posedge clock);


    #1 $finish;
  end

endmodule;