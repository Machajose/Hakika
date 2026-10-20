// Gives another wallet permission to write to the registry (e.g. the anchor service's wallet).
// Usage:  npx hardhat run scripts/add-issuer.js --network fuji
// Set in .env:  REGISTRY_ADDRESS=0x...   NEW_ISSUER=0x...   (REVOKE_ISSUER=true to remove instead)
const hre = require("hardhat");

async function main() {
  const registryAddress = process.env.REGISTRY_ADDRESS;
  const issuer = process.env.NEW_ISSUER;
  const allow = String(process.env.REVOKE_ISSUER || "false").toLowerCase() !== "true";
  if (!registryAddress || !issuer) throw new Error("Set REGISTRY_ADDRESS and NEW_ISSUER in .env");

  const registry = await hre.ethers.getContractAt("DocRegistry", registryAddress);
  const tx = await registry.setIssuer(issuer, allow);
  console.log((allow ? "Adding" : "Removing") + " issuer", issuer, "... tx:", tx.hash);
  await tx.wait();
  console.log("Done. isIssuer =", await registry.isIssuer(issuer));
}
main().catch((e) => { console.error(e); process.exitCode = 1; });
