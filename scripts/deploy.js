// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile 
  // manually to make sure everything is compiled
  // await hre.run('compile');
  // router testnet 0xD99D1c33F9fC3444f8101754aBC46c52416550D1
  //const WBNB = '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd'; // TESTNET
  const routerV2 = '0xD99D1c33F9fC3444f8101754aBC46c52416550D1'; // TESTNET
  //const routerDev = '0x10ED43C718714eb63d5aA57B78B54704E256024E';
  //const routerV2 = '0x10ED43C718714eb63d5aA57B78B54704E256024E'; //PancakeSwap: Router v2  Binance Mainnet

  const MooneryUtils = await hre.ethers.getContractFactory("MooneryUtils");
  const mooneryUtils = await MooneryUtils.deploy();
  await mooneryUtils.deployed();
  console.log("MooneryUtils deployed to:", mooneryUtils.address);

  const Moonery = await hre.ethers.getContractFactory("Moonery", {
    libraries: {
      MooneryUtils: mooneryUtils.address
    }
  });
  const moonery = await Moonery.deploy(routerV2);

  await moonery.deployed();
  console.log("Moonery deployed to:", moonery.address);

  /*await hre.run("verify:verify", {
    address: moonery.address,
    constructorArguments: [
      routerV2
    ],
    libraries: {
      MooneryUtils: mooneryUtils.address,
    }
  })*/
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
