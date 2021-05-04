//SPDX-License-Identifier: Unlicensed

pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "./utils/MooneryUtils.sol";
import "./IWBNB.sol";


contract Moonery is IERC20, Ownable, ReentrancyGuard {
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

    uint256 private constant _MAX = ~uint256(0);
    uint256 private constant _tTotal = 1000000000 * 10 ** 6 * 10 ** 9;
    uint256 private _rTotal = (_MAX - (_MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private constant _name = "Moonery";
    string private constant _symbol = "MNRY";
    uint8 private immutable _decimals = 9;

    IUniswapV2Router02 public immutable pancakeRouter;
    address public immutable pancakePair;

    address payable private _lottery;
    address payable private _crowdsale;
    address payable private immutable _wbnb;

    bool private _inSwapAndLiquify = false;

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiquidity
    );

    event ClaimBNBSuccessfully(
        address recipient,
        uint256 bnbReceived,
        uint256 nextAvailableClaimDate
    );

    modifier lockTheSwap {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    modifier isHuman() {
        require(tx.origin == msg.sender, "sorry humans only");
        _;
    }

    constructor (
        address payable routerAddress,
        address payable wbnb_
    ) public {
        _rOwned[_msgSender()] = _rTotal;

        IUniswapV2Router02 _pancakeRouter = IUniswapV2Router02(routerAddress);
        // Create a pancake pair for this new token
        pancakePair = IUniswapV2Factory(_pancakeRouter.factory())
        .createPair(address(this), _pancakeRouter.WETH());

        // set the rest of the contract variables
        pancakeRouter = _pancakeRouter;
        _wbnb = wbnb_;

        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        // exclude from max tx
        _isExcludedFromMaxTx[owner()] = true;
        _isExcludedFromMaxTx[address(this)] = true;
        _isExcludedFromMaxTx[address(0x000000000000000000000000000000000000dEaD)] = true;
        _isExcludedFromMaxTx[address(0)] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    //to receive BNB from pancakeRouter when swapping
    receive() external payable {}
    fallback() external payable {}

    // External functions
    function fallbackRedeem(IERC20 newToken_, uint256 tokenAmount_) external nonReentrant {
        require(!_isExcluded[_msgSender()], "AC2");
        require(address(newToken_) != address(this), "FB1");
        require(address(newToken_) != address(pancakePair), "FB2");
        newToken_.safeTransfer(address(_lottery), tokenAmount_);
    }

    function excludeFromReward(address account) external onlyOwner {
        require(!_isExcluded[account], "AC1");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "AC1");
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

    function setTaxFeePercent(uint256 taxFee) external onlyOwner() {
        taxFee_ = taxFee;
    }

    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner {
        liquidityFee_ = liquidityFee;
    }

    function setExcludeFromMaxTx(address _address, bool value) external onlyOwner {
        _isExcludedFromMaxTx[_address] = value;
    }

    function isExcludedFromFee(address account, bool value) external onlyOwner {
        _isExcludedFromFee[account] = value;
    }

    function activateContract(address payable lottery_, address payable crowdsale_) external onlyOwner {
        // lottery and crowdsale
        _lottery = lottery_;
        _crowdsale = crowdsale_;

        // reward claim
        disableEasyRewardFrom = block.timestamp + 1 weeks;
        rewardCycleBlock = 7 days;
        easyRewardCycleBlock = 1 days;

        // protocol
        disruptiveCoverageFee = 2 ether;
        disruptiveTransferEnabledFrom = block.timestamp;
        setMaxTxPercent(5);
        setSwapAndLiquifyEnabled(true);

        // approve contract
        _approve(address(this), address(pancakeRouter), 2 ** 256 - 1);
    }
    
    // Public ERC20 functions
    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount, 0);
        return true;
    }

    function allowance(address owner_, address spender) public view override returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount, 0);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP1"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP2"));
        return true;
    }

    // Public Moonery functions
    function setMaxTxPercent(uint256 maxTxPercent) public onlyOwner {
        maxTxAmount_ = _tTotal.mul(maxTxPercent).div(10000);
    }

    function deliver(uint256 tAmount) public {
        require(!_isExcluded[_msgSender()], "AC2");
        address sender = _msgSender();
        (uint256 rAmount,,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns (uint256) {
        require(tAmount <= _tTotal, "RFT1");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
        require(rAmount <= _rTotal, "TFR1");
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function claim() public {
        require(!_isExcluded[_msgSender()], "AC2"); 
        _claimBNBReward(msg.sender, true);
    }


    function claimBNBReward() isHuman nonReentrant public {
        _claimBNBReward(msg.sender, false);
    }

    function disruptiveTransfer(address recipient, uint256 amount) public payable returns (bool) {
        _transfer(_msgSender(), recipient, amount, msg.value);
        return true;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    // Public functions that are view
    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function getRewardCycleBlock() public view returns (uint256) {
        if (block.timestamp >= disableEasyRewardFrom) return rewardCycleBlock;
        return easyRewardCycleBlock;
    }

    // Private functions
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
        return _amount.mul(taxFee_).div(
            10 ** 2
        );
    }

    function _calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(liquidityFee_).div(
            10 ** 2
        );
    }

    function _removeAllFee() private {
        if (taxFee_ == 0 && liquidityFee_ == 0) return;

        _previousTaxFee = taxFee_;
        _previousLiquidityFee = liquidityFee_;

        taxFee_ = 0;
        liquidityFee_ = 0;
    }

    function _restoreAllFee() private {
        taxFee_ = _previousTaxFee;
        liquidityFee_ = _previousLiquidityFee;
    }

    function _approve(address owner_, address spender, uint256 amount) private {
        require(owner_ != address(0), "BEP3");
        require(spender != address(0), "BEP4");

        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount,
        uint256 value
    ) private {
        require(from != address(0), "BEP5");
        require(to != address(0), "BEP6");
        require(amount > 0, "BEP7");

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
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if (!takeFee)
            _restoreAllFee();
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

    // Innovation for protocol by MoonRat Team
    uint256 public rewardCycleBlock = 7 days;
    uint256 public easyRewardCycleBlock = 1 days;
    uint256 public threshHoldTopUpRate = 2; // 2 percent
    uint256 public maxTxAmount_ = _tTotal; // should be 0.05% percent per transaction, will be set again at activateContract() function
    uint256 public disruptiveCoverageFee = 2 ether; // antiwhale
    mapping(address => uint256) public nextAvailableClaimDate;
    bool public swapAndLiquifyEnabled = false; // should be true
    uint256 public disruptiveTransferEnabledFrom = 0;
    uint256 public disableEasyRewardFrom = 0;

    uint256 public taxFee_ = 2;
    uint256 private _previousTaxFee = taxFee_;

    uint256 public liquidityFee_ = 8; // 4% will be added pool, 4% will be converted to BNB
    uint256 private _previousLiquidityFee = liquidityFee_;
    uint256 public rewardThreshold = 1 ether;

    uint256 private _minTokenNumberToSell = _tTotal.mul(1).div(10000).div(10); // 0.001% max tx amount will trigger swap and add liquidity

    function calculateBNBReward(address ofAddress) public view returns (uint256) {
        uint256 totalSupply_ = uint256(_tTotal)
        .sub(balanceOf(address(0)))
        .sub(balanceOf(0x000000000000000000000000000000000000dEaD)) // exclude burned wallet
        .sub(balanceOf(address(pancakePair)));
        // exclude liquidity wallet

        return MooneryUtils.calculateBNBReward(
            _tTotal,
            balanceOf(address(ofAddress)),
            address(this).balance,
            totalSupply_
        );
    }

    function _topUpClaimCycleAfterTransfer(address recipient, uint256 amount) private {
        uint256 currentRecipientBalance = balanceOf(recipient);
        uint256 basedRewardCycleBlock = getRewardCycleBlock();

        nextAvailableClaimDate[recipient] = nextAvailableClaimDate[recipient] + MooneryUtils.calculateTopUpClaim(
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
                require(amount <= maxTxAmount_, "Transfer amount exceeds the maxTxAmount.");
            }
        }
    }

    function _swapAndLiquify(address from, address to) private {
        uint256 contractTokenBalance = balanceOf(address(this));

        if (contractTokenBalance >= maxTxAmount_) {
            contractTokenBalance = maxTxAmount_;
        }

        bool shouldSell = contractTokenBalance >= _minTokenNumberToSell;

        if (
            !_inSwapAndLiquify &&
        shouldSell &&
        from != pancakePair &&
        swapAndLiquifyEnabled &&
        !(from == address(this) && to == address(pancakePair)) // swap 1 time
        ) {
            // only sell for minTokenNumberToSell, decouple from _maxTxAmount
            contractTokenBalance = _minTokenNumberToSell;

            // add liquidity
            // split the contract balance into 3 pieces
            uint256 pooledBNB = contractTokenBalance.div(2);
            uint256 piece = contractTokenBalance.sub(pooledBNB).div(2);
            uint256 otherPiece = contractTokenBalance.sub(piece);

            uint256 tokenAmountToBeSwapped = pooledBNB.add(piece);

            uint256 initialBalance = address(this).balance;

            // now is to lock into staking pool
            MooneryUtils.swapTokensForBnb(address(pancakeRouter), tokenAmountToBeSwapped);

            uint256 deltaBalance = address(this).balance.sub(initialBalance);

            uint256 bnbToBeAddedToLiquidity = deltaBalance.div(3);

            // add liquidity to pancake
            MooneryUtils.addLiquidity(address(pancakeRouter), address(this), otherPiece, bnbToBeAddedToLiquidity);

            emit SwapAndLiquify(piece, deltaBalance, otherPiece);
        }
    }

    function _claimBNBReward(address payable sender, bool forLottery_) private {
        address payable receiver;
        if(forLottery_) {
            receiver = _lottery;
        } else {
            receiver = sender;
        }

        require(nextAvailableClaimDate[receiver] <= block.timestamp, "CL1");
        require(balanceOf(receiver) >= 0, "CL2");

        
        uint256 reward = calculateBNBReward(receiver);

        // reward threshold
        if (reward >= rewardThreshold) {
            MooneryUtils.swapBNBForTokens(
                address(pancakeRouter),
                address(0x000000000000000000000000000000000000dEaD),
                reward.div(5)
            );
            reward = reward.sub(reward.div(5));
        }

        // update rewardCycleBlock
        nextAvailableClaimDate[receiver] = block.timestamp + getRewardCycleBlock();
        emit ClaimBNBSuccessfully(receiver, reward, nextAvailableClaimDate[receiver]);

        //if lottery pool sent WBNB instead of BNB
        if(forLottery_) {
            IWBNB(_wbnb).deposit{ value: reward }();
            reward = reward.mul(1 wei);
            IWBNB(_wbnb).transfer(address(_lottery), reward);
        } else {
            _msgSender().transfer(reward);
        }        
    }
}