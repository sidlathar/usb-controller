`include "USBPkg.pkg"

// Wrapper for USB bus states. Notice that enum Z can only be driven, not read
typedef enum logic [1:0]
  {BS_J = 2'b10, BS_K = 2'b01, BS_SE0 = 2'b00, BS_SE1 = 2'b11, BS_NC = 2'bzz}
  bus_state_t;

module USBHost (
  USBWires wires,
  input logic clock, reset_n
);
  
  // Inputs
  logic        read_start, write_start;
  logic [15:0] write_mempage, read_mempage;
  logic [63:0] write_data;
  // Outputs
  logic DP_out, DM_out, sending,
        read_success, write_success, finished,
        DP_in, DM_in;
  logic [63:0] read_data;
  RW_FSM rw (.DP_in(DP_in), .DM_in(DM_in), .*);
  // module RW_FSM
  //   (input  logic clock, reset_n,
  //   // Inputs from USBHost
  //    input  logic        DP_in, DM_in, read_start, write_start,
  //    input  logic [15:0] write_mempage, read_mempage,
  //    input  logic [63:0] write_data,
  //   // Outputs from USBHost
  //    output logic DP_out, DM_out, sending, read_success, write_success, finished,
  //    output logic [63:0] read_data);


  assign wires.DP = (sending) ? DP_out : 1'bz; // A tristate driver
  assign wires.DM = (sending) ? DM_out : 1'bz; // Another tristate driver

  assign DP_in = (sending) ? 1'bz : wires.DP; // A tristate driver
  assign DM_in = (sending) ? 1'bz : wires.DM; // Another tristate driver

  task prelabRequest();
    // send_OUT <= 1; @(posedge clock); send_OUT <= 0; @(posedge clock);
    // send_IN <= 1; @(poswwedge clock); send_IN <= 0; @(posedge clock);
    // send_DATA0 <= 1; @(posedge clock); send_DATA0 <= 0; @(posedge clock);
    // send_ACK <= 1; @(posedge clock); send_ACK <= 0; @(posedge clock);
    // send_NAK <= 1; @(posedge clock); send_NAK <= 0; @(posedge clock);

    read_start <= 1;
    @ (posedge clock);
    read_start <= 0;

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

      data = read_data;
      success = read_success;

      read_start <= 1;
      read_mempage <= mempage;
      @ (posedge clock);

      read_start <= 0;
      @ (posedge clock);

      repeat (1000);
      @ (posedge clock);

  endtask : readData

  // Host sends mempage to thumb drive using a WRITE (OUT->DATA0->IN->DATA0)
  // transaction, and then sends data to it. This task should return the
  // transaction status, successful or unsuccessful, to the caller.
  task writeData
    ( input logic [15:0] mempage, // Page to write
      input logic [63:0] data, // Vector of bytes to write
      output logic success);

      write_mempage <= mempage;
      write_data <= data;

      write_start <= 1;

      wait (finished);

      write_start <= 0;
      // @(posedge clock);
      // success <= write_success;
      if (write_success == 1'b1) begin
        repeat (100) begin
          @ (posedge clock);
        end
        success <= 1;
      end else begin
        repeat (100) begin
          @ (posedge clock);
        end
        success <= 0;
      end

      @ (posedge clock);

  endtask : writeData

endmodule : USBHost