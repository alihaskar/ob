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

`default_nettype none
`timescale 1ns/1ps

`include "ob_pkg.vh"
`include "bcd_pkg.vh"
`include "macros_pkg.vh"

module ob_lm_table #(parameter int N = 16, parameter bit is_ask = 'b1) (

  // ======================================================================== //
  // Head Status
    input                                         head_pop
  //
  , input                                         head_upt
  , input ob_pkg::table_t                         head_upt_tbl

  , output logic                                  head_vld_r
  , output logic                                  head_did_update_r
  , output ob_pkg::table_t                        head_r

  // ======================================================================== //
  // Control Interface
  , input                                         insert
  , input ob_pkg::table_t                         insert_tbl

  // ======================================================================== //
  // Cancel UID Interface
  , input                                         cancel
  , input ob_pkg::uid_t                           cancel_uid
  //
  , output logic                                  cancel_hit_w
  , output ob_pkg::table_t                        cancel_hit_tbl_w

  // ======================================================================== //
  // Reject Interface
  , input                                         reject_pop

  , output logic                                  reject_vld_r
  , output ob_pkg::table_t                        reject_r

  // ======================================================================== //
  // Query Interface
  , input                                         qry_vld
  , input bcd_pkg::price_t                        qry_price
  , input ob_pkg::quantity_t                      qry_quantity
  //
  , output logic                                  qry_rsp_vld_r
  , output logic                                  qry_rsp_is_ge_r
  , output ob_pkg::accum_quantity_t               qry_rsp_qty_r

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst
);

  // ======================================================================== //
  //                                                                          //
  // Parameterizations                                                        //
  //                                                                          //
  // ======================================================================== //

  //
  localparam bcd_pkg::price_t INVALID_PRICE =
     is_ask ? bcd_pkg::PRICE_MAX : bcd_pkg::PRICE_MIN;

  // ======================================================================== //
  //                                                                          //
  // Helper functions                                                         //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  function automatic ob_pkg::table_t mux(
    logic [N:0] sel, ob_pkg::table_t [N:0] tbl); begin
    mux   = '0;
    for (int i = 0; i < N + 1; i++)
      if (sel[i])
        mux |= tbl [i];
  end endfunction

  function automatic logic price_compare(bcd_pkg::price_t x,
					 bcd_pkg::price_t t); begin
    return is_ask ? (x < t) : (x > t);
  end endfunction

  function automatic logic [N:0] pri(logic [N:0] x, bit lsb = 'b0); begin
    pri = '0;
    if (lsb) begin
      for (int i = 0; i < N + 1; i++) begin
        if (x[i])
          pri  = ('b1 << i);
      end
    end else begin
      for (int i = N; i >= 0; i--) begin
        if (x[i])
          pri  = ('b1 << i);
      end
    end
  end endfunction

  function automatic logic [N:0] mask(
    logic [N:0] x, bit inclusive = 'b1, bit lsb = 'b0); begin
    mask = 'b0;
    if (lsb) begin
      // Towards LSB; MSB -> LSB
      logic mask_enable  = 'b0;
      for (int i = N; i >= 0; i--) begin
        if (i == N)
          mask[i]  = (inclusive & x[i]);
        else
          mask[i]  = (inclusive & x[i]) | mask_enable;

        mask_enable |= x[i];
      end
    end else begin
      // Towards MSB; MSB <- LSB
      logic mask_enable  = 'b0;
      for (int i = 0; i <= N; i++) begin
        if (i == 0)
          mask[i]  = (inclusive & x[i]);
        else
          mask[i]  = (inclusive & x[i]) | mask_enable;

        mask_enable |= x[i];
      end
    end
  end endfunction // mask


  // ======================================================================== //
  //                                                                          //
  // Table state                                                              //
  //                                                                          //
  // ======================================================================== //

  // is_ask == 'b0; Buy-Table; order entries such that greatest are at head.
  // is_ask == 'b1; Ask-Table; order entries such that smallest are at head.

  // Table ordered according to is_ask/!is_ask: Nth entry is the head
  // entry, the zeroth entry is the reject.
  ob_pkg::table_t [N:0]                 tbl_r;
  ob_pkg::table_t [N:0]                 tbl_w;
  logic [N:0]                           tbl_en;
  `LIBV_REG_RST(logic [N:0], tbl_vld, '0);

  // ======================================================================== //
  //                                                                          //
  // Combinatorial                                                            //
  //                                                                          //
  // ======================================================================== //


  // ------------------------------------------------------------------------ //
  //
  logic [N:0]                           insert_match_d;
  logic [N:0]                           insert_match_sel_d;

  always_comb begin : insert_PROC

    // Compare unary mask locating the entries within the table
    // greater than/less than the price to be inserted.
    insert_match_d      = '0;
    for (int i = 0; i < N + 1; i++) begin
      insert_match_d [i]  =
        insert & price_compare(insert_tbl.price, tbl_r [i].price);
    end

    // Derive one-hot mask dennoting the location into which the insert
    // item is to be placed. This operation constitutes the critical
    // path through the table.
    insert_match_sel_d  = pri(insert_match_d, .lsb('b1));

  end // block: insert_PROC


  // ------------------------------------------------------------------------ //
  //
  logic [N:0]                           cancel_match_uid_d;
  logic [N:0]                           cancel_match_uid_mask_d;

  always_comb begin : cancel_PROC

    // Form 1-hot bit-vector containing entries which match the
    // current UID (UID should be unique therefore the match count
    // should equal 1 or 0; multiple matches may not take place).
    //
    cancel_match_uid_d   = '0;
    for (int i = 0; i < N + 1; i++) begin
      cancel_match_uid_d [i]  = tbl_vld_r [i] & (cancel_uid ==  tbl_r [i].uid);
    end

    // A hit on a cancel operation has occurred.
    cancel_hit_w            = cancel & (cancel_match_uid_d != 'b0);

    // Mux nominanted table entry as output.
    cancel_hit_tbl_w        = cancel ? mux(cancel_match_uid_d, tbl_r) : '0;

    // Form mask such that table entries preceeding current hit vector
    // are shifted up, to account for the canceld entry.
    cancel_match_uid_mask_d =
      cancel ?  mask(cancel_match_uid_d, .inclusive('b1), .lsb('b1)) : '0;

  end // block: cancel_PROC


  // ------------------------------------------------------------------------ //
  //
  logic [N:0]                           tbl_pop_head_d;

  always_comb begin : head_pop_PROC

    // On pop of head, all entries in the table are shifted up.
    tbl_pop_head_d = head_pop ? '1 : '0;

  end // block: head_pop_PROC


  // ------------------------------------------------------------------------ //
  //
  logic [N:0]                           tbl_install_d;
  logic [N:0]                           tbl_shift_up_d;
  logic [N:0]                           tbl_shift_dn_d;

  always_comb begin : t_op_PROC

    // Relative to head

    // One-hot mask denoting the location in the table where an entry is
    // to be inserted.
    //
    tbl_install_d   = (insert_match_sel_d);

    // Unary mask denoting the locations to be shifted upwards (towards the
    // MSB) in response to a pop or cancel operation.
    //
    tbl_shift_up_d  = (cancel_match_uid_mask_d | tbl_pop_head_d);

    // Unary mask denoting the locations to be shifted downwards (towards
    // the LSB) in reponse to a insert operation.
    //
    tbl_shift_dn_d  = mask(insert_match_sel_d, .inclusive('b0), .lsb('b1));

  end // block: t_op_PROC


  // ------------------------------------------------------------------------ //
  //
  always_comb begin : tbl_update_PROC

    // Defaults:
    tbl_en         = 'b0;
    tbl_w          = tbl_r;


    // Head entry (N-th); current bid-/ask- state.
    //

    // Enable head update on install or shift into operation.
    tbl_en [N]     = (tbl_install_d [N] |  tbl_shift_up_d [N - 1] | head_upt);

    // Head value update (unique, no priority)
    unique case  ({// Controller writes the head.
                   head_upt,
                   // New entry is installed in the head.
                   tbl_install_d [N],
                   // Prior table entry becomes head.
                   tbl_shift_up_d [N]
                   }) inside
      3'b1??:  tbl_w [N]  = head_upt_tbl;
      3'b01?:  tbl_w [N]  = insert_tbl;
      3'b001:  tbl_w [N]  = tbl_r [N - 1];
      default: tbl_w [N]  = tbl_r [N];
    endcase

    // Head is value whenver next value contains a valid price.
    tbl_vld_w [N]  = (tbl_w [N].price != INVALID_PRICE);

    // Table entries [N - 1: 1]; those contained within the table.
    //
    for (int i = N - 1; i > 0; i--) begin

      // Enable update when data moves into entry.
      tbl_en [i]  =
        (tbl_install_d [i] | tbl_shift_up_d [i] | tbl_shift_dn_d [i]);

      // Next state (unique, no priority)
      unique case  ({// Install new entry at current location
                     tbl_install_d [i],
                     // Shift entry up
                     tbl_shift_up_d [i],
                     // Shift entry down
                     tbl_shift_dn_d [i]
                     }) inside
        3'b1??: begin
          // Install new state
          tbl_w [i]  = insert_tbl;
        end
        3'b01?: begin
          // Next is value below current.
          tbl_w [i]  = tbl_r [i - 1];
        end
        3'b001: begin
          // Next is value above current.
          tbl_w [i]  = tbl_r [i + 1];
        end
        default: begin
          // Retain prior
          tbl_w [i]  = tbl_r [i];
        end
      endcase

      // Valid when next price is valid.
      tbl_vld_w [i] = (tbl_w [i].price != INVALID_PRICE);

      end // for (int i = 0; i < N; i++)

    // Tail entry (zeroth); reject entry: (unique, no priority)
    tbl_en [0] 	    =
      (tbl_install_d [0] | tbl_shift_up_d [0] | tbl_shift_dn_d [0] | reject_pop);

    unique case  ({// Install entry into reject (incoming command is
                   // immediately rejected by the table).
                   tbl_install_d [0],
                   // Shift Up; reject buffer is cleared
                   tbl_shift_up_d [0],
                   // Shift Down; last entry in table is rejected.
                   tbl_shift_dn_d [0],
                   // Controller removes reject entry.
                   reject_pop
                   }) inside
      4'b1???: begin
        tbl_w [0]        = insert_tbl;
      end
      4'b01??: begin
        tbl_w [0]        = tbl_r [0];
        tbl_w [0].price  = INVALID_PRICE;
      end
      4'b001?: begin
        tbl_w [0]        = tbl_r [1];
      end
      4'b0001: begin
        tbl_w [0]        = tbl_r [0];
        tbl_w [0].price  = INVALID_PRICE;
      end
      default: begin
        // Retain prior value.
        tbl_w [0]        = tbl_r [0];
      end
    endcase // case ({tbl_install_d [0]})

    // Entry is valid whenever it contains a price which is valid.
    tbl_vld_w [0]  = (tbl_w [0].price != INVALID_PRICE);

  end // block: tbl_update_PROC


  // ------------------------------------------------------------------------ //
  //
  `LIBV_REG_RST_W(logic, head_vld, 'b0);
  `LIBV_REG_EN_W(ob_pkg::table_t, head);
  `LIBV_REG_RST_W(logic, head_did_update, 'b0);

  always_comb begin : head_PROC

    // Head value was updated in the current cycle (to take effect in
    // the subsequent cycle).
    head_did_update_w  = tbl_en [N];

    // Head flop enable.
    head_en            = head_did_update_w;

    // Zeroth entry is the head
    head_w             = tbl_w [N];

    // Head value becomes valid.
    head_vld_w         =
      head_did_update_w ? (head_w.price != INVALID_PRICE) : head_vld_r;

  end // block: head_PROC


  // ------------------------------------------------------------------------ //
  //
  `LIBV_REG_RST_W(logic, reject_vld, 'b0);
  `LIBV_REG_EN_W(ob_pkg::table_t, reject);

  always_comb begin : reject_PROC

    // Reject valid whenever a valid price is inserted into the reject
    // slot of the table, otherwise retain.
    reject_vld_w =
      tbl_en [0] ? (tbl_w [0].price != INVALID_PRICE) : reject_vld_r;

    // Output reject latch.
    reject_en 	 = reject_vld_w;
    reject_w 	   = tbl_w [0];

  end // block: reject_PROC

  // ------------------------------------------------------------------------ //
  //
  logic                                 cnt_cmd_vld;
  bcd_pkg::price_t                      cnt_cmd_price;
  ob_pkg::quantity_t                    cnt_cmd_quantity;
  logic                                 cnt_rsp_attained_w;
  ob_pkg::accum_quantity_t              cnt_rsp_quantity_w;
  logic                                 cnt_rsp_en;
  `LIBV_REG_RST(logic, cnt_cmd_busy, 'b0);
  `LIBV_REG_RST_W(logic, qry_rsp_vld, 'b0);
  `LIBV_REG_EN_W(logic, qry_rsp_is_ge);
  `LIBV_REG_EN_W(ob_pkg::accum_quantity_t, qry_rsp_qty);

  always_comb begin : qry_PROC

    // Issue command to counter controller.
    cnt_cmd_vld      = qry_vld;
    cnt_cmd_price    = qry_price;
    cnt_cmd_quantity = qry_quantity;

    // Latch response from counter controller.
    case ({qry_vld, cnt_cmd_busy_r, cnt_cmd_busy_w}) inside
      3'b1_??: qry_rsp_vld_w = 'b0;
      3'b0_10: qry_rsp_vld_w = 'b1;
      default: qry_rsp_vld_w = qry_rsp_vld_r;
    endcase // case ({qry_vld, cnt_cmd_busy_r, cnt_cmd_busy_w})

    // Latch response on the output of the busy state.
    cnt_rsp_en       = cnt_cmd_busy_r & (~cnt_cmd_busy_w);

    qry_rsp_is_ge_en = cnt_rsp_en;
    qry_rsp_is_ge_w  = cnt_rsp_attained_w;
    qry_rsp_qty_en   = cnt_rsp_en;
    qry_rsp_qty_w    = cnt_rsp_quantity_w;

  end // block: qry_PROC

  // ======================================================================== //
  //                                                                          //
  // Flops                                                                    //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk) begin : t_FLOP
    if (rst) begin
      for (int i = 0; i < N + 1; i++)
	      tbl_r [i] <= is_ask ? ob_pkg::TABLE_ASK_INIT : ob_pkg::TABLE_BID_INIT;
    end else begin
      for (int i = 0; i < N + 1; i++)
	      if (tbl_en [i])
	        tbl_r [i] <= tbl_w [i];
    end
  end // block: t_FLOP

  // ======================================================================== //
  //                                                                          //
  // Instances                                                                //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  ob_lm_table_cnt #(.N(N), .is_ask(is_ask)) u_lm_table_cnt (
    //
      .cmd_vld                     (cnt_cmd_vld             )
    , .cmd_price                   (cnt_cmd_price           )
    , .cmd_quantity                (cnt_cmd_quantity        )
    //
    , .rsp_attained_w              (cnt_rsp_attained_w      )
    , .rsp_quantity_w              (cnt_rsp_quantity_w      )
    //
    , .tbl_r                       (tbl_r                   )
    , .tbl_vld_r                   (tbl_vld_r               )
    //
    , .busy_w                      (cnt_cmd_busy_w          )
    //
    , .clk                         (clk                     )
    , .rst                         (rst                     )
  );

endmodule // ob_table
