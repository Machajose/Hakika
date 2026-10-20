# Using your Oracle student package to your advantage

I do not know exactly what is in your package, so **check your OCI console** for what you really have (and when it expires; see section 8). Based on what you told me (APEX, Autonomous Databases, cloud virtual machines), here is the best use of each.

## 1. Who does what

| Oracle piece | Job in MUT-Verify | Why it is the right tool |
|---|---|---|
| **Autonomous Database (ADB)** | Stores students, offices, clearance requests, the audit log, and issued documents (including the PDF) | Real relational database; patches and backs itself up |
| **APEX** | The web app people use: student request page, office approval queue, registrar console | Low-code: tables to working pages in hours; built-in logins and roles |
| **OCI Compute VM** | Runs the **anchor service** (Node.js) that makes PDFs, calculates fingerprints and signs blockchain transactions | APEX cannot sign blockchain transactions itself, and the private key must live on a server you control |
| **Object Storage** (optional) | Backup copies of PDFs; could host the static verify page | Cheap file storage |
| **OCI Vault** (optional, recommended later) | Holds the issuer private key instead of a `.env` file | Keys do not sit in plain files |

What stays **outside** Oracle on purpose: the **verify page** and the **blockchain**. The public verify page should work even when the school's Oracle system is down, which is much of the point.

## 2. Architecture in one picture

```
APEX app (in ADB)  ──► PL/SQL: mv_issue_certificate ──► HTTPS ──► anchor-service on OCI VM ──► Avalanche
        ▲                                                         (makes PDF + QR, signs)
        └──── stores doc hash, tx hash, PDF back in the database ◄── reply
```

## 3. Create the Autonomous Database

1. OCI console → **Oracle Database → Autonomous Database → Create**.
2. Workload type: **Transaction Processing** (or APEX if offered). If your account offers an **Always Free** option, use it for the prototype.
3. Set the **ADMIN password** and store it safely.
4. Network access: the default **secure access from everywhere** is simplest for a student demo.
5. Wait until the status turns **Available** (a few minutes).

## 4. Create the app owner user, load the schema, create the APEX workspace

1. Open the database → **Database Actions** → **SQL** (logged in as ADMIN).
2. Create a normal user for the app (do not build in ADMIN):
   ```sql
   CREATE USER mutv IDENTIFIED BY "Choose-A-Strong-Password-1";
   GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, CREATE SEQUENCE, CREATE TRIGGER TO mutv;
   ALTER USER mutv QUOTA UNLIMITED ON data;
   GRANT EXECUTE ON apex_web_service TO mutv;   -- allows calling the anchor service (if your version needs the grant)
   ```
   (If `ON data` fails, run `SELECT tablespace_name FROM dba_tablespaces;` and use the one listed.)
3. Open **Database Actions → Database Users**, find `MUTV`, and enable **Web Access** (REST/ORDS) if you want APEX/REST later.
4. Log in to Database Actions as `MUTV` → **SQL** → run `oracle/01_schema.sql` (use *Run Script*, the "page with play button" icon).
5. Create the APEX workspace: from the database page open **Tools → Oracle APEX** (administration), sign in as ADMIN, **Create Workspace**, choose **Existing schema = MUTV**, and create a workspace admin user.
6. Sign in to the workspace as that user.

## 5. Make the anchor service reachable from the database

Autonomous Database only calls **HTTPS** addresses that have a **valid, trusted certificate**. A plain `http://ip:8080` or a self-signed certificate will fail.

Steps:
1. OCI console → **Compute → Instances → Create instance**. Ubuntu 22.04. If you have **Always Free** shapes, a small one is enough for this service. Add your SSH public key.
2. In the instance's subnet **Security List**, add **ingress** rules for TCP **80** and **443** from `0.0.0.0/0`.
3. Upload the `anchor-service` folder (`scp -r anchor-service ubuntu@<ip>:~/`) and `oracle/vm-setup.sh`.
4. Choose a hostname with a real certificate. Easiest free trick: `<ip with dashes>.sslip.io` (for example `152-67-10-20.sslip.io`). A DuckDNS name or a domain you own also works.
5. Run: `bash vm-setup.sh 152-67-10-20.sslip.io`. It installs Node, **Caddy** (automatic HTTPS), opens the VM firewall, and runs the service as a background service.
6. Edit `~/anchor-service/.env` (see `docs/AVALANCHE-SETUP.md` step 7), then `sudo systemctl restart mut-anchor`.
7. From your laptop: `curl https://152-67-10-20.sslip.io/health`.

