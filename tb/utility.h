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

#ifndef M_TB_UTILITY_H
#define M_TB_UTILITY_H

#include "verilated.h"
#include <vector>
#include <utility>
#include <sstream>

namespace tb::utility {

template<typename T>
T mask(std::size_t n) {
  if (sizeof(T) * 8 == n) return ~0;

  return (static_cast<T>(1) << n) - 1;
}

// Helper to convert some 'T' into hexadecimal representation.
template<typename T>
std::string hex(const T & t) {
  std::stringstream ss;
  ss << "0x" << std::hex << static_cast<vluint64_t>(t);
  return ss.str();
}

//
class KVListRenderer {
  using kv_type = std::pair<std::string, std::string>;

 public:
  KVListRenderer() = default;

  //
  std::string to_string() const;

  //
  void add_field(const std::string& key, const std::string& value);

 private:
  // Key/Value pairs
  std::vector<kv_type> kvs_;
};

const char* to_string(bool b);

} // namespace tb::utility

#endif
