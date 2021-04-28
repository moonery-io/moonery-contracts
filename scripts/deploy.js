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
  const routerV2 = '0xD99D1c33F9fC3444f8101754aBC46c52416550D1';

  const SecuredMoonRat = await hre.ethers.getContractFactory("SecuredMoonRat");
  const moonery = await SecuredMoonRat.deploy(routerV2);

  await moonery.deployed();
  console.log("Moonery deployed to:", moonery.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
