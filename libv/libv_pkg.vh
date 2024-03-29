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

`ifndef OB_LIBV_LIBV_PKG_VH
`define OB_LIBV_LIBV_PKG_VH

package libv_pkg;

  // Deque commands
  typedef enum logic [1:0] { OpPushFront = 2'b00,
                             OpPopFront = 2'b01,
                             OpPushBack = 2'b10,
                             OpPopBack = 2'b11
                             } deque_op_t;

  function automatic int max(int a, int b); begin
    return (a < b) ? b : a;
  end endfunction

  function automatic int ceil(int n, int d); begin
    ceil = 0;
    while (n > 0) begin
      ceil += 1;
      n    -= d;
    end
  end endfunction

  typedef enum logic [1:0] { CSA_3_2 = 'b00, // 3:2 compressor
                             CSA_7_2 = 'b01,  // 7:2 compressor
                             CSA_INFER = 'b11 // Inferred sum.
                             } csa_op_t;

endpackage // libv_pkg

`endif
