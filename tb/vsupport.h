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

#ifndef PA_VERIF_RUNTIME_VSUPPORT_H
#define PA_VERIF_RUNTIME_VSUPPORT_H

#include "verilated.h"

namespace vsupport {

template <typename T>
constexpr T mask(std::size_t bits) {
  static_assert(sizeof(T) <= 8);
  if (bits == 64) return static_cast<T>(0xFFFFFFFFFFFFFFFF);
  return static_cast<T>((1ull << bits) - 1);
}

void set(vluint8_t* v, bool b);

template<typename T>
void set(T* v, T t) { *v = t; }

template<typename T, std::size_t N>
void set(T* t, const T (&u)[N]) {
  for (std::size_t i = 0; i < N; i++) {
    t[i] = u[i];
  }
}

template<typename T>
T get(const T* t) { return *t; }

template<typename T, std::size_t N>
void get(T (&t)[N], const T* v) {
  for (std::size_t i = 0; i < N; i++) {
    t[i] = v[i];
  }
}


bool get_as_bool(const vluint8_t* v);

// Clean type 't' such that only 'bits' bits are set. Verilator requires
// that bits outside of the valid range are set to zero for correctness.
//
template<typename T> void clean(T* t, std::size_t bits = 1) {
  // Otherwise, apply mask
  constexpr std::size_t type_bits = sizeof(T) * 8;
  while (bits > type_bits) {
    t++;
    bits -= type_bits;
  }
  // TODO: check for overflow
  *t &= mask<T>(bits);
}

} // namespace vsupport

#endif
