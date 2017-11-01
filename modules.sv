`default_nettype none

/* HELPER MODULES BEGIN */

// A Parallel In, Serial Out register for a variable length
module PISO_Register_Right
  #(parameter W=100)
  (input  logic clock, load, shift,
   input  logic [W-1:0] D,
   output logic Q);

  logic [99:0] buff;
  assign Q = buff[0];

  always_ff @(posedge clock) begin
    if (load)
      buff <= D;
    else if (shift) begin
      buff <= (buff >> 1);
    end
  end

endmodule : PISO_Register_Right

// A Parallel In, Serial Out register for a known length
module PISO_Register_Left
  #(parameter W=5)
  (input  logic clock, load, shift,
   input  logic [W-1:0] D,
   output logic Q);

  logic [W-1:0] buff;
  assign Q = buff[W-1];

  always_ff @(posedge clock) begin
    if (load)
      buff <= D;
    else if (shift) begin
      buff <= (buff << 1);
    end
  end

endmodule : PISO_Register_Left
