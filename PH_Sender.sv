`default_nettype none

module SendPIDtoDPDM_FSM
  (input  logic clock, reset_n,
   input  logic start,
   input  logic [2:0] bit_cnt,
   output logic shift, ph_sending, cnt_clr, cnt_inc);

  enum logic {IDLE, SEND} currState, nextState;

  always_comb begin
    {shift, ph_sending, cnt_clr, cnt_inc} = 4'b0000; // defaults

    case (currState)
      IDLE : begin
        if (~start) begin
          nextState = IDLE;
        end else begin
          cnt_clr = 1;
          ph_sending = 1;
        end
      end

      SEND : begin
        if (bit_cnt != 3'd7) begin
          shift = 1;
          cnt_inc = 1;
          ph_sending = 1;

          nextState = SEND;
        end else begin
          nextState = IDLE;
        end
      end
    endcase // currState

  end

  always_ff @(posedge clock, negedge reset_n) begin
    if (reset_n) begin
      currState <= IDLE;
    end else begin
      currState <= nextState;
    end
  end

endmodule : SendPIDtoDPDM_FSM

module PH_Sender
  (input  logic        clock, reset_n,
                       send_OUT, send_IN, send_DATA0, send_ACK, send_NAK,
   input  logic  [3:0] endp,  // If we need it for OUT or IN
   input  logic [63:0] data,  // If we need it for DATA0
   output logic        DP_out, DM_out, out_done);

  // HARD-CODED PIDS
  logic [7:0] out_pid, in_pid, data0_pid, ack_pid, nak_pid;
  always_comb begin
    out_pid = 8'b1110_0001;
    in_pid = 8'b0110_1001;
    data0_pid = 8'b1100_0011;
    ack_pid = 8'b1101_0010;
    nak_pid = 8'b0101_1010;
  end

  /*********************** OUT/IN PREPARATION FOR CRC5  ***********************/
  logic [6:0] addr;
  assign addr = 7'd5; // addr is always 5

  logic [18:0] crc5_pkt_in;
  logic crc5_pkt_ready;
  always_comb begin
    {crc5_pkt_in} = 24'bx; // default

    // NOTE: FINE TO BE COMB, B/C CRC MODULES LOAD INTO REGISTER
    if (send_OUT) begin
      crc5_pkt_in = {endp, addr, out_pid};
    end else if (send_IN) begin
      crc5_pkt_in = {endp, addr, in_pid};
    end

    crc5_pkt_ready = (send_OUT || send_IN);
  end // always_comb

  /*********************** DATA0 PREPARATION FOR CRC16  ***********************/
  logic [71:0] crc16_pkt_in;
  logic crc16_pkt_ready;
  assign crc16_pkt_in = {data, data0_pid};
  assign crc16_pkt_ready = send_DATA0;

  /******************* ACK/NAK PREPARATION FOR DPDM_ENCODER *******************/
  logic [7:0] dpdm_pid;
  always_comb begin
    dpdm_pid = 8'bx; // default
    if (send_ACK)
      dpdm_pid = ack_pid;
    else if (send_NAK)
      dpdm_pid = nak_pid;
  end

  // PISO register to hold the ACK/NAK PID
  logic load, shift, ph_out_bit;
  assign load = (send_ACK || send_NAK);
  // PISO_Register_Right dut (.*);
  PISO_Register_Right #(8) pid_reg (.D(dpdm_pid), .Q(ph_out_bit),
                                .load(load), .shift(shift),
                                .*);

  // Counter for how many PID bits we've sent to DPDM
  logic cnt_inc, cnt_clr;
  logic [2:0] bit_cnt;
  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      bit_cnt <= 3'd0;
    end else if (cnt_clr) begin
      bit_cnt <= 3'd0;
    end else begin
      bit_cnt <= bit_cnt + 1;
    end
  end

  // FSM to send PID to DPDM
  logic start, ph_sending;
  assign start = (send_ACK || send_NAK);
  SendPIDtoDPDM_FSM fsm (.shift(shift), .*);
  //   (input  logic clock, reset_n,
  //    input  logic start,
  //    output logic shift, ph_sending);

  /************************** MODULE INSTANTIATION  **************************/

  // CRC 5 and CRC 16 MODULE INSTANTIATION
  logic bs_ready, // input from BitStuffer
        crc5_out_bit, crc5_valid_out,
        crc16_out_bit, crc16_valid_out; // output to BitStuffer
  CRC5_Encode   crc5 (.pkt_in(crc5_pkt_in), .pkt_ready(crc5_pkt_ready),
                    .out_bit(crc5_out_bit), .crc_valid_out(crc5_valid_out),
                    .*);
  // (input  logic clock, reset_n,
  //               pkt_ready,     // PH ready to send us a packet
  //               bs_ready,      // BS ready to receive bits
  //  input  logic [18:0] pkt_in, // orig packet from protocol handler
  //  output logic out_bit,       // bit going to BS
  //               crc_valid_out);  // telling BS we are sending bits
  CRC16_Encode crc16 (.pkt_in(crc16_pkt_in), .pkt_ready(crc16_pkt_ready),
                    .out_bit(crc16_out_bit), .crc_valid_out(crc16_valid_out),
                    .*);

  // BITSTUFFER MODULE INSTANTIATION
  logic bs_out_bit, bs_sending;
  BS_Encode bs (.crc5_valid_out(crc5_valid_out),
                 .crc5_in_bit(crc5_out_bit),
                 .crc16_valid_out(crc16_valid_out),
                 .crc16_in_bit(crc16_out_bit),
                 .out_bit(bs_out_bit), .*);
  // (input  logic clock, reset_n,
  //               crc5_valid_out, crc5_in_bit,
  //               crc16_valid_out, crc16_in_bit,                
  //  output logic out_bit, bs_ready, bs_sending);

  // NRZI MODULE INSTANTIATION
  logic nrzi_out_bit, nrzi_sending;
  NRZI_Encode nrzi (.in_bit(bs_out_bit), .out_bit(nrzi_out_bit), .*);
  // (input logic clock, reset_n,
  //              in_bit, bs_sending,
  //  output logic out_bit, nrzi_sending);

  // DPDM MODULE INSTANTIATION
  DPDM_Encode dpdm (
             .nrzi_in_bit(nrzi_out_bit), .nrzi_sending(nrzi_sending),
             .ph_in_bit(ph_out_bit), .ph_sending(ph_sending),
             .DP(DP_out), .DM(DM_out), .out_done(out_done), .*);
  // (input  logic clock, reset_n,
  //               nrzi_in_bit, nrzi_sending,
  //               ph_in_bit, ph_sending,
  //  output logic DP, DM, out_done);

endmodule : PH_Sender