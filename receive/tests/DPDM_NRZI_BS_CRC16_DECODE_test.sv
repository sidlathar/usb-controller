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

module testReceiver;
// module DPDM_decode(
// 	input logic clock, reset_n,
// 	input logic DP_in, DM_in, rec_start,
// 	output logic out_bit, dpdm_sending);
	logic clock, reset_n, DP_in, DM_in, rec_start;
	logic out_bit, dpdm_sending, load_data;

	DPDM_decode dpdm(.*);



// module NRZI_decoder
//   (input logic clock, reset_n,
//                in_bit, dpdm_sending, // insted of bs_sending it shuld be DPDM sending?
//    output logic out_bit, nrzi_sending);
	logic nrzi_out_bit, nrzi_sending;

	NRZI_decoder nrzi(.in_bit(out_bit), .out_bit(nrzi_out_bit), .*);


// // module BitStuffer_decode
// //   (input  logic clock, reset_n,
// //                 nrzi_sending, in_bit,
// //    output logic out_bit, bs_sending);

	logic bs_sending, bs_out_bit;

	BitStuffer_decode bsd(.in_bit(nrzi_out_bit), .out_bit(bs_out_bit), .*);


	logic crc_sending, crc_out_bit, crc_valid;
	logic [63:0] data0;

	CRC16_Decode crc16d(.in_bit(bs_out_bit), .out_bit(crc_out_bit), .*);


	// logic [98:0] DP, DM;
 	// assign DP = 99'b100011001101001001101101010110011001010010111000111100011010100111000000111000111010001010000101010;  //CRC//DATA0//PID//SYNC WORKS!
 	// assign DM = {3'b000 , ~('b011001101001001101101010110011001010010111000111100011010100111000000111000111010001010000101010)}; 

	// logic [100:0] DP, DM;
 	// assign DP = 101'b10001001001001111001000000011111110100101010101010101010101010101010101010101010101010001010000101010;  //CRC//DATA0//PID//SYNC  WORKS!
 	// assign DM = {3'b000 , ~('b01001001001111001000000011111110100101010101010101010101010101010101010101010101010001010000101010)};  

  	// logic [98:0] DP, DM;
  	// assign DP = 99'b100011001101001001101101010110011001010010111000111100011010100111000000111000111010001010000101010;  //CRC//DATA0//PID//SYNC  WORKS!  WORKS!
  	// assign DM = {3'b000 , ~('b011001101001001101101010110011001010010111000111100011010100111000000111000111010001010000101010)};

  	// logic [99:0] DP, DM;
  	// assign DP = 100'b1001001011011111000001111111000000101010010111000111100011010100111000000111000111010001010000101010;  //CRC//DATA0//PID//SYNC  WORKS!  WORKS!
  	// assign DM = {3'b000 , ~('b1001011011111000001111111000000101010010111000111100011010100111000000111000111010001010000101010)};


  	logic [99:0] DP, DM;
  	assign DP = 100'b1001001011011111000001111111000000101010010111000111100011010100111000000111000111010001010000101010;  //CRC//DATA0//PID//SYNC  WORKS!  WORKS!
  	assign DM = {3'b000 , ~('b1001011011111000001111111000000101010010111000111100011010100111000000111000111010001010000101010)};






  // TESTING RECEIVING PACKET
	  logic [79:0] pkt_received;
	  shiftRegister #(80) sr (.D(crc_out_bit), .Q(pkt_received), .load(crc_sending), .*);
	  // (input  logic             D,
	  //  input  logic             load, clear, clock, reset_n,
	  //  output logic [WIDTH-1:0] Q);


	  initial begin
	    $monitor ($stime,, " dpdm_sending: %b | nrzi_sending: %b | bs_sending: %b | crc_sending: %b |  se0_rec: %b | match_val = %b | cs: %s | ns: %s | pkt_received: %h | crc residue: %h, validCRC: %b | data0: %h",
	                        dpdm.fsm.dpdm_sending, nrzi_sending, bs_sending, crc_sending,  dpdm.se0_rec, dpdm.match_val, dpdm.fsm.currState.name, dpdm.fsm.nextState.name, pkt_received, crc16d.capture_residue, crc_valid, data0);
	    clock = 0;
	    reset_n = 0;
	    reset_n <= #1 1;
	    forever #5 clock = ~clock;
	  end

	  initial begin
	    //rec_start = 0;
	    @(posedge clock);
	    //rec_start = 1;
	    @(posedge clock);
	    //rec_start = 0;

	    for (int i = 0; i < 100; i ++) begin
	      DP_in <= DP[i];
	      DM_in <= DM[i];
	      @(posedge clock);
	    end


	     DP_in <= 1'bz;
	     DM_in <= 1'bz;
	     @(posedge clock);

	    @(posedge clock);
	    repeat(10)
	    @(posedge clock);

	    #1 $finish;
  end

// // module CRC16_Decode
// //   (input  logic clock, reset_n,
// //                 bs_sending,      // BS ready to receive bits
// //    input  logic in_bit, // orig packet from protocol handler
// //    output logic out_bit,       // bit going to BS
// //                 crc_sending);  // telling BS we are sending bits


// 	logic crc_sending, crc_out_bit;

// 	CRC16_Decode crc16d(.in_bit(bs_out_bit), .out_bit(crc_out_bit), .*);

endmodule: testReceiver // testReceiver













