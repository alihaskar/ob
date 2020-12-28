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
  , output logic                                  busy_r
  , output logic                                  mtr_r
  //
  , output ob_pkg::cmd_t                          cmd_r

  // ======================================================================== //
  // Machine state
  //
  , input                                         cntrl_evt_texe_r
  //
  , input                                         lm_bid_table_vld_r
  , input ob_pkg::table_t                         lm_bid_table_r
  //
  , input                                         lm_ask_table_vld_r
  , input ob_pkg::table_t                         lm_ask_table_r

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst
);

  // ------------------------------------------------------------------------ //
  //
  logic                                 dp_price_le;
  logic                                 dp_price_ge;

  always_comb begin : fsm_dp_PROC

    dp_price_le  = (cmd_r.price <= lm_bid_table_r.price);

    dp_price_ge  = (cmd_r.price >= lm_ask_table_r.price);

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
  `LIBV_REG_EN_RST(fsm_state_enc_t, fsm_state, FSM_IDLE);

  always_comb begin : fsm_PROC

    // Defaults:
    cmd_en       = 'b0;
    cmd_w        = cmd_r;

    fsm_state_en = 'b0;
    fsm_state_w  = fsm_state_r;

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
            // Buy Stop Loss/Limit matures whenever the market price for
            // the current security becomes lower than the current watching
            // price.
            fsm_state_en = cntrl_evt_texe_r & lm_bid_table_vld_r & dp_price_le;
          end
          ob_pkg::Op_SellStopLoss,
          ob_pkg::Op_SellStopLimit: begin
            // Sell Stop Loss/Limit matures whenever the market price for the
            // current security becomes greater than the current watching price
            // (should probably check whether these definitions are indeed accurate).
            fsm_state_en = cntrl_evt_texe_r & lm_ask_table_vld_r & dp_price_ge;
          end
          default: begin
            // Otherwise, error: invalid command and should not have been
            // dispatched the this conditional entry machine.
            fsm_state_en = 'b0;
          end
        endcase // case (fsm_cmd_r.opcode)

        // Transition to matured state.
        fsm_state_w = FSM_MATURED;
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

    // FSM is busy
    busy_r = fsm_state_r.busy;

    // FSM entry has matured.
    mtr_r  = fsm_state_r.matured;

  end // block: fsm_PROC

endmodule // ob_cn_table_entry