> This script is a template I could not run on a real OCI VM. Run its steps one by one and read the output.

## 6. Connect APEX to the service

1. In APEX: **App Builder → Workspace Utilities → Web Credentials → Create**, static ID `MUT_ANCHOR_KEY`, type HTTP Header, header `x-api-key`, value = your `API_KEY`. (Fallback if your version lacks that type is described in the header of `oracle/02_issue_procedure.sql`.)
2. In `oracle/02_issue_procedure.sql` replace `YOUR-DOMAIN` with your hostname, then run the script in SQL Workshop as `MUTV`.
3. Test from SQL:
   ```sql
   -- create a request for the first demo student, then force-clear the remaining offices:
   DECLARE r NUMBER; BEGIN mv_request_clearance(1, r); DBMS_OUTPUT.PUT_LINE(r); END;
   /
   UPDATE mv_clearance_steps SET status='CLEARED', decided_by='TEST', decided_at=SYSTIMESTAMP
    WHERE request_id = 1 AND status <> 'CLEARED';
   BEGIN mv_issue_certificate(1); END;
   /
   SELECT doc_id, doc_hash, tx_hash, explorer_url FROM mv_documents;
   ```
   If you get an HTTP error, read `mv_audit_log` (the procedure logs failures there).

## 7. Build the APEX app (pages to create)

Use **App Builder → Create → New Application**. Suggested pages:

| Page | Type | What it does |
|---|---|---|
| **Request clearance** (student) | Form | Student (or you, as a demo) selects themselves and presses **Request**. Process: `mv_request_clearance(:P1_STUDENT_ID, :P1_REQUEST_ID)` |
| **My clearance status** | Classic Report on `mv_clearance_steps` | Shows each office with CLEARED / PENDING / REJECTED and whether it was automatic |
| **Office queue** | Interactive Report on `mv_office_queue_v` filtered to the logged-in office and `status='PENDING'` | Buttons **Approve** / **Reject** → process `mv_decide_step(:STEP_ID, 'CLEARED', :APP_USER, :REMARKS)`. After it runs, add a second process: *if the request's status is `CLEARED`, call `mv_issue_certificate(:REQUEST_ID)`* |
| **Registrar console** | Interactive Report on `mv_documents` | Download PDF column (APEX supports "Download BLOB" link columns), link to the explorer URL, **Revoke** button → `mv_revoke_document` |
| **Audit log** | Report on `mv_audit_log` | Answers "who approved what, when?" |

Roles: use APEX **Access Control** (or authorization schemes) so only Finance staff see the Finance queue, and only the registrar sees the Registrar console. For the demo, simple roles named after the offices are enough.

Automation that already exists in the SQL: Finance and Library clear themselves when the data says so. Show students DEMO/0001 (everything clears automatically except the human offices), DEMO/0002 (owes fees, so Finance stays pending), DEMO/0003 (unreturned book, so Library stays pending).

## 8. Limits and traps (read this one)

- **Your package may expire.** Student/free-tier benefits usually end after a time limit or when you graduate (you are a final-year student). Check the **expiry date and what happens to the resources**. Do not make a university process depend on your personal student account. For anything real, the system must run on an account owned by MUT.
- **Always Free resources can be reclaimed if idle**, and free-tier capacity varies by region. Run a keep-alive or check the instance the day before the demo.
- **ADB will not call your service** unless it is HTTPS with a trusted certificate on a public address. If this blocks you, plan B: have APEX only write a "queued" row, and let the Node service poll a REST endpoint of the database (ORDS) for rows to process. I have not built plan B.
- **Do not put real student data in the demo database.**
- **The private key.** On the VM it is in a file readable only by the service user. For anything beyond a demo, move it to **OCI Vault**.
- **Optional extra:** Oracle Database has **blockchain tables** (insert-only, tamper-evident tables inside the database). They are not the public blockchain, but they make a good *internal* audit log. Availability depends on your database version; check before promising it.

## 9. Order of work (fastest path)

1. Level 2 test locally (`scripts/e2e-local.sh`) so the team trusts the core.
2. Deploy contract on Fuji (`AVALANCHE-SETUP.md`).
3. Run the anchor service on your laptop first, and test `mv_issue_certificate` against a temporary public tunnel *or* skip straight to the VM.
4. Build the APEX pages.
5. Rehearse the full demo, then record it.
