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

`ifndef OB_RTL_COMMON_MACROS_PKG_VH
`define OB_RTL_COMMON_MACROS_PKG_VH

`define LIBV_REG(__type, __name)\
__type __name``_r;\
__type __name``_w;\
always_ff @(posedge clk) \
  __name``_r <= __name``_w

`define LIBV_REG_R(__type, __name)\
  __type __name``_r;\
  always_ff @(posedge clk) \
  __name``_r <= __name``_w

`define LIBV_REG_W(__type, __name)\
  __type __name``_w;\
  always_ff @(posedge clk) \
  __name``_r <= __name``_w

`define LIBV_REG_N(__type, __name, __n)\
  __type [(__n) - 1:0] __name``_r;\
  __type [(__n) - 1:0] __name``_w;\
  always_ff @(posedge clk) \
  for (int i = 0; i < (__n); i++)\
  __name``_r [i] <= __name``_w [i]

`define LIBV_REG_RST(__type, __name, __reset = 'b0)\
  __type __name``_r;\
  __type __name``_w;\
  always_ff @(posedge clk) \
  if (rst)\
  __name``_r <= __reset;\
  else\
  __name``_r <= __name``_w

`define LIBV_REG_RST_R(__type, __name, __reset = 'b0)\
  __type __name``_r;\
  always_ff @(posedge clk) \
  if (rst)\
  __name``_r <= __reset;\
  else\
  __name``_r <= __name``_w

`define LIBV_REG_RST_W(__type, __name, __reset = 'b0)\
  __type __name``_w;\
  always_ff @(posedge clk) \
  if (rst)\
  __name``_r <= __reset;\
  else\
  __name``_r <= __name``_w

`define LIBV_REG_EN(__type, __name)\
  __type __name``_r;\
  __type __name``_w;\
  logic  __name``_en;\
  always_ff @(posedge clk) \
  if (__name``_en)\
  __name``_r <= __name``_w

`define LIBV_REG_EN_R(__type, __name)\
  __type __name``_r;\
  logic  __name``_en;\
  always_ff @(posedge clk) \
  if (__name``_en)\
  __name``_r <= __name``_w

`define LIBV_REG_EN_W(__type, __name)\
  __type __name``_w;\
  logic  __name``_en;\
  always_ff @(posedge clk) \
  if (__name``_en)\
  __name``_r <= __name``_w

`define LIBV_REG_EN_N(__type, __name, __n)\
  __type [(__n)-1:0] __name``_r;\
  __type [(__n)-1:0] __name``_w;\
  logic [(__n)-1:0] __name``_en;\
  always_ff @(posedge clk) \
  for (int i = 0; i < __n; i++)\
  if (__name``_en [i])\
  __name``_r [i] <= __name``_w [i]

`define LIBV_REG_EN_N_R(__type, __name, __n)\
  __type [(__n)-1:0] __name``_r;\
  logic [(__n)-1:0] __name``_en;\
  always_ff @(posedge clk) \
  for (int i = 0; i < __n; i++)\
  if (__name``_en [i])\
  __name``_r [i] <= __name``_w [i]

`define LIBV_REG_EN_N_W(__type, __name, __n)\
  __type [(__n)-1:0] __name``_w;\
  logic [(__n)-1:0] __name``_en;\
  always_ff @(posedge clk) \
  for (int i = 0; i < __n; i++)\
  if (__name``_en [i])\
  __name``_r [i] <= __name``_w [i]

`define LIBV_REG_EN_RST(__type, __name, __reset = 'b0)\
  __type __name``_r;\
  __type __name``_w;\
  logic              __name``_en;\
  always_ff @(posedge clk) \
  if (rst)\
  __name``_r <= __reset;\
  else\
  if (__name``_en)\
  __name``_r <= __name``_w

`define LIBV_REG_EN_RST_R(__type, __name, __reset = 'b0)\
  __type __name``_r;\
  logic              __name``_en;\
  always_ff @(posedge clk) \
  if (rst)\
  __name``_r <= __reset;\
  else\
  if (__name``_en)\
  __name``_r <= __name``_w

`define LIBV_REG_EN_RST_W(__type, __name, __reset = 'b0)\
  __type __name``_w;\
  logic              __name``_en;\
  always_ff @(posedge clk) \
  if (rst)\
  __name``_r <= __reset;\
  else\
  if (__name``_en)\
  __name``_r <= __name``_w

`define LIBV_REG_EN_RST_N(__type, __name, __n, __reset = 'b0)\
  __type [(__n)-1:0] __name``_r;\
  __type [(__n)-1:0] __name``_w;\
  logic  [(__n)-1:0] __name``_en;\
  always_ff @(posedge clk)\
    if (rst)\
      for (int i = 0; i < __n; i++)\
        __name``_r [i] <= __type'(__reset);\
    else\
      for (int i = 0; i < __n; i++)\
        if (__name``_en [i])\
          __name``_r [i] <= __name``_w [i]

`define LIBV_CREATE_ENCODE_DECODE(__etype, __dtype)\
  function __dtype decode_``__etype (__etype in); begin\
    return ('b1 << in);\
  end endfunction\
  function __etype encode_``__dtype (__dtype in); begin\
    encode_``__dtype  = '0;\
    for (int i = $bits(__dtype) - 1; i >= 0; i--) begin\
      if (in [i])\
        encode_``__dtype  = __etype'(i);\
    end\
    return encode_``__dtype;\
  end endfunction

`define LIBV_QUEUE_WIRES(__prefix, __data_type)\
  logic              __prefix``push;\
  __data_type        __prefix``push_data;\
  logic              __prefix``pop;\
  __data_type        __prefix``pop_data;\
  logic              __prefix``flush;\
  logic              __prefix``commit;\
  logic              __prefix``replay;\
  logic              __prefix``empty_w;\
  logic              __prefix``full_w

`endif
