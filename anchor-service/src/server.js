require("dotenv").config();
const express = require("express");
const rateLimit = require("express-rate-limit");
const crypto = require("crypto");
const chain = require("./chain");
const { fingerprint, encodePayload } = require("./hash");
const { buildCertificatePdf } = require("./pdf");

const PORT = Number(process.env.PORT || 8080);
const API_KEY = process.env.API_KEY || "";
const VERIFY_BASE_URL = process.env.VERIFY_BASE_URL || "http://localhost:5500/index.html";
const INSTITUTION = process.env.INSTITUTION_NAME || "Murang'a University of Technology";
const DOC_TYPES = ["CLEARANCE", "TRANSCRIPT", "DEGREE", "STUDENT_STATUS"];

if (!API_KEY || API_KEY.startsWith("change-me") || API_KEY.length < 16) {
  console.warn("[warn] API_KEY is missing or weak. Set a long random value in .env before exposing this service.");
}

chain.init();

const app = express();
app.disable("x-powered-by");
app.use(express.json({ limit: "100kb" }));
app.use(rateLimit({ windowMs: 60_000, limit: 60, standardHeaders: true, legacyHeaders: false }));

// ---- very small API-key check (constant-time compare) ----
function requireKey(req, res, next) {
  const given = Buffer.from(String(req.get("x-api-key") || ""));
  const want = Buffer.from(API_KEY);
  if (!want.length || given.length !== want.length || !crypto.timingSafeEqual(given, want)) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  next();
}

const HASH_RE = /^0x[0-9a-fA-F]{64}$/;
const str = (v, max = 120) => typeof v === "string" && v.trim().length > 0 && v.length <= max;

app.get("/health", async (_req, res) => {
  try {
    res.json({ ok: true, ...(await chain.health()) });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

/**
 * POST /issue   (needs x-api-key)
 * body: { docType, regNo, name, program, approvals?: [{office,status,date}] }
 * returns the PDF (base64) + fingerprint + blockchain transaction
 */
app.post("/issue", requireKey, async (req, res) => {
  try {
    const b = req.body || {};
    if (!DOC_TYPES.includes(b.docType)) return res.status(400).json({ error: `docType must be one of ${DOC_TYPES.join(", ")}` });
    for (const k of ["regNo", "name", "program"]) {
      if (!str(b[k])) return res.status(400).json({ error: `Missing or invalid: ${k}` });
    }

    const fields = {
      docId: crypto.randomUUID(),
      docType: b.docType,
      regNo: b.regNo,
      name: b.name,
      program: b.program,
      issuedOn: new Date().toISOString().slice(0, 10),
      salt: crypto.randomBytes(16).toString("hex"),
    };

    const docHash = fingerprint(fields); // throws if a field contains "|"
    const verifyUrl = `${VERIFY_BASE_URL}#${encodePayload(fields)}`;

    // 1) Build the PDF first (if this fails, nothing has been written to the blockchain)
    const approvals = Array.isArray(b.approvals)
      ? b.approvals.slice(0, 10).map((a) => ({
          office: String(a.office || "").slice(0, 40),
          status: String(a.status || "").slice(0, 20),
          date: String(a.date || "").slice(0, 10),
        }))
      : [];
    const pdf = await buildCertificatePdf({ institution: INSTITUTION, ...fields, verifyUrl, approvals });

    // 2) Write the fingerprint to the blockchain
    const tx = await chain.anchor(docHash);

    res.json({
      docId: fields.docId,
      docHash,
      issuedOn: fields.issuedOn,
      txHash: tx.txHash,
      explorerUrl: tx.explorerUrl,
      dryRun: tx.dryRun,
      verifyUrl,
      pdfBase64: pdf.toString("base64"),
    });
  } catch (e) {
    console.error("[issue] failed:", e.message);
    res.status(500).json({ error: e.message });
  }
});

/** POST /revoke  (needs x-api-key)  body: { docHash } */
app.post("/revoke", requireKey, async (req, res) => {
  try {
    const { docHash } = req.body || {};
    if (!HASH_RE.test(docHash || "")) return res.status(400).json({ error: "docHash must be a 0x + 64 hex string" });
    const tx = await chain.revoke(docHash);
    res.json({ ok: true, ...tx });
  } catch (e) {
    console.error("[revoke] failed:", e.message);
    res.status(500).json({ error: e.message });
  }
});

/** GET /verify/:hash  (public, read-only convenience) */
app.get("/verify/:hash", async (req, res) => {
  try {
    if (!HASH_RE.test(req.params.hash)) return res.status(400).json({ error: "Bad hash" });
    res.json(await chain.verify(req.params.hash));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.listen(PORT, () => console.log(`MUT-Verify anchor service listening on :${PORT}`));
