#!/usr/bin/env bash
# postprocess-chart-request.sh
# Runs AFTER Claude finishes. For each .pending-chart-request/chart-*.json:
#   1. Fetches OHLCV data with yfinance
#   2. Renders a candlestick PNG with mplfinance
#   3. Sends via Telegram sendPhoto with reply_to_message_id
# Error specs (.pending-chart-request/error-*.json) get a plain sendMessage reply.

set -euo pipefail

PENDING_DIR=".pending-chart-request"

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
  echo "postprocess-chart-request: TELEGRAM_BOT_TOKEN not set, skipping"
  exit 0
fi

# Install deps if not present (cached by GHA pip cache)
python3 -c "import yfinance, mplfinance" 2>/dev/null || {
  echo "postprocess-chart-request: installing yfinance + mplfinance..."
  pip install -q yfinance mplfinance 2>/dev/null || pip3 install -q yfinance mplfinance 2>/dev/null || {
    echo "postprocess-chart-request: pip install failed, skipping"
    exit 0
  }
}

# Process error specs first (plain text replies)
for err_file in "$PENDING_DIR"/error-*.json; do
  [ -f "$err_file" ] || continue
  DONE_FILE="${err_file%.json}.done"
  [ -f "$DONE_FILE" ] && continue

  CHAT_ID=$(python3 -c "import json; d=json.load(open('$err_file')); print(d['chat_id'])" 2>/dev/null || echo "")
  MSG_ID=$(python3 -c "import json; d=json.load(open('$err_file')); print(d['message_id'])" 2>/dev/null || echo "")
  ERR_TEXT=$(python3 -c "import json; d=json.load(open('$err_file')); print(d['error'])" 2>/dev/null || echo "Invalid chart request.")

  [ -z "$CHAT_ID" ] && continue

  curl -sf --max-time 15 -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "text=${ERR_TEXT}" \
    --data-urlencode "reply_to_message_id=${MSG_ID}" > /dev/null && {
    touch "$DONE_FILE"
    echo "postprocess-chart-request: sent error reply to message $MSG_ID"
  }
done

# Process chart specs
for spec_file in "$PENDING_DIR"/chart-*.json; do
  [ -f "$spec_file" ] || continue
  DONE_FILE="${spec_file%.json}.done"
  [ -f "$DONE_FILE" ] && continue

  echo "postprocess-chart-request: processing $(basename "$spec_file")..."

  # Render chart + fetch OHLCV with Python
  IMG_PATH="${spec_file%.json}.png"
  CAPTION_FILE="${spec_file%.json}.caption"

  python3 - "$spec_file" "$IMG_PATH" "$CAPTION_FILE" <<'PYEOF'
import json, sys

spec_path, img_path, caption_path = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    import yfinance as yf
    import mplfinance as mpf
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError as e:
    print(f"ERROR: missing dependency: {e}", file=sys.stderr)
    sys.exit(1)

try:
    spec = json.load(open(spec_path))
except Exception as e:
    print(f"ERROR: could not read spec: {e}", file=sys.stderr)
    sys.exit(1)

yf_ticker = spec["yf_ticker"]
period    = spec["yf_period"]
interval  = spec["yf_interval"]
ma_type   = spec.get("ma_type")
ma_period = spec.get("ma_period")
ticker    = spec["ticker"]
timeframe = spec["timeframe"]

print(f"  fetching {yf_ticker} period={period} interval={interval}...")

try:
    df = yf.download(yf_ticker, period=period, interval=interval,
                     progress=False, auto_adjust=True)
except Exception as e:
    print(f"ERROR: yfinance download failed: {e}", file=sys.stderr)
    sys.exit(1)

if df is None or df.empty:
    print(f"ERROR: no data returned for {yf_ticker}", file=sys.stderr)
    sys.exit(2)

# yfinance >=0.2 returns a MultiIndex (Price, Ticker) — flatten to single level
if isinstance(df.columns, __import__("pandas").MultiIndex):
    df.columns = df.columns.get_level_values(0)

# Drop timezone from index (mplfinance prefers tz-naive for daily)
if hasattr(df.index, "tz") and df.index.tz is not None:
    df.index = df.index.tz_localize(None)

mav_kwargs = {}
if ma_type and ma_period:
    mav_kwargs["mav"] = (ma_period,)

