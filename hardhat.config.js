require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

// Use a DEDICATED test wallet key here. Never put a key that holds real money in this file/.env.
const DEPLOYER_PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY || "";

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: { optimizer: { enabled: true, runs: 200 }, evmVersion: "paris" },
  },
  networks: {
    // Avalanche testnet (free test coins) - use this for the demo
    fuji: {
      url: process.env.FUJI_RPC_URL || "https://api.avax-test.network/ext/bc/C/rpc",
      chainId: 43113,
      accounts: DEPLOYER_PRIVATE_KEY ? [DEPLOYER_PRIVATE_KEY] : [],
    },
    // Avalanche mainnet - real money. Do NOT use until MUT officially approves.
    avalanche: {
      url: process.env.AVAX_MAINNET_RPC_URL || "https://api.avax.network/ext/bc/C/rpc",
      chainId: 43114,
      accounts: DEPLOYER_PRIVATE_KEY ? [DEPLOYER_PRIVATE_KEY] : [],
    },
  },
};
