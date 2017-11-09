`default_nettype none

module RW_FSM
  (input  logic clock, reset_n,
  // Inputs from USBHost
   input  logic        read_start, write_start,
   input  logic [15:0] write_mempage, read_mempage,
   input  logic [63:0] write_data
  // Outputs from USBHost
   output logic read_success, write_success,
   output logic [63:0] read_data);

  /*************************** DATAPATH COMPONENTS  ***************************/
  
  logic [63:0] read_addr, write_addr;
  assign write_addr = {write_mempage, 48'd0};
  assign read_addr = {read_mempage, 48'd0};

  // Mux which endp to send to OUT_Trans
  logic out_endp_sel; // 0 -> 4'd4, 1 -> 4'd8
  assign out_endp = (out_endp_sel) ? 4'd8 : 4'd4;

  // Mux which data to send to OUT_Trans
  logic [1:0] out_data_sel; // 0 -> read_addr, 1 -> write_addr, 2 -> write_data
  always_comb begin
    data = 64'dx; // Default to X's
    unique case (out_data_sel)
      2'd0 : data = read_addr;
      2'd1 : data = write_addr;
      2'd2 : data = write_data;
    endcase // out_data_sel
  end // always_comb

  // Instantiate OUT_Trans moudle
  logic        out_trans_start; // Input into OUT_Trans
  logic  [3:0] out_endp;        // Input into OUT_Trans (address = 4, data = 8)
  logic [63:0] out_data;        // Input into OUT_Trans (address or data)
  logic        out_trans_done, out_trans_success, out_trans_failure; // Outputs
  OUT_Trans out (.*);

  // Instantiate IN_Trans moudle
  logic        in_trans_start; // Input into IN_Trans
  logic        in_trans_done, in_trans_success, in_trans_failure; // Outputs
  IN_Trans in (.*);

  /*********************************** FSM ***********************************/

  enum logic [2:0] {IDLE,
                    READ_OUT_ADDR, READ_IN_DATA,
                    WRITE_OUT_ADDR, WRITE_OUT_DATA} currState, nextState;

  // Output and NS logic
  always_comb begin
    {read_success, write_success} = 2'b00;

    case (currState)
      IDLE: begin
        if (~read_start && ~write_start) begin
          nextState = IDLE;
        end else if (read_start) begin
          out_trans_start = 1;
          out_endp_sel = 0; // endp = 4
          out_data_sel = 2'd0; // data = read_addr

          nextState = READ_OUT_ADDR
        end else if (write_start) begin
          out_trans_start = 1;
          out_endp_sel = 0; //endp = 4
          out_data_sel = 2'd1; // data = write_addr

          nextState = WRITE_OUT_ADDR
        end
      end

      /**************************** "READ" BEGIN  ****************************/
      READ_OUT_ADDR : begin
        if (~out_trans_done) begin
          // OUT transaction working
          nextState = READ_OUT_ADDR;
        end else if (out_trans_success) begin
          // OUT transaction succeeded
          in_trans_start = 1;

          nextState = READ_IN_DATA
        end else if (out_trans_failure) begin
          // OUT transaction failed
          nextState = IDLE;
        end
      end

      READ_IN_DATA : begin
        if (~in_trans_done) begin
          // IN transaction working
          nextState = READ_IN_DATA;
        end else if (in_trans_success) begin
          // IN transaction succeeded
          read_success = 1;

          nextState = IDLE;
        end else if (in_trans_failure) begin
          // IN transaction failed
          nextState = IDLE;
        end
      end

      /**************************** "WRITE" BEGIN ****************************/
      WRITE_OUT_ADDR : begin
          // OUT transaction working
          nextState = WRITE_OUT_ADDR;
        end else if (out_trans_success) begin
          // OUT transaction succeeded
          out_endp_sel = 8; //endp = 1
          out_data_sel = 2'd2 // data = write_data

          nextState = WRITE_OUT_DATA;
        end else if (out_trans_failure) begin
          // OUT transaction failed
          nextState = IDLE;
      end

      WRITE_OUT_DATA : begin
          if (~in_trans_done) begin
            // OUT transaction working
            nextState = WRITE_OUT_DATA;
          end else if (in_trans_success) begin
            // OUT transaction succeeded
            write_success = 1;

            nextState = IDLE;
          end else if (in_trans_failure) begin
            // OUT transaction failed
            nextState = IDLE;
          end
        end

    endcase // currState

  end

  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      currState <= IDLE;
    end else begin
      currState <= nextState;
    end
  end

endmodule : RW_FSM