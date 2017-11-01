`default_nettype none
// A Parallel In, Serial Out register
module PISO_Register
  #(parameter W=24)
  (input  logic clock, load, shift,
   input  logic [W-1:0] D,
   output logic [3:0] Q);

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

module CRC_Calc
  (input  logic clock, reset_n,
                in_bit, // orig packet stream from PISO reg
                calc_start, load, shift, // signals from FSM
   output logic out_bit);

  logic x0_D, x1_D, x2_D, x3_D, x4_D,
        x0_Q, x1_Q, x2_Q, x3_Q, x4_Q;

  always_comb begin
    x0_D = in_bit ^ x4_Q;
    x1_D = x0_Q;
    x2_D = x1_Q ^ x0_D;
    x3_D = x2_Q;
    x4_D = x3_Q;
  end // always_comb

  // To hold our remainder
  logic load, shift;
  PISO_Register #(5) pr (.D({x4_Q, x3_Q, x2_Q, x1_Q, x0_Q}),
                         .Q(out_bit),
                         .*);
  // #(parameter W=24)
  // (input  logic clock, load, shift,
  //  input  logic [W-1:0] D,
  //  output logic Q);

  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      x0_Q <= 1;
      x1_Q <= 1;
      x2_Q <= 1;
      x3_Q <= 1;
      x4_Q <= 1;
    end else begin
      if (calc_start) begin      
        x0_Q <= x0_D;
        x1_Q <= x1_D;
        x2_Q <= x2_D;
        x3_Q <= x3_D;
        x4_Q <= x4_D;
      end else begin
        x0_Q <= 1;
        x1_Q <= 1;
        x2_Q <= 1;
        x3_Q <= 1;
        x4_Q <= 1;
      end
    end
  end // always_ff

endmodule : CRC_Calc

module CRC_Calc_test;
  logic clock, reset_n, in_bit, calc_start, load, shift, // inputs
                out_bit; // outputs

  CRC_Calc dut (.*);

  logic [10:0] test = 11'b0100_0000101;

  initial begin
    $monitor ($stime,, "reset_n: %b, in_bit: %b, calc_start: %b, out_bit: %b | remainder: %b",
                        reset_n, in_bit, calc_start, out_bit, dut.pr.D);
    clock = 0;
    reset_n = 0;
    reset_n <= #1 1;
    forever #5 clock = ~clock;
  end

  initial begin
    calc_start <= 1;
    in_bit <= test[0];
    @(posedge clock);
    in_bit <= test[1];
    @(posedge clock);
    in_bit <= test[2];
    @(posedge clock);
    in_bit <= test[3];
    @(posedge clock);

    in_bit <= test[4];
    @(posedge clock);
    in_bit <= test[5];
    @(posedge clock);
    in_bit <= test[6];
    @(posedge clock);
    in_bit <= test[7];
    @(posedge clock);

    in_bit <= test[8];
    @(posedge clock);
    in_bit <= test[9];
    @(posedge clock);
    in_bit <= test[10];
    @(posedge clock); // Message all sent!
    load <= 1;
    calc_start <= 0;
    @(posedge clock); // Remainder ready

    #1 $finish;
  end

endmodule;