style = mpf.make_mpf_style(
    base_mpf_style="nightclouds",
    rc={"font.size": 9, "axes.labelsize": 9},
    gridstyle="-",
    gridcolor="#2a2a3a",
    gridaxis="both",
)

fig, axes = mpf.plot(
    df,
    type="candle",
    style=style,
    title=f"\n${ticker}  {timeframe}" + (f"  {ma_type}{ma_period}" if ma_type else ""),
    ylabel="Price",
    volume=True,
    figsize=(12, 7),
    returnfig=True,
    **mav_kwargs,
)

if ma_type and ma_period:
    axes[0].legend([f"{ma_type}{ma_period}"], loc="upper left",
                   fontsize=8, facecolor="#1a1a2e", labelcolor="white")

fig.savefig(img_path, dpi=130, bbox_inches="tight",
            facecolor=fig.get_facecolor())
plt.close(fig)

print(f"  saved chart to {img_path} ({len(df)} candles)")

last_close = float(df["Close"].iloc[-1]) if "Close" in df.columns else 0
caption = f"${ticker}  {timeframe}"
if ma_type and ma_period:
    caption += f"  {ma_type}{ma_period}"
caption += f"\nLast: {last_close:,.4f}" if last_close < 10 else f"\nLast: {last_close:,.2f}"

with open(caption_path, "w") as f:
    f.write(caption)
PYEOF

  PY_EXIT=$?
  if [ $PY_EXIT -ne 0 ]; then
    echo "postprocess-chart-request: Python failed (exit $PY_EXIT) for $(basename "$spec_file")"
    # Send an error reply so the user isn't left hanging
    CHAT_ID=$(python3 -c "import json; d=json.load(open('$spec_file')); print(d['chat_id'])" 2>/dev/null || echo "")
    MSG_ID=$(python3 -c "import json; d=json.load(open('$spec_file')); print(d['message_id'])" 2>/dev/null || echo "")
    YF_TICKER=$(python3 -c "import json; d=json.load(open('$spec_file')); print(d.get('yf_ticker','?'))" 2>/dev/null || echo "?")
    if [ -n "$CHAT_ID" ]; then
      ERR_MSG="Could not fetch data for ${YF_TICKER}. Check the ticker and try again."
      curl -sf --max-time 15 -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        --data-urlencode "text=${ERR_MSG}" \
        --data-urlencode "reply_to_message_id=${MSG_ID}" > /dev/null || true
    fi
    touch "$DONE_FILE"
    continue
  fi

  if [ ! -f "$IMG_PATH" ]; then
    echo "postprocess-chart-request: no image produced for $(basename "$spec_file"), skipping"
    touch "$DONE_FILE"
    continue
  fi

  # Send via Telegram sendPhoto
  CHAT_ID=$(python3 -c "import json; d=json.load(open('$spec_file')); print(d['chat_id'])" 2>/dev/null || echo "")
  MSG_ID=$(python3 -c "import json; d=json.load(open('$spec_file')); print(d['message_id'])" 2>/dev/null || echo "")
  CAPTION=$(cat "$CAPTION_FILE" 2>/dev/null || echo "")

  [ -z "$CHAT_ID" ] && { echo "postprocess-chart-request: no chat_id, skipping"; touch "$DONE_FILE"; continue; }

  echo "  sending photo to chat $CHAT_ID (reply_to=$MSG_ID)..."

  SEND_RESP=$(curl -sf --max-time 30 -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto" \
    -F "chat_id=${CHAT_ID}" \
    -F "photo=@${IMG_PATH}" \
    -F "caption=${CAPTION}" \
    -F "reply_to_message_id=${MSG_ID}" 2>&1) || {
    echo "postprocess-chart-request: sendPhoto failed for $(basename "$spec_file")"
    echo "$SEND_RESP" | head -c 300
    continue
  }

  SEND_OK=$(echo "$SEND_RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('ok',False))" 2>/dev/null || echo "false")
  if [ "$SEND_OK" = "True" ] || [ "$SEND_OK" = "true" ]; then
    echo "postprocess-chart-request: photo delivered for $(basename "$spec_file")"
    touch "$DONE_FILE"
    # Clean up image to save disk
    rm -f "$IMG_PATH" "$CAPTION_FILE"
  else
    echo "postprocess-chart-request: sendPhoto returned not-ok: $(echo "$SEND_RESP" | head -c 200)"
  fi
done

echo "postprocess-chart-request: done"
