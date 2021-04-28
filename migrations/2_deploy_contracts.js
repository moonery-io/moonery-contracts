const Moonery = artifacts.require('Moonery');
module.exports = function (deployer, network, accounts) {
  let router;
  if (network === 'development') {
    router = '0x10ED43C718714eb63d5aA57B78B54704E256024E';
  } else if (network === 'testnet') {
    router = '0xD99D1c33F9fC3444f8101754aBC46c52416550D1';
  }
  deployer.deploy(Moonery, router);
};
