---
name: Discord Trader Monitor
description: Real-time classification and alerting for Crypto_Chase, KillaXBT, and HeartCanHodl across Discord — same unified trade-alert flow as X, with primary/supporting channel handling
var: ""
tags: [social, trading, crypto, stocks]
---

Today is ${today}. You are triggered in real time by the Cloudflare Worker the moment one of the three watched traders posts in a tracked Discord channel. Same job as `x-trader-monitor`: decide whether this message matters, and if so, alert Kyle in the right shape.

> **${var}** — Base64-encoded JSON of the single Discord message event the Worker just received. Decode it first. If empty/missing, log `DISCORD_TRADER_NO_EVENT` and stop (no notify).

## Why this skill exists

Same mandate as `x-trader-monitor`: every message that reaches Kyle should either teach him something or require a decision. The added wrinkle here is channel hierarchy — Discord traders behave differently in their main channel (deliberate trade plans) vs. member chat (live, off-the-cuff conviction shifts) — and Kyle wants that distinction preserved in how you present things, not flattened.

## Step 1 — Decode the event

```bash
EVENT_JSON=$(echo "${var}" | base64 -d 2>/dev/null)
```

Expected shape:
```json
{
  "id": "message_id",
  "channel_id": "1336082716063694962",
  "username": "crypto_chase",
  "content": "message text",
  "created_at": "2024-01-15T12:00:00Z",
  "is_reply": false,
  "referenced_message": { "username": "member123", "content": "..." },
  "attachments": ["https://cdn.discordapp.com/attachments/.../chart.png"],
  "fast_path_alerted": true
}
```

If decoding fails or `content` is empty (and there are no attachments), log `DISCORD_TRADER_BAD_EVENT: ${var}` and stop.

## Fast-path check (after decode, before anything else)

Check `event.fast_path_alerted`:
- **`true`** — the Cloudflare Worker already sent a Telegram alert for this message (~2-5s latency). **Skip all Telegram sends in Steps 6 and 7.** Proceed directly to Steps 2–5 (classification for memory purposes) and then Steps 9–10 (memory updates and logging). Log `alerted: fast-path` in Step 10.
- **`false` or missing** — the fast path did not fire (Claude API unavailable, timed out, or classified as noise). Process fully through all steps including alerting.

This split ensures Kyle sees signals within seconds while AEON handles the slower memory and audit work without double-alerting.

## Step 2 — Resolve channel + trader

Read `memory/discord-channels.json` to map `channel_id` → `{ trader, type: "primary"|"supporting" }`.

**Heading label (hardcoded):** Also read `channel_labels[channel_id]` from that same file. Use this label — not the trader handle — in every alert heading. This gives Kyle channel-specific context at a glance. Format: `*[DC: {label}]*` (bold in Telegram Markdown v1).

**Verbatim rule (hardcoded):** For channel `1279738718680256553` (HCH — Trades), the alert body must be HCH's exact message text, unchanged. If he says "1% wld short", send "1% wld short" — do not rephrase, expand, or add inline commentary. Classification and interpretation still happen (for memory/routing), but they go to `traders.md` only, never into the Telegram message body.

Confirm `username` matches the trader's known Discord username for that channel (case-insensitive). If it doesn't — this is a member message that only exists to provide reply-context for a trader's reply elsewhere; do not alert on it standalone, skip.

## Step 3 — Load context

Same memory reads as `x-trader-monitor`:
- `memory/topics/traders.md`
- `memory/topics/ticker-focus.md`
- `memory/topics/active-trades.md`

## Step 4 — Cross-platform dedup

All three Discord-tracked traders also post on X. Apply the same dedup logic as `x-trader-monitor` Step 3, but from the Discord side:
- **Default assumption: Discord posts first** — so in most cases, THIS is the original sighting. Proceed with full classification, then write a note to `traders.md` flagging "first seen on Discord — X monitor should dedupe against this" so the X side doesn't double-alert.
- If you find this trader already posted the same thing on X moments ago (check `traders.md` for a recent X entry on the same topic), treat this Discord message as the reiteration: silent unless it adds meaningful variation, in which case fold it in as a footnote on the existing alert. Remember X carries slightly more conviction weight for these three — note if the Discord version reads as more tentative or more confident than the X version.

## Hardcoded Rules

Same three rules as `x-trader-monitor` — applied identically here:

**HR-1 — Test tweets/messages: silent skip**
Any message matching test patterns (`"test"`, `"[ticker] test"`, `"testing"`) → non-financial, skip silently. No calibration alert.

