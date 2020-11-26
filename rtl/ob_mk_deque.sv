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
`include "macros_pkg.vh"

module ob_mk_deque #(parameter int N = 8) (

  // ======================================================================== //
  // Clk/Reset
    input                                         cmd_vld
  , input libv_pkg::deque_op_t                    cmd_op
  , input ob_pkg::table_t                         cmd_push_data

  // ======================================================================== //
  // Status
  , output logic                                  head_vld_r
  , output ob_pkg::table_t                        head_r
  //
  , output logic                                  empty_w
  , output logic                                  full_w
  //
  , output ob_pkg::accum_quantity_t               quantity_r

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst
);

  ob_pkg::table_t                       tail_r;

  // ------------------------------------------------------------------------ //
  //
  `LIBV_REG_EN_RST_W(ob_pkg::accum_quantity_t, quantity, '0);
  ob_pkg::quantity_t                    quantity_lhs;
  ob_pkg::accum_quantity_t              quantity_lhs_accum;

  always_comb begin : quantity_PROC

    // Defaults:
    quantity_en = cmd_vld;
    quantity_w  = quantity_r;

    // Compute the overall 'quantity' of tradeable stock in the Market pool
    // based upon the ingress/egress values. A simple low-cost way to determine
    // whether a AON/FOK transaction can complete.
    //
    case (cmd_op)
      libv_pkg::OpPushFront: quantity_lhs = cmd_push_data.quantity;
      libv_pkg::OpPopFront:  quantity_lhs = head_r.quantity;
      libv_pkg::OpPushBack:  quantity_lhs = cmd_push_data.quantity;
      libv_pkg::OpPopBack:   quantity_lhs = tail_r.quantity;
      default:               quantity_lhs = '0;
    endcase // case (cmd_op)

    // Extend:
    quantity_lhs_accum = ob_pkg::accum_quantity_t'(quantity_lhs);

    // Compute update.
    case (cmd_op)
      libv_pkg::OpPushFront,
      libv_pkg::OpPushBack: begin
        // Push, increment count.
        quantity_w = quantity_r + quantity_lhs_accum;
      end
      libv_pkg::OpPopFront,
      libv_pkg::OpPopBack: begin
        // Pop, decrement count.
        quantity_w = quantity_r - quantity_lhs_accum;
      end
      default: begin
        // Retain prior
        quantity_w = quantity_r;
      end
    endcase // case (cmd_op)

  end // block: quantity_PROC

  // ------------------------------------------------------------------------ //
  //
  libv_deque #(.W($bits(ob_pkg::table_t)), .N(N)) u_market_sell (
    //
      .cmd_vld                (cmd_vld                 )
    , .cmd_op                 (cmd_op                  )
    , .cmd_push_data          (cmd_push_data           )
    , .cmd_pop_data           () // UNUSED
    //
    , .head_r                 (head_r                  )
    , .tail_r                 (tail_r                  )
    //
    , .empty_w                (empty_w                 )
    , .full_w                 (full_w                  )
    //
    , .clk                    (clk                     )
    , .rst                    (rst                     )
  );

endmodule // ob_mk_deque
