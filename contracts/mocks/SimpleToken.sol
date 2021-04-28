//SPDX-License-Identifier: MIT

pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;


import "@openzeppelin/contracts3/token/ERC20/ERC20.sol";

/**
 * @title SimpleToken
 * @dev Very simple ERC20 Token example, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `ERC20` functions.
 */
contract SimpleToken is ERC20 {

    /**
     * @dev Constructor that gives _msgSender() all of existing tokens.
     */
    constructor () public ERC20("SimpleToken", "SIM") {
        _mint(_msgSender(), 10000 * (10 ** uint256(decimals())));
    }
}