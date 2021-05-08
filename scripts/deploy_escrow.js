// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { network } = require("hardhat");
const hre = require("hardhat");

async function main() {
  let WBNB;
  let router;

  if (network.name === "testnet" ) {
    WBNB = '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd'; // WBNB TESTNET
    router = '0xD99D1c33F9fC3444f8101754aBC46c52416550D1'; // TESTNET
  } else {
    WBNB = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c'; // WBNB MAINNET
    router = '0x10ED43C718714eb63d5aA57B78B54704E256024E'; //PancakeSwap: Router v2  Binance Mainnet
  }

  const MooneryEscrowTimeLock = await hre.ethers.getContractFactory("MooneryEscrowTimeLock");
  const escrow = await MooneryEscrowTimeLock.deploy();
  await escrow.deployed();
  console.log("MooneryEscrowTimeLock deployed to:", escrow.address);

  await hre.run("verify:verify", {
    address: escrow.address,
    constructorArguments: [],
  });

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
