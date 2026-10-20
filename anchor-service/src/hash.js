/**
 * The "fingerprint recipe". THE SAME RECIPE MUST BE USED BY THE VERIFY PAGE (verify-web/index.html).
 * If you change anything here, change it there too, and bump the version string.
 *
 * fingerprint = keccak256( "MUTV1|docId|docType|regNo|name|program|issuedOn|salt" )
 *
 * The random `salt` is what protects privacy: without it, someone could guess
 * "JOHN|SC211/0001/2021" and test whether it matches a hash on the public chain.
 */
const { keccak256, toUtf8Bytes } = require("ethers");

const VERSION = "MUTV1";

function clean(v, field) {
  const s = String(v ?? "").trim();
  if (!s) throw new Error(`Missing field: ${field}`);
  if (s.includes("|")) throw new Error(`Field "${field}" must not contain the "|" character`);
  return s.normalize("NFC");
}

function canonicalString(f) {
  return [
    VERSION,
    clean(f.docId, "docId"),
    clean(f.docType, "docType"),
    clean(f.regNo, "regNo"),
    clean(f.name, "name"),
    clean(f.program, "program"),
    clean(f.issuedOn, "issuedOn"),
    clean(f.salt, "salt"),
  ].join("|");
}

function fingerprint(fields) {
  return keccak256(toUtf8Bytes(canonicalString(fields)));
}

/** What goes inside the QR link (after the #). Base64url JSON. */
function encodePayload(f) {
  const obj = { v: 1, d: f.docId, t: f.docType, r: f.regNo, n: f.name, p: f.program, i: f.issuedOn, s: f.salt };
  return Buffer.from(JSON.stringify(obj), "utf8").toString("base64url");
}

module.exports = { fingerprint, canonicalString, encodePayload, VERSION };
