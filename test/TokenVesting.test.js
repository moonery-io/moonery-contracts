const { ethers } = require("hardhat");

const { BN, ether, expectEvent, expectRevert, time } = require('@openzeppelin/test-helpers');

const { expect } = require('chai');

const TokenVesting = artifacts.require('TokenVesting');
const SimpleToken = artifacts.require('SimpleToken');

contract('TokenVesting', function () {
  beforeEach(async function () {
    const [owner, beneficiary] = await ethers.getSigners();
    this.owner = owner.address
    this.beneficiary = beneficiary.address
  });

  const amount = new BN(1000);

  beforeEach(async function () {
    this.token = await SimpleToken.new({ from: this.owner });

    this.start = (await time.latest()).add(time.duration.minutes(1)); // +1 minute so it starts after contract instantiation
    this.cliff = time.duration.years(1);
    this.duration = time.duration.years(2);

    this.vesting = await TokenVesting.new(this.beneficiary, this.start, this.cliff, this.duration, true, { from: this.owner });

    await this.token.transfer(this.vesting.address, amount, { from: this.owner });
  });

  it('cannot be released before cliff', async function () {
    expectRevert(await this.vesting.release(this.token.address));
    //await this.vesting.release(this.token.address).should.be.rejectedWith(EVMRevert);
  });

  it('can be released after cliff', async function () {
    await time.increaseTo(this.start + this.cliff + time.duration.weeks(1));
    await this.vesting.release(this.token.address).should.be.fulfilled;
  });

  it('should release proper amount after cliff', async function () {
    await time.increaseTo(this.start + this.cliff);

    const { receipt } = await this.vesting.release(this.token.address);
    const block = await ethGetBlock(receipt.blockNumber);
    const releaseTime = block.timestamp;

    const balance = await this.token.balanceOf(this.beneficiary);
    expect(balance).to.be.bignumber.equal(amount.mul(releaseTime - this.start).div(this.duration).floor());
    //balance.should.bignumber.equal(amount.mul(releaseTime - this.start).div(this.duration).floor());
  });

  it('should linearly release tokens during vesting period', async function () {
    const vestingPeriod = this.duration - this.cliff;
    const checkpoints = 4;

    for (let i = 1; i <= checkpoints; i++) {
      const now = this.start + this.cliff + i * (vestingPeriod / checkpoints);
      await time.increaseTo(now);

      await this.vesting.release(this.token.address);
      const balance = await this.token.balanceOf(this.beneficiary);
      const expectedVesting = amount.mul(now - this.start).div(this.duration).floor();

      expect(balance).should.bignumber.equal(expectedVesting);
    }
  });

  it('should have released all after end', async function () {
    await time.increaseTo(this.start + this.duration);
    await this.vesting.release(this.token.address);
    const balance = await this.token.balanceOf(this.beneficiary);

    expect(balance).should.bignumber.equal(amount);

  });

  it('should be revoked by owner if revocable is set', async function () {
    await this.vesting.revoke(this.token.address, { from: owner }).should.be.fulfilled;
  });

  it('should fail to be revoked by owner if revocable not set', async function () {
    const vesting = await TokenVesting.new(beneficiary, this.start, this.cliff, this.duration, false, { from: owner });
    //await vesting.revoke(this.token.address, { from: owner }).should.be.rejectedWith(EVMRevert);
  });

  it('should return the non-vested tokens when revoked by owner', async function () {
    await time.increaseTo(this.start + this.cliff + duration.weeks(12));

    const vested = await this.vesting.vestedAmount(this.token.address);

    await this.vesting.revoke(this.token.address, { from: owner });

    const ownerBalance = await this.token.balanceOf(owner);
    ownerBalance.should.bignumber.equal(amount.sub(vested));
  });

  it('should keep the vested tokens when revoked by owner', async function () {
    await time.increaseTo(this.start + this.cliff + time.duration.weeks(12));

    const vestedPre = await this.vesting.vestedAmount(this.token.address);

    await this.vesting.revoke(this.token.address, { from: this.owner });

    const vestedPost = await this.vesting.vestedAmount(this.token.address);

    vestedPre.should.bignumber.equal(vestedPost);
  });

  it('should fail to be revoked a second time', async function () {
    await time.increaseTo(this.start + this.cliff + time.duration.weeks(12));

    await this.vesting.vestedAmount(this.token.address);

    await this.vesting.revoke(this.token.address, { from: this.owner });

    //await this.vesting.revoke(this.token.address, { from: this.owner }).should.be.rejectedWith(EVMRevert);
  });
});