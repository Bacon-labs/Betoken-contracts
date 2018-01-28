pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/token/ERC20/MintableToken.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './etherdelta.sol';
import './oraclizeAPI_0.4.sol';

// The main contract
contract GroupFund is Ownable {
  using SafeMath for uint256;

  enum CyclePhase { ChangeMaking, ProposalMaking, Waiting, Ended, Finalized }

  struct Proposal {
    address tokenAddress;
    string tokenSymbol;
    uint256 tokenDecimals;
    uint256 buyPriceInWeis;
    uint256 sellPriceInWeis;
    uint256 buyOrderExpirationBlockNum;
    uint256 sellOrderExpirationBlockNum;
    uint256 numFor;
    uint256 numAgainst;
  }

  modifier during(CyclePhase phase) {
    require(cyclePhase == phase);
    _;
  }

  modifier onlyParticipant {
    require(isParticipant[msg.sender]);
    _;
  }

  modifier onlyOraclize {
    require(msg.sender == oraclizeAddr);
    _;
  }

  // Address of the control token
  address public controlTokenAddr;

  // Address of the etherDelta decentralized exchange's address
  address public etherDeltaAddr;

  // Address of the helper contract that calls Oraclize
  address public oraclizeAddr;

  // The creator of the GroupFund
  address public creator;

  // Address to which the developer fees will be paid
  address public developerFeeAccount;

  //The number of the current cycle
  uint256 public cycleNumber;

  //10^decimals used for representing fixed point decimals
  uint256 public tenToDecimals;

  // The total amount of funds held by the group
  uint256 public totalFundsInWeis;

  //The start time for the current investment cycle, in seconds since Unix epoch
  uint256 public startTimeOfCycle;

  //Temporal length of each investment cycle, in seconds
  uint256 public timeOfCycle;

  //Temporal length of change making period at start of each cycle, in seconds
  uint256 public timeOfChangeMaking;

  //Temporal length of proposal making period at start of each cycle, in seconds
  uint256 public timeOfProposalMaking;

  //The time allotted for waiting for sell orders, in seconds
  uint256 public timeOfSellOrderWaiting;

  //Proportion of control people who vote against a proposal have to stake
  uint256 public minStakeProportion;

  // The maximum number of proposals a participant can make
  uint256 public maxProposals;

  // The proportion of the fund that gets distributed to Kairo holders every cycle
  uint256 public commissionRate;

  uint256 public orderExpirationTimeInBlocks;

  //The proportion of contract balance reserved for Oraclize fees
  uint256 public oraclizeFeeProportion;

  // The proportion of contract balance that goes the the devs
  uint256 public developerFeeProportion;

  //The max number of proposals a member can create
  uint256 public maxProposalsPerMember;

  uint256 public numProposals;

  bool public isFirstCycle;

  bool public initialized;

  mapping(address => bool) public isParticipant;

  // Mapping from Participant address to their balance
  mapping(address => uint256) public balanceOf;

  // Mapping from Proposal to total amount of Control Tokens being staked by supporters
  mapping(uint256 => uint256) public forStakedControlOfProposal;

  //Records the number of proposals a user has made in the current cycle
  mapping(address => uint256) public createdProposalCount;

  // Mapping from Proposal to Participant to number of Control Tokens being staked
  mapping(uint256 => mapping(address => uint256)) public forStakedControlOfProposalOfUser;
  mapping(uint256 => mapping(address => uint256)) public againstStakedControlOfProposalOfUser;

  // Mapping to check if a proposal for a token has already been made
  mapping(address => bool) public isTokenAlreadyProposed;

  address[] public participants; // A list of everyone who is participating in the GroupFund
  Proposal[] public proposals;

  // Referrents to other contracts
  ControlToken internal cToken;
  EtherDelta internal etherDelta;
  OraclizeHandler internal oraclize;

  CyclePhase public cyclePhase;

  event CycleStarted(uint256 _cycleNumber, uint256 _timestamp);
  event Deposit(uint256 _cycleNumber, address _sender, uint256 _amountInWeis, uint256 _timestamp);
  event Withdraw(uint256 _cycleNumber, address _sender, uint256 _amountInWeis, uint256 _timestamp);
  event ChangeMakingTimeEnded(uint256 _cycleNumber, uint256 _timestamp);
  event NewProposal(uint256 _cycleNumber, uint256 _id, address _tokenAddress, string _tokenSymbol, uint256 _amountInWeis);
  event SupportedProposal(uint256 _cycleNumber, uint256 _id, uint256 _amountInWeis);
  event ProposalMakingTimeEnded(uint256 _cycleNumber, uint256 _timestamp);
  event CycleEnded(uint256 _cycleNumber, uint256 _timestamp);
  event CycleFinalized(uint256 _cycleNumber, uint256 _timestamp);
  event ROI(uint256 _cycleNumber, uint256 _beforeTotalFunds, uint256 _afterTotalFunds);
  event PredictionResult(uint256 _cycleNumber, address _member, bool _success);
  event CommissionPaid(uint256 _cycleNumber, uint256 _totalCommissionInWeis);

  // GroupFund constructor
  function GroupFund(
    address _etherDeltaAddr,
    address _developerFeeAccount,
    uint256 _tenToDecimals,
    uint256 _timeOfCycle,
    uint256 _timeOfChangeMaking,
    uint256 _timeOfProposalMaking,
    uint256 _timeOfSellOrderWaiting,
    uint256 _minStakeProportion,
    uint256 _maxProposals,
    uint256 _commissionRate,
    uint256 _orderExpirationTimeInBlocks,
    uint256 _oraclizeFeeProportion,
    uint256 _developerFeeProportion,
    uint256 _maxProposalsPerMember
  )
    public
  {
    require(_timeOfChangeMaking.add(_timeOfProposalMaking) <= _timeOfCycle);

    etherDeltaAddr = _etherDeltaAddr;
    developerFeeAccount = _developerFeeAccount;
    tenToDecimals = _tenToDecimals;
    timeOfCycle = _timeOfCycle;
    timeOfChangeMaking = _timeOfChangeMaking;
    timeOfProposalMaking = _timeOfProposalMaking;
    timeOfSellOrderWaiting = _timeOfSellOrderWaiting;
    minStakeProportion = _minStakeProportion;
    maxProposals = _maxProposals;
    commissionRate = _commissionRate;
    orderExpirationTimeInBlocks = _orderExpirationTimeInBlocks;
    oraclizeFeeProportion = _oraclizeFeeProportion;
    developerFeeProportion = _developerFeeProportion;
    maxProposalsPerMember = _maxProposalsPerMember;
    startTimeOfCycle = 0;
    isFirstCycle = true;
    cyclePhase = CyclePhase.Finalized;
    creator = msg.sender;
    numProposals = 0;
    cycleNumber = 0;

    //Initialize etherDelta contract
    etherDelta = EtherDelta(etherDeltaAddr);
  }

  // Constructor for the Control Token and Oraclize contracts
  function initializeSubcontracts(address _cTokenAddr, address _oraclizeAddr) public {
    require(msg.sender == creator);
    require(!initialized);

    initialized = true;

    controlTokenAddr = _cTokenAddr;
    oraclizeAddr = _oraclizeAddr;

    cToken = ControlToken(controlTokenAddr);
    oraclize = OraclizeHandler(oraclizeAddr);
  }

  // Allow updating of the exchange's address
  function changeEtherDeltaAddress(address _newAddr) public onlyOwner {
    etherDeltaAddr = _newAddr;

    // Creates new EtherDelta API contract with the new address
    etherDelta = EtherDelta(_newAddr);
    oraclize.__changeEtherDeltaAddress(_newAddr);
  }

  // Allow the developer's address to change
  function changeDeveloperFeeAccount(address _newAddr) public onlyOwner {
    developerFeeAccount = _newAddr;
  }

  // *******
  // Getters
  // *******
  function participantsCount() public view returns(uint256 _count) {
    return participants.length;
  }

  function proposalsCount() public view returns(uint256 _count) {
    return proposals.length;
  }

  // *******
  // Fee Proportion setters
  // *******
  function changeOraclizeFeeProportion(uint256 _newProp) public onlyOwner {
    require(_newProp < oraclizeFeeProportion);
    oraclizeFeeProportion = _newProp;
  }

  function changeDeveloperFeeProportion(uint256 _newProp) public onlyOwner {
    require(_newProp < developerFeeProportion);
    developerFeeProportion = _newProp;
  }

  // Modify the commission that gets distributed to token holders
  function changeCommissionRate(uint256 _newProp) public onlyOwner {
    commissionRate = _newProp;
  }

  function topupOraclizeFees() public payable {
    oraclizeAddr.transfer(msg.value);
  }

  //Starts a new cycle
  function startNewCycle() public during(CyclePhase.Finalized) {
    // Contract needs to be initialized
    // (Used to prevent function calls before initializing subcontracts)
    require(initialized);

    // Update the Cycles
    cyclePhase = CyclePhase.ChangeMaking;
    startTimeOfCycle = now;
    cycleNumber = cycleNumber.add(1);

    //Reset data
    for (uint256 i = 0; i < participants.length; i = i.add(1)) {
      __resetMemberData(participants[i]);
    }

    for (i = 0; i < proposals.length; i = i.add(1)) {
      __resetProposalData(i);
    }
    oraclize.__deleteTokenSymbolOfProposal();
    delete proposals;
    delete numProposals;

    // Updated the time when the cycle started
    CycleStarted(cycleNumber, now);
  }

  // *******
  // Reset functions
  // *******
  function __resetMemberData(address _addr) internal {
    delete createdProposalCount[_addr];

    // Remove the associated corresponding control staked for/against for each proposal
    for (uint256 i = 0; i < proposals.length; i = i.add(1)) {
      delete forStakedControlOfProposalOfUser[i][_addr];
      delete againstStakedControlOfProposalOfUser[i][_addr];
    }
  }

  function __resetProposalData(uint256 _proposalId) internal {
    delete isTokenAlreadyProposed[proposals[_proposalId].tokenAddress];
    delete forStakedControlOfProposal[_proposalId];
  }

  // *******
  // Change making time functions
  // *******

  // Deposit into GroupFund
  function deposit()
    public
    payable
    during(CyclePhase.ChangeMaking)
  {
    // If caller is not a participant, add them onto the participants list
    if (!isParticipant[msg.sender]) {
      participants.push(msg.sender);
      isParticipant[msg.sender] = true;
    }

    //Register investment
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalFundsInWeis = totalFundsInWeis.add(msg.value);

    if (isFirstCycle) {
      //Give control tokens proportional to investment
      cToken.mint(msg.sender, msg.value);
    }

    Deposit(cycleNumber, msg.sender, msg.value, now);
  }

  // Withdraw from GroupFund
  function withdraw(uint256 _amountInWeis)
    public
    during(CyclePhase.ChangeMaking)
    onlyParticipant
  {
    require(!isFirstCycle);

    totalFundsInWeis = totalFundsInWeis.sub(_amountInWeis);
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(_amountInWeis);

    msg.sender.transfer(_amountInWeis);

    Withdraw(cycleNumber, msg.sender, _amountInWeis, now);
  }

  // End the change making time phase
  function endChangeMakingTime() public during(CyclePhase.ChangeMaking) {
    require(now >= startTimeOfCycle.add(timeOfChangeMaking));

    cyclePhase = CyclePhase.ProposalMaking;

    ChangeMakingTimeEnded(cycleNumber, now);
  }

  //Proposal making time functions
  function createProposal(
    address _tokenAddress,
    string _tokenSymbol,
    uint256 _tokenDecimals,
    uint256 _stakeInWeis
  )
    public
    during(CyclePhase.ProposalMaking)
    onlyParticipant
  {
    require(numProposals < maxProposals);
    require(!isTokenAlreadyProposed[_tokenAddress]);
    require(createdProposalCount[msg.sender] < maxProposalsPerMember);

    proposals.push(Proposal({
      tokenAddress: _tokenAddress,
      tokenSymbol: _tokenSymbol,
      tokenDecimals: _tokenDecimals,
      buyPriceInWeis: 0,
      sellPriceInWeis: 0,
      numFor: 0,
      numAgainst: 0,
      buyOrderExpirationBlockNum: 0,
      sellOrderExpirationBlockNum: 0
    }));

    isTokenAlreadyProposed[_tokenAddress] = true;
    oraclize.__pushTokenSymbolOfProposal(_tokenSymbol);
    createdProposalCount[msg.sender] = createdProposalCount[msg.sender].add(1);
    numProposals = numProposals.add(1);

    //Stake control tokens
    uint256 proposalId = proposals.length - 1;
    supportProposal(proposalId, _stakeInWeis);

    NewProposal(cycleNumber, proposalId, _tokenAddress, _tokenSymbol, _stakeInWeis);
  }

  function supportProposal(uint256 _proposalId, uint256 _stakeInWeis)
    public
    during(CyclePhase.ProposalMaking)
    onlyParticipant
  {
    require(_proposalId < proposals.length);
    require(isTokenAlreadyProposed[proposals[_proposalId].tokenAddress]); //Non-empty proposal

    //Stake control tokens

    //Ensure stake is larger than the minimum proportion of Kairo balance
    require(_stakeInWeis.mul(tenToDecimals) >= minStakeProportion.mul(cToken.balanceOf(msg.sender)));
    //Collect staked control tokens
    cToken.ownerCollectFrom(msg.sender, _stakeInWeis);
    //Update stake data
    if (forStakedControlOfProposalOfUser[_proposalId][msg.sender] == 0) {
      proposals[_proposalId].numFor = proposals[_proposalId].numFor.add(1);
    }
    forStakedControlOfProposal[_proposalId] = forStakedControlOfProposal[_proposalId].add(_stakeInWeis);
    forStakedControlOfProposalOfUser[_proposalId][msg.sender] = forStakedControlOfProposalOfUser[_proposalId][msg.sender].add(_stakeInWeis);

    SupportedProposal(cycleNumber, _proposalId, _stakeInWeis);
  }

  function cancelProposalSupport(uint256 _proposalId)
    public
    during(CyclePhase.ProposalMaking)
    onlyParticipant
  {
    require(_proposalId < proposals.length);
    require(proposals[_proposalId].numFor > 0); //Non-empty proposal

    //Remove stake
    uint256 stake = forStakedControlOfProposalOfUser[_proposalId][msg.sender];
    delete forStakedControlOfProposalOfUser[_proposalId][msg.sender];
    forStakedControlOfProposal[_proposalId] = forStakedControlOfProposal[_proposalId].sub(stake);

    //Remove support
    proposals[_proposalId].numFor = proposals[_proposalId].numFor.sub(1);

    //Return stake
    cToken.transfer(msg.sender, stake);

    //Delete proposal if necessary
    if (forStakedControlOfProposal[_proposalId] == 0) {
      __resetProposalData(_proposalId);
      numProposals = numProposals.sub(1);
      delete proposals[_proposalId];
      //Maybe subtract 1 from createdProposalCount[creator]
    }
  }

  function endProposalMakingTime()
    public
    during(CyclePhase.ProposalMaking)
  {
    require(now >= startTimeOfCycle.add(timeOfChangeMaking).add(timeOfProposalMaking));

    cyclePhase = CyclePhase.Waiting;

    __stakeAgainstVotes();
    __makeInvestments();

    ProposalMakingTimeEnded(cycleNumber, now);
  }

  function __stakeAgainstVotes() internal {
    //Stake against votes
    for (uint256 i = 0; i < proposals.length; i = i.add(1)) {
      if (proposals[i].numFor > 0) { //Ensure proposal isn't a deleted one
        //Calculate total Kairo balance of users against the proposal
        uint256 againstTotalBalance = 0;
        for (uint256 j = 0; j < participants.length; j = j.add(1)) {
          bool isFor = forStakedControlOfProposalOfUser[i][participants[j]] != 0;
          if (!isFor) {
            againstTotalBalance = againstTotalBalance.add(cToken.balanceOf(participants[j]));
          }
        }
        //Calculate the proportion of Kairo each user against the proposal have to stake
        uint256 stakeProportion = tenToDecimals;
        if (forStakedControlOfProposal[i] < againstTotalBalance) {
          stakeProportion = forStakedControlOfProposal[i].mul(tenToDecimals).div(againstTotalBalance);
        } else {
          //Mint new Kairo to fill the gap
          uint256 mintAmount = forStakedControlOfProposal[i] - againstTotalBalance;
          if (mintAmount > 0) {
            cToken.mint(address(this), mintAmount);
          }
        }
        //Collect stakes
        for (j = 0; j < participants.length; j = j.add(1)) {
          address participant = participants[j];
          isFor = forStakedControlOfProposalOfUser[i][participant] != 0;
          uint256 userBalance = cToken.balanceOf(participant);
          if (!isFor && userBalance > 0) {
            uint256 stake = stakeProportion.mul(userBalance).div(tenToDecimals);
            cToken.ownerCollectFrom(participant, stake);
            proposals[i].numAgainst = proposals[i].numAgainst.add(1);
            againstStakedControlOfProposalOfUser[i][participant] = againstStakedControlOfProposalOfUser[i][participant].add(stake);
          }
        }
      }
    }
  }

  function __makeInvestments() internal {
    //Invest in tokens using etherdelta
    for (uint256 i = 0; i < proposals.length; i = i.add(1)) {
      if (proposals[i].numFor > 0) { //Ensure proposal isn't a deleted one
        //Deposit ether
        uint256 investAmount = totalFundsInWeis.mul(forStakedControlOfProposal[i]).div(cToken.totalSupply());
        etherDelta.deposit.value(investAmount)();
        oraclize.__grabCurrentPriceFromOraclize(i);
      }
    }
  }

  function endCycle() public during(CyclePhase.Waiting) {
    require(now >= startTimeOfCycle.add(timeOfCycle));

    cyclePhase = CyclePhase.Ended;
    isFirstCycle = false;

    //Sell all invested tokens
    for (uint256 i = 0; i < proposals.length; i = i.add(1)) {
      if (proposals[i].numFor > 0) {
        //Ensure proposal isn't a deleted one
        oraclize.__grabCurrentPriceFromOraclize(i);
      }
    }

    CycleEnded(cycleNumber, now);
  }

  function finalizeEndCycle() public during(CyclePhase.Ended) {
    require(now >= startTimeOfCycle.add(timeOfCycle).add(timeOfSellOrderWaiting));

    cyclePhase = CyclePhase.Finalized;

    for (uint256 proposalId = 0; proposalId < proposals.length; proposalId = proposalId.add(1)) {
      if (proposals[proposalId].numFor > 0) { //Ensure proposal isn't a deleted one
        __settleBets(proposalId);
      }
    }
    //Burn any Kairo left in GroupFund's account
    cToken.burnOwnerBalance();

    //Withdraw from etherdelta
    uint256 balance = etherDelta.tokens(address(0), address(this));
    etherDelta.withdraw(balance);

    //Get all remaining funds from OraclizeHandler
    oraclize.__returnAllFunds();

    __distributeFundsAfterCycleEnd();

    CycleFinalized(cycleNumber, now);
  }

  //Internal use functions

  //Doesn't work. Always returns false for some inexplicable reason.
  //function __sellOrderFinished(uint256 _proposalId) internal returns(bool) {
    //Proposal storage prop = proposals[_proposalId];
    //uint256 sellTokenAmount = etherDelta.tokens(prop.tokenAddress, address(this));
    //uint256 getWeiAmount = sellTokenAmount.mul(prop.sellPriceInWeis).div(10**prop.tokenDecimals);
    //uint256 amountFilled = etherDelta.amountFilled(address(0), getWeiAmount, prop.tokenAddress, sellTokenAmount, prop.sellOrderExpirationBlockNum, _proposalId, address(this), 0, 0, 0);

    //return ((amountFilled >= sellTokenAmount) || (block.number > prop.sellOrderExpirationBlockNum));
  //}

  //Seperated from finalizeEndCycle() to avoid StackTooDeep error
  function __settleBets(uint256 _proposalId) internal {
    Proposal storage prop = proposals[_proposalId];

    //Prevent divide by zero errors
    if (prop.buyPriceInWeis == 0 || cToken.totalSupply() == 0) {
      __returnStakes(_proposalId);
      return;
    }

    uint256 stake;
    uint256 j;
    address participant;
    uint256 investAmount = totalFundsInWeis.mul(forStakedControlOfProposal[_proposalId]).div(cToken.totalSupply());

    if (etherDelta.amountFilled(prop.tokenAddress, investAmount.mul(10**prop.tokenDecimals).div(prop.buyPriceInWeis), address(0), investAmount, prop.sellOrderExpirationBlockNum, _proposalId, address(this), 0, 0, 0) != 0) {
      if (prop.sellPriceInWeis > prop.buyPriceInWeis) {
        //For wins
        for (j = 0; j < participants.length; j = j.add(1)) {
          participant = participants[j];
          stake = forStakedControlOfProposalOfUser[_proposalId][participant];
          if (stake > 0) {
            //Give control tokens
            cToken.transfer(participant, stake.mul(2));
            //Won bet
            PredictionResult(cycleNumber, participant, true);
          } else {
            if (againstStakedControlOfProposalOfUser[_proposalId][participant] > 0) {
              //Lost bet
              PredictionResult(cycleNumber, participant, false);
            }
          }
        }
      } else {
        //Against wins
        if (prop.numAgainst > 0) {
          for (j = 0; j < participants.length; j = j.add(1)) {
            participant = participants[j];
            stake = againstStakedControlOfProposalOfUser[_proposalId][participant];
            if (stake > 0) {
              //Give control tokens
              cToken.transfer(participant, stake.mul(2));
              //Won bet
              PredictionResult(cycleNumber, participant, true);
            } else {
              if (forStakedControlOfProposalOfUser[_proposalId][participant] > 0) {
                //Lost bet
                PredictionResult(cycleNumber, participant, false);
              }
            }
          }
        } else {
          //Everyone f'ed up somehow. No point in punishing. Return stakes.
          __returnStakes(_proposalId);
        }
      }
    } else {
      //Buy order failed completely. Give back stakes.
      __returnStakes(_proposalId);
    }
  }

  function __returnStakes(uint256 proposalId) internal {
    for (uint256 j = 0; j < participants.length; j = j.add(1)) {
      address participant = participants[j];
      uint256 stake = forStakedControlOfProposalOfUser[proposalId][participant].add(againstStakedControlOfProposalOfUser[proposalId][participant]);
      if (stake != 0) {
        cToken.transfer(participant, stake);
      }
    }
  }

  //Seperated from finalizeEndCycle() to avoid StackTooDeep error
  function __distributeFundsAfterCycleEnd() internal {
    //Distribute funds
    uint256 totalCommission = commissionRate.mul(this.balance).div(tenToDecimals);
    uint256 devFee = developerFeeProportion.mul(this.balance).div(tenToDecimals);
    uint256 oraclizeFee = oraclize.__oraclizeFee().mul(maxProposals.length).mul(2);
    uint256 newTotalRegularFunds = this.balance.sub(totalCommission).sub(devFee).sub(oraclizeFee);

    for (uint256 i = 0; i < participants.length; i = i.add(1)) {
      address participant = participants[i];
      uint256 newBalance = 0;
      //Add share
      if (totalFundsInWeis > 0) {
        newBalance = newBalance.add(newTotalRegularFunds.mul(balanceOf[participant]).div(totalFundsInWeis));
      }
      //Add commission
      //Adding a check for nonzero Kairo supply here makes Truffle go apeshit. Edge case anyways, so whatevs.
      newBalance = newBalance.add(totalCommission.mul(cToken.balanceOf(participant)).div(cToken.totalSupply()));
      //Update balance
      balanceOf[participant] = newBalance;
    }

    uint256 newTotalFunds = newTotalRegularFunds.add(totalCommission);
    ROI(cycleNumber, totalFundsInWeis, newTotalFunds);
    totalFundsInWeis = newTotalFunds;

    developerFeeAccount.transfer(devFee);
    oraclize.transfer(oraclizeFee);

    CommissionPaid(cycleNumber, totalCommission);
  }

  function __addControlTokenReceipientAsParticipant(address _receipient) public {
    require(msg.sender == controlTokenAddr);
    isParticipant[_receipient] = true;
    participants.push(_receipient);
  }

  function __makeOrder(address _tokenGet, uint _amountGet, address _tokenGive, uint _amountGive, uint _expires, uint _nonce) public onlyOraclize {
    etherDelta.order(_tokenGet, _amountGet, _tokenGive, _amountGive, _expires, _nonce);
  }

  function __setBuyPriceAndExpirationBlock(uint256 _proposalId, uint256 _buyPrice, uint256 _expires) public onlyOraclize {
    proposals[_proposalId].buyPriceInWeis = _buyPrice;
    proposals[_proposalId].buyOrderExpirationBlockNum = _expires;
  }

  function __setSellPriceAndExpirationBlock(uint256 _proposalId, uint256 _sellPrice, uint256 _expires) public onlyOraclize {
    proposals[_proposalId].sellPriceInWeis = _sellPrice;
    proposals[_proposalId].sellOrderExpirationBlockNum = _expires;
  }

  function() public payable {
    if (msg.sender != etherDeltaAddr && msg.sender != oraclizeAddr) {
      revert();
    }
  }
}

