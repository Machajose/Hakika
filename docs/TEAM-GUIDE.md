# Team Guide: explain it in plain words

Use this to bring every teammate (and the judges) to the same understanding. No tech background needed for sections 1 to 5.

## 1. The one-minute story

Forged certificates are a real problem in Kenya. Recently, anti-corruption investigators have been arresting people who used fake certificates to get jobs, and KNEC itself has said the scale of forgery is a reputation risk. Checking a certificate the old way means writing to the issuing office and waiting weeks.

KNEC's answer: give every certificate a **digital fingerprint**, and publish that fingerprint somewhere nobody can secretly edit (the Avalanche blockchain). Now an employer scans a QR code and knows in seconds whether the certificate is real.

**Our project does the same thing for MUT**, starting with the **clearance certificate**: the form every student needs signed by the library, finance, hostels, their department and the dean before they can graduate.

## 2. Two ideas, one project

| Idea | In plain words | Where it shows up |
|---|---|---|
| **Business process automation** | Replace the paper form that a student carries from office to office with a digital workflow that routes itself, checks what it can automatically, and chases people who are slow. | Oracle APEX app |
| **Blockchain trust layer** | When the last office signs, the system issues a certificate whose fingerprint is stored on a public ledger, so it can be checked by anyone, forever. | Smart contract + QR page |

Automation is the *engine*; blockchain is the *seal*.

## 3. The fingerprint, explained with a wax seal

Imagine a letter sealed with wax, and the pattern of the seal is *unique to that exact letter*. If anyone opens the letter and changes a word, the seal breaks.

A **hash** is the digital version: a short code (like `0x93a5...`) calculated from the certificate's contents. Change **one letter** and the code becomes completely different. You can calculate it again later and compare.

**Demo moment:** on the verify page there is a button that changes one letter of the student's name and re-checks. Result flips from GENUINE to NOT VERIFIED. This is the most convincing 10 seconds of the demo.

## 4. What the blockchain actually is (and is not)

Think of a **public notice board** that thousands of computers around the world each keep a copy of. Writing on it requires permission. Once something is written, nobody (not MUT, not us, not a hacker) can secretly erase or change it without all the other copies disagreeing.

**What we write on it:** only the fingerprint plus a timestamp. Nothing else.

| The blockchain DOES | The blockchain does NOT |
|---|---|
| Prove a document is exactly what MUT recorded, unchanged | Store names, grades or any personal data |
| Show *when* it was recorded | Prove MUT made no mistake when issuing |
| Let anyone verify, even if MUT's servers are down | Replace the university's official records |

## 5. Life of one certificate (the 8 steps)

1. A student clicks **Request clearance** in the portal.
2. The system creates one task for each office. Finance and Library **clear themselves** if the student has no balance and no unreturned books.
3. Other offices see the request in their queue and **approve or reject**.
4. When every office has approved, the system calls the **anchor service**.
5. The anchor service builds the **PDF with a QR code** and calculates the **fingerprint**.
6. It writes the fingerprint to the **Avalanche contract** (this is the only blockchain step).
7. The student downloads the certificate.
8. An employer **scans the QR code**. The page recalculates the fingerprint from the details in the QR, looks it up on the blockchain, and shows GENUINE / REVOKED / NOT VERIFIED.

## 6. Who does what (suggested split for 4 people)

| Role | Owns | Folder |
|---|---|---|
| **Lead / integration** | Keeps the pieces connected, deploys the service, owns the demo | `anchor-service/`, `oracle/vm-setup.sh` |
| **Blockchain** | Wallet, faucet, contract deployment, explorer, testing | `contracts/`, `scripts/`, `docs/AVALANCHE-SETUP.md` |
| **Oracle / APEX** | Database, APEX pages, approval workflow | `oracle/` |
| **Pitch / liaison** | Talks to registrar and ICT, builds slides, runs the demo script, tests with "fake users" | `docs/QUESTIONS.md`, this file |

## 7. Five-minute demo script

1. **Problem (45s):** show a real news line about forged certificates. "Verification takes weeks and fakes slip through."
2. **Solution (30s):** one sentence: "Every MUT document gets a QR code that anyone can scan to confirm it is genuine."
3. **Live: request clearance (60s):** as a student (fake data), request clearance. Show Finance and Library clearing themselves.
4. **Live: offices approve (45s):** switch to an office account, approve the remaining steps.
5. **Live: certificate appears (45s):** download the PDF, open the **explorer link** to show the transaction on Avalanche.
6. **Live: scan and verify (45s):** scan the QR with a phone → GENUINE.
7. **Tamper test (30s):** press "change one letter" → NOT VERIFIED.
8. **Close (20s):** "KNEC did this for millions of national records. We built a MUT-sized version in two weeks. Next step: transcripts and degrees."

**Always have a screen recording of the whole thing as a backup** in case the venue internet fails.

## 8. Questions judges are likely to ask

**"Why blockchain? Couldn't you just use a database?"**
A database works if everyone trusts whoever controls it. The blockchain proves MUT's record has not been changed *by anyone, including insiders*, and lets outsiders verify without asking MUT or relying on MUT's server being online. Be honest that simpler alternatives exist (for example digitally signed PDFs); blockchain adds independent, permanent proof.

**"What about student privacy?"**
Nothing personal is on the blockchain, only a fingerprint with a random salt. The details live in the Oracle database. This matches the spirit of the Data Protection Act.

**"What if someone copies the QR onto a fake certificate?"**
The verify page shows the real name and details from the genuine record, and warns the verifier to compare them with the document in hand. A fake document with someone else's QR would show the wrong name.

**"Who controls it? What if the key is stolen?"**
Only approved wallets can write. Keys must be protected, and a lost wallet can be removed by the contract owner. Revocation handles mistakes. (See `LOOPHOLES.md`.)

**"Is this official?"**
No, it is a prototype using fake data. Next step is approval from MUT's ICT, registrar and legal advisers.

**"How is it different from what KNEC did?"**
Same core idea, fingerprints anchored on Avalanche with a public verification portal. KNEC works at national scale with a technology partner; ours is a university-sized prototype with an automation workflow in front of it.

**"What does it cost?"**
Testnet is free. On the real network each recording costs a tiny fee in AVAX; batch recording (a whole graduating class in one transaction) keeps it low. Get actual current figures before quoting any number.

## 9. Glossary

- **Blockchain:** a shared record book copied across many computers, very hard to alter secretly.
- **Avalanche:** one such network. **C-Chain** is its part that runs smart contracts.
- **Fuji:** Avalanche's free **test** network. Coins there have no value.
- **Smart contract:** a small program that lives on the blockchain and follows fixed rules (ours: "only approved issuers may record fingerprints").
- **Hash / fingerprint:** a short code calculated from a document; any change gives a totally different code.
- **Salt:** random extra text mixed in before hashing, so fingerprints cannot be guessed.
- **Wallet:** an account on the blockchain, controlled by a secret **private key** (never share it).
- **Gas:** the small fee paid to record something on the blockchain.
- **Faucet:** a website that gives free test coins.
- **Explorer (Snowtrace):** a public website where anyone can look up transactions.
- **Anchor:** to record a fingerprint on the blockchain.
- **Revoke:** to mark a recorded document as cancelled (history stays visible).
- **APEX:** Oracle's low-code tool for building web apps on top of a database.
- **ADB:** Oracle Autonomous Database.
- **OCI:** Oracle Cloud Infrastructure (where your VM lives).
