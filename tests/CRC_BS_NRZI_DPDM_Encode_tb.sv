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

module BS_NRZI_DPDM_Send_tb;
  logic clock, reset_n; // Typical inputs 


  /************************** MODULE INSTANTIATION  **************************/
  logic crc5_pkt_ready, crc16_pkt_ready;
  logic [18:0] crc5_pkt_in;
  logic [71:0] crc16_pkt_in;

  // CRC 5 and CRC 16 MODULE INSTANTIATION
  logic bs_ready, // input from BitStuffer
        crc5_out_bit, crc5_valid_out,
        crc16_out_bit, crc16_valid_out; // output to BitStuffer
  CRC5_Encode   crc5 (.pkt_in(crc5_pkt_in), .pkt_ready(crc5_pkt_ready),
                    .out_bit(crc5_out_bit), .crc_valid_out(crc5_valid_out),
                    .*);
  // (input  logic clock, reset_n,
  //               pkt_ready,     // PH ready to send us a packet
  //               bs_ready,      // BS ready to receive bits
  //  input  logic [18:0] pkt_in, // orig packet from protocol handler
  //  output logic out_bit,       // bit going to BS
  //               crc_valid_out);  // telling BS we are sending bits
  CRC16_Encode crc16 (.pkt_in(crc16_pkt_in), .pkt_ready(crc16_pkt_ready),
                    .out_bit(crc16_out_bit), .crc_valid_out(crc16_valid_out),
                    .*);

  // BITSTUFFER MODULE INSTANTIATION
  logic bs_out_bit, bs_sending;
  BS_Encode bs (.crc5_valid_out(crc5_valid_out),
                 .crc5_in_bit(crc5_out_bit),
                 .crc16_valid_out(crc16_valid_out),
                 .crc16_in_bit(crc16_out_bit),
                 .out_bit(bs_out_bit), .*);
  // (input  logic clock, reset_n,
  //               crc5_valid_out, crc5_in_bit,
  //               crc16_valid_out, crc16_in_bit,                
  //  output logic out_bit, bs_ready, bs_sending);

  // NRZI MODULE INSTANTIATION
  logic nrzi_out_bit, nrzi_sending;
  NRZI_Encode nrzi (.in_bit(bs_out_bit), .out_bit(nrzi_out_bit), .*);
  // (input logic clock, reset_n,
  //              in_bit, bs_sending,
  //  output logic out_bit, nrzi_sending);

  // DPDM MODULE INSTANTIATION
  logic DP_out, DM_out, sent;
  logic ph_out_bit, ph_sending; // NOT USING
  DPDM_Encode dpdm (
             .nrzi_in_bit(nrzi_out_bit), .nrzi_sending(nrzi_sending),
             .ph_in_bit(ph_out_bit), .ph_sending(ph_sending),
             .DP(DP_out), .DM(DM_out), .sent(sent), .*);
  // (input  logic clock, reset_n,
  //               nrzi_in_bit, nrzi_sending,
  //               ph_in_bit, ph_sending,
  //  output logic DP, DM, sent);

//   // TESTING RECEIVING PACKET
  logic [119:0] pkt_received;
  logic always_load;
  assign always_load = 1;
  shiftRegister #(120) sr (.D(DP_out), .Q(pkt_received), .load(always_load), .*);
  // (input  logic             D,
  //  input  logic             load, clear, clock, reset_n,
  //  output logic [WIDTH-1:0] Q);  

  logic [71:0] test_pkt;
  // assign test_pkt = 72'hfff1000000000000_C3;
  // assign test_pkt = 72'h40aa11b7682df6d8_C3;
  // assign test_pkt = 72'hfef811b7682df6d8_C3;
  assign test_pkt = 72'he46700001b981111_C3;


  initial begin
    $monitor ($stime,, "pkt_in: %h |  DP: %b, DM: %b, sent: %b | ANS: %b",
                     test_pkt, DP_out, DM_out, sent, pkt_received);
    clock = 0;
    reset_n = 0;
    reset_n <= #1 1;
    forever #5 clock = ~clock;
  end

  initial begin
    crc16_pkt_ready <= 1;
    crc16_pkt_in <= test_pkt;
    @(posedge clock);
    crc16_pkt_ready <= 0;
    @(posedge clock);

    repeat(100)
    @(posedge clock);


    #1 $finish;
  end

endmodule;