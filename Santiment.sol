/**
 *Submitted for verification at basescan.org on 2023-08-10
*/

// File: contracts/Context.sol


// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
  function _msgSender() internal view virtual returns (address) {
    return msg.sender;
  }

  function _msgData() internal view virtual returns (bytes calldata) {
    return msg.data;
  }
}

// File: contracts/Ownable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev Initializes the contract setting the deployer as the initial owner.
     */
  constructor() {
    _transferOwnership(_msgSender());
  }

  /**
   * @dev Throws if called by any account other than the owner.
     */
  modifier onlyOwner() {
    _checkOwner();
    _;
  }

  /**
   * @dev Returns the address of the current owner.
     */
  function owner() public view virtual returns (address) {
    return _owner;
  }

  /**
   * @dev Throws if the sender is not the owner.
     */
  function _checkOwner() internal view virtual {
    require(owner() == _msgSender(), "Ownable: caller is not the owner");
  }

  /**
   * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
  function renounceOwnership() public virtual onlyOwner {
    _transferOwnership(address(0));
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
  function transferOwnership(address newOwner) public virtual onlyOwner {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    _transferOwnership(newOwner);
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
  function _transferOwnership(address newOwner) internal virtual {
    address oldOwner = _owner;
    _owner = newOwner;
    emit OwnershipTransferred(oldOwner, newOwner);
  }
}

// File: contracts/SanrSharesV1.sol

pragma solidity >=0.8.2 <0.9.0;

contract SanrSharesV1 is Ownable {
  address public protocolFeeDestination;
  uint256 public protocolFeePercent;
  uint256 public subjectFeePercent;

  uint256 public subjectsCount;

  event Trade(address indexed trader, address indexed subject, bool indexed isBuy, uint256 shareAmount, uint256 ethAmount, uint256 protocolEthAmount, uint256 referralsEthAmount, uint256 subjectEthAmount, uint256 supply);
  event FirstTrade(address subject);

  // SharesSubject => (Holder => Balance)
  mapping(address => mapping(address => uint256)) public sharesBalance;
  // SharesSubject => Supply
  mapping(address => uint256) public sharesSupply;
  // WhoWasInvited => InvitedBy
  mapping(address => address) public referrals;
  // Level => Fee Percent
  mapping(uint256 => uint256) public referralLevelsFeePercents;
  // Inviter => earned
  mapping(address => uint256) public earnedByReferralFees;
  // Subject => earned
  mapping(address => uint256) public earnedBySubjectFees;


  //for owner

  function setFeeDestination(address _feeDestination) public onlyOwner {
    protocolFeeDestination = _feeDestination;
  }

  function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
    protocolFeePercent = _feePercent;
  }

  function setSubjectFeePercent(uint256 _feePercent) public onlyOwner {
    subjectFeePercent = _feePercent;
  }

  function setReferralLevelFeePercent(uint256 _feePercent, uint256 _level) public onlyOwner {
    referralLevelsFeePercents[_level] = _feePercent;
  }


  // view

  function getPrice(uint256 supply, uint256 amount) public pure returns (uint256) {
    uint256 sum1 = supply == 0 ? 0 : (supply - 1) * (supply) * (2 * (supply - 1) + 1) / 6;
    uint256 sum2 = supply == 0 && amount == 1 ? 0 : (supply + amount - 1) * (supply + amount) * (2 * (supply + amount - 1) + 1) / 6;
    uint256 summation = sum2 - sum1;
    return summation * 1 ether / 16000;
  }

  function getBuyPrice(address sharesSubject, uint256 amount) public view returns (uint256) {
    return getPrice(sharesSupply[sharesSubject], amount);
  }

  function getSellPrice(address sharesSubject, uint256 amount) public view returns (uint256) {
    return getPrice(sharesSupply[sharesSubject] - amount, amount);
  }

  function getReferralsFee(address sharesSubject, uint256 price) public view returns (uint256) {
    address prevReferral = sharesSubject;
    uint256 referralsFee = 0;
    for (uint256 i = 0;; i++) {
      uint256 referralFeePercent = referralLevelsFeePercents[i];
      if (referralFeePercent == 0) break;

      address referral;
      if (prevReferral == owner()) referral = owner();
      else {
        referral = referrals[prevReferral];
        if (referral == address(0)) break;
      }
      prevReferral = referral;

      referralsFee += price * referralFeePercent / 1 ether;
    }

    return referralsFee;
  }

  function getBuyPriceAfterFee(address sharesSubject, uint256 amount) public view returns (uint256) {
    uint256 price = getBuyPrice(sharesSubject, amount);
    uint256 protocolFee = price * protocolFeePercent / 1 ether;
    uint256 subjectFee = price * subjectFeePercent / 1 ether;

    uint256 referralsFee = getReferralsFee(sharesSubject, price);

    return price + protocolFee + subjectFee + referralsFee;
  }

  function getSellPriceAfterFee(address sharesSubject, uint256 amount) public view returns (uint256) {
    uint256 price = getSellPrice(sharesSubject, amount);
    uint256 protocolFee = price * protocolFeePercent / 1 ether;
    uint256 subjectFee = price * subjectFeePercent / 1 ether;

    uint256 referralsFee = getReferralsFee(sharesSubject, price);

    return price - protocolFee - subjectFee - referralsFee;
  }


  // view many

  function getBuyPricesAfterFee(address[] calldata sharesSubjects, uint256[] calldata amounts) public view returns (uint256[] memory prices) {
    prices = new uint256[](sharesSubjects.length);

    for (uint256 i; i < sharesSubjects.length; i++) {
      prices[i] = getBuyPriceAfterFee(sharesSubjects[i], amounts[i]);
    }
  }

  function getSellPricesAfterFee(address[] calldata sharesSubjects, uint256[] calldata amounts) public view returns (uint256[] memory prices) {
    prices = new uint256[](sharesSubjects.length);

    for (uint256 i; i < sharesSubjects.length; i++) {
      prices[i] = getSellPriceAfterFee(sharesSubjects[i], amounts[i]);
    }
  }


  // view many for mappings

  function getSharesBalance(address[] calldata sharesSubjects, address[] calldata holder) public view returns (uint256[] memory balance) {
    balance = new uint256[](sharesSubjects.length);

    for (uint256 i; i < sharesSubjects.length; i++) {
      balance[i] = sharesBalance[sharesSubjects[i]][holder[i]];
    }
  }

  function getSharesSupply(address[] calldata sharesSubjects) public view returns (uint256[] memory supply) {
    supply = new uint256[](sharesSubjects.length);

    for (uint256 i; i < sharesSubjects.length; i++) {
      supply[i] = sharesSupply[sharesSubjects[i]];
    }
  }

  function getReferrals(address[] calldata whoWasInvited) public view returns (address[] memory invitedBy) {
    invitedBy = new address[](whoWasInvited.length);

    for (uint256 i; i < whoWasInvited.length; i++) {
      invitedBy[i] = referrals[whoWasInvited[i]];
    }
  }

  function getReferralLevelsFeePercents(uint256[] calldata level) public view returns (uint256[] memory percents) {
    percents = new uint256[](level.length);

    for (uint256 i; i < level.length; i++) {
      percents[i] = referralLevelsFeePercents[level[i]];
    }
  }

  function getEarnedByReferralFees(address[] calldata inviter) public view returns (uint256[] memory earned) {
    earned = new uint256[](inviter.length);

    for (uint256 i; i < inviter.length; i++) {
      earned[i] = earnedByReferralFees[inviter[i]];
    }
  }

  function getEarnedBySubjectFees(address[] calldata subject) public view returns (uint256[] memory earned) {
    earned = new uint256[](subject.length);

    for (uint256 i; i < subject.length; i++) {
      earned[i] = earnedBySubjectFees[subject[i]];
    }
  }

  // core

  function _sendFeeToReferrals(address sharesSubject, uint256 price) private {
    address prevReferral = sharesSubject;
    for (uint256 i = 0;; i++) {
      uint256 referralFeePercent = referralLevelsFeePercents[i];
      if (referralFeePercent == 0) break;

      address referral;
      if (prevReferral == owner()) referral = owner();
      else {
        referral = referrals[prevReferral];
        if (referral == address(0)) break;
      }

      earnedByReferralFees[referral] += price * referralFeePercent / 1 ether;

      (bool success1,) = referral.call{value : price * referralFeePercent / 1 ether}("");
      require(success1, "Unable to send referral fee");

      prevReferral = referral;
    }
  }

  function buyFirstShare(address referral, uint256 amount) external payable {
    require(referral == owner() || referrals[referral] != address(0), "Invalid referral");
    referrals[msg.sender] = referral;

    _buyShares(msg.sender, amount);

    emit FirstTrade(msg.sender);
    subjectsCount++;
  }

  function buyShares(address sharesSubject, uint256 amount) external payable {
    require(sharesSupply[sharesSubject] > 0, "First share should be purchased by buyFirstShare");
    _buyShares(sharesSubject, amount);
  }

  function _buyShares(address sharesSubject, uint256 amount) private {
    uint256 supply = sharesSupply[sharesSubject];
    uint256 price = getPrice(supply, amount);
    uint256 protocolFee = price * protocolFeePercent / 1 ether;
    uint256 subjectFee = price * subjectFeePercent / 1 ether;

    uint256 referralsFee = getReferralsFee(sharesSubject, price);
    uint256 totalPrice = price + protocolFee + subjectFee + referralsFee;
    require(msg.value >= totalPrice, "Insufficient payment");
    if (msg.value > totalPrice) {
      (bool success0,) = msg.sender.call{value : msg.value - totalPrice}("");
      require(success0, "Unable to send change");
    }

    sharesBalance[sharesSubject][msg.sender] = sharesBalance[sharesSubject][msg.sender] + amount;
    sharesSupply[sharesSubject] = supply + amount;
    emit Trade(msg.sender, sharesSubject, true, amount, price, protocolFee, referralsFee, subjectFee, supply + amount);
    (bool success1,) = protocolFeeDestination.call{value : protocolFee}("");
    earnedBySubjectFees[sharesSubject] += subjectFee;
    (bool success2,) = sharesSubject.call{value : subjectFee}("");
    require(success1 && success2, "Unable to send funds");


    _sendFeeToReferrals(sharesSubject, price);
  }

  function sellShares(address sharesSubject, uint256 amount) external payable {
    uint256 supply = sharesSupply[sharesSubject];
    require(supply > amount, "Cannot sell the last share");
    uint256 price = getPrice(supply - amount, amount);
    uint256 protocolFee = price * protocolFeePercent / 1 ether;
    uint256 subjectFee = price * subjectFeePercent / 1 ether;
    uint256 referralsFee = getReferralsFee(sharesSubject, price);
    require(sharesBalance[sharesSubject][msg.sender] >= amount, "Insufficient shares");
    sharesBalance[sharesSubject][msg.sender] = sharesBalance[sharesSubject][msg.sender] - amount;
    sharesSupply[sharesSubject] = supply - amount;
    emit Trade(msg.sender, sharesSubject, false, amount, price, protocolFee, referralsFee, subjectFee, supply - amount);
    (bool success1,) = msg.sender.call{value : price - protocolFee - subjectFee - referralsFee}("");
    (bool success2,) = protocolFeeDestination.call{value : protocolFee}("");
    earnedBySubjectFees[sharesSubject] += subjectFee;
    (bool success3,) = sharesSubject.call{value : subjectFee}("");
    require(success1 && success2 && success3, "Unable to send funds");

    _sendFeeToReferrals(sharesSubject, price);
  }
}