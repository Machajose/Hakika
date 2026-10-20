// Tiny test with no framework: node test/hash.test.js
const assert = require("assert");
const { fingerprint, canonicalString, encodePayload } = require("../src/hash");

const base = {
  docId: "11111111-2222-3333-4444-555555555555",
  docType: "CLEARANCE",
  regNo: "SC211/0001/2021",
  name: "Jane Wanjiru",
  program: "BSc Medical Laboratory Sciences",
  issuedOn: "2026-10-19",
  salt: "abcdef0123456789abcdef0123456789",
};

const h1 = fingerprint(base);
assert.match(h1, /^0x[0-9a-f]{64}$/);

// same input -> same fingerprint
assert.strictEqual(fingerprint({ ...base }), h1);

// change ONE letter -> completely different fingerprint (this is the "tamper" demo)
assert.notStrictEqual(fingerprint({ ...base, name: "Jane Wanjiro" }), h1);

// different salt -> different fingerprint
assert.notStrictEqual(fingerprint({ ...base, salt: "00000000000000000000000000000000" }), h1);

// "|" is rejected so fields cannot be smuggled across boundaries
assert.throws(() => fingerprint({ ...base, name: "Jane|Wanjiru" }));

// missing field is rejected
assert.throws(() => fingerprint({ ...base, regNo: "" }));

// payload round-trips
const decoded = JSON.parse(Buffer.from(encodePayload(base), "base64url").toString("utf8"));
assert.strictEqual(decoded.n, base.name);
assert.strictEqual(decoded.s, base.salt);

console.log("canonical:", canonicalString(base));
console.log("hash     :", h1);
console.log("All hash tests passed");
