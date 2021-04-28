# MOONERY-CONTRACTS
Moonery is a community-driven, no-loss price game and no-loss pool launchpad


## Overview
Moonery is a community-driven, no-loss price game and no-loss pool launchpad

## Installation
The guides in the [OpenZeppelin docs site](https://docs.openzeppelin.com/learn/developing-smart-contracts) will teach how to deploy and interaction to smart contract.

## Step by Step Installation using Truffle
1. Make sure you have node v12.8.3 or higher, check it with
```
node --version
```

2. Install packages
```
yarn
```

4. Download, install and open [Ganache](https://www.trufflesuite.com/ganache)

5. Compile solidity with hardhat
```
yarn compile
```

5. Deploy smart contracts to your localhost Hardhat
```
yarn deploy
```

result of your deployment:
```
yarn run v1.22.10
warning ../../../package.json: No license field
$ npx hardhat run scripts/deploy.js
Moonery deployed to: 0x4A679253410272dd5232B3Ff7cF5dbB88f295319
✨  Done in 9.05s.
```


## Testing and linting
Running unit test
```
yarn test
```

Running test coverage
```
yarn coverage
```

Lint solidity
```
yarn lint:sol
```

## Connecting to public test networks
see also [Connecting to public test networks](https://docs.openzeppelin.com/learn/connecting-to-public-test-networks)

### Create a new account 
To send transactions in a testnet, you will need a new Ethereum account using mnemonics package
```
yarn mnemonics
drama film snack motion ...
```

### Copy and change secrets
```
cp secrets.json.example secrets.json
```

Copy your mnemonics words to secret.json



### Get funds
Using [Binance Testnet Faucet](https://testnet.binance.org/faucet-smart)
or using [MetaMask’s faucet](https://faucet.metamask.io/)


### Deploy and migrate to Binance testnet
```
yarn truffle migrate --network binance_testnet
```


## Verify your contract on Binance Smart Chain


1. Generate an API Key on your BSCscan account

If you don't have one yet, just go to [this page](https://bscscan.com/login) to sign up.


Add your BSCscan API key to your secrets.json


2.  Deploy your contract

```
yarn compile
yarn deploy:testnetya
```

or 

```
truffle compile
truffle migrate --network testnet
```


3. Verify your contract

```
truffle run verify BEP20Token@{deployed-address} --network binance_testnet

```

## Security

If you find a security issue, please join our Discord

## Developer Resources


- Ask for help and follow progress at: Discord

Interested in contributing to MOONERY?

- Issue tracker: [issues](https://github.com/moonery-io/moonery-contracts/issues)
- Contribution guidelines: [contributing](https://github.com/moonery-io/moonery-contracts/blob/master/CONTRIBUTING.md)


## License
Code released under the [MIT License](https://github.com/moonery-io/moonery-contracts/blob/master/LICENSE).
