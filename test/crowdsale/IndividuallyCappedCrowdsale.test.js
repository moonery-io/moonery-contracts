const { ethers } = require("hardhat");

const { BN, ether, expectRevert } = require('@openzeppelin/test-helpers');

const { expect } = require('chai');

const IndividuallyCappedCrowdsaleImpl = artifacts.require('IndividuallyCappedCrowdsaleImpl');
const SimpleToken = artifacts.require('SimpleToken');

describe('IndividuallyCappedCrowdsale', function () {

  beforeEach(async function () {
    const [owner, capper, otherCapper, wallet, alice, bob, charlie, other, ...otherAccounts] = await ethers.getSigners();
    this.owner = owner.address
    this.capper = capper.address;
    this.otherCapper = otherCapper.address;
    this.wallet = wallet.address;
    this.alice = alice.address;
    this.bob = bob.address;
    this.charlie = charlie.address;
    this.other = other.address;
  });

  const rate = new BN(1);
  const capAlice = ether('10');
  const capBob = ether('2');
  const lessThanCapAlice = ether('6');
  const lessThanCapBoth = ether('1');
  const tokenSupply = new BN('10').pow(new BN('22'));

  const CAPPER_ROLE = web3.utils.soliditySha3('CAPPER_ROLE');


  beforeEach(async function () {
    this.token = await SimpleToken.new({ from: this.owner });
    this.crowdsale = await IndividuallyCappedCrowdsaleImpl.new(rate, this.wallet, this.token.address, this.capper, { from: this.owner });
  });

  describe('capper role', function () {
    beforeEach(async function () {
      this.contract = this.crowdsale;
      await this.contract.grantRole(CAPPER_ROLE, this.otherCapper, { from: this.capper });
    });
  });

  describe('individual caps', function () {
    it('sets a cap when the sender is a capper', async function () {
      await this.crowdsale.setCap(this.alice, capAlice, { from: this.capper });
      expect(await this.crowdsale.getCap(this.alice)).to.be.bignumber.equal(capAlice);
    });

    it('reverts when a non-capper sets a cap', async function () {
      await expectRevert(this.crowdsale.setCap(this.alice, capAlice, { from: this.other }),
        'IndividuallyCappedCrowdsale: caller is not capper'
      );
    });

    context('with individual caps', function () {
      beforeEach(async function () {
        await this.crowdsale.setCap(this.alice, capAlice, { from: this.capper });
        await this.crowdsale.setCap(this.bob, capBob, { from: this.capper });
        await this.token.transfer(this.crowdsale.address, tokenSupply);
      });

      describe('accepting payments', function () {
        it('should accept payments within cap', async function () {
          await this.crowdsale.buyTokens(this.alice, { value: lessThanCapAlice });
          await this.crowdsale.buyTokens(this.bob, { value: lessThanCapBoth });
        });

        it('should reject payments outside cap', async function () {
          await this.crowdsale.buyTokens(this.alice, { value: capAlice });
          await expectRevert(this.crowdsale.buyTokens(this.alice, { value: 1 }),
            'IndividuallyCappedCrowdsale: beneficiary\'s cap exceeded'
          );
        });

        it('should reject payments that exceed cap', async function () {
          await expectRevert(this.crowdsale.buyTokens(this.alice, { value: capAlice.addn(1) }),
            'IndividuallyCappedCrowdsale: beneficiary\'s cap exceeded'
          );
          await expectRevert(this.crowdsale.buyTokens(this.bob, { value: capBob.addn(1) }),
            'IndividuallyCappedCrowdsale: beneficiary\'s cap exceeded'
          );
        });

        it('should manage independent caps', async function () {
          await this.crowdsale.buyTokens(this.alice, { value: lessThanCapAlice });
          await expectRevert(this.crowdsale.buyTokens(this.bob, { value: lessThanCapAlice }),
            'IndividuallyCappedCrowdsale: beneficiary\'s cap exceeded'
          );
        });

        it('should default to a cap of zero', async function () {
          await expectRevert(this.crowdsale.buyTokens(this.charlie, { value: lessThanCapBoth }),
            'IndividuallyCappedCrowdsale: beneficiary\'s cap exceeded'
          );
        });
      });

      describe('reporting state', function () {
        it('should report correct cap', async function () {
          expect(await this.crowdsale.getCap(this.alice)).to.be.bignumber.equal(capAlice);
        });

        it('should report actual contribution', async function () {
          await this.crowdsale.buyTokens(this.alice, { value: lessThanCapAlice });
          expect(await this.crowdsale.getContribution(this.alice)).to.be.bignumber.equal(lessThanCapAlice);
        });
      });
    });
  });
});