# Avalanche setup: exactly what to open and click

**Good news: you do not "create" a testnet.** Avalanche already runs a free public test network called **Fuji**. You connect to it, get free test coins, and deploy your contract there. Total cost: zero.

Network details (as listed in Avalanche's own docs when I checked on 19 Oct 2026; confirm they are unchanged):

| Setting | Value |
|---|---|
| Network name | Avalanche Fuji C-Chain |
| RPC URL | `https://api.avax-test.network/ext/bc/C/rpc` |
| Chain ID | `43113` (mainnet is `43114`, do not confuse them) |
| Currency symbol | `AVAX` |
| Explorer | `https://testnet.snowtrace.io` (some docs now list `https://testnet.snowscan.xyz`; either works to look up transactions) |

## Step 1: Make a wallet (10 minutes)

A wallet is your account on the blockchain. It is controlled by a secret **private key**.

1. Install **Core** (Avalanche's own wallet) from `core.app` as a browser extension. MetaMask also works.
2. Create a new wallet. **Write the recovery phrase on paper**, not in a chat or a photo. Anyone with the phrase owns the wallet.
3. **Make this a throwaway test wallet.** Never use a wallet that holds real money for this project.
4. Better practice: make **two** wallets:
   - **Owner wallet:** deploys the contract and decides who may write (keep it safe).
   - **Issuer wallet:** used by the anchor service to record fingerprints (this key sits on the server).
   For a first demo, one wallet is acceptable, but know the difference.

## Step 2: Switch the wallet to the test network

**Core:** open Settings → Advanced and turn on **Testnet Mode**. Core then switches to Fuji automatically. (Menu wording changes between versions.)

**MetaMask:** Settings → Networks → Add network manually, and enter the values from the table above.

Confirm that the chain ID shown is **43113**.

## Step 3: Get free test AVAX (the faucet)

Test coins pay the small "gas" fee for each transaction. They have no real-world value.

Use the **C-Chain** option (not only the P-Chain). Options Avalanche's docs list:
1. **Core testnet faucet:** `https://core.app/tools/testnet-faucet/?subnet=c&token=c`
2. **Avalanche Builder Hub faucet:** `https://build.avax.network/console/primary-network/faucet`
3. If a faucet asks for a coupon or a mainnet balance, Avalanche's docs say you can request a **coupon on Guild**, or ask the admins/mods on the official Avalanche **Discord**.
4. **Ask your friend who built on Avalanche**: they may be able to send you a little test AVAX or a coupon.

Request for both wallets (or at least the issuer wallet). A few test AVAX is plenty for hundreds of recordings. Check the balance in the wallet.

## Step 4: Get the private key for Hardhat

1. In your wallet, open the account menu and find **Show private key** (MetaMask: three dots → Account details → Show private key; Core: under account / security settings).
2. Copy it into the project root file `.env` as `DEPLOYER_PRIVATE_KEY=0x...` (copy `.env.example` to `.env` first).
3. If the key has no `0x` at the start, add it.
4. **Never commit `.env` to GitHub** (it is already in `.gitignore`). Never paste the key into chats or screenshots.

## Step 5: Deploy the contract

On your laptop (Node.js 20+ installed), in the project root:

```bash
npm install
npx hardhat test                               # should print 12 passing
npx hardhat run scripts/deploy.js --network fuji
```

You should see `DocRegistry deployed to: 0x...`. The address is also saved in `deployment.fuji.json`.

Paste the address into the explorer: `https://testnet.snowtrace.io/address/<your address>`. **Screenshot this for your pitch**, it is public proof that you deployed.

If it says "0 AVAX": the faucet has not paid you yet; check the C-Chain balance and wait a minute.

## Step 6: Let the anchor service write (issuer wallet)

If the anchor service uses a **different** wallet than the one that deployed the contract:

```bash
# in the root .env add:
# REGISTRY_ADDRESS=0x<contract address>
# NEW_ISSUER=0x<issuer wallet address>
npx hardhat run scripts/add-issuer.js --network fuji
```

(If you use one wallet for everything, the deployer is already an issuer; skip this.)

## Step 7: Connect the other parts

1. `anchor-service/.env`:
   - `DRY_RUN=false`
   - `CONTRACT_ADDRESS=` the address from step 5
   - `ISSUER_PRIVATE_KEY=` the issuer wallet's key
   - `API_KEY=` a long random string (`node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`)
   - `VERIFY_BASE_URL=` the public address where `verify-web` is hosted
2. `verify-web/config.js`: set `CONTRACT_ADDRESS` to the same address.
3. Start the service (`npm start` in `anchor-service`), then check `GET /health`: it should show your issuer wallet and balance.

## Step 8: Host the verify page

`verify-web` is a plain static site (no server needed). Free options: GitHub Pages, Netlify, Vercel, or your OCI VM through Caddy. Put the **public URL** in `VERIFY_BASE_URL` so QR codes point to it.

Test it before the demo: issue a certificate, open the verify link from your phone, and check that it says GENUINE.

## Step 9: Checklist before you demo

- [ ] Contract address visible on the explorer
- [ ] `GET /health` shows balance above `lowFunds`
- [ ] One full run: request, approve, certificate, scan, GENUINE
- [ ] The tamper button flips the result
- [ ] Screen recording of the full run saved offline
- [ ] Faucet coins topped up the day before

## What about "mainnet", "our own Avalanche chain", and costs?

- **Mainnet** (chain ID 43114) uses real AVAX that must be bought. Do **not** move there for the competition. A real deployment needs MUT's official approval, a funded and secured wallet, and a clear owner.
- **A custom Avalanche L1 (your own chain)** exists but is extra complexity and cost. Reports about KNEC describe anchoring on the public **C-Chain**, so staying on the C-Chain matches what the government did.
- **Costs on mainnet:** each recording costs a small gas fee. Check current gas prices before quoting a figure. Use `anchorBatch` (already in the contract) to record a whole graduating class in one transaction.

## Common errors

| Message | Meaning / fix |
|---|---|
| `Deployer wallet has 0 AVAX` | Faucet not received yet; check you requested C-Chain and wait |
| `HH502 Couldn't download compiler` | Internet issue; retry on another network |
| `nonce has already been used` | Two transactions sent at once from one wallet; the service already queues these, so restart it |
| `NotIssuer` (contract error) | The wallet is not allowed to write; run `add-issuer.js` |
| `AlreadyAnchored` | That fingerprint is already recorded (expected for duplicates) |
| `invalid BytesLike value` | Private key is missing `0x` or is not 64 hex characters |
