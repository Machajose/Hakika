const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Network:        ", hre.network.name);
  console.log("Deployer wallet:", deployer.address);
  console.log("Balance (AVAX): ", hre.ethers.formatEther(balance));

  if (balance === 0n) {
    throw new Error(
      "Deployer wallet has 0 AVAX. Get free Fuji test AVAX from the faucet first (see docs/AVALANCHE-SETUP.md)."
    );
  }

  const Registry = await hre.ethers.getContractFactory("DocRegistry");
  const registry = await Registry.deploy();
  await registry.waitForDeployment();
  const address = await registry.getAddress();

  console.log("\nDocRegistry deployed to:", address);
  if (hre.network.name === "fuji") {
    console.log("Explorer: https://testnet.snowtrace.io/address/" + address);
  }

  // Save the address so the other parts of the project can read it.
  const out = {
    network: hre.network.name,
    chainId: Number((await hre.ethers.provider.getNetwork()).chainId),
    address,
    deployer: deployer.address,
    deployedAt: new Date().toISOString(),
  };
  const file = path.join(__dirname, "..", "deployment." + hre.network.name + ".json");
  fs.writeFileSync(file, JSON.stringify(out, null, 2));
  console.log("Saved:", file);
  console.log("\nNEXT: copy the address into anchor-service/.env (CONTRACT_ADDRESS) and verify-web/config.js");
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
