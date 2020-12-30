//========================================================================== //
// Copyright (c) 2020, Stephen Henry
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice, this
//   list of conditions and the following disclaimer.
//
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//========================================================================== //

`include "ob_pkg.vh"
`include "libv_pkg.vh"

module ob_cn_table_entry (
  // ======================================================================== //
  // Allocation
    input                                         al_vld
  , input ob_pkg::cmd_t                           al_cmd_r
  //
  , input                                         dl_vld
  //
  , output logic                                  busy_w
  , output logic                                  mtr_vld_w
  //
  , output ob_pkg::cmd_t                          cmd_r

  // ======================================================================== //
  // Machine state
  //
  , input                                         cntrl_evt_texe_r
  , input bcd_pkg::price_t                        cntrl_evt_texe_ask_r
  , input bcd_pkg::price_t                        cntrl_evt_texe_bid_r

  // ======================================================================== //
  // Cancel Interface
  , input                                         cancel
  , input ob_pkg::uid_t                           cancel_uid
  //
  , output logic                                  cancel_hit

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst
);

  // ------------------------------------------------------------------------ //
  //
  logic                                 dp_ask_le;
  logic                                 dp_bid_ge;

  always_comb begin : fsm_dp_PROC

    // Conditional price has fallen below the current asking price.
    //
    dp_ask_le  = (cmd_r.price1 >= cntrl_evt_texe_ask_r);

    // Conditional price has risen above the current bidding price.
    dp_bid_ge  = (cmd_r.price1 <= cntrl_evt_texe_bid_r);

  end // block: fsm_dp_PROC

  // ------------------------------------------------------------------------ //
  //
  typedef struct packed {
    // FSM is busy
    logic        busy;
    // Current operating state.
    logic        matured;
  } fsm_state_enc_t;

  typedef enum   logic [1:0] { FSM_IDLE    = 2'b0_0,
                               FSM_ACTIVE  = 2'b1_0,
                               FSM_MATURED = 2'b1_1
                               } fsm_state_t;

  `LIBV_REG_EN_W(ob_pkg::cmd_t, cmd);
  fsm_state_enc_t                       fsm_state_upt;
  `LIBV_REG_EN_RST(fsm_state_enc_t, fsm_state, FSM_IDLE);

  always_comb begin : fsm_PROC

    // Defaults:
    cmd_en       = 'b0;
    cmd_w        = cmd_r;

    fsm_state_en = 'b0;
    fsm_state_w  = fsm_state_r;

    case (cancel_hit) inside
      1'b1: begin
        // On cancel operation, transition back to the IDLE state.
        fsm_state_en = 'b1;
        fsm_state_w  = FSM_IDLE;
      end
      default: begin
        // Otherwise, proceed with normal FSM operation.

        case (fsm_state_r)
          FSM_IDLE: begin
            if (al_vld) begin
              // Allocation valid, transition to ACTIVE state and latch command.
              cmd_en       = 'b1;
              cmd_w        = al_cmd_r;

              // Machine becomes active.
              fsm_state_en = 'b1;
              fsm_state_w  = FSM_ACTIVE;
            end
          end
          FSM_ACTIVE: begin

            case (cmd_r.opcode)
              ob_pkg::Op_BuyStopLoss,
              ob_pkg::Op_BuyStopLimit: begin
                // BuyStop{Loss,Limit} Matures whenever the asking price falls below
                // the watch value.
                fsm_state_en = cntrl_evt_texe_r & dp_ask_le;
              end
              ob_pkg::Op_SellStopLoss,
              ob_pkg::Op_SellStopLimit: begin
                // Sell Stop Loss/Limit matures whenever the market price for the
                // current security becomes greater than the current watching price
                // (should probably check whether these definitions are indeed accurate).
                fsm_state_en = cntrl_evt_texe_r & dp_bid_ge;
              end
              default: begin
                // Otherwise, error: invalid command and should not have been
                // dispatched the this conditional entry machine.
                fsm_state_en = 'b0;
              end
            endcase // case (fsm_cmd_r.opcode)

            // As the command matures, it permutes from the "Stop" order to the
            // corresponding Market/Limit Order
            case (cmd_r.opcode)
              ob_pkg::Op_BuyStopLoss: begin
                // Op_BuyStopLess -> Op_BuyMarket
                cmd_w.opcode = ob_pkg::Op_BuyMarket;
              end
              ob_pkg::Op_SellStopLoss: begin
                // Op_SellStopLess -> Op_SellMarket
                cmd_w.opcode = ob_pkg::Op_SellMarket;
              end
              ob_pkg::Op_BuyStopLimit: begin
                // Op_BuyStopLimit -> Op_BuyLimit
                cmd_w.opcode = ob_pkg::Op_BuyLimit;
              end
              ob_pkg::Op_SellStopLimit: begin
                // Op_SellStopLimit -> Op_SellLimit
                cmd_w.opcode = ob_pkg::Op_SellLimit;
              end
              default: begin
                // Otherwise, error: Unknown command is present in entry.
              end
            endcase

            // Update command.
            cmd_en      = fsm_state_en;
            fsm_state_w = fsm_state_en ? FSM_MATURED : fsm_state_r;
            // Transition to matured state.
          end
          FSM_MATURED: begin
            if (dl_vld) begin
              // Deallocation valid, return to IDLE state.
              fsm_state_en = 'b1;
              fsm_state_w  = FSM_IDLE;
            end
          end
          default: begin
          end
        endcase // case (fsm_state_r)
      end // case: default
    endcase // case (cancel_hit)

    // FSM is busy
    busy_w    = fsm_state_w.busy;

    // FSM entry has matured.
    mtr_vld_w = fsm_state_w.matured;

  end // block: fsm_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb begin : cancel_PROC

    case (fsm_state_r)
      FSM_IDLE: begin
        cancel_hit = cancel & al_vld & (al_cmd_r.uid == cancel_uid);
      end
      FSM_ACTIVE,
      FSM_MATURED: begin
        cancel_hit = cancel & (cmd_r.uid == cancel_uid);
      end
      default: begin
        cancel_hit = 'b0;
      end
    endcase // case (fsm_state_r)

  end // block: cancel_PROC

endmodule // ob_cn_table_entry
