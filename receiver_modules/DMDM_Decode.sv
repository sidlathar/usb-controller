`default_nettype none

module DPDM_decode_FSM
  (input  logic       clock, reset_n,
                      sync_rec, se0_rec, in_bit, fsm_start,
   input  logic [2:0] PID_rec,          //Ones hot signak for what PID receieve
   output logic       dpdm_sending, ACK_rec, NAK_rec, DATA0_rec,
                      rec_start, load_data);

  enum logic [4:0] {DEAD, WAITSYNC, WAITPID, 
            DATA0_R, EOP0, EOP1, EOP2} currState, nextState;

  // Hard-code PIDs so we can recognize them
  logic [2:0] ACK_PID, NAK_PID, DATA0_PID;
  assign ACK_PID = 3'b001;
  assign NAK_PID = 3'b010;
  assign DATA0_PID = 3'b100;

  logic [2:0] pkt_pid;  // Temporary hold for PID_rec

  always_comb begin
    {dpdm_sending, ACK_rec, NAK_rec, DATA0_rec, rec_start,
     load_data} = 6'b0000_00;

    case (currState)

      DEAD: begin
        if(~fsm_start) begin

          nextState = DEAD;
        end else begin
          rec_start = 1;

          nextState = WAITSYNC;
        end
      end

      WAITSYNC: begin  //WAIT FOR SYNC TO PASS
        if(~sync_rec) begin
          nextState = WAITSYNC;
        end else begin
          nextState = WAITPID;
        end
      end

      WAITPID: begin   //REGISTER THE PID RECEIVED
        if(PID_rec == 3'b000) begin 
          nextState = WAITPID;
        end else if (PID_rec == ACK_PID) begin 
          pkt_pid = ACK_PID;

          nextState = EOP0;
        end else if (PID_rec == NAK_PID) begin 
          pkt_pid = NAK_PID;

          nextState = EOP0;
        end else if (PID_rec == DATA0_PID) begin 
          dpdm_sending = 1;
          pkt_pid = DATA0_PID;

          nextState = DATA0_R;
        end
      end


      DATA0_R: begin  //SEND DATA0 FOR DECODING
        if (se0_rec) begin  //STARTED RECEIVING EOP
          load_data = 1;

          nextState = EOP0;
        end else begin 
          dpdm_sending = 1;

          nextState = DATA0_R;
        end
      end

      EOP0: begin
        if (se0_rec)

          nextState = EOP1;
      end

      EOP1: begin
        if (in_bit) 

          nextState = EOP2;
      end

      EOP2: begin  // ASSERT SIGNALS BASED ON WHAT PACKET WAS RECEIEVD
        case (pkt_pid) 
          3'b001: ACK_rec = 1;
          3'b010: NAK_rec = 1;
          3'b100: DATA0_rec = 1;
        endcase

        nextState  = DEAD;
      end
    endcase
  end

  always_ff @ (posedge clock, negedge reset_n) begin
    if (~reset_n)
      currState <= DEAD;
    else
      currState <= nextState;
  end

endmodule : DPDM_decode_FSM

module DPDM_decode(
  input  logic clock, reset_n,
               DP_in, DM_in, host_sending,
  output logic out_bit, dpdm_sending, rec_start, load_data,
               ACK_rec, NAK_rec, DATA0_rec);

  logic sync_rec, se0_rec, load_matchReg, clr_cnt, fsm_start;
  logic [2:0] PID_rec;
  logic [7:0] match_val; //REGISTER TO HOLD 8 INCOMING BITS AT A TIME TO...
                          //...MATCH AGAINST HARD CODED PIDS AND SYNC

  DPDM_decode_FSM fsm (.in_bit(out_bit), .*);

  //MATCHREG REGISTER
  SIPO_Register_Right matchReg (.D(out_bit), .load(load_matchReg), 
                  .Q(match_val),  .*); 

    //host_sending tells if sender side is sending messege
    always_comb begin
      if ((host_sending) || (DP_in === 1'bz && DM_in === 1'bz)) begin
        fsm_start = 0;
      end else begin
        fsm_start = 1;
      end
    end

  always_ff @(posedge clock, negedge reset_n) begin // LOADING FOR MATCHREG 
    if(~reset_n) begin
      load_matchReg <= 0;
    end else begin
      load_matchReg <= 1;
    end
  end

  always_comb begin //ASSIGN OUT BIT BASED ON DP, DM
    {out_bit, se0_rec} = 2'bz0;
    case({DP_in, DM_in})
      2'b10 : out_bit = 1'b1;
      2'b01 : out_bit = 1'b0;
      2'b00 : begin
              out_bit = 1'bz;
              se0_rec = 1'b1;
      end
      2'bzz : out_bit = 1'bz;
    endcase
  end

  always_comb begin //HARDCODED PIDS
    {PID_rec,sync_rec} = 4'b0000;
    case (match_val)
      8'b0010_1010: sync_rec = 1;  //SYNC
      8'b0001_1011: PID_rec = 3'b001;  //ACK
      8'b0110_0011: PID_rec = 3'b010; //NAK
      8'b0001_0100: PID_rec = 3'b100; //DATA0
    endcase
  end

endmodule: DPDM_decode