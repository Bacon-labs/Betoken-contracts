// Generated by CoffeeScript 2.1.0
var Web3, betoken, betoken_addr, clock, countdownDay, countdownHour, countdownMin, countdownSec, cyclePhase, displayedKairoBalance, displayedKairoUnit, etherDelta_addr, getCurrentAccount, kairoBalance, kairoTotalSupply, kairo_addr, loadFundData, memberList, proposalList, showCountdown, startTimeOfCycle, supportedProposalList, timeOfChangeMaking, timeOfCycle, timeOfProposalMaking, totalFunds, userAddress, userBalance, web3;

import './body.html';

import './body.css';

import './tablesort.js';

import {
  Betoken
} from '../objects/betoken.js';

import Chart from 'chart.js';

import BigNumber from 'bignumber.js';

//Import web3
Web3 = require('web3');

web3 = window.web3;

if (typeof web3 !== void 0) {
  web3 = new Web3(web3.currentProvider);
} else {
  web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));
}

//Fund metadata
betoken_addr = new ReactiveVar("0xc1d9ba667f5f363f9bb93918d04e8be43c33a6c1");

betoken = new Betoken(betoken_addr.get());

kairo_addr = new ReactiveVar("");

etherDelta_addr = new ReactiveVar("");

//Session data
userAddress = new ReactiveVar("");

userBalance = new ReactiveVar(BigNumber("0"));

kairoBalance = new ReactiveVar(BigNumber("0"));

kairoTotalSupply = new ReactiveVar(BigNumber("0"));

cyclePhase = new ReactiveVar(0);

startTimeOfCycle = new ReactiveVar(0);

timeOfCycle = new ReactiveVar(0);

timeOfChangeMaking = new ReactiveVar(0);

timeOfProposalMaking = new ReactiveVar(0);

totalFunds = new ReactiveVar(BigNumber("0"));

proposalList = new ReactiveVar([]);

supportedProposalList = new ReactiveVar([]);

memberList = new ReactiveVar([]);

//Displayed variables
displayedKairoBalance = new ReactiveVar(BigNumber("0"));

displayedKairoUnit = new ReactiveVar("KRO");

countdownDay = new ReactiveVar(0);

countdownHour = new ReactiveVar(0);

countdownMin = new ReactiveVar(0);

countdownSec = new ReactiveVar(0);

showCountdown = new ReactiveVar(true);

getCurrentAccount = function() {
  return web3.eth.getAccounts().then(function(accounts) {
    return web3.eth.defaultAccount = accounts[0];
  }).then(function() {
    return web3.eth.defaultAccount;
  });
};

$('document').ready(function() {
  var ctx, myChart;
  $('.menu .item').tab();
  $('table').tablesort();
  clock();
  ctx = $("#myChart");
  return myChart = new Chart(ctx, {
    type: 'line',
    data: {
      datasets: [
        {
          label: "ROI Per Cycle",
          backgroundColor: 'rgba(0, 0, 100, 0.5)',
          borderColor: 'rgba(0, 0, 100, 1)',
          data: [
            {
              x: 1,
              y: 10
            },
            {
              x: 2,
              y: 13
            },
            {
              x: 3,
              y: 20
            }
          ]
        }
      ]
    },
    options: {
      scales: {
        xAxes: [
          {
            type: 'linear',
            position: 'bottom',
            scaleLabel: {
              display: true,
              labelString: 'Investment Cycle'
            },
            ticks: {
              stepSize: 1
            }
          }
        ],
        yAxes: [
          {
            type: 'linear',
            position: 'left',
            scaleLabel: {
              display: true,
              labelString: 'Percent'
            },
            ticks: {
              beginAtZero: true
            }
          }
        ]
      }
    }
  });
});

