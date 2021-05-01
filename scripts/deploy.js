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
  const routerV2 = '0xD99D1c33F9fC3444f8101754aBC46c52416550D1'; // TESTNET
  //const routerV2 = '0x10ED43C718714eb63d5aA57B78B54704E256024E'; //PancakeSwap: Router v2  Binance Mainnet


  const rate = 61600;
  const capper = "0x5a30c6Cc080D0Cc246fAfb0C700b2EcA6eD2cF01";

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

  const MoonerySale = await hre.ethers.getContractFactory("MoonerySale");
  const moonerySale = await MoonerySale.deploy(rate, capper, moonery.address, capper);
  await moonerySale.deployed();
  console.log("MoonerySale deployed to:", moonerySale.address);

  await hre.run("verify:verify", {
    address: moonery.address,
    constructorArguments: [routerV2],
    libraries: {
      MooneryUtils: mooneryUtils.address
    }
  });
  
  await hre.run("verify:verify", {
    address: moonerySale.address,
    constructorArguments: [rate, capper, moonery.address, capper],
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
