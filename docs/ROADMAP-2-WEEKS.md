# Two-week roadmap

Adjust the dates to your innovation-week schedule. Owners use the roles from `TEAM-GUIDE.md`: **Lead**, **Chain** (blockchain), **Oracle**, **Pitch**.

## Week 1: make the core work, on real infrastructure

| Day | Goal | Owner | Done when |
|---|---|---|---|
| 1 | Everyone reads `TEAM-GUIDE.md`; run `bash scripts/e2e-local.sh` on each laptop | All | Each person has seen a certificate issued and verified locally |
| 1 | Ask the questions in `QUESTIONS.md` (registrar, ICT, your friend) | Pitch | Answers written down; sponsor identified |
| 2 | Wallets created, Fuji test AVAX received (`AVALANCHE-SETUP.md` 1 to 4) | Chain | Balance visible in wallet |
| 2 | Autonomous DB created, `MUTV` user, `01_schema.sql` loaded | Oracle | `SELECT * FROM mv_students` returns 3 rows |
| 3 | Contract deployed on Fuji; address screenshot from the explorer | Chain | Address visible on Snowtrace |
| 3 | OCI VM created, `vm-setup.sh` run, `https://<host>/health` works | Lead | `/health` returns `ok` from your phone |
| 4 | Anchor service in live mode issues a real Fuji transaction | Lead + Chain | Explorer shows the fingerprint transaction |
| 4 | Verify page hosted; QR scan from a phone says GENUINE | Chain | Phone test passes |
| 5 | APEX: web credential + `02_issue_procedure.sql`; SQL test from `ORACLE-GUIDE.md` 6 works | Oracle | `mv_documents` row appears with a tx hash |
| 6 to 7 | Buffer day + first review with a lecturer; fix what broke | All | List of issues triaged |

## Week 2: workflow, polish, rehearse

| Day | Goal | Owner | Done when |
|---|---|---|---|
| 8 | APEX pages: request, status, office queue | Oracle | A student can request and see steps |
| 9 | Approve/reject buttons; auto-issue when the last office clears | Oracle + Lead | Clearing the last office produces a certificate |
| 10 | Registrar console: download PDF, explorer link, revoke | Oracle | Revoke makes the verify page say REVOKED |
| 11 | Tamper demo and failure cases (rejected student, owes fees, unreturned book) | Chain + Pitch | All three demo students behave as planned |
| 12 | Slides, demo script, **backup screen recording** | Pitch | Recording saved on two devices |
| 13 | Full dry run with fresh eyes; top up faucet; check `/health` | All | No surprises |
| 14 | Present | All | Done |

## Stretch goals (only if everything above is solid)
- Use `anchorBatch` to anchor a whole class in one transaction.
- Transcript document type (the generator already accepts `TRANSCRIPT`; add a proper layout).
- SMS/email notifications when an office approves.
- Move the issuer key into OCI Vault.
- Timetable generator (second automation idea) as a "next phase" slide.

## Rules of the road
- Demo data only. No real students.
- If something is not working by end of Day 4, simplify (run the service locally and show the explorer) rather than add features.
- One person owns each box in the architecture picture, and every explanation has two people who can give it.
