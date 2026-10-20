#!/usr/bin/env bash
# Full local test with NO wallet, NO internet blockchain, NO cost:
#   starts a private test blockchain -> deploys the contract -> starts the service ->
#   issues a certificate -> verifies it -> revokes it -> shows tamper detection.
# Run from the project root:   bash scripts/e2e-local.sh
set -euo pipefail
set -m   # job control: each background job gets its own process group, so cleanup can stop the whole tree
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
HH_ARGS=""; [ -n "${HH_CONFIG:-}" ] && HH_ARGS="--config $HH_CONFIG"
TMP="$(mktemp -d)"
PIDS=()
cleanup() {
  for p in "${PIDS[@]:-}"; do kill -TERM -- "-$p" 2>/dev/null || kill "$p" 2>/dev/null || true; done
  rm -f "$ROOT/deployment.localhost.json"; rm -rf "$TMP"
}
trap cleanup EXIT

echo "1) Starting a private test blockchain..."
npx hardhat $HH_ARGS node > "$TMP/node.log" 2>&1 & PIDS+=($!)
KEY=""
for i in $(seq 1 40); do
  KEY=$(grep -A1 "Account #0" "$TMP/node.log" 2>/dev/null | grep -o "0x[0-9a-f]\{64\}" | head -1 || true)
  [ -n "$KEY" ] && break
  sleep 1
done
if [ -z "$KEY" ]; then
  echo "Could not start the test blockchain. Is something already using port 8545? Log:"; cat "$TMP/node.log"; exit 1
fi

echo "2) Deploying the contract..."
npx hardhat $HH_ARGS run scripts/deploy.js --network localhost | grep -E "deployed to"
ADDR=$(node -e "console.log(require('./deployment.localhost.json').address)")

echo "3) Starting the anchor service (live mode, local chain)..."
( cd anchor-service
  DRY_RUN=false API_KEY=local-test-key-0123456789 PORT=8097 RPC_URL=http://127.0.0.1:8545 CHAIN_ID=31337 \
  CONTRACT_ADDRESS="$ADDR" ISSUER_PRIVATE_KEY="$KEY" node src/server.js > "$TMP/svc.log" 2>&1 ) & PIDS+=($!)
sleep 3

echo "4) Issuing a certificate for a FAKE student..."
curl -s -X POST localhost:8097/issue -H 'content-type: application/json' -H 'x-api-key: local-test-key-0123456789' \
  -d '{"docType":"CLEARANCE","regNo":"DEMO/0001/2021","name":"Jane Wanjiru","program":"BSc Medical Laboratory Sciences"}' > "$TMP/issue.json"
node -e "const j=require('$TMP/issue.json'); if(j.error) throw new Error(j.error); console.log('   fingerprint:', j.docHash); console.log('   tx         :', j.txHash); require('fs').writeFileSync('$ROOT/sample-certificate.pdf', Buffer.from(j.pdfBase64,'base64')); console.log('   PDF saved  : sample-certificate.pdf')"
H=$(node -e "console.log(require('$TMP/issue.json').docHash)")

echo "5) Verify (should say exists:true, revoked:false):"; curl -s localhost:8097/verify/$H; echo
echo "6) Revoke it:"; curl -s -X POST localhost:8097/revoke -H 'content-type: application/json' -H 'x-api-key: local-test-key-0123456789' -d "{\"docHash\":\"$H\"}" | cut -c1-80; echo
echo "7) Verify again (should say revoked:true):"; curl -s localhost:8097/verify/$H; echo
echo "8) A fingerprint that was never issued (should say exists:false):"; curl -s localhost:8097/verify/0x$(printf 'ab%.0s' {1..32}); echo
echo "9) Three certificates requested AT THE SAME MOMENT (tests the write queue):"
CURLS=()
for n in 1 2 3; do
  curl -s -X POST localhost:8097/issue -H 'content-type: application/json' -H 'x-api-key: local-test-key-0123456789' \
    -d "{\"docType\":\"CLEARANCE\",\"regNo\":\"DEMO/100$n/2021\",\"name\":\"Student $n\",\"program\":\"BSc Test\"}" > "$TMP/c$n.json" &
  CURLS+=($!)
done
for c in "${CURLS[@]}"; do wait "$c" || true; done
for n in 1 2 3; do node -e "const j=require('$TMP/c$n.json'); console.log('   #$n', j.error ? 'FAILED: '+j.error : 'ok '+j.docHash.slice(0,18)+'...')"; done
echo; echo "ALL STEPS DONE. Open sample-certificate.pdf to see what a certificate looks like."
