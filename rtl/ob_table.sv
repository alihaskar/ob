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
`include "bcd_pkg.vh"

module ob_table #(parameter int N = 16, parameter bit is_ask = 'b1) (

  // ======================================================================== //
  // Head Status
    output logic                                  head_vld_r
  , output ob_pkg::table_t                        head_r

  // ======================================================================== //
  // Install Interface
  , input                                         install_vld
  , input ob_pkg::table_t                         install

  // ======================================================================== //
  // Reject Interface
  , input                                         reject_pop

  , output logic                                  reject_valid_r
  , output ob_pkg::table_t                        reject_r

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst
);

  // is_ask == 'b0; Buy-Table; order entries such that greatest are at head.
  // is_ask == 'b1; Ask-Table; order entries such that smallest are at head.

  // Table ordered according to is_ask/!is_ask: zeroth entry is the head
  // entry, the Nth entry is the reject.
  ob_pkg::table_t [N:0]                 t_r;
  ob_pkg::table_t [N:0]                 t_w;
  logic [N:0]                           t_en;

  // ------------------------------------------------------------------------ //
  //
  function logic price_compare(bcd_pkg::price_t x,
			       bcd_pkg::price_t t); begin
    return is_ask ? (x < t) : (x > t);
  end endfunction

  function logic [N:0] lzd(logic [N:0] x); begin
    lzd = '0;
    for (int i = N; i >= 0; i--)
      if (x [i])
	lzd = 'b1 << i;
  end endfunction

  logic [N:0]                           match;
  
  always_comb begin : match_PROC

    match      = '0;
    for (int i = 0; i < N + 1; i++) begin
      match [i] = price_compare(install.price, t_r [i].price);
    end

  end // block: match_PROC
  
  // ------------------------------------------------------------------------ //
  //
  always_comb begin : t_PROC

    // Defaults:
    t_en = 'b0;
    t_w  = t_r;


  end // block: t_PROC

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk) begin : t_FLOP
    if (rst) begin
      for (int i = 0; i < N + 1; i++)
	t_r [i] <= is_ask ? ob_pkg::TABLE_ASK_INIT : ob_pkg::TABLE_BID_INIT;
    end else begin
      for (int i = 0; i < N + 1; i++)
	if (t_en [i])
	  t_r [i] <= t_w [i];
    end
  end // block: t_FLOP

endmodule // ob_table
