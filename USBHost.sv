`include "USBPkg.pkg"

// Wrapper for USB bus states. Notice that enum Z can only be driven, not read
typedef enum logic [1:0]
  {BS_J = 2'b10, BS_K = 2'b01, BS_SE0 = 2'b00, BS_SE1 = 2'b11, BS_NC = 2'bzz}
  bus_state_t;

module USBHost (
  USBWires wires,
  input logic clock, reset_n
);
// module CRC_Encoder_FSM
//   ();
// endmodule : CRC_Encoder_FSM

// module CRC_Encoder
//   ();
// endmodule : CRC_Encoder

/* CRC ENCODING END */


  // task prelabRequest();

  //   // Prelab packet to send
  //   logic [3:0] pid;
  //   logic [7:0] pid_encoded;
  //   logic [6:0] addr; 
  //   logic [3:0] endp;
  //   assign pid = 4'b0001; // OUT
  //   assign pid_encoded = {~pid, pid};
  //   assign addr = 7'd5;
  //   assign endp = 7'd4;

  //   // pkt_t prelab_pkt;
  //   // prelab_pkt.pid = PID_OUT;
  //   // prelab_pkt.addr = 7'd5;
  //   // prelab_pkt.endp = 7'd4;

  //   // Generic fixed size packet
  //   // typedef struct {
  //   //   pid_t pid;
  //   //   logic [`ADDR_BITS-1:0] addr;
  //   //   logic [`ENDP_BITS-1:0] endp;
  //   //   logic [`PAYLOAD_BITS-1:0] payload;
  //   // } pkt_t;
  //   // const pid_t valid_pids[5] = '{PID_OUT, PID_IN, PID_DATA0, PID_ACK, PID_NAK};


  //   initial begin
  //     pkt_in <= prelab_pkt;
  //     @(posedge clock);
  //   end

  // endtask : prelabRequest

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


/* COMPONENT MODULES BEGIN */
// A normal counter
module Counter
   (input  logic clock, clear, inc, reset_n,
    output logic [31:0] Q);

  always_ff @(posedge clock, negedge reset_n)
    if (~reset_n)
      Q <= 0;
    else if (clear)
      Q <= 0;
    else if (inc)
      // else: always count clocks
      Q <= Q + 1;
endmodule : Counter

// A Parallel In, Serial Out register
module PISO_Register
  #(parameter W=24)
  (input  logic clock, load, shift,
   input  logic [W-1:0] D,
   output logic Q);

  logic [W-1:0] buff;

  always_ff @(posedge clock) begin
    if (load)
      buff <= D;
    else if (shift) begin
      Q <= buff[W-1];
      buff <= (buff << 1);
    end
  end

endmodule : PISO_Register
/* COMPONENT MODULES END */

// /* CRC ENCODING BEGIN */