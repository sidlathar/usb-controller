`include "USBPkg.pkg"

/*
 * Samuel Kim (ssk1) and Siddhanth Lathar (slathar)
 * 18-341 USB
 */

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
  logic DP_out, DM_out, sending, read_success, write_success, finished,
        DP_in, DM_in;
  logic [63:0] read_data;
  RW_FSM rw (.DP_in(DP_in), .DM_in(DM_in), .*);
  //   (input  logic clock, reset_n,
  //   // Inputs from USBHost
  //    input  logic        DP_in, DM_in, read_start, write_start,
  //    input  logic [15:0] write_mempage, read_mempage,
  //    input  logic [63:0] write_data,
  //   // Outputs from USBHost
  //    output logic DP_out, DM_out, sending, read_success, write_success,
  //                 finished,
  //    output logic [63:0] read_data);


  assign wires.DP = (sending) ? DP_out : 1'bz; // A tristate driver
  assign wires.DM = (sending) ? DM_out : 1'bz; // Another tristate driver

  assign DP_in = (sending) ? 1'bz : wires.DP; // A tristate driver
  assign DM_in = (sending) ? 1'bz : wires.DM; // Another tristate driver

  task prelabRequest();
    write_mempage <= 16'd0;
    write_data <= 64'd0;

    write_start <= 1;
    @ (posedge clock);

    wait (finished);

    write_start <= 0;
    @(posedge clock);

  endtask : prelabRequest

  // Host sends mempage to thumb drive using a READ (OUT->DATA0->OUT->DATA0)
  // transaction, and then receives data from it. This task should return both
  // data and the transaction status, successful or unsuccessful, to the caller.
  task readData
    ( input logic [15:0] mempage, // Page to read
      output logic [63:0] data, // Vector of bytes to read
      output logic success);

      read_mempage <= mempage;
      read_start <= 1;
      @ (posedge clock);
      write_start <= 0;
      @(posedge finished);
      #1 wait(finished);
      success <= read_success;
      data <= read_data;
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
      @ (posedge clock);
      write_start <= 0;
      @(posedge finished);
      #1 wait(finished);
      success <= write_success;
      @ (posedge clock);

  endtask : writeData

endmodule : USBHost