//SPDX-License-Identifier: Unlicensed

pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts3/access/AccessControl.sol";
import "@openzeppelin/contracts3/utils/Address.sol";
import "@openzeppelin/contracts3/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts3/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts3/access/Ownable.sol";
import "@openzeppelin/contracts3/utils/ReentrancyGuard.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";


import "./Utils.sol";

contract Moonery is AccessControl, IERC20, Ownable, ReentrancyGuard, Utils {
    using SafeMath for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;
    mapping(address => bool) private _isExcludedFromMaxTx;

    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 1000000000 * 10 ** 6 * 10 ** 9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private _name = "Moonery";
    string private _symbol = "MNRY";
    uint8 private _decimals = 9;

    IUniswapV2Router02 public immutable pancakeRouter;
    address private immutable _pancakePair;

    address payable private _lottery;
    address payable private _crowdsale;

    bool inSwapAndLiquify = false;

    // Innovation for protocol by MoonRat Team
    uint256 public rewardCycleBlock = 7 days;
    uint256 public easyRewardCycleBlock = 1 days;
    uint256 public threshHoldTopUpRate = 2; // 2 percent
    uint256 public _maxTxAmount = _tTotal; // should be 0.05% percent per transaction, will be set again at activateContract() function
    uint256 public disruptiveCoverageFee = 2 ether; // antiwhale
    mapping(address => uint256) public nextAvailableClaimDate;
    bool public swapAndLiquifyEnabled = false; // should be true
    uint256 public disruptiveTransferEnabledFrom = 0;
    uint256 public disableEasyRewardFrom = 0;
    uint256 public winningDoubleRewardPercentage = 5;

    uint256 public _taxFee = 2;
    uint256 private _previousTaxFee = _taxFee;

    uint256 public _liquidityFee = 8; // 4% will be added pool, 4% will be converted to BNB
    uint256 private _previousLiquidityFee = _liquidityFee;
    uint256 public rewardThreshold = 1 ether;

    uint256 minTokenNumberToSell = _tTotal.mul(1).div(10000).div(10); // 0.001% max tx amount will trigger swap and add liquidity

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event ClaimBNBSuccessfully(
        address recipient,
        uint256 ethReceived,
        uint256 nextAvailableClaimDate
    );

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    modifier isHuman() {
        require(tx.origin == msg.sender, "Moonery: only humans");
        _;
    }

    constructor (
        address payable routerAddress_
    ) public {
        _rOwned[_msgSender()] = _rTotal;

        IUniswapV2Router02 pancakeRouter_ = IUniswapV2Router02(routerAddress_);
        // Create a pancake pair for this new token
        _pancakePair = IUniswapV2Factory(pancakeRouter_.factory())
        .createPair(address(this), pancakeRouter_.WETH());

        // set the rest of the contract variables
        pancakeRouter = pancakeRouter_;

        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        // exclude from max tx
        _isExcludedFromMaxTx[owner()] = true;
        _isExcludedFromMaxTx[address(this)] = true;
        _isExcludedFromMaxTx[address(0x000000000000000000000000000000000000dEaD)] = true;
        _isExcludedFromMaxTx[address(0)] = true;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    //to receive BNB from pancakeRouter when swapping
    // This function is called for plain Ether transfers, i.e.
    // for every call with empty calldata.
    receive() external payable {}

    // This function is called for all messages sent to
    // this contract, except plain Ether transfers
    // (there is no other function except the receive function).
    // Any call with non-empty calldata to this contract will execute
    // the fallback function (even if Ether is sent along with the call).
    fallback() external {}

    // External functions

    /**
     * @dev Faalback Redeem tokens. The ability to redeem token whe okenst are accidentally sent to the contract
    *
     *
     * Requirements:
     *
     * - `msg_sender` sender must be an admin.
     * - `to` cannot be zero address.
      * - `to` cannot be this address.
     * - `newToken_` be zero address.
     * - `newToken_` cannot redeem $MNRY.
     * - `newToken_` cannot redeem pancakePair.
     *
     * @param newToken_ Address of the token
     * @param amount Number of tokens to be emitted
     * @param to address Recipient of the recovered tokens
    */
    function fallbackRedeem(IERC20 newToken_, uint256 amount,  address payable to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Moonery: caller is not admin");
        require(to != address(0), "Moonery: cannot recover to zero address");
        require(to != address(this), "Moonery: cannot recover to zero address");
        require(newToken_ != IERC20(0), "Moonery: token cannot be zero address");
        require(newToken_ != IERC20(this), "Moonery: cannot redeem $MNRY");
        require(newToken_ != IERC20(pancakePair()), "Moonery: cannot redeem $LP");
        newToken_.safeTransfer(to, amount);
    }

    /**
     * @dev include an account in reward
     *
     *
     * Requirements:
     *
     * - `msg_sender` sender must be an admin.
     * - `account` cannot be the zero address.
     * - `account` cannot already included.
     */
    function includeInReward(address account) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Moonery: caller is not admin");
        require(account != address(0), "Moonery: account cannot be zero address");
        require(isExcludedFromReward(account), "Moonery: account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    /**
     * @dev exclude an account from reward
     *
     *
     * Requirements:
     *
     * - `msg_sender` sender must be an admin.
     * - `account` cannot be the zero address.
     * - `account` cannot already excluded.
     */
    function excludeFromReward(address account) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Moonery: caller is not admin");
        require(account != address(0), "Moonery: account cannot be zero address");
        require(!isExcludedFromReward(account), "Moonery: account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    /**
     * @dev set tax fee precentage
     *
     *
     * Requirements:
     *
     * - `msg_sender` sender must be an admin.
     * - `taxFee_` cannot be the same value.
     */
    function setTaxFeePercent(uint256 taxFee_) external returns (bool) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Moonery: caller is not admin");
        require(taxFee_ != _taxFee, "Moonery: taxFee_ cannot be the same value");
        _taxFee = taxFee_;

        return true;
    }

    /**
     * @dev set liquidity fee precentage
     *
     *
     * Requirements:
     *
     * - `msg_sender` sender must be an admin.
     * - `liquidityFee_` cannot be the same value.
     */
    function setLiquidityFeePercent(uint256 liquidityFee_) external returns (bool) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Moonery: caller is not admin");
        require(liquidityFee_ != _liquidityFee, "Moonery: liquidityFee_ cannot be the same value");
        _liquidityFee = liquidityFee_;

        return true;
    }

    /**
     * @dev set excluded address from maximum precentage
     *
     *
     * Requirements:
     *
     * - `msg_sender` sender must be an admin.
     * - `account` cannot be the zero address.
     */
    function setExcludeFromMaxTx(address account, bool value_) external returns (bool) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Moonery: caller is not admin");
        require(account != address(0), "Moonery: account cannot be zero address");
        _isExcludedFromMaxTx[account] = value_;

        return true;
    }

    /**
     * @dev set include address from fee
     *
     *
     * Requirements:
     *
     * - `msg_sender` sender must be an admin.
     * - `account` cannot be the zero address.
     * - `account` had not been already excluded.
     */
    function excludeFromFee(address account) public returns (bool) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Moonery: caller is not admin");
        require(account != address(0), "Moonery: account cannot be zero address");
        require(isExcludedFromFee(account), "Moonery: account is already excluded");
        _isExcludedFromFee[account] = true;

        return true;
    }

    /**
     * @dev set include address in fee
     *
     *
     * Requirements:
     *
     * - `msg_sender` sender must be an admin.
     * - `account` cannot be the zero address.
     * - `account` had not been already included.
     */
    function includeInFee(address account) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Moonery: caller is not admin");
        require(account != address(0), "Moonery: account cannot be zero address");
        require(!isExcludedFromFee(account), "Moonery: account is already included");
        _isExcludedFromFee[account] = false;
    }

    /**
     * @dev set lottery
     *
     *
     * Requirements:
     *
     * - `msg_sender` sender must be an admin.
     * - `lottery_` sender cannot be zero.
     * - `lottery_` cannot be the same value.
     */
    function setLottery(address payable lottery_) external returns (bool) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Moonery: caller is not admin");
        require(lottery_ != _lottery, "Moonery: lottery_ cannot be the same value");
        require(lottery_ != address(0), "Moonery: lottery_ cannot be zero address");
        _lottery = lottery_;
        _isExcludedFromFee[lottery_] = true;
        _isExcludedFromMaxTx[lottery_] = true;   
        return true;
    }

    /**
     * @dev set crowdsale
     *
     *
     * Requirements:
     *
     * - `msg_sender` sender must be an admin.
     * - `crowdsale_` sender cannot be zero.
     * - `crowdsale_` cannot be the same value.
     */
    function setCrowdsale(address payable crowdsale_) external returns (bool) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Moonery: caller is not admin");
        require(crowdsale_ != _crowdsale, "Moonery: crowdsale_ cannot be the same value");
        require(crowdsale_ != address(0), "Moonery: crowdsale_ cannot be zero address");
        _crowdsale = crowdsale_;
        _isExcludedFromFee[crowdsale_] = true;
        _isExcludedFromMaxTx[crowdsale_] = true;  
        return true; 
    }

    function activateContract() external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Moonery: caller is not admin");
        // reward claim
        disableEasyRewardFrom = block.timestamp + 1 weeks;
        rewardCycleBlock = 7 days;
        easyRewardCycleBlock = 1 days;

        winningDoubleRewardPercentage = 5;

        // protocol
        disruptiveCoverageFee = 2 ether;
        disruptiveTransferEnabledFrom = block.timestamp;
        setMaxTxPercent(1);
        setSwapAndLiquifyEnabled(true);

        // approve contract
        _approve(address(this), address(pancakeRouter), 2 ** 256 - 1);
    }

    function activateTestNet() external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Moonery: caller is not admin");
        // reward claim
        disableEasyRewardFrom = block.timestamp;
        rewardCycleBlock = 30 minutes;
        easyRewardCycleBlock = 30 minutes;

        winningDoubleRewardPercentage = 5;

        // protocol
        disruptiveCoverageFee = 2 ether;
        disruptiveTransferEnabledFrom = block.timestamp;
        setMaxTxPercent(1);
        setSwapAndLiquifyEnabled(true);

        // approve contract
        _approve(address(this), address(pancakeRouter), 2 ** 256 - 1);
    }



    // External functions that are view
    // ...

    // External functions that are pure
    // ...

    // Public ERC20 functions
    
    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overloaded;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        if (isExcludedFromReward(account)) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount, 0);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount, 0);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    // Public Moonery functions

    /**
     * @dev Returns the address of the LP token (pancakePair)
     */
    function pancakePair() public view returns (address) {
        return _pancakePair;
    }

    /**
     * @dev Returns the address of lottery
     */
    function lottery() public view returns (address) {
        return _lottery;
    }

    
    /**
     * @dev Returns the address of crowdsale
     */
    function crowdsale() public view returns (address) {
        return _crowdsale;
    }

    /**
     * @dev Returns taxfee
     */
     function taxFee() public view returns (uint256) {
        return _taxFee;
    }

    /**
     * @dev Returns the address included from fee
     */
    function isExcludedFromFee(address account_) public view returns (bool) {
        return _isExcludedFromFee[account_];
    }
    

    /**
     * @dev Returns the address excluded from reward
     */
    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    /**
     * @dev Returns the address excluded from max trx
     */
    function isExcludedFromMaxTx(address account) public view returns (bool) {
        return _isExcludedFromMaxTx[account];
    }
        
    /**
     * @dev set maximum transaction precentage
     *
     *
     * Requirements:
     *
     * - `msg_sender` sender must be an admin.
     */
    function setMaxTxPercent(uint256 maxTxPercent_) public returns (bool) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Moonery: caller is not admin");
        _maxTxAmount = _tTotal.mul(maxTxPercent_).div(10000);
        return true;
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns (uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function disruptiveTransfer(address recipient, uint256 amount) public payable returns (bool) {
        _transfer(_msgSender(), recipient, amount, msg.value);
        return true;
    }

     function setSwapAndLiquifyEnabled(bool _enabled) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Moonery: caller is not admin");
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    // Internal functions
    // ...

    // Private functions
    // ...


    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        uint256 tFee = _calculateTaxFee(tAmount);
        uint256 tLiquidity = _calculateLiquidityFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        return (tTransferAmount, tFee, tLiquidity);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }

    function _calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(
            10 ** 2
        );
    }

    function _calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_liquidityFee).div(
            10 ** 2
        );
    }

    function _removeAllFee() private {
        if (_taxFee == 0 && _liquidityFee == 0) return;

        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;

        _taxFee = 0;
        _liquidityFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount,
        uint256 value
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "ERC20: transfer amount must be greater than zero");

        _ensureMaxTxAmount(from, to, amount, value);

        // swap and liquify
        _swapAndLiquify(from, to);

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
        if (!takeFee)
            _removeAllFee();

        // top up claim cycle
        _topUpClaimCycleAfterTransfer(recipient, amount);

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if (!takeFee)
            restoreAllFee();
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function calculateBNBReward(address ofAddress) public view returns (uint256) {
        uint256 totalSupply = uint256(_tTotal)
        .sub(balanceOf(address(0)))
        .sub(balanceOf(0x000000000000000000000000000000000000dEaD)) // exclude burned wallet
        .sub(balanceOf(pancakePair()));
        // exclude liquidity wallet

        return Utils.calculateBNBReward(
            _tTotal,
            balanceOf(address(ofAddress)),
            address(this).balance,
            winningDoubleRewardPercentage,
            totalSupply,
            ofAddress
        );
    }

    function getRewardCycleBlock() public view returns (uint256) {
        if (block.timestamp >= disableEasyRewardFrom) return rewardCycleBlock;
        return easyRewardCycleBlock;
    }

    function claimBNBReward() isHuman nonReentrant public {
        require(nextAvailableClaimDate[msg.sender] <= block.timestamp, 'Error: next available not reached');
        require(balanceOf(msg.sender) >= 0, 'Error: must own MRAT to claim reward');

        uint256 reward = calculateBNBReward(msg.sender);

        // reward threshold
        if (reward >= rewardThreshold) {
            Utils.swapETHForTokens(
                address(pancakeRouter),
                address(0x000000000000000000000000000000000000dEaD),
                reward.div(5)
            );
            reward = reward.sub(reward.div(5));
        }

        // update rewardCycleBlock
        nextAvailableClaimDate[msg.sender] = block.timestamp + getRewardCycleBlock();
        emit ClaimBNBSuccessfully(msg.sender, reward, nextAvailableClaimDate[msg.sender]);

        (bool sent,) = address(msg.sender).call{value : reward}("");
        require(sent, 'Error: Cannot withdraw reward');
    }

    function _topUpClaimCycleAfterTransfer(address recipient, uint256 amount) private {
        uint256 currentRecipientBalance = balanceOf(recipient);
        uint256 basedRewardCycleBlock = getRewardCycleBlock();

        nextAvailableClaimDate[recipient] = nextAvailableClaimDate[recipient] + Utils.calculateTopUpClaim(
            currentRecipientBalance,
            basedRewardCycleBlock,
            threshHoldTopUpRate,
            amount
        );
    }

    function _ensureMaxTxAmount(
        address from,
        address to,
        uint256 amount,
        uint256 value
    ) private {
        if (
            _isExcludedFromMaxTx[from] == false && // default will be false
            _isExcludedFromMaxTx[to] == false // default will be false
        ) {
            if (value < disruptiveCoverageFee && block.timestamp >= disruptiveTransferEnabledFrom) {
                require(amount <= _maxTxAmount, "Moonery: transfer amount exceeds the maxTxAmount.");
            }
        }
    }
    function _swapAndLiquify(address from, address to) private {
        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is pancake pair.
        uint256 contractTokenBalance = balanceOf(address(this));

        if (contractTokenBalance >= _maxTxAmount) {
            contractTokenBalance = _maxTxAmount;
        }

        bool shouldSell = contractTokenBalance >= minTokenNumberToSell;

        if (
            !inSwapAndLiquify &&
        shouldSell &&
        from != pancakePair() &&
        swapAndLiquifyEnabled &&
        !(from == address(this) && to == pancakePair()) // swap 1 time
        ) {
            // only sell for minTokenNumberToSell, decouple from _maxTxAmount
            contractTokenBalance = minTokenNumberToSell;

            // add liquidity
            // split the contract balance into 3 pieces
            uint256 pooledBNB = contractTokenBalance.div(2);
            uint256 piece = contractTokenBalance.sub(pooledBNB).div(2);
            uint256 otherPiece = contractTokenBalance.sub(piece);

            uint256 tokenAmountToBeSwapped = pooledBNB.add(piece);

            uint256 initialBalance = address(this).balance;

            // now is to lock into staking pool
            Utils.swapTokensForEth(address(pancakeRouter), tokenAmountToBeSwapped);

            // how much BNB did we just swap into?

            // capture the contract's current BNB balance.
            // this is so that we can capture exactly the amount of BNB that the
            // swap creates, and not make the liquidity event include any BNB that
            // has been manually sent to the contract
            uint256 deltaBalance = address(this).balance.sub(initialBalance);

            uint256 bnbToBeAddedToLiquidity = deltaBalance.div(3);

            // add liquidity to pancake
            Utils.addLiquidity(address(pancakeRouter), owner(), otherPiece, bnbToBeAddedToLiquidity);

            emit SwapAndLiquify(piece, deltaBalance, otherPiece);
        }
    }
}