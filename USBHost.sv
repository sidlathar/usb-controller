`include "USBPkg.pkg"

// Wrapper for USB bus states. Notice that enum Z can only be driven, not read
typedef enum logic [1:0]
  {BS_J = 2'b10, BS_K = 2'b01, BS_SE0 = 2'b00, BS_SE1 = 2'b11, BS_NC = 2'bzz}
  bus_state_t;

module USBHost (
  USBWires wires,
  input logic clock, reset_n
);

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
  // assign data = 64'h0f21000000000000;
  // payload=40aa11b7682df6d8 crc16=544a
  assign data = 64'h40aa11b7682df6d8;


  // // Assign DP, DM to the wire
  assign wires.DP = DP_out;
  assign wires.DM = DM_out;


  task prelabRequest();
    // send_OUT <= 1; @(posedge clock); send_OUT <= 0; @(posedge clock);
    // send_IN <= 1; @(posedge clock); send_IN <= 0; @(posedge clock);
    // send_DATA0 <= 1; @(posedge clock); send_DATA0 <= 0; @(posedge clock);
    // send_ACK <= 1; @(posedge clock); send_ACK <= 0; @(posedge clock);
    send_NAK <= 1; @(posedge clock); send_NAK <= 0; @(posedge clock);

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