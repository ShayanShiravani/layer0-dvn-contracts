import { ethers, run } from "hardhat";

function sleep(milliseconds: number) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function main() {

  const args = [
    "0x6EDCE65403992e310A62460808c4b910D972f10f",
    "0xb57490CDAABEDb450df33EfCdd93079A24ac5Ce5",
    "0x9bA9F04936e20c918Fb0F4733D909AE7fe61a92C"
  ]

  const contract = await ethers.deployContract("ERC721MinterOApp", args);

  await contract.waitForDeployment();
  const contractAddress = await contract.getAddress();

  console.log(
    `contract deployed to ${contractAddress}`
  );
  
  await sleep(20000);

  await run("verify:verify", {
    address: contractAddress,
    constructorArguments: args
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
