`include "USBPkg.pkg"

// Wrapper for USB bus states. Notice that enum Z can only be driven, not read
typedef enum logic [1:0]
  {BS_J = 2'b10, BS_K = 2'b01, BS_SE0 = 2'b00, BS_SE1 = 2'b11, BS_NC = 2'bzz}
  bus_state_t;

module USBHost (
  USBWires wires,
  input logic clock, reset_n
);

  /* OUR MODULES BEGIN HERE */



   // CRC MODULE INSTANTIATION
   logic pkt_ready, bs_ready, // inputs
         crc_out_bit, crc_valid_out; //output
   CRC_Calc crc (.out_bit(crc_out_bit), .*);

   // BITSTUFFER MODULE INSTANTIATION
   logic bs_out_bit, bs_sending;
   BitStuffer bs (.in_bit(crc_out_bit), .out_bit(bs_out_bit), .*);

   // NRZI MODULE INSTANTIATION
   logic nrzi_out_bit, nrzi_sending;
   NRZI_Encoder nrzi (.in_bit(bs_out_bit), .out_bit(nrzi_out_bit), .*);

   // DPDM MODULE INSTANTIATION
   logic out_DP, out_DM, out_done;
   DPDM dpdm (.in_bit(nrzi_out_bit), .DP(out_DP), .DM(out_DM), .*);


  /* OUR MODULES END HERE */

  // "TASK" inputs to CRC (should be coming from our Protocol Handler)
  logic [99:0] pkt_in; // input
  logic [31:0] pkt_len; // input
  
   /// PRELAB: OUT, addr=5, ENDP=4, crc5=10
   logic [18:0] test_pkt;
   assign test_pkt = 19'b0100_0000101_11100001;

  // Assign DP, DM to the wire
  assign wires.DP = out_DP;
  assign wires.DM = out_DM;

  task prelabRequest();
    pkt_in <= test_pkt;
    pkt_ready <= 1;
    pkt_len <= 32'd19;
    @(posedge clock);
    pkt_ready <= 0;
    @(posedge clock);

    repeat(100)
    @(posedge clock);

  endtask : prelabRequest

  task readData
    // Host sends mempage to thumb drive using a READ (OUT->DATA0->OUT->DATA0)
    // transaction, and then receives data from it. This task should return both the
    // data and the transaction status, successful or unsuccessful, to the caller.
    ( input logic [15:0] mempage, // Page to write
      output logic [63:0] data, // Vector of bytes to write
      output logic success);

      data = 64'h0;
      success = 1'b0;

  endtask : readData

  task writeData
    // Host sends mempage to thumb drive using a WRITE (OUT->DATA0->IN->DATA0)
    // transaction, and then sends data to it. This task should return the
    // transaction status, successful or unsuccessful, to the caller.
    ( input logic [15:0] mempage, // Page to write
      input logic [63:0] data, // Vector of bytes to write
      output logic success);

      success = 1'b0;

  endtask : writeData

endmodule : USBHost