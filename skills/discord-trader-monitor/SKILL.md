---
name: Discord Trader Monitor
description: Monitor Crypto_Chase, KillaXBT, and HeartCanHodl across their Discord channels. Primary channels = core trade plans. Supporting channels = real-time conviction updates from member Q&A.
var: ""
tags: [social, trading, crypto, stocks]
---

Today is ${today}. Monitor watched traders across their Discord channels and send real-time Telegram alerts.

## Channel hierarchy

Read `memory/discord-channels.json` to understand which channels belong to which trader and whether each is "primary" or "supporting". This distinction determines how you format and present each alert.

**Primary channels** — the trader's main posts. Treat these as the core trade plan/idea. Alert fully.

**Supporting channels** — usually member Q&A chats. The trader's replies here reflect *real-time changes in conviction or sentiment*. Do not alert on these independently — instead, tag them as addenda to what the trader already said in a primary channel. If the trader's reply isn't self-explanatory (e.g. it's clearly a response to a question), briefly include what the member asked.

## Steps

### 1. Load seen message IDs

```bash
SEEN_IDS=$(cat memory/discord-trader-seen.txt 2>/dev/null || echo "")
```

### 2. Read prefetch cache and channel config

```bash
CACHE=$(cat .xai-cache/discord-traders.json 2>/dev/null)
CONFIG=$(cat memory/discord-channels.json 2>/dev/null)
```

If cache is missing or empty: log `DISCORD_TRADER_EMPTY` to `memory/logs/${today}.md` and stop.

### 3. Identify trader messages

For each message in the cache:
- Skip if `id` is in `SEEN_IDS`
- Skip if `created_at` is more than 24 hours old
- Determine which trader owns the channel (`channel_id`) by looking them up in `discord-channels.json`
- Determine if it's from the trader or a member by checking the `username` field against the trader's `discord_username` in the config

Only process messages FROM the watched traders (Chase, Killa, HCH). Member messages exist in the cache only to provide reply context — do not alert on them.

### 4. Classify each trader message as a trading signal

For each trader message:

**Classify as SIGNAL if it contains:**
- A directional call (bullish/bearish, long/short, buy/sell)
- A price target, level, stop, or invalidation point
- A specific asset with a trade setup or opinion
- A change in position, conviction, or thesis
- A macro view with actionable implications

**Classify as NOISE if it is:**
- Administrative (links, scheduling, announcements)
- Generic banter or reactions
- Pure motivational content without trade detail

### 5. Format and send Telegram alerts

**For PRIMARY channel SIGNAL messages:**

```
💬 *[Discord: {trader_handle}]*

{message_text}
```

If the message is a reply (`is_reply: true`) and the context adds clarity, prepend:
```
↩️ _Replying to {reply_to_username}: "{reply_to_text}"_

```

**For SUPPORTING channel SIGNAL messages:**

Do NOT send a standalone alert. Instead:
- Check if there's a related primary channel message from the same trader in the current run (same session, related topic)
- If yes: append it to that alert as a footnote:
  ```
  📎 _[Member chat update] {message_text}_
  ```
- If no related primary message: send it as a standalone alert clearly tagged as a member chat update:
  ```
  💬 *[Discord: {trader_handle} — member chat]*

  {message_text}
  ```
  If it's a reply and context matters:
  ```
  ↩️ _Replying to {reply_to_username}: "{reply_to_text}"_
  ```

**Important Telegram formatting rules:**
- Use `*bold*` for headers
- Use `_italics_` for context/footnotes
- Keep message text unmodified (don't paraphrase the trader)
- Don't @ mention usernames (no `@username` format in the message body)

### 6. Update seen list and log

Append ALL processed message IDs (signal and noise, from traders only) to `memory/discord-trader-seen.txt`:

```bash
mkdir -p memory
echo "$TRADER_MSG_ID" >> memory/discord-trader-seen.txt
```

Log to `memory/logs/${today}.md`:

```
### discord-trader-monitor (${today} run)
- signals_sent: N
- noise_filtered: N
- by_trader:
  - Crypto_Chase: N signals (primary: N, supporting: N)
  - KillaXBT: N signals
  - HeartCanHodl: N signals (primary: N, supporting: N)
```

### 7. Seen-file maintenance

```bash
LINES=$(wc -l < memory/discord-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/discord-trader-seen.txt > memory/discord-trader-seen.tmp && mv memory/discord-trader-seen.tmp memory/discord-trader-seen.txt
fi
```

## Environment Variables

- `TELEGRAM_BOT_TOKEN` — GitHub secret
- `TELEGRAM_CHAT_ID` — GitHub secret
- `DISCORD_USER_TOKEN` — GitHub secret (used by prefetch script, not directly here)
- Config: `memory/discord-channels.json`
- Cache: `.xai-cache/discord-traders.json`

## Sandbox note

Discord API calls are handled by the prefetch script. Read only from the cache.
