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
#include <cstdio>

namespace tb {

void Random::init(unsigned seed) {
#ifdef OPT_LOGGING_ENABLE
  std::cout << "[RND] seed set to " << seed << "\n";
#endif
  mt_ = std::mt19937{seed};
}

bool Random::boolean(double true_prob) {
  std::bernoulli_distribution d(true_prob);
  return d(mt_);
}

std::string to_bcd_string(double d) {
  static char c[128];
  snprintf(c, 128, "%.2f", d);
  return std::string(c);
}

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
  if ((*this == Bcd::MAX) || (*this == Bcd::MIN)) {
    return false;
  }
  for (std::size_t i = 0; i < 3; i++) {
    if (dollars[i] > 9) return false;
  }
  for (std::size_t i = 0; i < 2; i++) {
    if (cents[i] > 9) return false;
  }
  return true;
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
    case Opcode::Cancel: return "Cancel";
    default: return "Invalid";
  }
}

std::string Command::to_string() const {
  using std::to_string;

  utility::KVListRenderer r;
  r.add_field("uid", utility::hex(uid));
  r.add_field("opcode", to_opcode_string(opcode));
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
    case Opcode::Cancel: {
      r.add_field("cancel_uid", utility::hex(oprands.cancel.uid));
    } break;
  }
  return r.to_string();
}

const char* to_status_string(vluint8_t status) {
  switch (status) {
    case Status::Okay: return "Okay";
    case Status::Reject: return "Reject";
    case Status::CancelHit: return "CancelHit";
    case Status::CancelMiss: return "CancelMiss";
    case Status::Bad: return "Bad";
    case Status::BadPop: return "BadPop";
    default: return "Invalid";
  }
}

std::string Response::to_string(vluint8_t opcode) const {
  using std::to_string;

  utility::KVListRenderer r;
  r.add_field("uid", utility::hex(uid));
  r.add_field("status", to_status_string(status));
  if (uid == 0xFFFFFFFF) {
    // Trade
    r.add_field("op", "trade");
    r.add_field("bid_uid", utility::hex(result.trade.bid_uid));
    r.add_field("ask_uid", utility::hex(result.trade.ask_uid));
    r.add_field("quantity", to_string(result.trade.quantity));
  } else {
    switch (opcode) {
      case Opcode::QryBidAsk: {
        r.add_field("op", to_opcode_string(opcode));
        r.add_field("bid", to_string(result.qrybidask.bid));
        r.add_field("ask", to_string(result.qrybidask.ask));
      } break;
      case Opcode::PopTopBid:
      case Opcode::PopTopAsk: {
        const Bcd price = Bcd::from_packed(result.poptop.price);
        r.add_field("op", to_opcode_string(opcode));
        r.add_field("price", price.to_string());
        r.add_field("quantity", to_string(result.poptop.quantity));
        r.add_field("uid", utility::hex(uid));
      } break;
    }
  }
  return r.to_string();
}

bool operator==(const Response& lhs, const Response& rhs) {
  if (lhs.uid != rhs.uid) return false;
  if (lhs.status != rhs.status) return false;

  return true;
}

