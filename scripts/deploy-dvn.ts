import { ethers, run } from "hardhat";

function sleep(milliseconds: number) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function main() {

    const args = [
    "93503201847067459816865778983521324688116667814772937141130154736249866362126",
    {
      x: "0x4182885822fe798509811091b5b6300299deae3d98a771cc179c2ffd11dabebb",
      parity: 1,
    },
    "0x9d34AC454DF11724bE4e11F0E9c9C9bd68bC8173",
    "0x6edce65403992e310a62460808c4b910d972f10f"
  ]

  const contract = await ethers.deployContract("MuonDVN", args);

  await contract.deployed();

  console.log(
    `contract deployed to ${contract.address}`
  );
  
  await sleep(20000);

  await run("verify:verify", {
    address: contract.address,
    constructorArguments: args,
    // contract: "contracts/muon/MuonClient.sol:MuonClient"
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