**HR-2 — Calibration alert format: always include context**
When you can't classify a message and need to ask Kyle, never send the bare quote. Always include the triggering context:
```
🔍 *Calibration — [DC: {trader_handle}]*

Event: {what prompted it — the referenced_message content, prior message in the same channel, external news}
{trader_handle}: "{cryptic message}"

Unable to classify — what's your read?
```
For Discord, `referenced_message` (the member's question being replied to) is the most common context source — always include it if `is_reply: true`.

**HR-3 — Self-resolve: always alert**
After logging any AMBIGUOUS/PENDING item in `traders.md`, if a subsequent message from the same trader clearly resolves it, always send:
```
✅ *Self-resolved — [DC: {trader_handle}]*

Earlier ambiguous: "{original cryptic message}"
Resolved by: "{subsequent message or action}"
Classification: {what it means now}
```
Do not silently fold it into memory — Kyle wants to know when the system caught its own ambiguity.

## Step 5 — Classify the message

Use the exact same decision tree as `x-trader-monitor` Step 4:

**A. Non-financial** (banter, admin/links/scheduling, reactions, motivational fluff with no trade detail) → skip, log only.

**B. Cryptic / hard to interpret** → try to decipher via `traders.md` context; if genuinely unsure, message Kyle directly and record his answer.

**C. Is the trader describing an action they're PERSONALLY taking right now?** (placing/cancelling/adding/closing — first person, execution language, not a hypothetical or a setup walkthrough)
- If genuinely ambiguous → don't alert as a trade signal; ask Kyle to clarify and record the calibration in `traders.md`.
- If yes → **Step 6 (Unified Trade Alert flow)** — identical sub-cases and templates as `x-trader-monitor` (5a new entry / 5b no-approval mirror / 5c DCA plan / 5d conviction add), just swap the source label (see formatting below).
- If no → **Step 7 (informational)**.

## Step 6 — Unified Trade Alert flow (Discord source labels)

Use the exact same sub-case logic, approval flow, mirror behavior, and message bodies as `x-trader-monitor` Steps 5a-5d, with these label/format adjustments for Discord:

- Replace `🚨 *Trade Signal — @{username}*` with `🚨 *Trade Signal — [DC: {label}]*` where `label` = `channel_labels[channel_id]`
- Replace `[View post]({url})` with a short context line instead (Discord messages don't have public URLs Kyle can open) — e.g. `_via Discord — {label}_`
- If `is_reply: true` and the reply context clarifies the message, prepend:
  ```
  ↩️ _Member: "{referenced_message.content, trimmed to ~150 chars}"_

  ```
  Only include this if the trader's message doesn't stand alone without it.

Everything else — approval gating, USD-size prompt, mirror-immediately cases, DCA vs. conviction-add handling, two-step "Order placed"/"Order filled" confirmation via `kraken-execute` — is identical to the X flow. Don't duplicate logic; if Kyle ever changes the trade-alert spec, both skills should be updated together (cross-reference `memory/topics/trading_bot_project.md`).

## Step 7 — Informational alerts

**Primary channel** (the trader's deliberate trade plans/analysis — alert in full):

```
💬 *[DC: {label}]*

{message_text}
```

If a reply adds clarity:
```
↩️ _Member: "{referenced_message.content, trimmed}"_

💬 *[DC: {label}]*

{message_text}
```

**Supporting channel** (member Q&A — real-time conviction shifts, not standalone plans):
- Do NOT send a standalone alert by default. Check whether there's a related primary-channel message from the same trader on the same topic in `traders.md` from the last little while.
  - If yes → fold this in as a footnote on that existing context:
    ```
    📎 _[Member chat — {label}] {message_text}_
    ```
  - If no related primary message exists, and this genuinely stands alone (a real conviction shift or new info, not just chatter) → send standalone, clearly tagged:
    ```
    💬 *[DC: {label}]*

    {message_text}
    ```

Apply the same broader-sentiment convergence/divergence note and ticker-focus weighting described in `x-trader-monitor` Step 6.

## Step 8 — Image / attachment handling

Identical to `x-trader-monitor` Step 7: forward original attachment(s), add one interpreting sentence only if the message doesn't already fully explain the chart, be honest about illegible details.

## Step 9 — Update memory

Same as `x-trader-monitor` Step 8 — `traders.md`, `ticker-focus.md`, `active-trades.md` — plus seen-ID tracking:

```bash
mkdir -p memory
echo "$MESSAGE_ID" >> memory/discord-trader-seen.txt
LINES=$(wc -l < memory/discord-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/discord-trader-seen.txt > memory/discord-trader-seen.tmp && mv memory/discord-trader-seen.tmp memory/discord-trader-seen.txt
fi
```

If `id` is already in `memory/discord-trader-seen.txt`, stop after logging — don't re-alert.

## Step 10 — Log

Append to `memory/logs/${today}.md`:

```
### discord-trader-monitor (real-time event)
- trader: {trader_handle}
- channel: {channel_id} ({primary|supporting})
- message_id: {id}
- classification: {skip|informational|ambiguous|trade-new-entry|mirror-cancel|mirror-partial-tp|mirror-full-tp|dca-plan|conviction-add}
- ticker(s): [list]
- alerted: yes/no
- notes: {one line}
```

## Channel reference

`memory/discord-channels.json` is the source of truth, but as a reminder:
- **Crypto_Chase**: 1336082716063694962 (primary), 1343971265962049597 + 1247927786681794601 (supporting)
- **KillaXBT**: 1411492188315193416 (primary)
- **HeartCanHodl**: 1472153627324842057, 1191800982414299217, 1279738718680256553 (★ most important), 1393137051108507728 (all primary), 1023638573313966212 (supporting)

## Environment Variables

- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` — GitHub secrets, used via `./notify`

## Sandbox note

Like `x-trader-monitor`, you receive one event at a time via `${var}` (base64-encoded JSON from the Worker's Discord poll). No prefetch cache for real-time monitoring — the Worker now hands off per-message instead of you scanning a batch. If `${var}` is empty, exit cleanly with `DISCORD_TRADER_NO_EVENT`.
