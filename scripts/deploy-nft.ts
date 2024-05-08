import { ethers, upgrades, run } from "hardhat";

function sleep(milliseconds: number) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export async function deploy() {
  const Particle = await ethers.getContractFactory("Particle");

  const args = [
    "0xb57490CDAABEDb450df33EfCdd93079A24ac5Ce5"
  ]
  
  const particle = await upgrades.deployProxy(Particle, args);

  await particle.waitForDeployment();
  const contractAddress = await particle.getAddress();
  console.log("V1 Contract deployed to:", contractAddress);

  await sleep(20000);

  await run("verify:verify", {
    address: contractAddress,
    constructorArguments: args
  });
}

deploy().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});