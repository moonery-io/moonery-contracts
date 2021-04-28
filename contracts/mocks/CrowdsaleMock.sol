//SPDX-License-Identifier: MIT

pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "../crowdsale/Crowdsale.sol";

contract CrowdsaleMock is Crowdsale {
    constructor (uint256 rate_, address payable wallet_, IERC20 token_) public Crowdsale(rate_, wallet_, token_) {
        // solhint-disable-previous-line no-empty-blocks
    }
}