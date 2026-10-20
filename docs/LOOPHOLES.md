# Loopholes and risks you may have missed

Ordered roughly by how badly each could hurt you. For each: **what it is**, **why it matters**, **what to do**.

## Critical

### 1. It is not official, and you need permission
- **What:** MUT's ERP is run by the university (and a vendor). The registrar, ICT, and probably legal/Senate decide what counts as an official MUT document. Your prototype issues documents nobody has authorised.
- **Why:** If you hand out something that looks like an official clearance certificate, you risk disciplinary trouble and damage the idea itself.
- **Do:** Print "PROTOTYPE, NOT AN OFFICIAL RECORD" on demo documents (the generator already does). Get a supportive lecturer or the ICT/registrar to sponsor the pilot *before* innovation week if you can. Use fake students only.

### 2. The issuer private key is the keys to the kingdom
- **What:** Whoever holds the issuer key can record any fingerprint, which means issuing "genuine" fake documents.
- **Why:** The blockchain cannot tell a legitimate issuer from a thief who has the key.
- **Do:** Dedicated wallet, nothing else on it. Key only on the server (file permission 600), never in GitHub, chat or screenshots. Rotate it if anyone leaves the team (use `scripts/add-issuer.js` with `REVOKE_ISSUER=true` to remove the old wallet). Later: OCI Vault; multiple approvers.

### 3. Blockchain proves "unchanged", not "correct"
- **What:** If a staff member (or a bug) issues a wrong certificate, the blockchain will faithfully prove the wrong certificate is genuine.
- **Why:** The weak point moves from the paper to the issuing process.
- **Do:** Keep human approvals and the **audit log** (`mv_audit_log`). Restrict who can trigger issuing. Use **revoke** for mistakes and issue a corrected one. In your pitch, never say "blockchain makes certificates 100% secure".

### 4. A real QR code on a fake document
- **What:** Someone could print a genuine QR code onto a different, forged paper.
- **Why:** The QR only proves the *record* is real.
- **Do:** The verify page shows the name and details from the record and tells the verifier to compare them with the paper (already built in). Train verifiers on this. For high-stakes checks, add ID verification of the holder.

### 5. Student privacy and the Data Protection Act
- **What:** The QR link contains the student's name, reg number and programme so the page can recompute the fingerprint. The blockchain itself holds only a salted fingerprint.
- **Why:** Kenya's Data Protection Act applies to student data. Blockchains cannot delete data, which clashes with erasure rights if you ever put personal data on-chain.
- **Do:** Never put personal data on-chain (already the design). Use the random salt (already built in). The details sit after `#` in the link, which is not sent to servers. Get ICT/legal to confirm the approach, and note that the ERP tender required the vendor to be registered with the Office of the Data Protection Commissioner, so MUT already treats this seriously. Ask who the "data controller" is for this prototype.

### 6. Your student cloud account is temporary
- **What:** Student cloud benefits expire, and you are in your final year.
- **Why:** A system tied to your personal account disappears when your access does, which is a bad story for a university process.
- **Do:** Check the expiry date now. Present it as a pilot. For continuity, the infrastructure must move to an account the **university** owns, and the contract owner wallet should be held by an institutional role, not an individual.

## High

### 7. Testnet is for demos, not for real records
- **What:** Fuji test coins have no value, and a testnet gives no guarantee of permanence.
- **Why:** If a testnet were reset or retired, your "permanent" proof could vanish.
- **Do:** Call it a prototype. Mainnet needs real AVAX, funding, and an owner. Find out who would pay and manage this.

### 8. Fake look-alike verification pages
- **What:** A scammer can copy your verify page and make it say GENUINE for anything.
- **Why:** People trust the page, not the blockchain behind it.
- **Do:** Publish **one official verification address** (for example a MUT sub-domain) and print it on every document next to the QR. Add a way to check the contract address on the explorer for people who want to verify the verifier.

### 9. Dependence on a public connection (RPC)
- **What:** The verify page talks to Avalanche through a public RPC address that can be slow or rate-limited.
- **Why:** The demo could fail at the worst moment.
- **Do:** Add a second or third RPC URL to `verify-web/config.js` (it tries them in order). Keep a screen recording.

### 10. Not integrated with the real ERP
- **What:** The tender shows MUT's ERP is a vendor system. Your Oracle app is a separate prototype with its own data.
- **Why:** In real life the data (fees, library, hostels) lives in the ERP, so you need the vendor's cooperation and an integration (API/export).
- **Do:** Present your solution as an add-on layer, and list the integration points (fee balance, student record, graduation list). Ask ICT what interfaces the ERP offers. Do not claim it replaces the ERP.

### 11. Legal standing of electronic certificates
- **What:** Whether an employer or court treats a blockchain-verified PDF as equal to the paper original is a legal question I cannot answer for you.
- **Do:** Say "supports verification" rather than "legally replaces". Ask a law lecturer or MUT's legal office.

## Medium

### 12. Revocation, name changes, reissue
- Name spelling corrections, lost certificates, and fraud all need a process: revoke the old fingerprint and issue a new one (supported). Decide *who* may revoke.

### 13. Duplicate and lost documents
- A genuine certificate can be shared with someone else. The verify page will say GENUINE. Verification proves the document, not who is holding it.

### 14. Version control of the fingerprint recipe
- The recipe (`MUTV1`) must be identical in the service and the verify page. If one changes, everything verifies as NOT FOUND. Keep the version string, and never change the recipe after issuing real documents without a new version.

### 15. Free faucet coins can run out or the faucet can be down
- Top up the day before the demo. `/health` warns when the balance is low.

### 16. Cost surprises on mainnet
- Each write costs gas, and gas prices vary. Batch issuing (`anchorBatch`) exists in the contract but the service does not use it yet. Get real numbers before promising any figure.

### 17. Dense QR codes
- The QR holds the details, so it is fairly dense. Print it at least about 3 cm wide, on good paper, and test scanning on cheap phones.

### 18. Team knowledge gaps
- If only one person understands the blockchain part, the demo has a single point of failure. Rotate who explains each step during rehearsals.

## Honest weak spots in the idea itself (judges may probe)

- **"Why not a signed PDF and a database?"** That would work and is simpler. The extra value of the blockchain is independent, permanent proof that does not rely on trusting MUT's own server or staff. Say so honestly.
- **Reports about KNEC vary:** some say 15 million records anchored at launch, others 30 million or more, with about 35 million projected. Also, coverage noted that adoption by employers had not been disclosed. Quote "millions of records" and avoid precise claims you cannot source.
- **Adoption problem:** a verification system only helps if employers use it. Plan how people will learn the verification address.

## What I could not check for you

- Deployment to the real Fuji network, the Oracle SQL on a live Autonomous Database, the OCI VM script, and the verify page in a real browser were not tested here. Run them early (Days 2 to 4 of the roadmap) so surprises happen when there is still time.
