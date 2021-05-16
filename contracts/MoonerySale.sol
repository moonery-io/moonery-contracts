//SPDX-License-Identifier: MIT

pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@pooltogether/pooltogether-contracts/contracts/prize-pool/PrizePoolInterface.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./crowdsale/IndividuallyCappedCrowdsale.sol";

import "./access/Ownable.sol";

contract MoonerySale is IndividuallyCappedCrowdsale {
  using SafeMath for uint256;
  using Address for address;

  // The token being sold
  IERC20 private _token;

  uint256 private _rate;

  PrizePoolInterface private _lottery;
  address _controlledToken;

  constructor (uint256 rate_, address payable wallet_, IERC20 token_, address capper) public IndividuallyCappedCrowdsale(rate_, wallet_, token_, capper) {
    // solhint-disable-previous-line no-empty-blocks
    _token = token_;
  }

  // External functions
  function setLottery(PrizePoolInterface lottery_) external {
    require(hasRole(CAPPER_ROLE, _msgSender()), "MoonerySale: caller is not admin");
    require(address(lottery_) != address(0), "MoonerySale: lottery is zero address");
    require(address(lottery_) != address(_lottery), "MoonerySale: lottery cannot be the same value");
    _lottery = lottery_;
  }

  function setControlledToken(address controlledToken_) external {
    require(hasRole(CAPPER_ROLE, _msgSender()), "MoonerySale: caller is not admin");
    require(address(controlledToken_) != address(0), "MoonerySale: controlledToken is zero address");
    require(address(controlledToken_) != address(_controlledToken), "MoonerySale: controlledToken cannot be the same value");
    _controlledToken = controlledToken_;
  }

  function changeRate(uint256 rate_) external {
    require(hasRole(CAPPER_ROLE, _msgSender()), "MoonerySale: caller is not admin");
    _rate = rate_;
  }

  // Public ERC20 functions
  function lottery() public view returns (address) {
        return address(_lottery);
  }

  function controlledToken() public view returns (address) {
        return _controlledToken;
  }

  // private 
  /**
    * @dev Deliver tokens to Lottery contract as sponsor
    * @param beneficiary Address performing the token purchase
    * @param tokenAmount Number of tokens to be emitted
  */
  function _deliverTokens(address beneficiary, uint256 tokenAmount) internal override {
    _token.approve(address(_lottery), tokenAmount);
    _lottery.depositTo(beneficiary, tokenAmount, controlledToken(), beneficiary);
  }
}