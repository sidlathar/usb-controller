`default_nettype none

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

module PH_Sender_tb;
  logic clock, reset_n; // Typical inputs 
 
  logic send_OUT, send_IN, send_DATA0, send_ACK, send_NAK; // Inputs
  logic [3:0] endp; // Input
  logic [63:0] data; // Input
  logic DP_out, DM_out, out_done; // Outputs
  PH_Sender dut (.*);
  // module PH_Sender
  //   (input  logic        clock, reset_n,
  //                        send_OUT, send_IN, send_DATA0, send_ACK, send_NAK,
  //    input  logic  [3:0] endp,  // If we need it for OUT or IN
  //    input  logic [63:0] data,  // If we need it for DATA0
  // output logic        DP_out, DM_out, out_done);

  // TESTING RECEIVING PACKET
  logic [24:0] pkt_received;
  logic always_load;
  assign always_load = 1;
  shiftRegister #(25) sr (.D(DP_out), .Q(pkt_received), .load(always_load), .*);
  // (input  logic             D,
  //  input  logic             load, clear, clock, reset_n,
  //  output logic [WIDTH-1:0] Q);  

  // PRELAB: OUT, addr=5, ENDP=4, crc5=10
  // assign test_pkt_crc5 = 19'b0100_0000101_11100001; 
  assign endp = 4'd4;

  logic [71:0] test_pkt;
  // payload=0f21000000000000 crc16=a0e7
  // assign test_pkt = 72'h0f21000000000000_C3;
  // payload=40aa11b7682df6d8 crc16=544a
  // assign test_pkt = 72'h40aa11b7682df6d8_C3;
  // assign test_pkt = 72'hffffff0000000000_C3;



  initial begin
    $monitor ($stime,, "DP_out: %b, out_done: %b | ANS: %b",
                  DP_out, out_done, pkt_received);
    clock = 0;
    reset_n = 0;
    reset_n <= #1 1;
    forever #5 clock = ~clock;
  end

  initial begin
    send_OUT <= 1;
    @(posedge clock);
    send_OUT <= 0;
    @(posedge clock);

    repeat(1000)
    @(posedge clock);


    #1 $finish;
  end

endmodule;