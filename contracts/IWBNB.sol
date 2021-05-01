//SPDX-License-Identifier: Unlicensed

pragma solidity >=0.6.8 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IWBNB is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}