clock = function() {
  return setInterval(function() {
    var days, distance, hours, minutes, now, seconds, target;
    now = Math.floor(new Date().getTime() / 1000);
    target = 0;
    switch (cyclePhase.get()) {
      case 0:
        target = startTimeOfCycle.get() + timeOfChangeMaking.get();
        break;
      case 1:
        target = startTimeOfCycle.get() + timeOfChangeMaking.get() + timeOfProposalMaking.get();
        break;
      case 2:
        target = startTimeOfCycle.get() + timeOfCycle.get();
    }
    distance = target - now;
    if (distance > 0) {
      showCountdown.set(true);
      days = Math.floor(distance / (60 * 60 * 24));
      hours = Math.floor((distance % (60 * 60 * 24)) / (60 * 60));
      minutes = Math.floor((distance % (60 * 60)) / 60);
      seconds = Math.floor(distance % 60);
      countdownDay.set(days);
      countdownHour.set(hours);
      countdownMin.set(minutes);
      return countdownSec.set(seconds);
    } else {
      return showCountdown.set(false);
    }
  }, 1000);
};

loadFundData = function() {
  var members, proposals, supportedProposals;
  proposals = [];
  supportedProposals = [];
  members = [];
  return getCurrentAccount().then(function(_userAddress) {
    //Initialize user address
    userAddress.set(_userAddress);
  }).then(function() {
    return betoken.getMappingOrArrayItem("balanceOf", userAddress.get());
  }).then(function(_balance) {
    //Get user Ether deposit balance
    return userBalance.set(BigNumber(web3.utils.fromWei(_balance, "ether")).toFormat(18));
  }).then(function() {
    //Get user's Kairo balance
    return betoken.getKairoBalance(userAddress.get());
  }).then(function(_kairoBalance) {
    kairoBalance.set(BigNumber(_kairoBalance));
    displayedKairoBalance.set(BigNumber(web3.utils.fromWei(_kairoBalance, "ether")).toFormat(18));
  }).then(function() {
    //Get Kairo's total supply
    return betoken.getKairoTotalSupply();
  }).then(function(_kairoTotalSupply) {
    kairoTotalSupply.set(BigNumber(_kairoTotalSupply));
  }).then(function() {
    //Get total funds
    return betoken.getPrimitiveVar("totalFundsInWeis").then(function(_totalFunds) {
      return totalFunds.set(BigNumber(_totalFunds));
    });
  }).then(function() {
    //Get cycle phase
    return betoken.getPrimitiveVar("cyclePhase").then(function(_cyclePhase) {
      return cyclePhase.set(+_cyclePhase);
    });
  }).then(function() {
    //Get startTimeOfCycle
    return betoken.getPrimitiveVar("startTimeOfCycle").then(function(_startTime) {
      return startTimeOfCycle.set(+_startTime);
    });
  }).then(function() {
    //Get timeOfCycle
    return betoken.getPrimitiveVar("timeOfCycle").then(function(_time) {
      return timeOfCycle.set(+_time);
    });
  }).then(function() {
    //Get timeOfChangeMaking
    return betoken.getPrimitiveVar("timeOfChangeMaking").then(function(_time) {
      return timeOfChangeMaking.set(+_time);
    });
  }).then(function() {
    //Get timeOfProposalMaking
    return betoken.getPrimitiveVar("timeOfProposalMaking").then(function(_time) {
      return timeOfProposalMaking.set(+_time);
    });
  }).then(function() {
    //Set Kairo contract address
    return kairo_addr.set(betoken.addrs.controlToken);
  }).then(function() {
    //Get etherDelta address
    return betoken.getPrimitiveVar("etherDeltaAddr");
  }).then(function(_etherDeltaAddr) {
    return etherDelta_addr.set(_etherDeltaAddr);
  }).then(function() {
    //Get proposals
    return betoken.getArray("proposals");
  }).then(function(_proposals) {
    var allPromises, i, j, ref;
    allPromises = [];
    if (_proposals.length > 0) {
      for (i = j = 0, ref = _proposals.length - 1; 0 <= ref ? j <= ref : j >= ref; i = 0 <= ref ? ++j : --j) {
        if (_proposals[i].numFor > 0) {
          allPromises.push(betoken.getMappingOrArrayItem("forStakedControlOfProposal", i).then(function(_stake) {
            var investment, proposal;
            investment = BigNumber(_stake).dividedBy(kairoTotalSupply.get()).times(web3.utils.fromWei(totalFunds.get()));
            proposal = {
              id: i,
              token_symbol: _proposals[i].tokenSymbol,
              investment: investment.toFormat(4),
              supporters: _proposals[i].numFor
            };
            return proposals.push(proposal);
          }));
        }
      }
    }
    return Promise.all(allPromises);
  }).then(function() {
    proposalList.set(proposals);
  }).then(function() {
    var allPromises, j, len, proposal, ref;
    //Filter out proposals the user supported
    allPromises = [];
    ref = proposalList.get();
    for (j = 0, len = ref.length; j < len; j++) {
      proposal = ref[j];
      allPromises.push(betoken.getDoubleMapping("forStakedControlOfProposalOfUser", proposal.id, userAddress.get()).then(function(_stake) {
        _stake = BigNumber(_stake);
        if (_stake.greaterThan(0)) {
          proposal.user_stake = _stake;
          return supportedProposals.push(proposal);
        }
      }));
    }
    return Promise.all(allPromises);
  }).then(function() {
    supportedProposalList.set(supportedProposals);
  }).then(function() {
    return betoken.getArray("participants").then(function(_array) {
      var i, j, ref;
      //Get member addresses
      members = new Array(_array.length);
      if (_array.length > 0) {
        for (i = j = 0, ref = _array.length - 1; 0 <= ref ? j <= ref : j >= ref; i = 0 <= ref ? ++j : --j) {
          members[i] = new Object();
          members[i].address = _array[i];
        }
      }
    }).then(function() {
      var allPromises, i, setBalance;
      //Get member ETH balances
      setBalance = function(id) {
        return betoken.getMappingOrArrayItem("balanceOf", members[id].address).then(function(_eth_balance) {
          members[id].eth_balance = BigNumber(web3.utils.fromWei(_eth_balance, "ether")).toFormat(4);
        });
      };
      allPromises = (function() {
        var j, ref, results;
        results = [];
        for (i = j = 0, ref = members.length - 1; 0 <= ref ? j <= ref : j >= ref; i = 0 <= ref ? ++j : --j) {
          results.push(setBalance(i));
        }
        return results;
      })();
      return Promise.all(allPromises);
    }).then(function() {
      var allPromises, i, setBalance;
      //Get member KRO balances
      setBalance = function(id) {
        return betoken.getKairoBalance(members[id].address).then(function(_kro_balance) {
          members[id].kro_balance = BigNumber(web3.utils.fromWei(_kro_balance, "ether")).toFormat(4);
        });
      };
      allPromises = (function() {
        var j, ref, results;
        results = [];
        for (i = j = 0, ref = members.length - 1; 0 <= ref ? j <= ref : j >= ref; i = 0 <= ref ? ++j : --j) {
          results.push(setBalance(i));
        }
        return results;
      })();
      return Promise.all(allPromises);
    }).then(function() {
      var j, len, member;
      //Get member KRO proportions
      for (j = 0, len = members.length; j < len; j++) {
        member = members[j];
        member.kro_proportion = BigNumber(member.kro_balance).dividedBy(web3.utils.fromWei(kairoTotalSupply.get().toString())).times(100).toPrecision(4);
      }
    }).then(function() {
      //Update reactive_list
      return memberList.set(members);
    });
  });
};

