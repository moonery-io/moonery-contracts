//SPDX-License-Identifier: Unlicensed

pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/payment/escrow/Escrow.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract MooneryEscrowTimeLock is Escrow, ReentrancyGuard {
  using Address for address;
  using SafeERC20 for IERC20;
  address private _owner;
  uint256 private _unlocktime;

  event TokenDeposited(IERC20 token, address indexed payee, uint256 weiAmount);
  event TokenWithdrawn(IERC20 token, address indexed payee, uint256 weiAmount);

   mapping (address => mapping (address => uint256)) private _tokenDeposits;

  /**
   * @dev Reverts if not in crowdsale time range.
    */
  modifier onlyWhileOpen {
    require(isOpen(), "MooneryEscrowTimeLock: not open");
    _;
  }

  // External functions
  function fallbackRedeem(IERC20 newToken_, uint256 tokenAmount_, address to) 
    external 
    onlyWhileOpen 
    onlyOwner 
  {
    require(address(newToken_) != address(0), "MooneryEscrowTimeLock: token adress is the zero address");
    require(to != address(0), "MooneryEscrowTimeLock: transfer to the zero address");
    require(tokenAmount_ > 0, "MooneryEscrowTimeLock: amount is zero");
    newToken_.safeTransfer(to, tokenAmount_);
    emit TokenWithdrawn(newToken_, msg.sender, tokenAmount_);
  }

  fallback() external payable {
    deposit(msg.sender);
  }

  function tokenDepositsOf(IERC20 token, address payee) public view returns (uint256) {
    return _tokenDeposits[address(token)][payee];
  }

  /**
   * @dev Stores the sent amount as credit to be withdrawn.
   * @param payee The destination address of the funds.
   */
  function tokenDeposit(IERC20 token, address payee, uint256 amount) public {
    require(address(token) != address(0), "MooneryEscrowTimeLock: token adress is the zero address");
    require(payee != address(0), "MooneryEscrowTimeLock: transfer to the zero address");
    require(amount > 0, "MooneryEscrowTimeLock: amount is zero");
    _tokenDeposits[address(token)][payee] = _tokenDeposits[address(token)][payee].add(amount);

    token.safeTransferFrom(msg.sender, address(this), amount);

    emit TokenDeposited(token, payee, amount);
  }

  function geUnlockTime() public view returns (uint256) {
    return _unlocktime;
  }

  /**
   * @return true if the MooneryEscrowTimeLock is open, false otherwise.
   */
  function isOpen() public view returns (bool) {
    // solhint-disable-next-line not-rely-on-time
    return geUnlockTime() < block.timestamp;
  }

  function withdraw(address payable payee) public virtual override onlyWhileOpen {
    require(payee != address(0), "MooneryEscrowTimeLock: withdraw to the zero address");
    super.withdraw(payee);
  }

  function tokenWithdraw(IERC20 token, address payable payee) public virtual onlyWhileOpen {
    require(address(token) != address(0), "MooneryEscrowTimeLock: token adress is the zero address");
    require(payee != address(0), "MooneryEscrowTimeLock: withdraw to the zero address");
    uint256 payment = _tokenDeposits[address(token)][payee];

    _tokenDeposits[address(token)][payee] = 0;

    token.safeTransfer(payee, payment);

    emit TokenWithdrawn(token, payee, payment);
  }

  //Locks the contract for owner for the amount of time provided
  function lock(uint256 unlocktime) public virtual onlyOwner {
    _unlocktime = unlocktime;
  }

}