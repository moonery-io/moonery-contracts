/// ENVVAR
// - ENABLE_GAS_REPORT
// - CI
// - COMPILE_MODE

const fs = require('fs');
const path = require('path');

require('@nomiclabs/hardhat-truffle5');
require('@nomiclabs/hardhat-solhint');
require('solidity-coverage');
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-ethers');
require("@nomiclabs/hardhat-etherscan");

for (const f of fs.readdirSync(path.join(__dirname, 'hardhat'))) {
  require(path.join(__dirname, 'hardhat', f));
}

const { privateKey, mnemonic, bscApiKey } = require('./secrets.json');


const PRIVATE_KEY = privateKey;
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.6.8"
      }
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      forking: {
        url: 'https://bsc-dataseed.binance.org',
        method: "hardhat_reset",
      },
      allowUnlimitedContractSize: true
    },
    testnet: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      "accounts": {
        "mnemonic": mnemonic,
      },
      allowUnlimitedContractSize: true,
      gas: "auto"
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
    buildinfo: "./artifacts/build-info"
  },
  etherscan: {
    apiKey: bscApiKey
  }
};