contract OraclizeHandler is usingOraclize, Ownable {
  using SafeMath for uint256;

  enum CyclePhase { ChangeMaking, ProposalMaking, Waiting, Ended, Finalized }

  // URL for querying prices, default is set to cryptocompare
  // Later on, modify this to be more flexible for additional queries, etc.
  string public priceCheckURL1;
  string public priceCheckURL2;
  string public priceCheckURL3;

  address public controlTokenAddr;
  address public etherDeltaAddr;

  mapping(bytes32 => uint256) public proposalIdOfQuery;

  GroupFund internal groupFund;
  ControlToken internal cToken;
  EtherDelta internal etherDelta;

  string[] public tokenSymbolOfProposal;

  function OraclizeHandler(address _controlTokenAddr, address _etherDeltaAddr) public {
    controlTokenAddr = _controlTokenAddr;
    etherDeltaAddr = _etherDeltaAddr;
    cToken = ControlToken(_controlTokenAddr);
    etherDelta = EtherDelta(_etherDeltaAddr);
    // Initialize cryptocompare URLs:
    priceCheckURL1 = "json(https://min-api.cryptocompare.com/data/price?fsym=";
    priceCheckURL2 = "&tsyms=";
    priceCheckURL3 = ").ETH";
  }

  function __changeEtherDeltaAddress(address _newAddr) public onlyOwner {
    etherDeltaAddr = _newAddr;
    etherDelta = EtherDelta(_newAddr);
  }

  function __pushTokenSymbolOfProposal(string _tokenSymbol) public onlyOwner {
    tokenSymbolOfProposal.push(_tokenSymbol);
  }

  function __deleteTokenSymbolOfProposal() public onlyOwner {
    delete tokenSymbolOfProposal;
  }

  function __returnAllFunds() public onlyOwner {
    owner.transfer(this.balance);
  }

  function __oraclizeFee() public view returns(uint256) {
    return oraclize_getPrice("URL");
  }

  // *******
  //Oraclize functions
  // *******

  // Query Oraclize for the current price
  function __grabCurrentPriceFromOraclize(uint _proposalId) public payable onlyOwner {
    require(oraclize_getPrice("URL") <= this.balance);

    groupFund = GroupFund(owner);

    string storage tokenSymbol = tokenSymbolOfProposal[_proposalId];

    // Grab the cryptocompare URL that is the price in ETH of the token to purchase
    string memory etherSymbol = "ETH";
    string memory urlToQuery = strConcat(priceCheckURL1, tokenSymbol, priceCheckURL2, etherSymbol, priceCheckURL3);

    // Call Oraclize to grab the most recent price information via JSON
    proposalIdOfQuery[oraclize_query("URL", urlToQuery)] = _proposalId;
  }

  // Callback function from Oraclize query:
  function __callback(bytes32 _myID, string _result) public {
    require(msg.sender == oraclize_cbAddress());

    // Require the callback response to be non-empty:
    require(keccak256(_result) != keccak256(""));

    groupFund = GroupFund(owner);

    // Grab ETH price in Weis
    uint256 priceInWeis = parseInt(_result, 18);

    uint256 proposalId = proposalIdOfQuery[_myID];
    var (tokenAddress, _, decimals,) = groupFund.proposals(proposalId);

    uint256 investAmount = groupFund.totalFundsInWeis().mul(groupFund.forStakedControlOfProposal(proposalId)).div(cToken.totalSupply());
    uint256 expires = block.number.add(groupFund.orderExpirationTimeInBlocks());
    if (uint(groupFund.cyclePhase()) == uint(CyclePhase.Waiting)) {
      //Buy
      groupFund.__setBuyPriceAndExpirationBlock(proposalId, priceInWeis, expires);

      uint256 buyTokenAmount = investAmount.mul(10**decimals).div(priceInWeis);
      groupFund.__makeOrder(tokenAddress, buyTokenAmount, address(0), investAmount, expires, proposalId);
    } else if (uint(groupFund.cyclePhase()) == uint(CyclePhase.Ended)) {
      //Sell
      groupFund.__setSellPriceAndExpirationBlock(proposalId, priceInWeis, expires);

      uint256 sellTokenAmount = etherDelta.tokens(tokenAddress, owner);
      uint256 getWeiAmount = sellTokenAmount.mul(priceInWeis).div(10**decimals);
      groupFund.__makeOrder(address(0), getWeiAmount, tokenAddress, sellTokenAmount, expires, proposalId);
    }

    //Reset data
    delete proposalIdOfQuery[_myID];
  }

  function() public payable {
    if (msg.sender != owner) {
      revert();
    }
  }
}

