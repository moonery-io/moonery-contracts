const { balance, BN, constants, expectEvent, expectRevert, time, MaxUint256} = require('@openzeppelin/test-helpers');
const { expect } = require('chai');
const { utils, ContractFactory, Contract } = require('ethers');
const { artifacts } = require('hardhat');
const { ZERO_ADDRESS } = constants;

const  { abi, bytecode } = require('@uniswap/v2-periphery/build/UniswapV2Router02.json');
//const { UniswapV2Router02 } = require('@uniswap/v2-periphery/contracts/UniswapV2Router02.sol');

const {
  shouldBehaveLikeERC20,
  shouldBehaveLikeERC20Transfer,
  shouldBehaveLikeERC20Approve,
} = require('./behaviors/ERC20.behavior');
const ether = require('@openzeppelin/test-helpers/src/ether');

const Moonery = artifacts.require('Moonery');
//const UniswapV2Router02 = artifacts.require('UniswapV2Router02');

const overrides = {
  gasLimit: 9999999
}

contract('Moonery', function (accounts) {
  const [ initialHolder, recipient, anotherAccount, ...otherAccounts ] = accounts;

  const name = 'Moonery';
  const symbol = 'MNRY';
  const decimals = new BN(9);
  const taxFee = new BN(1);
  const initialSupply = '1000000000000000000000000';
  const amountToPancakeSwap = '300000000000000000000000';
  const router = '0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F';
  const routerV2 = '0x10ED43C718714eb63d5aA57B78B54704E256024E';
  const lottery = '0xdaa3249E3e5Ed1C2C70D73A860D0f2338C353527';
  const burnaddress = '0x000000000000000000000000000000000000dEaD';
  const maxTrxAmount = '100000000000000000000';
  const WETHAmount ='4000000000000000000';
  //const provider = new ethers.providers.JsonRpcProvider();
  //const signer = provider.getSigner(initialHolder);
  //const factory = new ContractFactory( JSON.stringify(abi), bytecode, signer);
  

  beforeEach(async function () {
    this.token = await Moonery.new(routerV2, {  from: initialHolder });
    this.tokenAddress = await this.token.address;
    await this.token.setLottery(lottery, {  from: initialHolder });
    //await this.token.setMoonerySale();
    //this.contract = await UniswapV2Router02.at(routerV2);
    //this.contract = await factory.attach(routerV2);
    //await this.token.approve(routerV2, amountToPancakeSwap, { from: initialHolder });
    /*
    await this.contract.addLiquidityETH(this.tokenAddress, amountToPancakeSwap, amountToPancakeSwap, WETHAmount, initialHolder, amountToPancakeSwap, {
      ...overrides,
      value: WETHAmount,
      from: initialHolder,
    });
    */
  });

  it('has a name', async function () {
    expect(await this.token.name()).to.equal(name);
  });

  it('has a symbol', async function () {
    expect(await this.token.symbol()).to.equal(symbol);
  });

  it('has decimals', async function () {
    expect(await this.token.decimals()).to.be.bignumber.equal(decimals);
  });

  it('totalsupply', async function () {
    expect(await this.token.totalSupply()).to.be.bignumber.equal(initialSupply);
  });

  it('has pancakepair', async function () {
    expect(await this.token.pancakePair()).to.be.properAddress;
  });

  it('has lottery', async function () {
    expect(await this.token.lottery()).to.be.properAddress;
  });

  context('_isExcluded', async function () {
    it('should excluded from reward', async function () {
      expect(await this.token.isExcludedFromReward(this.token.address)).to.be.equal(false);
      expect(await this.token.isExcludedFromReward(lottery)).to.be.equal(false);
      expect(await this.token.isExcludedFromReward(initialHolder)).to.be.equal(false);
      expect(await this.token.isExcludedFromReward(burnaddress)).to.be.equal(false);
    });
    describe('excludeFromReward', function () {
      it('should revert when account is not admin', async function () {
        await expectRevert(this.token.excludeFromReward(recipient, { from: anotherAccount }),
          'Moonery: caller is not admin',
        );
      });

      it('should revert when account is zero address', async function () {
        await expectRevert(this.token.excludeFromReward(ZERO_ADDRESS, { from: initialHolder }),
          'Moonery: account cannot be zero address',
        );
      });

      it('should exclude from reward', async function () {
        await this.token.excludeFromReward(burnaddress, { from: initialHolder });
        expect(await this.token.isExcludedFromReward(burnaddress)).to.be.equal(true);
      });
    });
    describe('includeInReward', function () {
      it('should revert when account is not admin', async function () {
        await expectRevert(this.token.includeInReward(recipient, { from: anotherAccount }),
          'Moonery: caller is not admin',
        );
      });

      it('should revert when account is zero address', async function () {
        await expectRevert(this.token.includeInReward(ZERO_ADDRESS, { from: initialHolder }),
          'Moonery: account cannot be zero address',
        );
      });

      it('should include in reward', async function () {
        await this.token.excludeFromReward(burnaddress, { from: initialHolder });
        expect(await this.token.isExcludedFromReward(burnaddress)).to.be.equal(true);
        await this.token.includeInReward(burnaddress, { from: initialHolder });
        expect(await this.token.isExcludedFromReward(burnaddress)).to.be.equal(false);
      });
    });
  });

  context('_isExcludedFromFee', async function () {
    describe('includeInFee', function () {
      it('should revert when account is not admin', async function () {
        await expectRevert(this.token.includeInFee(recipient, { from: anotherAccount }),
          'Moonery: caller is not admin',
        );
      });

      it('should revert when account is zero address', async function () {
        await expectRevert(this.token.includeInFee(ZERO_ADDRESS, { from: initialHolder }),
          'Moonery: account cannot be zero address',
        );
      });
  
      it('should revert when account already included', async function () {
        await expectRevert(this.token.includeInFee(lottery, { from: initialHolder }),
          'Moonery: account is already included',
        );
      });

      it('should exclude from fee', async function () {
        expect(await this.token.isExcludedFromFee(this.token.address)).to.be.equal(true);
        expect(await this.token.isExcludedFromFee(initialHolder)).to.be.equal(true);
        expect(await this.token.isExcludedFromFee(lottery)).to.be.equal(true);
      });

      it('should include in fee', async function () {
        await this.token.includeInFee(recipient, { from: initialHolder });
        expect(await this.token.isExcludedFromFee(recipient)).to.be.equal(false);
      });
    });

    describe('excludeFromFee', function () {
      it('should revert when account is not admin', async function () {
        await expectRevert(this.token.excludeFromFee(recipient, { from: anotherAccount }),
          'Moonery: caller is not admin',
        );
      });

      it('should revert when account is zero address', async function () {
        await expectRevert(this.token.excludeFromFee(ZERO_ADDRESS, { from: initialHolder }),
          'Moonery: account cannot be zero address',
        );
      });

      it('should exclude from fee', async function () {
        await this.token.excludeFromFee(lottery, { from: initialHolder });
        expect(await this.token.isExcludedFromFee(lottery)).to.be.equal(true);
      });
    });
  });

  context('_isExcludedFromMaxTx', async function () {
    it('should exclude from max tx', async function () {
      expect(await this.token.isExcludedFromMaxTx(this.token.address)).to.be.equal(true);
      expect(await this.token.isExcludedFromMaxTx(initialHolder)).to.be.equal(true);
      expect(await this.token.isExcludedFromMaxTx(lottery)).to.be.equal(true);
      expect(await this.token.isExcludedFromMaxTx(burnaddress)).to.be.equal(true);
    });

    describe('setExcludeFromMaxTx', function () {
      it('should revert when account is not admin', async function () {
        await expectRevert(this.token.setExcludeFromMaxTx(recipient, true, { from: anotherAccount }),
          'Moonery: caller is not admin',
        );
      });

      it('should revert when account is zero address', async function () {
        await expectRevert(this.token.setExcludeFromMaxTx(ZERO_ADDRESS, true, { from: initialHolder }),
          'Moonery: account cannot be zero address',
        );
      });

      it('should include from max tx', async function () {
        await this.token.setExcludeFromMaxTx(recipient, true, { from: initialHolder });
        expect(await this.token.isExcludedFromMaxTx(recipient)).to.be.equal(true);
      });

      it('should exclude from max tx', async function () {
        await this.token.setExcludeFromMaxTx(recipient, false, { from: initialHolder });
        expect(await this.token.isExcludedFromMaxTx(recipient)).to.be.equal(false);
      });
    });
  });

  describe('setTaxFeePercent', function () {
    it('should revert when account is not admin', async function () {
      await expectRevert(this.token.setTaxFeePercent(taxFee, { from: anotherAccount }),
        'Moonery: caller is not admin',
      );
    });
    it('should revert when taxfee has same value', async function () {
      await expectRevert(this.token.setTaxFeePercent(taxFee.addn(1), { from: initialHolder }),
        'Moonery: taxFee_ cannot be the same value',
      );
    });
    it('should change taxfee ', async function () {
      await this.token.setTaxFeePercent(taxFee, { from: initialHolder });
      expect(await this.token.taxFee()).to.be.bignumber.equal(taxFee);
    });
  });

  describe('setMaxTxPercent', function () {
    it('should revert when account is not admin', async function () {
      await expectRevert(this.token.setMaxTxPercent(taxFee, { from: anotherAccount }),
        'Moonery: caller is not admin',
      );
    });
  });

  it('should exclude from max transaction', async function () {
    expect(await this.token.isExcludedFromMaxTx(this.token.address)).to.be.equal(true);
    expect(await this.token.isExcludedFromMaxTx(initialHolder)).to.be.equal(true);
    expect(await this.token.isExcludedFromMaxTx(lottery)).to.be.equal(true);
    expect(await this.token.isExcludedFromMaxTx(burnaddress)).to.be.equal(true);
  });

  it('should be admin', async function () {
    const admin = await this.token.getRoleAdmin('0x00');
    expect(await this.token.hasRole(admin, initialHolder)).to.be.equal(true);
  });

  context('activate', async function () {
    it('reverts when sender not admin', async function () {
      await expectRevert(this.token.activateContract({ from: anotherAccount }),
        'Moonery: caller is not admin',
      );
    });

    beforeEach(async function () {
      await this.token.activateContract({ from: initialHolder });
      this.newTime = (await time.latest()).add(time.duration.seconds(1));
      this.openingTime = (await time.latest()).add(time.duration.weeks(1));
      await time.increaseTo( this.newTime );
    });

    it('swapAndLiquifyEnabled', async function () {
      expect(await this.token.swapAndLiquifyEnabled()).to.be.equal(true);
    });

    it('reward should disable for 1 weak', async function () {
      expect(await this.token.disableEasyRewardFrom()).to.be.bignumber.equal(this.openingTime);
    });

    context('transfer', async function () {
      beforeEach(async function () {
        await this.token.transfer( anotherAccount, maxTrxAmount, { from: initialHolder });
      });
  
      it('has balance', async function () {
        expect(await this.token.balanceOf(anotherAccount)).to.be.bignumber.equal(maxTrxAmount);
      });
  
      describe('whale protection', function () {
        it('spender sent maxTrxAmount', async function () {
          //expect(await this.token.maxTxAmount()).to.be.bignumber.equal(maxTrxAmount);
          expect(await this.token.isExcludedFromMaxTx(recipient)).to.be.equal(false);
          expect(await this.token.isExcludedFromMaxTx(anotherAccount)).to.be.equal(false);
          expect(await this.token.isExcludedFromFee(recipient)).to.be.equal(false);
          await expectRevert(this.token.transfer( recipient, maxTrxAmount+1, { from: anotherAccount }), 'Moonery: transfer amount exceeds the maxTxAmount.');
        });
      });

      context('taxes', async function () {
        describe('transactional tax', function () {
          it('should tax 10%', async function () {
            await this.token.transfer( recipient, maxTrxAmount, { from: anotherAccount });
            expect(await this.token.balanceOf(anotherAccount)).to.be.bignumber.equal('0');
            expect(await this.token.balanceOf(recipient)).to.be.bignumber.equal('90000180000360000720');
            console.log('calculateBNBReward = ' +await this.token.calculateBNBReward(anotherAccount));
          });  
          it('should log SwapAndLiquify', async function () {
            const amount = await this.token.balanceOf(initialHolder);
            console.log('balanceOf this before = ' +await this.token.balanceOf(this.tokenAddress));
            await this.token.transfer(this.tokenAddress, amount, { from: initialHolder });
            const { logs } = await this.token.transfer( recipient, maxTrxAmount, { from: anotherAccount });
            console.log('balanceOf this = ' +await this.token.balanceOf(this.tokenAddress));
            expectEvent.inLogs(logs, 'SwapAndLiquify', {
              tokensSwapped: this.tokenAddress,
              ethReceived: maxTrxAmount,
              tokensIntoLiqudity: 0,
            });
          });
        });
      });
    });
  });

  shouldBehaveLikeERC20('ERC20', initialSupply, initialHolder, recipient, anotherAccount);
});
