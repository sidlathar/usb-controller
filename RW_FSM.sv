`default_nettype none

module RW_FSM
  (input  logic clock, reset_n,
  // Inputs from USBHost
   input  logic        DP_in, DM_in, read_start, write_start,
   input  logic [15:0] write_mempage, read_mempage,
   input  logic [63:0] write_data,
  // Outputs to USBHost
   output logic DP_out, DM_out, sending, finished, read_success, write_success,
   output logic [63:0] read_data);

  /*************************** DATAPATH COMPONENTS  ***************************/

  logic [63:0] read_addr, write_addr;
  assign write_addr = {write_mempage, 48'd0};
  assign read_addr = {read_mempage, 48'd0};

  // Mux which endp to send to PH_Sender
  logic [3:0] out_endp;
  logic endp_sel; // 0 -> 4'd4, 1 -> 4'd8
  always_comb begin
    out_endp = 4'dx; // Default to X's
    if (endp_sel)
      out_endp = 4'd8;
    else
      out_endp = 4'd4;
  end

  // Mux which data to send to PH_Sender
  logic [63:0] out_data;
  logic [1:0] out_data_sel; // 0 -> read_addr, 1 -> write_addr, 2 -> write_data
  always_comb begin
    out_data = 64'dx; // Default to X's
    case (out_data_sel)
      2'd0 : out_data = read_addr;
      2'd1 : out_data = write_addr;
      2'd2 : out_data = write_data;
    endcase // out_data_sel
  end // always_comb

  // Instantiate PH_Sender module
  logic send_OUT, send_IN, send_DATA0, send_ACK, send_NAK; // Inputs
  logic sent; // Outputs
  PH_Sender sender (.endp(out_endp), .data(out_data), .send_OUT(send_OUT), .*);
  //   (input  logic        clock, reset_n,
  //                        send_OUT, send_IN, send_DATA0, send_ACK, send_NAK,
  //    input  logic  [3:0] endp,  // If we need it for OUT or IN
  //    input  logic [63:0] data,  // If we need it for DATA0
  //    output logic        DP_out, DM_out, sent);

  // Instantiate PH_Receiver module
  logic rec_ACK, rec_NAK, rec_DATA0; // Outputs
  logic [63:0] data_rec;             // Outputs
  logic data_valid, rec_start;       // Outputs (all outputs, just listening)
  PH_Receiver rec (.host_sending(sending), .data_rec(read_data), .*);
  // (input logic clock, reset_n, host_sending, DP_in, DM_in,
  // output logic rec_ACK, rec_NAK, rec_DATA0,
  // output logic [63:0] data_rec, 
  // output logic data_valid, rec_start); //TO READ WRITE FSM

  // Instantiate OUT_Trans module
  logic out_trans_start,
        out_sending, out_trans_done, out_trans_success, out_trans_failure;
  OUT_Trans out (.start(out_trans_start), .sending(out_sending),
                 .done(out_trans_done), .success(out_trans_success),
                 .failure(out_trans_failure),
                 .send_OUT(send_OUT),
                 .send_DATA0(send_DATA0), .*);
  // (input  logic clock, reset_n,
  // // RW_FSM signals
  // input  logic        start,
  // output logic        sending, done, success, failure
  // // PH_Sender signals
  // input  logic sent,
  // output logic send_OUT, send_DATA0,
  // // PH_Receiver signals
  // input  logic rec_ACK, rec_NAK, rec_start);

  // Instantiate IN_Trans module
  logic in_trans_start,
        in_sending, in_trans_done, in_trans_success, in_trans_failure;
  IN_Trans in (.start(in_trans_start), .sending(in_sending),
               .done(in_trans_done), .success(in_trans_success),
               .failure(in_trans_failure), .*);
  // (input  logic clock, reset_n,
  // // RW_FSM signals
  // input  logic        start,
  // output logic        sending, done, success, failure
  // // PH_Sender signals
  // input  logic sent,
  // output logic send_IN, send_ACK, send_NAK,
  // // PH_Receiver signals
  // input  logic        rec_DATA0, data_valid, rec_start,
  // input  logic [63:0] data_rec);


  // SENDING SIGNAL (WHENEVER DP/DM IS BEING DRIVEN BY US, THE SENDER)
  assign sending = (out_sending || in_sending);


  /*********************************** FSM ***********************************/

  enum logic [2:0] {IDLE,
                    READ_OUT_ADDR, READ_IN_DATA,
                    WRITE_OUT_ADDR, WRITE_OUT_DATA} currState, nextState;

  // Output and NS logic
  always_comb begin
    {read_success, write_success, out_trans_start, in_trans_start,
     endp_sel, out_data_sel, finished} = 7'b0;

     nextState = currState;

    case (currState)
      IDLE: begin
        if (~read_start && ~write_start) begin
          nextState = IDLE;
        end else if (read_start) begin
          out_trans_start = 1;
          endp_sel = 0; // endp = 4
          out_data_sel = 2'd0; // data = read_addr

          nextState = READ_OUT_ADDR;
        end else if (write_start) begin
          out_trans_start = 1;
          endp_sel = 0; //endp = 4
          out_data_sel = 2'd1; // data = write_addr

          nextState = WRITE_OUT_ADDR;
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
          endp_sel = 1;

          nextState = READ_IN_DATA;
        end else if (out_trans_failure) begin
          // OUT transaction failed
          finished = 1;

          nextState = IDLE;
        end
      end

      READ_IN_DATA : begin
        if (~in_trans_done) begin
          // IN transaction working
          nextState = READ_IN_DATA;
        end else if (in_trans_success) begin
          // IN transaction succeeded
          finished = 1;
          read_success = 1;

          nextState = IDLE;
        end else if (in_trans_failure) begin
          // IN transaction failed
          finished = 1;

          nextState = IDLE;
        end
      end

      /**************************** "WRITE" BEGIN ****************************/
      WRITE_OUT_ADDR : begin
        if (~out_trans_done) begin
          // OUT transaction working
          nextState = WRITE_OUT_ADDR;
        end else if (out_trans_success) begin
          // OUT transaction succeeded
          out_trans_start = 1;
          endp_sel = 1; //endp = 8
          out_data_sel = 2'd2; // data = write_data

          nextState = WRITE_OUT_DATA;
        end else if (out_trans_failure) begin
          // OUT transaction failed
          finished = 1;

          nextState = IDLE;
        end
      end

      WRITE_OUT_DATA : begin
          if (~out_trans_done) begin
            // OUT transaction working
            nextState = WRITE_OUT_DATA;
          end else if (out_trans_success) begin
            // OUT transaction succeeded
            write_success = 1;
            finished = 1;

            nextState = IDLE;
          end else if (out_trans_failure) begin
            // OUT transaction failed
            finished = 1;

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