Template.body.onCreated(loadFundData);

Template.top_bar.helpers({
  show_countdown: function() {
    return showCountdown.get();
  },
  betoken_addr: function() {
    return betoken_addr.get();
  },
  kairo_addr: function() {
    return kairo_addr.get();
  },
  etherdelta_addr: function() {
    return etherDelta_addr.get();
  }
});

Template.top_bar.events({
  "click .next_phase": function(event) {
    return betoken.endPhase().then(loadFundData);
  },
  "click .change_contract": function(event) {
    return $('.ui.basic.modal.change_contract_modal').modal({
      onApprove: function(e) {
        var error, new_addr;
        try {
          new_addr = $("#contract_addr_input")[0].value;
          betoken_addr.set(new_addr);
          betoken = new Betoken(betoken_addr.get());
          return loadFundData();
        } catch (error1) {
          error = error1;
        }
      }
    //Todo:Display error message
    }).modal('show');
  },
  "click .refresh_button": function(event) {
    return loadFundData();
  }
});

Template.countdown_timer.helpers({
  day: function() {
    return countdownDay.get();
  },
  hour: function() {
    return countdownHour.get();
  },
  minute: function() {
    return countdownMin.get();
  },
  second: function() {
    return countdownSec.get();
  }
});

Template.phase_indicator.helpers({
  phase_active: function(index) {
    if (cyclePhase.get() === index) {
      return "active";
    }
    return "";
  }
});

