`default_nettype none
// TODO : NOT SENDING ACK/NAK PROPERLY BECAUSE THEY'RE VERY SHORT PACKETS....

// A special counter that will wrap-around at M
module modCounter
  #(M = 5)
   (input  logic clock, inc, reset_n,
    output logic [3:0] Q);

  always_ff @(posedge clock, negedge reset_n)
    if (~reset_n)
      Q <= 0;
    else if (inc & (Q == M-1))
      Q <= 0;
    else if (inc)
      Q <= Q + 1;
    // else: hold value

endmodule: modCounter

module FIFO  (
  input logic              clock, reset_n,
  input logic  data_in,
  input logic              we, re,
  output logic data_out,
  output logic             full, empty);

  logic [7:0] Q; // Queue of size 8
  logic [3:0] size;

  // Special wrap-around counters for wPtr and rPtr
  logic [3:0] wPtr, rPtr;  // 3-bits for [0,1,2,3,4]
  logic wPtrCnt_inc, rPtrCnt_inc;
  modCounter #(8) wPtrCnt (.inc(wPtrCnt_inc), .Q(wPtr), .*);
  modCounter #(8) rPtrCnt (.inc(rPtrCnt_inc), .Q(rPtr), .*);

  // Increment wPtr and rPtr
  assign wPtrCnt_inc = (we & !(full));
  assign rPtrCnt_inc = (re & !(empty));

  // Combinational, so data_out is always valid (except when buffer is empty)
  assign data_out = Q[rPtr];

  // Status points about the queue
  assign empty = (size == 4'd0);
  assign full = (size == 4'd9);

  // Pseudo FSM-DP to sequentially handle size and data writes
  always_ff @ (posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      size <= 4'd8;
      Q <= 8'b0010_1010;
    end else begin
      if (re & we) begin
        // Read AND write, no need to update size
        Q[wPtr] <= data_in;
      end else if (re & (!empty)) begin
        // Combinational read, update size
        size  <= size - 1;
      end else if (we && (!full)) begin
        // Sequential write, update size
        Q[wPtr] <= data_in;
        size   <= size + 1;
      end
    end
  end

endmodule : FIFO

module DPDM_Encode_FSM
  (input  logic        clock, reset_n,
                       incoming_valid,
   input  logic [31:0] flush_count,
   output logic        re, we, cnt_inc, cnt_clr, out_done,
   output logic  [1:0] eop_index, out_sel); // 0, 1, or 2

  enum logic [2:0] {IDLE, PACKET, FLUSH,
                    EOP_0, EOP_1, EOP_2} currState, nextState;
 
  always_comb begin
    {re, we, cnt_inc, cnt_clr, eop_index, out_sel, out_done} = 9'b0_0000_0000;

    case (currState)
      IDLE: begin
        if (~incoming_valid) begin
          nextState = IDLE;
        end else begin
          out_sel = 2'd1;
          re = 1;
          we = 1;

          nextState = PACKET;
        end
      end

      PACKET : begin
        if (incoming_valid) begin
          out_sel = 2'd1;
          re = 1;
          we = 1;

          nextState = PACKET;
        end else begin
         out_sel = 2'd1;
         re = 1;
         we = 1;
         cnt_clr = 1; // Flush counter clear
         
         nextState = FLUSH; 
        end
      end

      FLUSH : begin
        if (flush_count != 32'd6) begin
          out_sel = 2'd1;
          re = 1; // ONLY READ TO FLUSH OUT
          cnt_inc = 1;

          nextState = FLUSH;
        end else begin
          out_sel = 2'd1;
          re = 1; // ONLY READ TO FLUSH OUT

          nextState = EOP_0;
        end
      end

      EOP_0 : begin
        out_sel = 2'd2;
        eop_index = 2'd0;

        nextState = EOP_1;
      end

      EOP_1 : begin
        out_sel = 2'd2;
        eop_index = 2'd1;

        nextState = EOP_2;
      end

      EOP_2 : begin
        out_sel = 2'd2;
        eop_index = 2'd2;
        out_done = 1; // DONE SENDING THIS ENTIRE PACKET

        nextState = IDLE;
      end

    endcase // currState

  end //always_comb

  always_ff @ (posedge clock, negedge reset_n) begin
    if (~reset_n)
      currState <= IDLE;
    else
      currState <= nextState;
  end

endmodule : DPDM_Encode_FSM

module DPDM_Encode
  (input  logic clock, reset_n,
                nrzi_in_bit, nrzi_sending,
                ph_in_bit, ph_sending,
   output logic DP, DM, out_done);

  // HANDLE NRZI / PH INCOMING 
  logic in_bit, incoming_valid;
  always_comb begin
    {in_bit, incoming_valid} = 2'b00; // defaults

    if (nrzi_sending) begin
      incoming_valid = 1;
      in_bit = nrzi_in_bit;
    end else if (ph_sending) begin
      incoming_valid = 1;
      in_bit = ph_in_bit;
    end

  end

  // assign in_bit = nrzi_in_bit;
  // assign incoming_valid = nrzi_sending;

  // assign in_bit = ph_in_bit;
  // assign incoming_valid = ph_sending;

  // BUFFER TO HOLD INCOMING BITS WHILE WE SEND SYNC
  logic data_out, we, re;
  logic full, empty; // NOT USED
  FIFO buff (.data_in(in_bit), .*);
  //  input logic              clock, reset_n,
  //  input logic data_in,
  //  input logic              we, re,
  //  output logic data_out,
  //  output logic             full, empty);

  // COMB BLOCK TO CONVERT 1 -> J, 0 -> K
  logic [1:0] data_dpdm;
  always_comb begin
    if (data_out)
      data_dpdm = 2'b10;
    else
      data_dpdm = 2'b01;
  end

  // COUNT HOW MANY WE'VE FLUSHED OUT
  logic [31:0] flush_count;
  logic cnt_inc, cnt_clr;
  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      flush_count <= 32'b0;
    end else if (cnt_clr) begin
      flush_count <= 0;
    end else if (cnt_inc) begin
      flush_count <= flush_count + 1;
    end
  end

  // EOP TO SEND OUT
  logic [1:0] eop_index;
  logic [2:0] eop_dpdm;
  always_comb begin
    if (eop_index == 2'd0)
      eop_dpdm = 2'b00;
    else if (eop_index == 2'd1)
      eop_dpdm = 2'b00;
    else // eop_index == 2'd2
      eop_dpdm = 2'b10;
  end

  // MUX THE OUTPUT
  logic [1:0] out_sel;
  always_comb begin
    if (out_sel == 0)
      {DP, DM} = 2'bzz;
    else if (out_sel == 1)
      {DP, DM} = data_dpdm;
    else if (out_sel == 2)
      {DP, DM} = eop_dpdm;
  end

  DPDM_Encode_FSM fsm (.*);
  // (input  logic        clock, reset_n,
  //                      incoming_valid,
  //  input  logic [31:0] flush_count,
  //  output logic        re, we, out_sel, cnt_inc, cnt_clr,
  //  output logic  [1:0] eop_index); // 0, 1, or 2

endmodule : DPDM_Encode