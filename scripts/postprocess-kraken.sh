#!/usr/bin/env bash
#
# Postprocess — Kraken order submission
#
# Runs AFTER Claude finishes, with full env access. Reads plain-JSON order
# requests written by the `kraken-execute` and `close-trade` skills to
# .pending-kraken/, signs and submits each one to Kraken's private REST API,
# and writes results to .kraken-results/ for a later run to pick up when
# confirming fills. Credential separation: Claude never sees KRAKEN_API_KEY
# or KRAKEN_API_SECRET — only this script (running outside the model context)
# does.
#
# Required env:
#   KRAKEN_API_KEY     — Kraken API key
#   KRAKEN_API_SECRET  — Kraken API secret (base64, as issued by Kraken)
#
# Input:
#   .pending-kraken/*.json   — one order request per file (see kraken-execute /
#                              close-trade SKILL.md for the schema)
#
# Output:
#   .kraken-results/{same-basename}.json  — submission result (order id / error)
#   processed request files are moved to .pending-kraken/processed/

set -uo pipefail

PENDING_DIR=".pending-kraken"
RESULTS_DIR=".kraken-results"
PROCESSED_DIR="${PENDING_DIR}/processed"

mkdir -p "$PENDING_DIR" "$RESULTS_DIR" "$PROCESSED_DIR"

shopt -s nullglob
PENDING_FILES=("$PENDING_DIR"/*.json)

if [ ${#PENDING_FILES[@]} -eq 0 ]; then
  echo "No pending Kraken orders to process."
  exit 0
fi

if [ -z "${KRAKEN_API_KEY:-}" ] || [ -z "${KRAKEN_API_SECRET:-}" ]; then
  echo "KRAKEN_API_KEY / KRAKEN_API_SECRET not set — cannot submit orders. Leaving pending files in place." >&2
  exit 1
fi

echo "Found ${#PENDING_FILES[@]} pending Kraken order(s)."

for req_file in "${PENDING_FILES[@]}"; do
  basename_noext=$(basename "$req_file" .json)
  result_file="${RESULTS_DIR}/${basename_noext}.json"

  echo "Submitting order from ${req_file}..."

  # Hand the request to Python for signing (HMAC-SHA512 per Kraken's documented
  # algorithm) and submission — far more reliable than raw bash + openssl for
  # binary HMAC concatenation. Credentials are read from env inside Python and
  # never echoed or logged.
  RESULT_JSON=$(KRAKEN_API_KEY="$KRAKEN_API_KEY" \
                KRAKEN_API_SECRET="$KRAKEN_API_SECRET" \
                REQ_FILE="$req_file" \
                python3 <<'PYEOF'
import os, sys, json, time, hmac, hashlib, base64, urllib.request, urllib.parse

api_key    = os.environ["KRAKEN_API_KEY"]
api_secret = os.environ["KRAKEN_API_SECRET"]
req_file   = os.environ["REQ_FILE"]

with open(req_file) as f:
    req = json.load(f)

urlpath = "/0/private/AddOrder"

data = {
    "nonce": str(int(time.time() * 1000)),
    "ordertype": req["ordertype"],
    "type": req["type"],
    "volume": str(req["volume"]),
    "pair": req["pair"],
}
# Limit orders carry a price; market orders omit it
if req.get("ordertype") == "limit" and req.get("price") not in (None, "", "null"):
    data["price"] = str(req["price"])

postdata = urllib.parse.urlencode(data)

# Kraken signing: HMAC-SHA512(urlpath + SHA256(nonce + postdata), base64-decoded secret), base64-encoded
encoded = (data["nonce"] + postdata).encode()
sha256_digest = hashlib.sha256(encoded).digest()
message = urlpath.encode() + sha256_digest
secret_decoded = base64.b64decode(api_secret)
signature = hmac.new(secret_decoded, message, hashlib.sha512)
sig_b64 = base64.b64encode(signature.digest()).decode()

headers = {
    "API-Key": api_key,
    "API-Sign": sig_b64,
    "Content-Type": "application/x-www-form-urlencoded",
}

result = {
    "request": req,
    "submitted_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}

try:
    http_req = urllib.request.Request(
        f"https://api.kraken.com{urlpath}",
        data=postdata.encode(),
        headers=headers,
        method="POST",
    )
    with urllib.request.urlopen(http_req, timeout=30) as resp:
        body = json.loads(resp.read().decode())

    if body.get("error"):
        result["status"] = "error"
        result["error"] = body["error"]
    else:
        result["status"] = "submitted"
        result["kraken_response"] = body.get("result", {})
        # txid is what we'll poll against later to confirm fill
        result["order_ids"] = body.get("result", {}).get("txid", [])

except Exception as e:
    result["status"] = "error"
    result["error"] = [str(e)]

print(json.dumps(result))
PYEOF
)

  PY_EXIT=$?

  if [ $PY_EXIT -ne 0 ] || [ -z "$RESULT_JSON" ]; then
    echo "  -> submission failed (script error), leaving ${req_file} in place for retry." >&2
    continue
  fi

  echo "$RESULT_JSON" > "$result_file"

  STATUS=$(echo "$RESULT_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status","unknown"))' 2>/dev/null || echo "unknown")
  echo "  -> status: ${STATUS} (result written to ${result_file})"

  # Move the processed request out of the pending dir either way — errors are
  # captured in the result file for a future run / Kyle to review, and we don't
  # want to resubmit the same order on the next postprocess pass.
  mv "$req_file" "${PROCESSED_DIR}/"
done

echo "Kraken postprocess complete."