//Proportional to Wei when minted
contract ControlToken is MintableToken {
  using SafeMath for uint256;

  string public constant name = "Kairo";
  string public constant symbol = "KRO";
  uint8 public constant decimals = 18;

  event OwnerCollectFrom(address _from, uint256 _value);

  function transfer(address _to, uint256 _value) public returns(bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);

    //Add receipient as a participant if not already a participant
    addParticipant(_to);

    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);

    //Add receipient as a participant if not already a participant
    addParticipant(_to);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }

  function ownerCollectFrom(address _from, uint256 _value) public onlyOwner returns(bool) {
    require(_from != address(0));
    require(_value <= balances[_from]);

    // SafeMath.sub will throw if there is not enough balance.
    balances[_from] = balances[_from].sub(_value);
    balances[msg.sender] = balances[msg.sender].add(_value);
    OwnerCollectFrom(_from, _value);
    return true;
  }

  function addParticipant(address _to) internal {
    GroupFund groupFund = GroupFund(owner);
    if (!groupFund.isParticipant(_to)) {
      groupFund.__addControlTokenReceipientAsParticipant(_to);
    }
  }

  function burnOwnerBalance() public onlyOwner {
    totalSupply = totalSupply.sub(balances[owner]);
    balances[owner] = 0;
  }

  function() public {
    revert();
  }
}
