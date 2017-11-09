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

module NRZI_DPDM_Send_tb;
  logic clock, reset_n; // Typical inputs 
 
  // NRZI MODULE INSTANTIATION
  logic nrzi_in_bit, bs_sending; // Inputs to NRZI_Encode
  logic nrzi_out_bit, nrzi_sending; // Outputs from NRZI_Encode
  NRZI_Encode nrzi (.in_bit(nrzi_in_bit), .out_bit(nrzi_out_bit), .*);
  // (input logic clock, reset_n,
  //              in_bit, bs_sending,
  //  output logic out_bit, nrzi_sending);

  // DPDM MODULE INSTANTIATION
  logic ph_in_bit, ph_sending; // NOT USED
  logic DP_out, DM_out, out_done; // Outputs from DPDM_ENcode
  DPDM_Encode dpdm (
             .nrzi_in_bit(nrzi_out_bit), .nrzi_sending(nrzi_sending),
             .ph_in_bit(ph_in_bit), .ph_sending(ph_sending),
             .DP(DP_out), .DM(DM_out), .out_done(out_done), .*);
  // (input  logic clock, reset_n,
  //               nrzi_in_bit, nrzi_sending,
  //               ph_in_bit, ph_sending,
  //  output logic DP, DM, out_done);

//   // TESTING RECEIVING PACKET
  logic [98:0] pkt_received;
  logic always_load;
  assign always_load = 1;
  shiftRegister #(99) sr (.D(DP_out), .Q(pkt_received), .load(always_load), .*);
  // (input  logic             D,
  //  input  logic             load, clear, clock, reset_n,
  //  output logic [WIDTH-1:0] Q);  

  logic [87:0] test_pkt;
  // payload=0f21000000000000 crc16=a0e7
  // assign test_pkt = 72'h0f21000000000000_C3;
  // payload=40aa11b7682df6d8 crc16=544a
  assign test_pkt = 88'h544a_40aa11b7682df6d8_C3;

  initial begin
    $monitor ($stime,, "pkt_in: %b | DP: %b, DM: %b, out_done: %b | ANS: %b",
                     test_pkt, DP_out, DM_out, out_done, pkt_received);
    clock = 0;
    reset_n = 0;
    reset_n <= #1 1;
    forever #5 clock = ~clock;
  end

  initial begin
    bs_sending <= 1;
    for (int i = 0; i < 88; i++) begin
        nrzi_in_bit <= test_pkt[i];
        @ (posedge clock);
    end
    bs_sending <= 0;
    @(posedge clock);

    repeat(20)
    @(posedge clock);


    #1 $finish;
  end

endmodule;