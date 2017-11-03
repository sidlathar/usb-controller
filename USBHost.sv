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
  // logic pkt_ready, bs_ready, // inputs
  //      crc_out_bit, crc_valid_out; //output
  // CRC5_Calc crc (.out_bit(crc_out_bit), .*);

  logic pkt_ready, bs_ready, // inputs
       crc_out_bit, crc_valid_out; //output
  CRC16_Calc crc (.out_bit(crc_out_bit), .*);

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

  logic [18:0] test_pkt;
  // PRELAB: OUT, addr=5, ENDP=4, crc5=10
  // assign test_pkt = 19'b0100_0000101_11100001; 

  // OUT, addr=5 endp=8 crc5=0e
  // assign test_pkt = 19'b1000_0000101_11100001; 

  // IN, addr=5 endp=8 crc5=0e
  // assign test_pkt = 19'b1000_0000101_01101001;

  // Test BS
  assign test_pkt = 19'b1111_1111111_01101001;

  logic [71:0] test_pkt_crc16;
  // payload=0f21000000000000 crc16=a0e7
  // assign test_pkt_crc16 = 72'h000000000000_84F0_C3;
  // payload=40aa11b7682df6d8 crc16=544a
  assign test_pkt_crc16 = 72'h40aa11b7682df6d8_C3;

  // Assign DP, DM to the wire
  assign wires.DP = out_DP;
  assign wires.DM = out_DM;

  task prelabRequest();
    // pkt_in <= test_pkt;
    // pkt_len <= 32'd19;

    pkt_in <= test_pkt_crc16;
    pkt_len <= 32'd72;
    pkt_ready <= 1;
    @(posedge clock);
    pkt_ready <= 0;
    @(posedge clock);

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