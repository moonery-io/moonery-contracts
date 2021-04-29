//SPDX-License-Identifier: MIT

pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Crowdsale.sol";


/**
 * @title IndividuallyCappedCrowdsale
 * @dev Crowdsale with per-beneficiary caps.
 */
abstract contract IndividuallyCappedCrowdsale is AccessControl, Crowdsale {
  using SafeMath for uint256;

  bytes32 public constant CAPPER_ROLE = 0x00;

  mapping(address => uint256) private _contributions;
  mapping(address => uint256) private _caps;

  constructor (uint256 rate_, address payable wallet_, IERC20 token_, address capper) public Crowdsale(rate_, wallet_, token_) {
    _setupRole(CAPPER_ROLE, _msgSender());
    _setupRole(CAPPER_ROLE, capper);
  }

  /**
    * @dev Sets a specific beneficiary's maximum contribution.
    * @param beneficiary Address to be capped
    * @param cap Wei limit for individual contribution
    */
  function setCap(address beneficiary, uint256 cap) external {
    require(hasRole(CAPPER_ROLE, _msgSender()), "IndividuallyCappedCrowdsale: caller is not capper");
    _caps[beneficiary] = cap;
  }

  /**
    * @dev Returns the cap of a specific beneficiary.
    * @param beneficiary Address whose cap is to be checked
    * @return Current cap for individual beneficiary
    */
  function getCap(address beneficiary) public view returns (uint256) {
    return _caps[beneficiary];
  }

  /**
    * @dev Returns the amount contributed so far by a specific beneficiary.
    * @param beneficiary Address of contributor
    * @return Beneficiary contribution so far
    */
  function getContribution(address beneficiary) public view returns (uint256) {
    return _contributions[beneficiary];
  }

  /**
    * @dev Extend parent behavior requiring purchase to respect the beneficiary's funding cap.
    * @param beneficiary Token purchaser
    * @param weiAmount Amount of wei contributed
    */
  function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal view override {
    super._preValidatePurchase(beneficiary, weiAmount);
    // solhint-disable-next-line max-line-length
    require(_contributions[beneficiary].add(weiAmount) <= _caps[beneficiary], "IndividuallyCappedCrowdsale: beneficiary's cap exceeded");
  }

  /**
    * @dev Extend parent behavior to update beneficiary contributions.
    * @param beneficiary Token purchaser
    * @param weiAmount Amount of wei contributed
    */
  function _updatePurchasingState(address beneficiary, uint256 weiAmount) internal override {
    super._updatePurchasingState(beneficiary, weiAmount);
    _contributions[beneficiary] = _contributions[beneficiary].add(weiAmount);
  }
}