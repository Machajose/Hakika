# HAKIKI(MUT-Verify (prototype)

Give every official MUT document a tamper-proof fingerprint on the Avalanche blockchain, so anyone can scan a QR code and confirm the document is genuine, the same idea KNEC used for national certificates, scaled down for one university.

> **Status: innovation-week prototype.** Fake demo data only. Not an official MUT system until the university approves it. Read `docs/LOOPHOLES.md` before you present.

## Start here (pick your role)

| You are… | Read this first |
|---|---|
| Explaining it to teammates / judges | `docs/TEAM-GUIDE.md` |
| Setting up the blockchain side | `docs/AVALANCHE-SETUP.md` |
| Using your Oracle student account | `docs/ORACLE-GUIDE.md` |
| Planning the two weeks | `docs/ROADMAP-2-WEEKS.md` |
| Worried about what could go wrong | `docs/LOOPHOLES.md` |
| Meeting your friend / the registrar / ICT | `docs/QUESTIONS.md` |

## What is in the box

```
contracts/DocRegistry.sol   The smart contract: a public list of fingerprints (nothing personal)
test/                       12 automated tests for the contract
scripts/deploy.js           Puts the contract on a blockchain
scripts/add-issuer.js       Lets another wallet (the service) write to the contract
scripts/e2e-local.sh        ONE COMMAND full test on a private local chain (no wallet, no cost)
anchor-service/             The "issuing desk": makes the PDF + QR, writes the fingerprint on-chain
verify-web/                 The public page employers see after scanning the QR (static, no server)
oracle/01_schema.sql        Oracle tables + the automatic clearance logic
oracle/02_issue_procedure.sql  Oracle -> anchor service bridge (issue + revoke)
oracle/vm-setup.sh          Template to run the service on an OCI VM with https
```

## How the pieces fit

```
 Student / offices                 Oracle Autonomous DB + APEX            OCI VM (anchor-service)            Avalanche
 ─────────────────  clearance  ─►  tables, approvals, auto-checks  ─────►  makes PDF + QR, computes   ─────►  stores ONLY the
 (APEX web app)     requests        when ALL offices clear:                fingerprint, signs & sends          fingerprint
                                    call mv_issue_certificate              the transaction                     (DocRegistry)
                                                                                                                  ▲
 Employer scans QR  ─────────►  verify-web page (static)  ─ recomputes the fingerprint in the browser, ─────────┘
                                                            reads the contract directly (free)
```

Key design choices (so you can defend them):
- **Only a fingerprint goes on-chain.** Names and grades stay in Oracle. The fingerprint includes a random *salt*, so nobody can guess a student's details from it.
- **The verify page needs no server and no login.** It talks to the blockchain directly, so verification still works even if MUT's servers are down.
- **The QR link keeps the details after the `#`.** Browsers do not send that part to any server, so the details do not land in server logs.
- **Revocation exists.** A wrong or cancelled document can be marked revoked; its history stays visible.

## Quick start: three levels

You need Node.js 20 or newer.

### Level 1: no blockchain, 5 minutes (just see it work)
```bash
cd anchor-service
npm install
cp .env.example .env          # leave DRY_RUN=true
npm run dev                   # service on http://localhost:8080
```
Then in another terminal:
```bash
curl -X POST localhost:8080/issue -H "content-type: application/json" \
  -H "x-api-key: change-me-to-a-long-random-string" \
  -d '{"docType":"CLEARANCE","regNo":"DEMO/0001/2021","name":"Jane Wanjiru","program":"BSc Medical Laboratory Sciences"}'
```
The reply contains `pdfBase64` (the certificate) and the fingerprint. (In dry-run the blockchain is pretended.)

### Level 2: private local blockchain, 3 minutes (the whole pipeline, free)
```bash
npm install                   # in the project root
cd anchor-service && npm install && cd ..
bash scripts/e2e-local.sh     # issues, verifies, revokes, tests 3 simultaneous requests
```
It leaves `sample-certificate.pdf` in the project root.

### Level 3: real Avalanche testnet (Fuji), what you present
Follow `docs/AVALANCHE-SETUP.md` step by step (wallet, free test coins, deploy, connect).

## Run the tests
```bash
npm test                      # contract tests (12)
cd anchor-service && npm test # fingerprint tests
```

## What I could and could not test
- **Tested here:** contract (12 tests), fingerprint logic, the service end to end against a private local blockchain (issue, verify, revoke, three simultaneous requests, tamper detection), the PDF output, and the verify page loaded in a headless DOM (jsdom) against that local chain: it showed GENUINE for the real record and NOT VERIFIED after the one-letter tamper test, with no script errors. That run also confirmed the page and the service produce the *same* fingerprint.
- **Not tested here (no access to them):** deployment to the real Fuji testnet, the Oracle SQL/PL/SQL against a live Autonomous Database, the OCI VM script, and the verify page in a real phone/desktop browser (open it on your phone early). Expect small fixes on first run; the guides say where.
- A bug found and fixed during testing: two blockchain writes in quick succession failed with "nonce already used". The service now queues writes one at a time.
- The Solidity compiler could not be downloaded in my workspace, so I compiled with the `solc` npm package. On your machine, `npx hardhat test` downloads the compiler normally.
