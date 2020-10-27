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

#include "tb.h"
#include "vsupport.h"
#include "utility.h"
#include "vobj/Vtb_ob.h"
#include "verilated_vcd_c.h"
#include "gtest/gtest.h"
#ifdef OPT_TRACE_ENABLE
#  include <iostream>
#endif
#include <algorithm>

namespace tb {

Bcd Bcd::from_string(const std::string& s) {
  Bcd b;
  
  std::string::size_type i = s.find('.');

  std::string dollar{s.substr(0, i)};
  for (std::string::size_type i = 0; !dollar.empty(); i++) {
    const char c = dollar.back();
    b.dollars[i] = c - '0';
    dollar.pop_back();
  }
  
  std::string cents{s.substr(i + 1)};
  std::reverse(cents.begin(), cents.end());
  for (std::size_t i = 0; i < cents.size(); i++) {
    b.cents[i] = cents[i] - '0';
  }

  return b;
}

Bcd Bcd::from_packed(vluint32_t p) {
  Bcd b;
  // Cents:
  for (std::size_t i = 0; i < 2; i++) {
    b.cents[i] = (p & utility::mask<vluint32_t>(4));
    p >>= 4;
  }

  // Dollars:
  for (std::size_t i = 0; i < 3; i++) {
    b.dollars[i] = (p & utility::mask<vluint32_t>(4));
    p >>= 4;
  }

  return b;
}

const Bcd Bcd::MAX = Bcd::from_string("999.99");

const Bcd Bcd::MIN = Bcd::from_string("000.00");

Bcd::Bcd() {
  for (std::size_t i = 0; i < 3; i++) {
    dollars [i] = 0x0;
  }
  for (std::size_t i = 0; i < 2; i++) {
    dollars [i] = 0x0;
  }
}

std::string Bcd::to_string() const {
  std::string s;
  if (dollars[2] != 0) {
    s += ('0' + dollars[2]);
  }
  if (!s.empty() || (dollars[1] != 0)) {
    s += ('0' + dollars[1]);
  }
  if (!s.empty() || (dollars[0] != 0)) {
    s += ('0' + dollars[0]);
  }
  s += '.';
  s += ('0' + cents[1]);
  s += ('0' + cents[0]);
  return s;
}

bool Bcd::is_valid() const {
  return (*this != Bcd::MAX) || (*this != Bcd::MIN);
}

vluint32_t Bcd::pack() const {
  vluint32_t r = 0;

  // Dollars
  r |= (dollars[2] & 0xF);
  r <<= 4;
  r |= (dollars[1] & 0xF);
  r <<= 4;
  r |= (dollars[0] & 0xF);
  r <<= 4;

  // Cents
  r |= (cents[1] & 0xF);
  r <<= 4;
  r |= (cents[0] & 0xF);
  r <<= 0;
  
  return r;
}

bool operator==(const Bcd& lhs, const Bcd& rhs) {
  // Compare dollars
  for (std::size_t i = 0; i < 3; i++) {
    if (lhs.dollars[i] != rhs.dollars[i]) {
      return false;
    }
  }

  // Compare cents
  for (std::size_t i = 0; i < 2; i++) {
    if (lhs.cents [i] != rhs.cents [i]) {
      return false;
    }
  }

  return true;
}

bool operator!=(const Bcd& lhs, const Bcd& rhs) {
  return !operator==(lhs, rhs);
}


const char* to_opcode_string(vluint8_t opcode) {
  switch (opcode) {
    case Opcode::Nop: return "Nop";
    case Opcode::QryBidAsk: return "QryBidAsk";
    case Opcode::Buy: return "Buy";
    case Opcode::Sell: return "Sell";
    case Opcode::PopTopBid: return "PopTopBid";
    case Opcode::PopTopAsk: return "PopTopAsk";
    default: return "Invalid";
  }
}

std::string Command::to_string() const {
  using std::to_string;

  utility::KVListRenderer r;
  r.add_field("opcode", to_opcode_string(opcode));
  r.add_field("uid", utility::hex(uid));
  switch (opcode) {
    case Opcode::Buy: {
      r.add_field("quantity", to_string(oprands.buy.quantity));
      const Bcd bcd = Bcd::from_packed(oprands.buy.price);
      r.add_field("price", bcd.to_string());
    } break;
    case Opcode::Sell: {
      r.add_field("quantity", to_string(oprands.sell.quantity));
      const Bcd bcd = Bcd::from_packed(oprands.sell.price);
      r.add_field("price", bcd.to_string());
    } break;
  }
  return r.to_string();
}

const char* to_status_string(vluint8_t status) {
  switch (status) {
    case Status::Okay: return "Okay";
    case Status::Reject: return "Reject";
    case Status::BadPop: return "BadPop";
    default: return "Invalid";
  }
}

std::string Response::to_string() const {
  using std::to_string;

  utility::KVListRenderer r;
  r.add_field("uid", utility::hex(uid));
  r.add_field("status", to_status_string(status));
  return r.to_string();
}

bool operator==(const Response& lhs, const Response& rhs) {
  if (lhs.uid != rhs.uid) return false;
  if (lhs.status != rhs.status) return false;

  return true;
}

bool compare(const Response& lhs, const Response& rhs) {
  EXPECT_EQ(lhs.uid, rhs.uid);
  EXPECT_EQ(lhs.status, rhs.status);

  return (lhs == rhs);
}

vluint64_t VSignals::cycle() const {
  return vsupport::get(tb_cycle);
}

//
void VSignals::set_rsp_accept(bool b) {
  vsupport::set(rsp_accept, b);
}

void VSignals::set_clk(bool b) {
  vsupport::set(clk, b);
}

void VSignals::set_rst(bool b) {
  vsupport::set(rst, b);
}

//
void VSignals::set(const Command& cmd) {
  vsupport::set(cmd_vld_r, cmd.valid);
  vsupport::set(cmd_opcode_r, cmd.opcode);
  vsupport::set(cmd_uid_r, cmd.uid);
  switch (cmd.opcode) {
    case Opcode::Nop: {
    } break;
    case Opcode::QryBidAsk: {
    } break;
    case Opcode::Buy: {
      vsupport::set(cmd_buy_quantity_r, cmd.oprands.buy.quantity);
      vsupport::set(cmd_buy_price_r, cmd.oprands.buy.price);
    } break;
    case Opcode::Sell: {
      vsupport::set(cmd_sell_quantity_r, cmd.oprands.sell.quantity);
      vsupport::set(cmd_sell_price_r, cmd.oprands.sell.price);
    } break;
    default: {
      // Unknown opcode.
    } break;
  }
}

//
bool VSignals::get_cmd_full_r() const {
  return vsupport::get_as_bool(cmd_full_r);
}

bool VSignals::get_clk() const {
  return vsupport::get_as_bool(clk);
}

bool VSignals::get_rst() const {
  return vsupport::get_as_bool(rst);
}

//
void VSignals::get(Response& rsp) {
  rsp.valid = vsupport::get_as_bool(rsp_vld);
  rsp.uid = vsupport::get(rsp_uid);
  rsp.status = vsupport::get(rsp_status);
}

TB::TB(const Options& opts) : opts_(opts) {
#ifdef OPT_VCD_ENABLE
  if (opts.wave_enable) {
    Verilated::traceEverOn(true);
  }
#endif
  u_ = new Vtb_ob;
  vs_ = VSignals::bind(u_);
#ifdef OPT_VCD_ENABLE
  if (opts.wave_enable) {
    wave_ = new VerilatedVcdC;
    u_->trace(wave_, 99);
    wave_->open(opts.wave_name.c_str());
#ifdef OPT_TRACE_ENABLE
    std::cout << "[TB] Dumping to VCD: " << opts.wave_name << "\n";
#endif
  }
#endif
}

TB::~TB() {
  delete u_;
#ifdef OPT_VCD_ENABLE
  if (wave_) {
    wave_->close();
    delete wave_;
  }
#endif
}

void TB::run() {
  cycle_ = 0;
  time_ = 0;

  // Run reset
  reset();

  // Drive interfaces to idle.
  Command cmd;
  vs_.set(cmd);
  
  // Response accept
  vs_.set_rsp_accept(true);

  bool stopped = false;
  while (!stopped) {
    const bool cmd_full_r = vs_.get_cmd_full_r();
    if (!cmd_full_r && !cmds_.empty()) {
      // Apply input command.
      cmd = cmds_.front();
#ifdef OPT_TRACE_ENABLE
      std::cout << "[TB] Issue command: " << cmd.to_string() << "\n";
#endif
      cmds_.pop_front();
    } else {
      // Idle
      cmd.valid = false;
    }
    vs_.set(cmd);

    Response actual;
    vs_.get(actual);
    if (actual.valid) {
#ifdef OPT_TRACE_ENABLE
      std::cout << "[TB] Response received: " << actual.to_string() << "\n";
#endif
      // Must be expected a response.
      ASSERT_FALSE(rsps_.empty());

      const Response expected{rsps_.front()};
      rsps_.pop_front();
      compare(actual, expected);
    }
    step();

    // Stopped when we've received all data.
    stopped = (cmds_.empty() && rsps_.empty());
  }

  // Set interfaces to idle.
  cmd.valid = false;
  vs_.set(cmd);

  // Wind-down simulation
  step(20);
}

void TB::reset() {
  vs_.set_rst(false);
  for (vluint64_t i = 0; i < 20; i++) {
    vs_.set_rst((i > 5) && (i < 15));
    step();
  }
  vs_.set_rst(false);
}

void TB::step(std::size_t n) {
  while (n-- > 0) {
    // !CLK region
    vs_.set_clk(false);
    u_->eval();
#ifdef OPT_VCD_ENABLE
    if (wave_) {
      wave_->dump(time());
    }
#endif
    time_ += 5;

    // CLK region
    vs_.set_clk(true);
    ++cycle_;
    u_->eval();
#ifdef OPT_VCD_ENABLE
    if (wave_) {
      wave_->dump(time());
    }
#endif
    time_ += 5;
  }
}

} // namespace tb