bool compare(vluint8_t opcode, const Response& actual, const Response& expected) {
  EXPECT_EQ(actual.uid, expected.uid);
  EXPECT_EQ(actual.status, expected.status) <<
      " Expected: " << to_status_string(expected.status) <<
      " Actual: " << to_status_string(actual.status);
  if (actual.uid == 0xFFFFFFFF) {
    // Trade
    EXPECT_EQ(actual.result.trade.bid_uid, expected.result.trade.bid_uid);
    EXPECT_EQ(actual.result.trade.ask_uid, expected.result.trade.ask_uid);
    EXPECT_EQ(actual.result.trade.quantity, expected.result.trade.quantity);
  } else {
    // Some operation
    switch (opcode) {
      case Opcode::QryBidAsk: {
      } break;
      case Opcode::PopTopBid:
      case Opcode::PopTopAsk: {
      } break;
    }
  }

  return (actual == expected);
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
    case Opcode::Cancel: {
      vsupport::set(cmd_cancel_uid_r, cmd.oprands.cancel.uid);
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
  rsp.result.trade.bid_uid = vsupport::get(rsp_trade_bid_uid);
  rsp.result.trade.ask_uid = vsupport::get(rsp_trade_ask_uid);
  rsp.result.trade.quantity = vsupport::get(rsp_trade_quantity);
  rsp.result.qrybidask.bid = vsupport::get(rsp_qry_bid);
  rsp.result.qrybidask.ask = vsupport::get(rsp_qry_ask);
  rsp.result.poptop.price = vsupport::get(rsp_pop_price);
  rsp.result.poptop.quantity = vsupport::get(rsp_pop_quantity);
  rsp.result.poptop.uid = vsupport::get(rsp_pop_uid);
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

  std::map<vluint32_t, vluint8_t> uid_to_op;
  bool stopped = false;
  while (!stopped) {
    const bool cmd_full_r = vs_.get_cmd_full_r();
    if (!cmd_full_r && !cmds_.empty()) {
      // Apply input command.
      cmd = cmds_.front();
      uid_to_op.insert(std::make_pair(cmd.uid, cmd.opcode));
#ifdef OPT_TRACE_ENABLE
      if (opts_.trace_enable) {
        std::cout << "[TB] " << vs_.cycle()
                  << " ;Issue command: " << cmd.to_string() << "\n";
      }
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
      // Must be expected a response.
      ASSERT_FALSE(rsps_.empty());

      const Response expected{rsps_.front()};
      rsps_.pop_front();

      vluint8_t opcode = 0;
      if (auto it = uid_to_op.find(actual.uid); it != uid_to_op.end()) {
        // Got opcode, now able to render.
        opcode = it->second;
        uid_to_op.erase(it);
      } else if (actual.uid != 0xFFFFFFFF) {
#ifdef OPT_TRACE_ENABLE
        // Disregards controller materialized responses.
        std::cout << "[TB] " << vs_.cycle()
                  << " ; Unknown UID received: " << actual.uid << "\n";
#endif
      }
#ifdef OPT_TRACE_ENABLE
      if (opts_.trace_enable) {
        std::cout << "[TB] " << vs_.cycle()
                  << " ; Response received: " << expected.to_string(opcode) << "\n";
      }
#endif
      compare(opcode, actual, expected);
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

bool operator==(const Entry& lhs, const Entry& rhs) {
  if (lhs.uid != rhs.uid) return false;
  if (lhs.quantity != rhs.quantity) return false;
  if (lhs.price != rhs.price) return false;

  return true;
}

class UidFinder {
 public:
  UidFinder(vluint32_t uid)
      : uid_(uid)
  {}

  vluint32_t uid() const { return uid_; }

  bool operator()(const Entry& e) const {
    return e.uid == uid_;
  }

 private:
  vluint32_t uid_;
};

class AskComparer {
 public:
  AskComparer() = default;

  bool operator()(const Entry& lhs, const Entry& rhs) const {
    return lhs.price < rhs.price;
  }
};

class BidComparer {
 public:
  BidComparer() = default;

  bool operator()(const Entry& lhs, const Entry& rhs) const {
    return lhs.price > rhs.price;
  }
};

Model::Model(std::size_t bid_n, std::size_t ask_n)
    : bid_n_(bid_n), ask_n_(ask_n)
{}

bool Model::can_execute(const Command& cmd) const {
  // Commands can always be sunk.
  return true;
}

void Model::apply(const Command& cmd, std::vector<Response>& rsps) {

  if (!cmd.valid) {
    // No command, return
    return;
  }

  Response rsp;
  switch (cmd.opcode) {
    case Opcode::Nop: {
      rsp.valid = true;
      rsp.uid = cmd.uid;
      rsp.status = Status::Okay;
      rsps.push_back(rsp);
    } break;
    case Opcode::QryBidAsk: {
      rsp.valid = true;
      rsp.uid = cmd.uid;
      rsp.status = Status::Okay;
      if (bid_table_.empty() || ask_table_.empty()) {
        // Either table is unpopulated therefore command cannot complete.
        rsp.status = Status::Bad;
      }
      rsps.push_back(rsp);
    } break;
    case Opcode::Buy: {
      // Command executes, therefore emit response
      rsp.valid = true;
      rsp.uid = cmd.uid;
      rsp.status = Status::Okay;
      rsps.push_back(rsp);
      
      Entry e;
      e.uid = cmd.uid;
      e.quantity = cmd.oprands.buy.quantity;
      e.price = cmd.oprands.buy.price;
      bid_table_.push_back(e);
      std::stable_sort(bid_table_.begin(), bid_table_.end(), BidComparer{});
      
      while (attempt_trade(rsp)) {
        rsps.push_back(rsp);
      }
      if (bid_table_.size() > bid_n_) {
        // Issue reject
        const Entry& reject = bid_table_.back();
        rsp.valid = true;
        rsp.uid = reject.uid;
        rsp.status = Status::Reject;
        rsps.push_back(rsp);

        bid_table_.pop_back();
      }
    } break;
    case Opcode::Sell: {
      // Command executes, therefore emit response
      rsp.valid = true;
      rsp.uid = cmd.uid;
      rsp.status = Status::Okay;
      rsps.push_back(rsp);
      
      Entry e;
      e.uid = cmd.uid;
      e.quantity = cmd.oprands.sell.quantity;
      e.price = cmd.oprands.sell.price;
      ask_table_.push_back(e);
      std::stable_sort(ask_table_.begin(), ask_table_.end(), AskComparer{});
      
      while (attempt_trade(rsp)) {
        rsps.push_back(rsp);
      }
      if (bid_table_.size() > bid_n_) {
        // Issue reject
        const Entry& reject = ask_table_.back();
        rsp.valid = true;
        rsp.uid = reject.uid;
        rsp.status = Status::Reject;
        rsps.push_back(rsp);

        ask_table_.pop_back();
      }
    } break;
    case Opcode::PopTopBid: {
      rsp.valid = true;
      rsp.uid = cmd.uid;
      rsp.status = Status::BadPop;
      if (!bid_table_.empty()) {
        const Entry& e = bid_table_.front();
        rsp.status = Status::Okay;
        rsp.result.poptop.price = e.price;
        rsp.result.poptop.quantity = e.quantity;
        rsp.result.poptop.uid = e.uid;
        bid_table_.erase(bid_table_.begin());
      }
      rsps.push_back(rsp);
    } break;
    case Opcode::PopTopAsk: {
      rsp.valid = true;
      rsp.uid = cmd.uid;
      rsp.status = Status::BadPop;
      if (!ask_table_.empty()) {
        const Entry& e = ask_table_.front();
        rsp.status = Status::Okay;
        rsp.result.poptop.price = e.price;
        rsp.result.poptop.quantity = e.quantity;
        rsp.result.poptop.uid = e.uid;
        ask_table_.erase(ask_table_.begin());
      }
      rsps.push_back(rsp);
    } break;
    case Opcode::Cancel: {
      bool did_cancel = false;
      const vluint32_t uid_to_cancel = cmd.oprands.cancel.uid;
      if (auto it = std::find_if(bid_table_.begin(), bid_table_.end(),
                                 UidFinder{uid_to_cancel});
          !did_cancel && (it != bid_table_.end())) {
        // Cancel occurs.
        did_cancel = true;
        bid_table_.erase(it);
      }
      if (auto it = std::find_if(ask_table_.begin(), ask_table_.end(),
                                 UidFinder{uid_to_cancel});
          !did_cancel && (it != ask_table_.end())) {
        // Cancel occurs
        did_cancel = true;
        ask_table_.erase(it);        
      }

      rsp.valid = true;
      rsp.uid = cmd.uid;
      rsp.status = did_cancel ? Status::CancelHit : Status::CancelMiss;
      rsps.push_back(rsp);
    } break;
  }
}

bool Model::attempt_trade(Response& rsp) {
  if (ask_table_.empty() || bid_table_.empty()) {
    return false;
  }

  Entry& bid = bid_table_.front();
  Entry& ask = ask_table_.front();

  if (bid.price < ask.price) {
    // Bid does not take place.
    return false;
  }

  // Bid takes place.

  bool consume_bid = false;
  bool consume_ask = false;

  rsp.valid = true;
  rsp.status = Status::Okay;
  rsp.uid = 0xFFFFFFFF;

  rsp.result.trade.bid_uid = bid.uid;
  rsp.result.trade.ask_uid = ask.uid;

  if (bid.quantity < ask.quantity) {
    // Bid consumed.
    consume_bid = true;
    rsp.result.trade.quantity = bid.quantity;
    // Update ask.
    ask.quantity = (ask.quantity - bid.quantity);
  } else if (bid.quantity > ask.quantity) {
    // Ask consumed
    consume_ask = true;
    rsp.result.trade.quantity = ask.quantity;
    // Update bid
    bid.quantity = (bid.quantity - ask.quantity);
  } else {
    // Bid/Ask consumed
    consume_bid = true;
    consume_ask = true;
    rsp.result.trade.quantity = bid.quantity;
  }

  if (consume_bid) {
    // Remove head.
    bid_table_.erase(bid_table_.begin());
  }

  if (consume_ask) {
    // Remove head.
    ask_table_.erase(ask_table_.begin());
  }
  
  return true;
}

StimulusGenerator::StimulusGenerator(TB* tb, const Bag<vluint8_t>& opcodes,
                                     double mean, double stddev)
    : tb_(tb), opcodes_(opcodes), model_(BID_TABLE_N, ASK_TABLE_N),
      mean_(mean), stddev_(stddev) {
}

void StimulusGenerator::generate(std::size_t n) {
  Command cmd;
  std::vector<Response> rsps;
  while (n != 0) {
    // Generate a new command.
    generate(cmd);
    if (model_.can_execute(cmd)) {
      // Command can execute in the current cycle, therefore issue to
      // RTL.
      rsps.clear();
      model_.apply(cmd, rsps);
      // Add command to the model.
      tb_->push_back(cmd);
      // Add predicted responses to the model
      for (const Response& rsp : rsps) {
        tb_->push_back(rsp);
      }
      --n;
      // Advance UID
      ++uid_i_;
      // Retain prior UID for cancel operation.
      add_uid(cmd.uid);
    }
  }
}


void StimulusGenerator::generate(Command& cmd) {
  cmd.valid = true;
  cmd.uid = uid_i_;
  cmd.opcode = opcodes_();

  const double price = Random::normal(mean_, stddev_);
  const Bcd bcd = Bcd::from_string(to_bcd_string(price));
  ASSERT_TRUE(bcd.is_valid());
  const vluint16_t quantity = Random::uniform<int>(100, 10);
  
  switch (cmd.opcode) {
    case Opcode::Nop: {
      // No oprands.
    } break;
    case Opcode::QryBidAsk: {
      // No oprands.
    } break;
    case Opcode::Buy: {
      cmd.oprands.buy.quantity = quantity;
      cmd.oprands.buy.price = bcd.pack();
    } break;
    case Opcode::Sell: {
      cmd.oprands.sell.quantity = quantity;
      cmd.oprands.sell.price = bcd.pack();
    } break;
    case Opcode::PopTopBid: {
      // No oprands.
    } break;
    case Opcode::PopTopAsk: {
      // No oprands.
    } break;
    case Opcode::Cancel: {
      const bool do_definately_miss = Random::boolean(0.1);
      if (!do_definately_miss) {
        auto it = Random::select_one(prior_uid_.begin(), prior_uid_.end());
        cmd.oprands.cancel.uid = *it;
      } else {
        // Some UID we haven't issued yet and which is guarenteed to
        // miss.
        cmd.oprands.cancel.uid = (uid_i_ + 100);
      }
    } break;
  }
}

void StimulusGenerator::add_uid(vluint32_t uid) {
  prior_uid_.push_back(uid);

  if (prior_uid_.size() == model_.bid_n()) {
    // Remove oldest entry.
    prior_uid_.erase(prior_uid_.begin());
  }
}

} // namespace tb
