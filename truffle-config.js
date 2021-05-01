const { mnemonic, projectId, bscApiKey, privateKey } = require('./secrets.json');
const HDWalletProvider = require('@truffle/hdwallet-provider');

module.exports = {
  

  networks: {
    development: {
      host: '127.0.0.1',
      port: 8545,
      network_id: '97',
    },
    testnet: {
      provider: () => new HDWalletProvider(mnemonic, `https://data-seed-prebsc-1-s1.binance.org:8545`),
      network_id: 97,
      skipDryRun: true
    },   
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: '0.6.8',
    }
  },

  db: {
    enabled: false
  },
  plugins: [
    'truffle-plugin-verify',
  ],
  api_keys: {
    bscscan: bscApiKey
  }
};
