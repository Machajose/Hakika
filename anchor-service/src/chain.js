/**
 * Talks to the DocRegistry contract on Avalanche.
 * In DRY_RUN mode it pretends (in memory) so you can test everything without a wallet.
 */
const { ethers } = require("ethers");

const ABI = [
  "function anchor(bytes32 docHash)",
  "function anchorBatch(bytes32[] docHashes)",
  "function revoke(bytes32 docHash)",
  "function verify(bytes32 docHash) view returns (bool exists, bool revoked, uint64 issuedAt, uint64 revokedAt, address issuer)",
  "function isIssuer(address) view returns (bool)",
];

const DRY_RUN = String(process.env.DRY_RUN || "true").toLowerCase() === "true";
const EXPLORER_BASE = (process.env.EXPLORER_BASE || "https://testnet.snowtrace.io").replace(/\/$/, "");

let contract = null;
let wallet = null;
const fake = new Map(); // dry-run storage: hash -> {issuedAt, revokedAt}

function init() {
  if (DRY_RUN) {
    console.log("[chain] DRY_RUN=true  -> no real blockchain transactions will be sent");
    return;
  }
  const { RPC_URL, CHAIN_ID, CONTRACT_ADDRESS, ISSUER_PRIVATE_KEY } = process.env;
  for (const [k, v] of Object.entries({ RPC_URL, CHAIN_ID, CONTRACT_ADDRESS, ISSUER_PRIVATE_KEY })) {
    if (!v) throw new Error(`Missing ${k} in .env (required when DRY_RUN=false)`);
  }
  // cacheTimeout:-1 -> never reuse a cached answer (a cached "transaction count" caused "nonce already used" errors)
  const provider = new ethers.JsonRpcProvider(RPC_URL, Number(CHAIN_ID), { cacheTimeout: -1, staticNetwork: true });
  wallet = new ethers.Wallet(ISSUER_PRIVATE_KEY, provider);
  contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, wallet);
  console.log("[chain] Connected. Issuer wallet:", wallet.address, "| contract:", CONTRACT_ADDRESS);
}

function explorerTx(txHash) {
  return `${EXPLORER_BASE}/tx/${txHash}`;
}

// A wallet can only send ONE transaction at a time safely (each has a counter called a "nonce").
// If two requests arrive together, this queue makes the second wait for the first to finish.
let queue = Promise.resolve();
function serial(fn) {
  const run = queue.then(fn);
  queue = run.catch(() => {}); // a failure must not block the queue forever
  return run;
}

async function anchor(docHash) {
  if (DRY_RUN) {
    if (fake.has(docHash)) throw new Error("Already anchored");
    fake.set(docHash, { issuedAt: Math.floor(Date.now() / 1000), revokedAt: 0 });
    const txHash = ethers.keccak256(ethers.toUtf8Bytes("dry-run-" + docHash));
    return { txHash, explorerUrl: null, dryRun: true };
  }
  return serial(async () => {
    const tx = await contract.anchor(docHash);
    const receipt = await tx.wait(1);
    return { txHash: receipt.hash, explorerUrl: explorerTx(receipt.hash), dryRun: false };
  });
}

async function revoke(docHash) {
  if (DRY_RUN) {
    const r = fake.get(docHash);
    if (!r) throw new Error("Not found");
    if (r.revokedAt) throw new Error("Already revoked");
    r.revokedAt = Math.floor(Date.now() / 1000);
    return { txHash: ethers.keccak256(ethers.toUtf8Bytes("dry-run-revoke-" + docHash)), explorerUrl: null, dryRun: true };
  }
  return serial(async () => {
    const tx = await contract.revoke(docHash);
    const receipt = await tx.wait(1);
    return { txHash: receipt.hash, explorerUrl: explorerTx(receipt.hash), dryRun: false };
  });
}

async function verify(docHash) {
  if (DRY_RUN) {
    const r = fake.get(docHash);
    return r
      ? { exists: true, revoked: !!r.revokedAt, issuedAt: r.issuedAt, revokedAt: r.revokedAt, issuer: "dry-run" }
      : { exists: false, revoked: false, issuedAt: 0, revokedAt: 0, issuer: null };
  }
  const r = await contract.verify(docHash);
  return {
    exists: r.exists,
    revoked: r.revoked,
    issuedAt: Number(r.issuedAt),
    revokedAt: Number(r.revokedAt),
    issuer: r.issuer,
  };
}

async function health() {
  if (DRY_RUN) return { mode: "dry-run" };
  const bal = await wallet.provider.getBalance(wallet.address);
  return {
    mode: "live",
    issuerWallet: wallet.address,
    issuerBalanceAvax: ethers.formatEther(bal),
    lowFunds: bal < ethers.parseEther("0.05"),
  };
}

module.exports = { init, anchor, revoke, verify, health, DRY_RUN };
