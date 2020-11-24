// ==================================================================== //
// Copyright (c) 2020, Stephen Henry
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// * Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
//
// * Redistributions in binary form must reproduce the above copyright
//   notice, this list of conditions and the following disclaimer in
//   the documentation and/or other materials provided with the
//   distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
// OF THE POSSIBILITY OF SUCH DAMAGE.
// ==================================================================== //

`include "macros_pkg.vh"
`include "libv_pkg.vh"

module libv_deque #(
   // Word width in bits
   parameter integer W = 32

   // Number of words in the deque
 , parameter integer N = 8

) (

   //======================================================================== //
   //                                                                         //
   // Misc.                                                                   //
   //                                                                         //
   //======================================================================== //

     input                                   clk
   , input                                   rst

   //======================================================================== //
   //                                                                         //
   // Command Interface                                                       //
   //                                                                         //
   //======================================================================== //

   , input                                   cmd_vld
   , input libv_pkg::cmd_t                   cmd_op
   , input [W - 1:0]                         cmd_push_data

   , output logic [W - 1:0]                  cmd_pop_data

   //======================================================================== //
   //                                                                         //
   // Status Interface                                                        //
   //                                                                         //
   //======================================================================== //

   , output logic                            empty_w
   , output logic                            full_w
);

  // ======================================================================== //
  //                                                                          //
  // Wires                                                                    //
  //                                                                          //
  // ======================================================================== //

  // Memory address type.
  typedef logic [$clog2(N) - 1:0]       addr_t;

  // Memory pointer type.
  typedef struct packed {
    logic                 w;
    addr_t                a;
  } ptr_t;

  `LIBV_REG_EN_RST(ptr_t, head_ptr);
  `LIBV_REG_EN_RST(ptr_t, tail_ptr);
  addr_t                   wr_ptr;
  addr_t                   rd_ptr;

  //
  logic [N - 1:0][W - 1:0] mem_r;
  logic                    mem_en;

  //
  logic                    mem_upt;

  //
  logic                    head_ptr_inc;
  logic                    head_ptr_dec;

  //
  logic                    tail_ptr_inc;
  logic                    tail_ptr_dec;

  // ======================================================================== //
  //                                                                          //
  // Logic                                                                    //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  always_comb begin : cntrl_PROC

    // Defaults:

    // Head pointer:
    head_ptr_inc = 'b0;
    head_ptr_dec = 'b0;

    // Tail pointer:
    tail_ptr_inc = 'b0;
    tail_ptr_dec = 'b0;

    // Memory update
    mem_upt      = 'b1;

    case (cmd_op)
      libv_pkg::PushFront: begin
        mem_upt      = 'b1;
        head_ptr_inc = 'b1;
      end
      libv_pkg::PopFront: begin
        head_ptr_dec = 'b1;
      end
      libv_pkg::PushBack: begin
        mem_upt      = 'b1;
        tail_ptr_dec = 'b1;
      end
      libv_pkg::PopBack: begin
        tail_ptr_inc = 'b1;
      end
    endcase // case (cmd)

    mem_en = mem_upt & cmd_vld;

  end // block: ptr_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb begin : ptr_PROC

    // Update head on increment/decrement
    head_ptr_en = cmd_vld & (head_ptr_inc | head_ptr_dec);

    // Update next
    case ({head_ptr_inc, head_ptr_dec})
      2'b10:   head_ptr_w = head_ptr_r + 'b1;
      2'b01:   head_ptr_w = head_ptr_r - 'b1;
      default: head_ptr_w = head_ptr_r;
    endcase // case ({head_ptr_inc, head_ptr_dec})


    // Update tail on increment/decrement
    tail_ptr_en = cmd_vld & (tail_ptr_inc | tail_ptr_dec);

    // Tail next
    case ({tail_ptr_inc, tail_ptr_dec})
      2'b10:   tail_ptr_w = tail_ptr_r + 'b1;
      2'b01:   tail_ptr_w = tail_ptr_r - 'b1;
      default: tail_ptr_w = tail_ptr_r;
    endcase // case ({tail_ptr_inc, tail_ptr_dec})

    // Write pointer is next head/tail pointer on current op.
    wr_ptr = (cmd_op == libv_pkg::PushFront) ? head_ptr_w.a : tail_ptr_w.a;

    // Read pointer is head/tail pointer on current op.
    rd_ptr = (cmd_op == libv_pkg::PopFront) ? head_ptr_r.a : tail_ptr_r.a;

  end // block: ptr_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb begin : flags_PROC

    // Dequeue becomes empty when read-/write- pointers are equal
    empty_w = (head_ptr_w == tail_ptr_w);

    // Dequeue becomes full when read-/write- pointers wraparound.
    full_w  = (head_ptr_w.w ^ tail_ptr_w.w) & (head_ptr_w.a == tail_ptr_w.a);

  end // block: flags_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb cmd_pop_data = mem_r [rd_ptr];

  // ======================================================================== //
  //                                                                          //
  // Flops                                                                    //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk)
    if (mem_en)
      mem_r [wr_ptr] <= cmd_push_data;

endmodule // libv_deque