Template.sidebar.helpers({
  user_address: function() {
    return userAddress.get();
  },
  user_balance: function() {
    return userBalance.get();
  },
  user_kairo_balance: function() {
    return displayedKairoBalance.get();
  },
  kairo_unit: function() {
    return displayedKairoUnit.get();
  }
});

Template.sidebar.events({
  "click .kairo_unit_switch": function(event) {
    if (event.target.checked) {
      //Display proportion
      displayedKairoBalance.set(kairoBalance.get().dividedBy(kairoTotalSupply.get()).times("100").toFormat(18));
      return displayedKairoUnit.set("%");
    } else {
      //Display Kairo
      displayedKairoBalance.set(BigNumber(web3.utils.fromWei(kairoBalance.get().toString(), "ether")).toFormat(18));
      return displayedKairoUnit.set("KRO");
    }
  }
});

Template.transact_box.onCreated(function() {
  Template.instance().depositInputHasError = new ReactiveVar(false);
  return Template.instance().withdrawInputHasError = new ReactiveVar(false);
});

Template.transact_box.helpers({
  is_disabled: function() {
    if (cyclePhase.get() !== 0) {
      return "disabled";
    }
    return "";
  },
  has_error: function(input_id) {
    if (input_id === 0) {
      if (Template.instance().depositInputHasError.get()) {
        return "error";
      }
    } else {
      if (Template.instance().withdrawInputHasError.get()) {
        return "error";
      }
    }
    return "";
  }
});

Template.transact_box.events({
  "click .deposit_button": function(event) {
    var amount;
    try {
      Template.instance().depositInputHasError.set(false);
      amount = BigNumber(web3.utils.toWei($("#deposit_input")[0].value));
      return betoken.deposit(amount).then(loadFundData);
    } catch (error1) {
      return Template.instance().depositInputHasError.set(true);
    }
  },
  "click .withdraw_button": function(event) {
    var amount;
    try {
      Template.instance().withdrawInputHasError.set(false);
      amount = BigNumber(web3.utils.toWei($("#withdraw_input")[0].value));
      return betoken.withdraw(amount).then(loadFundData);
    } catch (error1) {
      return Template.instance().withdrawInputHasError.set(true);
    }
  }
});

Template.supported_props_box.helpers({
  proposal_list: function() {
    return supportedProposalList.get();
  },
  is_disabled: function() {
    if (cyclePhase.get() !== 1) {
      return "disabled";
    }
    return "";
  }
});

Template.supported_props_box.events({
  "click .cancel_support_button": function(event) {
    return betoken.cancelSupport(this.id).then(loadFundData);
  }
});

Template.proposals_tab.helpers({
  proposal_list: function() {
    return proposalList.get();
  },
  is_disabled: function() {
    if (cyclePhase.get() !== 1) {
      return "disabled";
    }
    return "";
  }
});

Template.proposals_tab.events({
  "click .support_proposal": function(event) {
    return $('.ui.basic.modal.support_proposal_modal_' + this.id).modal({
      onApprove: function(e) {
        var error, kairoAmountInWeis;
        try {
          kairoAmountInWeis = BigNumber($("#stake_input_" + this.id)[0].value).times("1e18");
          return betoken.supportProposal(this.id, kairoAmountInWeis).then(loadFundData);
        } catch (error1) {
          error = error1;
        }
      }
    //Todo:Display error message
    }).modal('show');
  },
  "click .new_proposal": function(event) {
    return $('.ui.basic.modal.new_proposal_modal').modal({
      onApprove: function(e) {
        var address, error, kairoAmountInWeis, tickerSymbol;
        try {
          address = $("#address_input_new")[0].value;
          tickerSymbol = $("#ticker_input_new")[0].value;
          kairoAmountInWeis = BigNumber($("#stake_input_new")[0].value).times("1e18");
          return betoken.createProposal(address, tickerSymbol, kairoAmountInWeis).then(loadFundData);
        } catch (error1) {
          error = error1;
        }
      }
    //Todo:Display error message
    }).modal('show');
  }
});

Template.members_tab.helpers({
  member_list: function() {
    return memberList.get();
  }
});
