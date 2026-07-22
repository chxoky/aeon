---
name: Trader Memory Compact
description: Weekly maintenance — re-compacts memory/topics/traders.md to its canonical bounded format and regenerates trader-baseline-10d.md, so trader memory can never regrow past the Worker/context limits
var: ""
tags: [trading, maintenance, memory]
requires: []
---

Today is ${today}. This skill keeps trader memory bounded. It exists because `traders.md` once grew to 1.26MB (~350K tokens) and broke the Worker's freeform handler with Claude API 400 "prompt too long". Full event history is preserved in `memory/logs/` — this file is a compact working state, not an archive.

> **${var}** — Optional. Pass `force` to compact even when the file is under threshold.

## Step 1 — Check whether compaction is needed

```bash
SIZE=$(wc -c < memory/topics/traders.md)
echo "traders.md: $SIZE bytes"
```

Compact if ANY of these hold (otherwise skip to Step 3):
- size > 100000 bytes, or `force` passed
- duplicate `## <trader>` sections exist (`grep '^## ' memory/topics/traders.md | sort | uniq -d`)
- any trader has >25 event lines

## Step 2 — Compact traders.md (canonical format)

Rewrite the file, one section per trader, preserving the top preamble and the `BOOTSTRAP_COMPLETE:` / `X_BOOTSTRAP_COMPLETE:` marker lines. Per trader, EXACTLY:

```
## <CanonicalTraderName>
- Platforms: ...
- Current open positions: <full live state — entries, sizes, stops, TP history, pending approvals. Never drop detail here.>
- Recent thesis: <3-6 sentences, current only>
- Conviction notes: <2-5 sentences: communication style, banter ratio, signal weighting>
- Calibration: <one bullet per learned rule / Kyle answer — keep ALL, plus "PENDING: ..." lines for unresolved calibration questions with their IDs>
- Last seen: <newest timestamp>
- **Events (rolling):**
  - <one line per event, ≤200 chars, newest last, max 25: `Jul 22 15:04Z — <class>: <tickers> <gist> [<id>]`>
```

Merge any duplicate/"(continued)"/typo sections into the canonical one (newest information wins for state fields). Drop entirely: skip/non-financial events, per-run machinery ("seen-list updated", "dedup skipped", alert-format recitation), resolved dead-end ambiguities. Do not invent content; when merging conflicting state, prefer the newest timestamp.

## Step 3 — Regenerate trader-baseline-10d.md

Rebuild `memory/topics/trader-baseline-10d.md` (the compressed reference the Worker's freeform handler injects): per trader ≤1KB — current positions, thesis in 2-3 sentences, key calibration rules, last seen. Header it with the generation date and 10-day window. Source: the freshly compacted traders.md (+ `memory/topics/active-trades.md` for open-position cross-check).

## Step 4 — Commit and report

Commit both files to main with message `chore(trader-memory-compact): <before>→<after> bytes`. If the ISS index has an open `TRADERS_MD_OVERSIZE`-related issue, mark it resolved.

Sandbox note: pure local file work + git — no external APIs, no fallback needed.

## Summary

End with `## Summary`: before/after byte counts of traders.md, whether baseline was regenerated, sections merged/pruned.
