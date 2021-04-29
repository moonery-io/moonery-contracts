//SPDX-License-Identifier: MIT

pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../crowdsale/TimedCrowdsale.sol";

contract TimedCrowdsaleImpl is TimedCrowdsale {
    constructor (uint256 openingTime, uint256 closingTime, uint256 rate_, address payable wallet_, IERC20 token_)
        public
        Crowdsale(rate_, wallet_, token_)
        TimedCrowdsale(openingTime, closingTime)
    {
        // solhint-disable-previous-line no-empty-blocks
    }

    function extendTime(uint256 closingTime) public {
        _extendTime(closingTime);
    }
}