//SPDX-License-Identifier: Unlicensed

pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/payment/escrow/Escrow.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract MooneryEscrowTimeLock is Escrow, ReentrancyGuard {
  using SafeERC20 for IERC20;
  address private _owner;
  address private _previousOwner;
  uint256 private _lockTime;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

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
    newToken_.safeTransfer(to, tokenAmount_);
  }

  fallback() external payable {
    deposit(msg.sender);
  }

  function geUnlockTime() public view returns (uint256) {
    return _lockTime;
  }

  /**
   * @return true if the MooneryEscrowTimeLock is open, false otherwise.
   */
  function isOpen() public view returns (bool) {
    // solhint-disable-next-line not-rely-on-time
    return block.timestamp <= geUnlockTime();
  }

  function withdraw(address payable payee) public virtual override onlyWhileOpen {
    super.withdraw(payee);
  }

  //Locks the contract for owner for the amount of time provided
  function lock(uint256 time) public virtual onlyOwner {
    _previousOwner = _owner;
    _owner = address(0);
    _lockTime = time;
    emit OwnershipTransferred(_owner, address(0));
  }

   //Unlocks the contract for owner when _lockTime is exceeds
    function unlock() public virtual {
      require(_previousOwner == msg.sender, "You don't have permission to unlock");
      require(now > _lockTime , "Contract is locked until locktime is over");
      emit OwnershipTransferred(_owner, _previousOwner);
      _owner = _previousOwner;
    }

}