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
#include <cerrno>
#include "vsupport.h"
#include "utility.h"
#include "vobj/Vtb_ob.h"
#ifdef OPT_VCD_ENABLE
#  include "verilated_vcd_c.h"
#endif
#include "gtest/gtest.h"
#ifdef OPT_TRACE_ENABLE
#  include <iostream>
#endif
#include <algorithm>
#include <cstdio>

//#define UID_AS_HEX

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
    case Opcode::BuyLimit: return "BuyLimit";
    case Opcode::SellLimit: return "SellLimit";
    case Opcode::PopTopBid: return "PopTopBid";
    case Opcode::PopTopAsk: return "PopTopAsk";
    case Opcode::Cancel: return "Cancel";
    case Opcode::BuyMarket: return "BuyMarket";
    case Opcode::SellMarket: return "SellMarket";
    case Opcode::QryTblAskLe: return "QryTblAskLe";
    case Opcode::QryTblBidGe: return "QryTblBidGe";
    case Opcode::BuyStopLoss: return "BuyStopLoss";
    case Opcode::SellStopLoss: return "SellStopLoss";
    case Opcode::BuyStopLimit: return "BuyStopLimit";
    case Opcode::SellStopLimit: return "SellStopLimit";
    default: return "Invalid";
  }
}

// Convert a conditional command to its equivalent 'matured' command.
Command to_mtr_command(const Command& cmd) {
  Command out{cmd};
  switch (cmd.opcode) {
    case Opcode::BuyStopLoss: {
      out.opcode = Opcode::BuyMarket;
    } break;
    case Opcode::SellStopLoss: {
      out.opcode = Opcode::SellMarket;
    } break;
    case Opcode::BuyStopLimit: {
      out.opcode = Opcode::BuyLimit;
    } break;
    case Opcode::SellStopLimit: {
      out.opcode = Opcode::SellLimit;
    } break;
    default: {
      // Otherwise, unexpected command
    } break;
  }
  return out;
}

