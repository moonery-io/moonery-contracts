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
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      forking: {
        url: 'https://bsc-dataseed.binance.org'
      },
      allowUnlimitedContractSize: true
    },
    testnet: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      "accounts": {
        "mnemonic": mnemonic,
      },
      allowUnlimitedContractSize: true,
      gasPrice: 8000000
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  etherscan: {
    apiKey: bscApiKey
  }
};