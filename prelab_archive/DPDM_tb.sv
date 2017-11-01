
/* TESTBENCH BEGIN */

// SIPO right shift register
// module shiftRegister
//   #(parameter WIDTH=8)
//   (input  logic             D,
//    input  logic             load, clock, reset_n,
//    output logic [WIDTH-1:0] Q);
   
//   always_ff @(posedge clock, negedge reset_n) begin
//     if (~reset_n)
//       Q <= 0;
//     else if (load)
//       Q <= {D, Q[WIDTH-1:1]};
//   end
      
// endmodule : shiftRegister

// module DPDM_Test;
//   logic clock, reset_n; // Typical inputs 
  
//   logic in_bit, nrzi_sending, // inputs
//         DP, DM, out_done; // outputs

//   DPDM dut (.*);
//     // (input  logic clock, reset_n,
//     //               in_bit, nrzi_sending,
//     //  output logic DP, DM);

//   // TESTING RECEIVING PACKET
//   logic [34:0] DP_received;
//   logic always_load;
//   assign always_load = 1'b1;
//   shiftRegister #(35) srDP (.D(DP), .Q(DP_received), .load(always_load), .*);

//   logic [34:0] DM_received;
//   shiftRegister #(35) srDM (.D(DM), .Q(DM_received), .load(always_load), .*);
//   // (input  logic             D,
//   //  input  logic             load, clear, clock, reset_n,
//   //  output logic [WIDTH-1:0] Q);

//   logic [23:0] test_pkt;
//   // 101011001010100111110101 (OUTPUT FROM NRZI)
//   assign test_pkt = 24'b101011001010100111110101;
//   /* FINAL (CORRECT) RESULT: DPDM: zz, out_done: 0 |
//   * DP_rec: 1001010110010101001111101010010101000000
//   * DM_rec: 0000101001101010110000010101101010100000 */

//   initial begin
//     $monitor ($stime,, "pkt_in: %b | n_sending: %b, in_bit: %b | DPDM: %b%b, out_done: %b | DP_rec: %b, DM_rec: %b | cs: %s ns: %s",
//                         test_pkt, nrzi_sending, in_bit, DP, DM, out_done, DP_received, DM_received, dut.fsm.currState.name, dut.fsm.nextState.name);
//     clock = 0;
//     reset_n = 0;
//     reset_n <= #1 1;
//     forever #5 clock = ~clock;
//   end

//   initial begin
//     for (int i = 0; i < 23; i ++) begin
//       in_bit <= test_pkt[i];
//       nrzi_sending <= 1;
//       @(posedge clock);
//     end
//     in_bit <= test_pkt[23];
//     nrzi_sending <= 0;
//     @(posedge clock);

//     repeat (15)
//     @(posedge clock);

//     #1 $finish;
//   end

// endmodule : DPDM_Test