std::string Command::to_string() const {
  using std::to_string;

  utility::KVListRenderer r;
#ifdef UID_AS_HEX
  r.add_field("uid", utility::hex(uid));
#else
  r.add_field("uid", to_string(uid));
#endif
  r.add_field("opcode", to_opcode_string(opcode));
  switch (opcode) {
    case Opcode::BuyMarket: {
      r.add_field("quantity", to_string(quantity));
    } break;
    case Opcode::BuyLimit: {
      r.add_field("quantity", to_string(quantity));
      const Bcd bcd = Bcd::from_packed(price);
      r.add_field("price", bcd.to_string());
    } break;
    case Opcode::SellMarket: {
      r.add_field("quantity", to_string(quantity));
    } break;
    case Opcode::SellLimit: {
      r.add_field("quantity", to_string(quantity));
      const Bcd bcd = Bcd::from_packed(price);
      r.add_field("price", bcd.to_string());
    } break;
    case Opcode::Cancel: {
      r.add_field("cancelled uid", to_string(uid1));
    } break;
    case Opcode::QryTblAskLe:
    case Opcode::QryTblBidGe: {
      r.add_field("price", Bcd::from_packed(price).to_string());
    } break;
    case Opcode::BuyStopLoss:
    case Opcode::SellStopLoss:
    case Opcode::BuyStopLimit:
    case Opcode::SellStopLimit: {
      r.add_field("quantity", to_string(quantity));
      r.add_field("price", Bcd::from_packed(price).to_string());
      r.add_field("price1", Bcd::from_packed(price1).to_string());
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
  if (uid == 0xFFFFFFFF) {
    // Trade
#ifdef UID_AS_HEX
    r.add_field("bid_uid", utility::hex(result.trade.bid_uid));
    r.add_field("ask_uid", utility::hex(result.trade.ask_uid));
#else
    r.add_field("bid_uid", to_string(result.trade.bid_uid));
    r.add_field("ask_uid", to_string(result.trade.ask_uid));
#endif
    r.add_field("quantity", to_string(result.trade.quantity));
  } else {
#ifdef UID_AS_HEX
    r.add_field("uid", utility::hex(uid));
#else
    r.add_field("uid", to_string(uid));
#endif
    r.add_field("status", to_status_string(status));
    switch (opcode) {
      case Opcode::QryBidAsk: {
        r.add_field("op", to_opcode_string(opcode));
        if (status != Status::Bad) {
          const Bcd bid = Bcd::from_packed(result.qrybidask.bid);
          r.add_field("bid", bid.to_string());
          const Bcd ask = Bcd::from_packed(result.qrybidask.ask);
          r.add_field("ask", ask.to_string());
        }
      } break;
      case Opcode::PopTopBid:
      case Opcode::PopTopAsk: {
        r.add_field("op", to_opcode_string(opcode));
        const Bcd price = Bcd::from_packed(result.poptop.price);
        r.add_field("price", price.to_string());
        r.add_field("quantity", to_string(result.poptop.quantity));
#ifdef UID_AS_HEX
        r.add_field("uid", utility::hex(uid));
#else
        r.add_field("uid", to_string(uid));
#endif
      } break;
      case Opcode::QryTblAskLe:
      case Opcode::QryTblBidGe: {
        r.add_field("accum", to_string(result.qry.accum));
      } break;
    }
  }
  return r.to_string();
}

bool Response::is_trade() const {
  return (uid == 0xFFFFFFFF);
}

bool operator==(const Response& lhs, const Response& rhs) {
  if (lhs.uid != rhs.uid) return false;
  if (lhs.status != rhs.status) return false;

  return true;
}

bool compare(const Command& cmd, const Response& actual,
             const Response& expected) {
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
    switch (cmd.opcode) {
      case Opcode::QryBidAsk: {
      } break;
      case Opcode::PopTopBid:
      case Opcode::PopTopAsk: {
      } break;
      case Opcode::QryTblAskLe:
      case Opcode::QryTblBidGe: {
        EXPECT_EQ(actual.result.qry.accum, expected.result.qry.accum);
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
    case Opcode::BuyMarket:
    case Opcode::BuyLimit: {
      vsupport::set(cmd_quantity_r, cmd.quantity);
      vsupport::set(cmd_price_r, cmd.price);
    } break;
    case Opcode::SellMarket:
    case Opcode::SellLimit: {
      vsupport::set(cmd_quantity_r, cmd.quantity);
      vsupport::set(cmd_price_r, cmd.price);
    } break;
    case Opcode::Cancel: {
      vsupport::set(cmd_uid1_r, cmd.uid1);
    } break;
    case Opcode::QryTblAskLe:
    case Opcode::QryTblBidGe: {
      vsupport::set(cmd_quantity_r, cmd.quantity);
      vsupport::set(cmd_price_r, cmd.price);
    } break;
    case Opcode::BuyStopLoss:
    case Opcode::SellStopLoss:
    case Opcode::BuyStopLimit:
    case Opcode::SellStopLimit: {
      vsupport::set(cmd_quantity_r, cmd.quantity);
      vsupport::set(cmd_price_r, cmd.price);
      vsupport::set(cmd_price1_r, cmd.price1);
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
void VSignals::get(TbSupport& tb) const {
  tb.commit = vsupport::get_as_bool(tb_cmdl_commit);
  tb.uid = vsupport::get(tb_cmdl_uid);
  tb.mtr = vsupport::get_as_bool(tb_cn_mtr_vld);
  tb.mtr_uid = vsupport::get(tb_cn_mtr_uid);
}

//
void VSignals::get(Response& rsp) const {
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
  rsp.result.qry.accum = vsupport::get(rsp_qry_accum);
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

  // Initialize state
  cycle_ = 0;
  time_ = 0;

  // Run reset
  reset();

  // Drive interfaces to idle.
  Command cmd;
  vs_.set(cmd);

  // Response accept
  vs_.set_rsp_accept(true);

  std::map<vluint32_t, Command> uid_to_cmd;
  std::deque<std::pair<Command, Response> > rsps;

  // Prediction model
  Model model(BID_TABLE_DEPTH_N, ASK_TABLE_DEPTH_N);

  bool stopped = false;
  while (!stopped) {
    // Issue command:
    cmd.valid = false;
    if (!vs_.get_cmd_full_r() && !cmds_.empty()) {
      // Apply input command.
      cmd = cmds_.front();
      uid_to_cmd.insert(std::make_pair(cmd.uid, cmd));
#ifdef OPT_TRACE_ENABLE
      if (opts_.trace_enable) {
        std::cout << "[TB] " << vs_.cycle()
                  << ": Issue command: " << cmd.to_string() << "\n";
      }
#endif
      cmds_.pop_front();
    }
    // Issue command to RTL
    vs_.set(cmd);


    // Process Response:
    //
    Response actual;
    vs_.get(actual);
    if (actual.valid) {
      bool resolved_uid = false;
      if (actual.is_trade()) {
        // A trade has been received.
        EXPECT_FALSE(rsps.empty());
        const std::pair<Command, Response>& cr = rsps.front();
#ifdef OPT_TRACE_ENABLE
        if (opts_.trace_enable) {
          std::cout << "[TB] " << vs_.cycle() << ": Trade emitted: "
                    << actual.to_string(cr.first.opcode) << "\n";
        }
#endif
        compare(cr.first, actual, cr.second);
        rsps.pop_front();
      } else if (!rsps.empty()) {
        // A pre-computed response has been received.
        const std::pair<Command, Response>& cr = rsps.front();
#ifdef OPT_TRACE_ENABLE
        if (opts_.trace_enable) {
          std::cout << "[TB] " << vs_.cycle() << ": Response received: "
                    << cr.second.to_string(cr.first.opcode) << "\n";
        }
#endif
        compare(cr.first, actual, cr.second);
        rsps.pop_front();
      } else if (auto it = uid_to_cmd.find(actual.uid); it != uid_to_cmd.end()) {
        // Command response.
        const Command& cmd = it->second;
        // Compute set of expected responses.
        std::deque<Response> expected_rsps = model.apply(cmd);
        if (cmd.was_cn) {
          // If the current command originated from the CN table; care must
          // be delete to delete the entry from this table so that we do not
          // see it again (on a cancel operation, for example).
          model.delete_uid_from_cn(cmd.uid);
        }
#ifdef OPT_TRACE_ENABLE
        if (opts_.trace_enable) {
          std::cout << "[TB] " << vs_.cycle() << ": Response received: "
                    << actual.to_string(cmd.opcode) << "\n";
        }
#endif
        bool delete_uid = true;
        switch (cmd.opcode) {
          case Opcode::BuyStopLoss:
          case Opcode::SellStopLoss:
          case Opcode::BuyStopLimit:
          case Opcode::SellStopLimit: {
            // Difficult to predict the occupancy of the CN table here because
            // of pipelining. Instead, we accept the status from the RTL as
            // truth, otherwise if incorrect, the models would soon diverge
            // anyway.
            if (actual.status != Status::Reject) {
              // Command was not rejected, therefore permute command.
              Command permuted_cmd = to_mtr_command(cmd);
              permuted_cmd.was_cn = true;
#ifdef OPT_TRACE_ENABLE
              if (opts_.trace_enable) {
                std::cout << "[TB] " << vs_.cycle()
                          << ": Conditional command issued, becomes (on maturity): "
                          << permuted_cmd.to_string()
                          << "\n";
              }
#endif
              uid_to_cmd[actual.uid] = permuted_cmd;
              delete_uid = false;
            } else {
              // Command has been rejected.
              model.delete_uid_from_cn(actual.uid);
#ifdef OPT_TRACE_ENABLE
              if (opts_.trace_enable) {
                std::cout << "[TB] " << vs_.cycle()
                          << ": Conditional command is rejected\n";
              }
#endif
            }
          } break;
          default: {
            // Otherwise, just a standard command.
            compare(cmd, actual, expected_rsps.front());
            expected_rsps.pop_front();

            // Predicted tail commands:
            for (const Response& rsp : expected_rsps) {
              rsps.push_back(std::make_pair(cmd, rsp));
            }
          } break;
        }
        if (delete_uid) {
          // Finished with current UID.
          uid_to_cmd.erase(it);
        }
      } else if (opts_.trace_enable) {
#ifdef OPT_TRACE_ENABLE
        // Unknown UID has been received.
        std::cout << "[TB] " << vs_.cycle() << ": Unexpected response: "
                  << actual.to_string(0) << "\n";
#endif
      }
    }

    // Advance RTL by one cycle.
    step();

    // Stopped when we've received all data.
    stopped = cmds_.empty();
  }


  // Set interfaces to idle.
  cmd.valid = false;
  vs_.set(cmd);

  // Wind-down simulation
  step(20);
#ifdef OPT_TRACE_ENABLE
  if (opts_.trace_enable) {
    std::cout << "[TB] " << vs_.cycle() << ": Simulation complete!\n";
  }
#endif
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

std::string Entry::to_string() const {
  using std::to_string;

  utility::KVListRenderer r;
  r.add_field("uid", to_string(uid));
  r.add_field("quantity", to_string(quantity));
  const Bcd bcd = Bcd::from_packed(price);
  r.add_field("price", bcd.to_string());
  return r.to_string();
}

bool CNModel::cancel(vluint32_t uid) {
  if (auto it = cmds_.find(uid); it != cmds_.end()) {
    // Hit matching UID in table. Command is cancelled.
    cmds_.erase(it);
    return true;
  }
  return false;
}

bool CNModel::insert(const Command& cmd) {
  cmds_.insert(std::make_pair(cmd.uid, cmd));
  return true;
}

Model::Model(std::size_t bid_n, std::size_t ask_n)
    : bid_n_(bid_n), ask_n_(ask_n)
{}

bool Model::can_execute(const Command& cmd) const {
  // Commands can always be sunk.
  return true;
}

std::deque<Response> Model::apply(const Command& cmd) {

  std::deque<Response> rsps;
  if (!cmd.valid) {
    // No command, return
    return {};
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
    case Opcode::BuyLimit: {
      // Command executes, therefore emit response
      rsp.valid = true;
      rsp.uid = cmd.uid;
      rsp.status = Status::Okay;
      rsps.push_back(rsp);

      Entry e;
      e.uid = cmd.uid;
      e.quantity = cmd.quantity;
      e.price = cmd.price;
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
    case Opcode::SellLimit: {
      // Command executes, therefore emit response
      rsp.valid = true;
      rsp.uid = cmd.uid;
      rsp.status = Status::Okay;
      rsps.push_back(rsp);

      Entry e;
      e.uid = cmd.uid;
      e.quantity = cmd.quantity;
      e.price = cmd.price;
      ask_table_.push_back(e);
      std::stable_sort(ask_table_.begin(), ask_table_.end(), AskComparer{});

      while (attempt_trade(rsp)) {
        rsps.push_back(rsp);
      }
      if (ask_table_.size() > ask_n_) {
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
      const vluint32_t uid_to_cancel = cmd.uid1;
      // Search bid table limit:
      if (auto it = std::find_if(bid_table_.begin(), bid_table_.end(),
                                 UidFinder{uid_to_cancel});
          !did_cancel && (it != bid_table_.end())) {
        // Cancel occurs.
        did_cancel = true;
        bid_table_.erase(it);
      }
      // Search bid table market:
      if (auto it = std::find_if(bid_table_mk_.begin(), bid_table_mk_.end(),
                                 UidFinder{uid_to_cancel});
          !did_cancel && (it != bid_table_mk_.end())) {
        // Cancel occurs
        did_cancel = true;
        bid_table_mk_.erase(it);
      }
      // Search ask table limit:
      if (auto it = std::find_if(ask_table_.begin(), ask_table_.end(),
                                 UidFinder{uid_to_cancel});
          !did_cancel && (it != ask_table_.end())) {
        // Cancel occurs
        did_cancel = true;
        ask_table_.erase(it);
      }
      // Search ask table market:
      if (auto it = std::find_if(ask_table_mk_.begin(), ask_table_mk_.end(),
                                 UidFinder{uid_to_cancel});
          !did_cancel && (it != ask_table_mk_.end())) {
        // Cancel occurs
        did_cancel = true;
        ask_table_mk_.erase(it);
      }
      if (!did_cancel && cn_model_.cancel(uid_to_cancel)) {
        // Did cancel in conditional model table.
        did_cancel = true;
      }

      rsp.valid = true;
      rsp.uid = cmd.uid;
      rsp.status = did_cancel ? Status::CancelHit : Status::CancelMiss;
      rsps.push_back(rsp);
    } break;
    case Opcode::QryTblAskLe: {
      rsp.valid = true;
      rsp.uid = cmd.uid;
      rsp.status = Status::Okay;
      rsp.result.qry.accum = 0;
      for (const Entry& e : ask_table_) {
        if (cmd.price >= e.price) {
          rsp.result.qry.accum += e.quantity;
        }
      }
      for (const Entry& e : ask_table_mk_) {
        rsp.result.qry.accum += e.quantity;
      }
      rsps.push_back(rsp);
    } break;
    case Opcode::QryTblBidGe: {
      rsp.valid = true;
      rsp.uid = cmd.uid;
      rsp.status = Status::Okay;
      rsp.result.qry.accum = 0;
      for (const Entry& e : bid_table_) {
        if (cmd.price <= e.price) {
          rsp.result.qry.accum += e.quantity;
        }
      }
      for (const Entry& e : bid_table_mk_) {
        rsp.result.qry.accum += e.quantity;
      }
      rsps.push_back(rsp);
    } break;
    case Opcode::BuyMarket: {
      rsp.valid = true;
      rsp.uid = cmd.uid;
      if (bid_table_mk_.size() == MARKET_BID_DEPTH_N) {
        // Table has reached capacity, reject
        rsp.status = Status::Reject;
        rsps.push_back(rsp);
      } else {
        // Okay push to the back of the deque.
        Entry e;
        e.uid = cmd.uid;
        e.quantity = cmd.quantity;
        e.price = cmd.price;
        bid_table_mk_.push_back(e);
        rsp.status = Status::Okay;
        rsps.push_back(rsp);
        while (attempt_trade(rsp)) {
          rsps.push_back(rsp);
        }
      }
    } break;
    case Opcode::SellMarket: {
      rsp.valid = true;
      rsp.uid = cmd.uid;
      rsp.status = Status::Okay;
      if (ask_table_mk_.size() == MARKET_ASK_DEPTH_N) {
        // Table has reached capacity, reject
        rsp.status = Status::Reject;
        rsps.push_back(rsp);
      } else {
        // Okay push to the back of the deque.
        Entry e;
        e.uid = cmd.uid;
        e.quantity = cmd.quantity;
        e.price = cmd.price;
        ask_table_mk_.push_back(e);
        rsp.status = Status::Okay;
        rsps.push_back(rsp);

        while (attempt_trade(rsp)) {
          rsps.push_back(rsp);
        }
      }
    } break;
    case Opcode::BuyStopLoss:
    case Opcode::SellStopLoss:
    case Opcode::BuyStopLimit:
    case Opcode::SellStopLimit: {
      const bool success = cn_model_.insert(cmd);
      rsp.valid = true;
      rsp.uid = cmd.uid;
      rsp.status = success ? Status::Okay : Status::Reject;
      rsps.push_back(rsp);
    } break;
    default: {
#ifdef OPT_TRACE_ENABLE
      std::cout << "[TB] Unknown opcode encountered: " << utility::hex(cmd.opcode) << "\n";
      ADD_FAILURE();
#endif
    } break;
  }

#if defined(OPT_VERBOSE) && defined(OPT_TRACE_ENABLE)
  verbose();
#endif
  return rsps;
}

std::deque<Response> Model::apply_mtr(const Command& cmd) {
  // Cancel pending command in table. Expect this command to be
  // already present in the table.
  //  EXPECT_TRUE(cn_model_.cancel(cmd.uid));

  const Command permuted_command = to_mtr_command(cmd);
  return apply(permuted_command);
}

bool Model::delete_uid_from_cn(vluint32_t uid) {
  return cn_model_.cancel(uid);
}

void Model::dump(std::ostream& os) const {
  os << "Bid Table:\n";
  for (int i = 0; i < bid_table_.size(); i++) {
    os << i << " " << bid_table_[i].to_string() << "\n";
  }
  os << "Ask Table:\n";
  for (int i = 0; i < ask_table_.size(); i++) {
    os << i << " " << ask_table_[i].to_string() << "\n";
  }
  os << "Bid Table (Market):\n";
  for (int i = 0; i < bid_table_mk_.size(); i++) {
    os << i << " " << bid_table_mk_[i].to_string() << "\n";
  }
  os << "Ask Table (Market):\n";
  for (int i = 0; i < ask_table_mk_.size(); i++) {
    os << i << " " << ask_table_mk_[i].to_string() << "\n";
  }

}


bool Model::attempt_trade(Response& rsp) {
  if (attempt_trade_lm_lm(rsp)) { return true; }
  if (attempt_trade_lm_mk(rsp)) { return true; }
  if (attempt_trade_mk_lm(rsp)) { return true; }
  if (attempt_trade_mk_mk(rsp)) { return true; }

  return false;
}

bool Model::attempt_trade_lm_lm(Response& rsp) {
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

bool Model::attempt_trade_lm_mk(Response& rsp) {
  if (ask_table_.empty() || bid_table_mk_.empty()) {
    return false;
  }

  Entry& ask = ask_table_.front();
  Entry& bid = bid_table_mk_.front();

  // Do not consider price as market trade

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
    bid_table_mk_.pop_front();
  }

  if (consume_ask) {
    // Remove head.
    ask_table_.erase(ask_table_.begin());
  }

  return true;
}

bool Model::attempt_trade_mk_lm(Response& rsp) {
  if (ask_table_mk_.empty() || bid_table_.empty()) {
    return false;
  }
  Entry& ask = ask_table_mk_.front();
  Entry& bid = bid_table_.front();

  // Do not consider price as market trade

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
    ask_table_mk_.pop_front();
  }

  return true;
}

bool Model::attempt_trade_mk_mk(Response& rsp) {
  if (ask_table_mk_.empty() || bid_table_mk_.empty()) {
    return false;
  }
  // Trade can therefore occur has market entries exist.

  bool consume_bid = false;
  bool consume_ask = false;

  Entry& bid = bid_table_mk_.front();
  Entry& ask = ask_table_mk_.front();

  rsp.valid = true;
  rsp.status = Status::Okay;
  rsp.uid = 0xFFFFFFFF;

  rsp.result.trade.bid_uid = bid.uid;
  rsp.result.trade.ask_uid = ask.uid;

  if (bid.quantity < ask.quantity) {
    consume_bid = true;

    rsp.result.trade.quantity = bid.quantity;
    // Update ask.
    ask.quantity = (ask.quantity - bid.quantity);
  } else if (bid.quantity > ask.quantity) {
    consume_ask = true;

    rsp.result.trade.quantity = ask.quantity;
    // Update bid
    bid.quantity = (bid.quantity - ask.quantity);
  } else {
    // bid.quantity == ask.quantity
    consume_bid = true;
    consume_ask = true;

    rsp.result.trade.quantity = bid.quantity;
  }

  if (consume_bid) {
    // Remove head.
    bid_table_mk_.pop_front();
  }

  if (consume_ask) {
    // Remove head.
    ask_table_mk_.pop_front();
  }

  return true;
}
#if defined(OPT_VERBOSE) && defined(OPT_TRACE_ENABLE)

void Model::verbose() const {
  std::cout << "[TB] Bid Table:\n";
  for (int i = 0; i < bid_table_.size(); i++) {
    std::cout << "[TB] " << i << " " << bid_table_[i].to_string() << "\n";
  }

  std::cout << "[TB] Ask Table:\n";
  for (int i = 0; i < ask_table_.size(); i++) {
    std::cout << "[TB] " << i << " " << ask_table_[i].to_string() << "\n";
  }
  std::cout.flush();
}
#endif

StimulusGenerator::StimulusGenerator(const Bag<vluint8_t>& opcodes,
                                     double mean, double stddev)
    : opcodes_(opcodes), model_(BID_TABLE_DEPTH_N, ASK_TABLE_DEPTH_N),
      mean_(mean), stddev_(stddev) {
}

std::deque<Command> StimulusGenerator::generate(std::size_t n) {
  std::deque<Command> cmds;

  Command cmd;
  std::deque<Response> rsps;
  while (n != 0) {
    // Generate a new command.
    generate(cmd);
    if (model_.can_execute(cmd)) {
      // Command can execute in the current cycle, therefore issue to
      // RTL.
      rsps.clear();
      rsps = model_.apply(cmd);
      // Add command to the model.
      cmds.push_back(cmd);

      --n;
      // Advance UID
      ++uid_i_;
      // Retain prior UID for cancel operation.
      add_uid(cmd.uid);
    }
  }
  return cmds;
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
    case Opcode::BuyMarket: {
      cmd.quantity = quantity;
    } break;
    case Opcode::BuyLimit: {
      cmd.quantity = quantity;
      cmd.price = bcd.pack();
    } break;
    case Opcode::SellMarket: {
      cmd.quantity = quantity;
    } break;
    case Opcode::SellLimit: {
      cmd.quantity = quantity;
      cmd.price = bcd.pack();
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
        cmd.uid1 = *it;
      } else {
        // Some UID we haven't issued yet and which is guarenteed to
        // miss.
        cmd.uid1 = (uid_i_ + 100);
      }
    } break;
    case Opcode::QryTblAskLe:
    case Opcode::QryTblBidGe: {
      // Query either table for some random price.
      cmd.price = bcd.pack();
    } break;
    case Opcode::BuyStopLoss:
    case Opcode::SellStopLoss:
    case Opcode::BuyStopLimit:
    case Opcode::SellStopLimit: {
      const double price1 = Random::normal(mean_, stddev_);
      const Bcd bcd1 = Bcd::from_string(to_bcd_string(price1));
      cmd.price1 = bcd1.pack();
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
