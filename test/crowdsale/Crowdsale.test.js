const { ethers } = require("hardhat");
const { balance, BN, constants, ether, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;

const { expect } = require('chai');

const Crowdsale = artifacts.require('CrowdsaleMock');
const SimpleToken = artifacts.require('SimpleToken');

describe('Crowdsale', function () {
  beforeEach(async function () {
    const [owner, wallet, investor, purchaser] = await ethers.getSigners();
    this.owner = owner.address
    this.wallet = wallet.address;
    this.investor = investor.address;
    this.purchaser = purchaser.address;
  });

  const rate = new BN(1);
  const value = ether('42');
  const tokenSupply = new BN('10').pow(new BN('22'));
  const expectedTokenAmount = rate.mul(value);

  it('requires a non-null token', async function () {
    await expectRevert(
      Crowdsale.new(rate, this.wallet , ZERO_ADDRESS, { from: this.owner }),
      'Crowdsale: token is the zero address'
    );
  });

  context('with token', async function () {
    beforeEach(async function () {
        this.token = await SimpleToken.new( { from: this.owner });
    });

    it('requires a non-zero rate', async function () {
      await expectRevert(
        Crowdsale.new(0, this.wallet, this.token.address, { from: this.owner }), 'Crowdsale: rate is 0'
      );
    });

    it('requires a non-null wallet', async function () {
      await expectRevert(
        Crowdsale.new(rate, ZERO_ADDRESS, this.token.address, { from: this.owner }), 'Crowdsale: wallet is the zero address'
      );
    });

    context('once deployed', async function () {
      beforeEach(async function () {
        this.crowdsale = await Crowdsale.new(rate, this.wallet, this.token.address, { from: this.owner });
        await this.token.transfer(this.crowdsale.address, tokenSupply, { from: this.owner });
      });

      describe('accepting payments', function () {
        describe('bare payments', function () {
          it('should accept payments', async function () {
            await this.crowdsale.send(value, { from: this.purchaser });
          });

          it('reverts on zero-valued payments', async function () {
            await expectRevert(
              this.crowdsale.send(0, { from: this.purchaser }), 'Crowdsale: weiAmount is 0'
            );
          });
        });

        describe('buyTokens', function () {
          it('should accept payments', async function () {
            await this.crowdsale.buyTokens(this.investor, { value: value, from: this.purchaser });
          });

          it('reverts on zero-valued payments', async function () {
            await expectRevert(
              this.crowdsale.buyTokens(this.investor, { value: 0, from: this.purchaser }), 'Crowdsale: weiAmount is 0'
            );
          });

          it('requires a non-null beneficiary', async function () {
            await expectRevert(
              this.crowdsale.buyTokens(ZERO_ADDRESS, { value: value, from: this.purchaser }),
              'Crowdsale: beneficiary is the zero address'
            );
          });
        });
      });

      describe('high-level purchase', function () {
        it('should log purchase', async function () {
          const { logs } = await this.crowdsale.sendTransaction({ value: value, from: this.investor });
          expectEvent.inLogs(logs, 'TokensPurchased', {
            purchaser: this.investor,
            beneficiary: this.investor,
            value: value,
            amount: expectedTokenAmount,
          });
        });

        it('should assign tokens to sender', async function () {
          await this.crowdsale.sendTransaction({ value: value, from: this.investor });
          expect(await this.token.balanceOf(this.investor)).to.be.bignumber.equal(expectedTokenAmount);
        });

        it('should forward funds to wallet', async function () {
          const balanceTracker = await balance.tracker(this.wallet);
          await this.crowdsale.sendTransaction({ value, from: this.investor });
          expect(await balanceTracker.delta()).to.be.bignumber.equal(value);
        });
      });

      describe('low-level purchase', function () {
        it('should log purchase', async function () {
          const { logs } = await this.crowdsale.buyTokens(this.investor, { value: value, from: this.purchaser });
          expectEvent.inLogs(logs, 'TokensPurchased', {
            purchaser: this.purchaser,
            beneficiary: this.investor,
            value: value,
            amount: expectedTokenAmount,
          });
        });

        it('should assign tokens to beneficiary', async function () {
          await this.crowdsale.buyTokens(this.investor, { value, from: this.purchaser });
          expect(await this.token.balanceOf(this.investor)).to.be.bignumber.equal(expectedTokenAmount);
        });

        it('should forward funds to wallet', async function () {
          const balanceTracker = await balance.tracker(this.wallet);
          await this.crowdsale.buyTokens(this.investor, { value, from: this.purchaser });
          expect(await balanceTracker.delta()).to.be.bignumber.equal(value);
        });
      });
    });
  });
});