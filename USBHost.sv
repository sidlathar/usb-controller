`include "USBPkg.pkg"

// Wrapper for USB bus states. Notice that enum Z can only be driven, not read
typedef enum logic [1:0]
  {BS_J = 2'b10, BS_K = 2'b01, BS_SE0 = 2'b00, BS_SE1 = 2'b11, BS_NC = 2'bzz}
  bus_state_t;

module USBHost (
  USBWires wires,
  input logic clock, reset_n
);

  // /* OUR MODULES BEGIN HERE */

  // // CRC 5 and CRC 16 MODULE INSTANTIATION
  // logic [18:0] crc5_pkt_in;
  // logic crc5_pkt_ready;

  // logic bs_ready, // input from BitStuffer
  //       crc5_out_bit, crc5_valid_out,
  //       crc16_out_bit, crc16_valid_out; // output to BitStuffer
  // CRC5_Encode   crc5 (.pkt_in(crc5_pkt_in), .pkt_ready(crc5_pkt_ready),
  //                   .out_bit(crc5_out_bit), .crc_valid_out(crc5_valid_out),
  //                   .*);

  // logic [71:0] crc16_pkt_in;
  // logic crc16_pkt_ready;

  // CRC16_Encode crc16 (.pkt_in(crc16_pkt_in), .pkt_ready(crc16_pkt_ready),
  //                   .out_bit(crc16_out_bit), .crc_valid_out(crc16_valid_out),
  //                   .*);

  // // BITSTUFFER MODULE INSTANTIATION
  // logic bs_out_bit, bs_sending;
  // BitStuffer bs (.crc5_valid_out(crc5_valid_out),
  //                .crc5_in_bit(crc5_out_bit),
  //                .crc16_valid_out(crc16_valid_out),
  //                .crc16_in_bit(crc16_out_bit),
  //                .out_bit(bs_out_bit), .*);

  // // NRZI MODULE INSTANTIATION
  // logic nrzi_out_bit, nrzi_sending;
  // NRZI_Encoder nrzi (.in_bit(bs_out_bit), .out_bit(nrzi_out_bit), .*);

  // // DPDM MODULE INSTANTIATION
  // logic out_DP, out_DM, out_done, ph_out_bit, ph_sending;
  // DPDM dpdm (.nrzi_in_bit(nrzi_out_bit), .nrzi_sending(nrzi_sending),
  //            .ph_in_bit(ph_out_bit), .ph_sending(ph_sending),
  //            .DP(out_DP), .DM(out_DM), .*);


  // /* OUR MODULES END HERE */

  // // "TASK" inputs to CRC (should be coming from our Protocol Handler)

  // // logic [18:0] pkt_in; // input
  // logic [18:0] test_pkt_crc5;
  // // PRELAB: OUT, addr=5, ENDP=4, crc5=10
  // // assign test_pkt_crc5 = 19'b0100_0000101_11100001; 

  // // OUT, addr=5 endp=8 crc5=0e
  // // assign test_pkt_crc5 = 19'b1000_0000101_11100001; 

  // // IN, addr=5 endp=8 crc5=0e
  // // assign test_pkt_crc5 = 19'b1000_0000101_01101001;

  // // Test BS
  // // assign test_pkt_crc5 = 19'b1111_1111111_01101001;

  // logic [71:0] pkt_in; // input
  // logic [71:0] test_pkt_crc16;
  // // payload=0f21000000000000 crc16=a0e7
  // // assign test_pkt_crc16 = 72'h000000000000_84F0_C3;
  // // payload=40aa11b7682df6d8 crc16=544a
  // // assign test_pkt_crc16 = 72'h40aa11b7682df6d8_C3;

  // assign test_pkt_crc16 = 72'hffff000000000000_C3;
  // // assign test_pkt_crc16 = 72'hffffff0000000000_C3;


  // // Assign DP, DM to the wire
  // assign wires.DP = out_DP;
  // assign wires.DM = out_DM;

  // task prelabRequest();
  //   // crc5_pkt_in <= test_pkt_crc5;
  //   // crc5_pkt_ready <= 1;
  //   // @(posedge clock);
  //   // crc5_pkt_ready <= 0;
  //   // @(posedge clock);

  //   crc16_pkt_in <= test_pkt_crc16;
  //   crc16_pkt_ready <= 1;
  //   @(posedge clock);
  //   crc16_pkt_ready <= 0;
  //   @(posedge clock);

  //   repeat(100)
  //   @(posedge clock);

  // endtask : prelabRequest

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

  // PRELAB: OUT, addr=5, ENDP=4, crc5=10
  // assign test_pkt_crc5 = 19'b0100_0000101_11100001; 
  assign endp = 4'd4;

  // payload=0f21000000000000 crc16=a0e7
  assign data = 64'h0f21000000000000;



  // // Assign DP, DM to the wire
  assign wires.DP = DP_out;
  assign wires.DM = DM_out;


  task prelabRequest();
    // send_OUT <= 1;
    // @(posedge clock);
    // send_OUT <= 0;
    // @(posedge clock);

    // send_DATA0 <= 1;
    // @(posedge clock);
    // send_DATA0 <= 0;
    // @(posedge clock);

    // send_ACK <= 1;
    // @(posedge clock);
    // send_ACK <= 0;
    // @(posedge clock);

    repeat(100)
    @(posedge clock);


  endtask : prelabRequest

  // Host sends mempage to thumb drive using a READ (OUT->DATA0->OUT->DATA0)
  // transaction, and then receives data from it. This task should return both the
  // data and the transaction status, successful or unsuccessful, to the caller.
  task readData
    ( input logic [15:0] mempage, // Page to read
      output logic [63:0] data, // Vector of bytes to read
      output logic success);

      data = 64'h0;
      success = 1'b0;

  endtask : readData

  // Host sends mempage to thumb drive using a WRITE (OUT->DATA0->IN->DATA0)
  // transaction, and then sends data to it. This task should return the
  // transaction status, successful or unsuccessful, to the caller.
  task writeData
    ( input logic [15:0] mempage, // Page to write
      input logic [63:0] data, // Vector of bytes to write
      output logic success);

      success = 1'b0;

  endtask : writeData

endmodule : USBHost