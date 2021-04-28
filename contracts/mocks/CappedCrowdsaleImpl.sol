//SPDX-License-Identifier: MIT

pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts3/token/ERC20/IERC20.sol";
import "../crowdsale/CappedCrowdsale.sol";

contract CappedCrowdsaleImpl is CappedCrowdsale {
    constructor (uint256 rate_, address payable wallet_, IERC20 token_, uint256 cap_)
        public
        Crowdsale(rate_, wallet_, token_)
        CappedCrowdsale(cap_)
    {
        // solhint-disable-previous-line no-empty-blocks
    }
}