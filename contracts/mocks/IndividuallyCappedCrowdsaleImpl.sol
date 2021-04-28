//SPDX-License-Identifier: MIT

pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts3/token/ERC20/IERC20.sol";
import "../crowdsale/IndividuallyCappedCrowdsale.sol";

contract IndividuallyCappedCrowdsaleImpl is IndividuallyCappedCrowdsale {
    constructor (uint256 rate_, address payable wallet_, IERC20 token_, address capper) public IndividuallyCappedCrowdsale(rate_, wallet_, token_, capper) {
        // solhint-disable-previous-line no-empty-blocks
    }
}