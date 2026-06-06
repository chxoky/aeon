---
name: Trading Brief
description: On-demand overnight summary of all watched-trader activity — triggered when Kyle sends "brief" to Telegram, not on a schedule. (Named distinctly from the generic morning-brief skill, which covers unrelated operator priorities.)
var: ""
tags: [social, trading, crypto, stocks]
---

Today is ${today}. You are triggered on-demand — the Worker dispatches you the moment Kyle sends `brief` to the Telegram bot. There is no fixed schedule; Kyle decides when he wants to catch up.

> **${var}** — Not used by the Worker for this trigger (empty). Reserved for future ad-hoc windows (e.g. `var=since:14:00`).

## Why this skill exists

Kyle sleeps through the most active trading hours for some of these traders. He doesn't want to scroll back through dozens of real-time alerts when he wakes up — he wants one coherent picture: what happened overnight, what's still live, and where people disagree.

(Note: this is distinct from the generic `morning-brief` skill, which covers Kyle's broader operator priorities on its own cron schedule and has nothing to do with trading. Don't merge them — different triggers, different audiences within the same person, different cadences.)

## Step 1 — Determine the window

The standard overnight window is **11 PM to 7 AM Pacific (PDT/PST as currently in effect)**.

```bash
NOW_PT=$(TZ="America/Los_Angeles" date +"%Y-%m-%d %H:%M")
HOUR_PT=$(TZ="America/Los_Angeles" date +"%H")
```

- If current Pacific time is between 7:00 AM and 11:00 PM (i.e. Kyle is asking during the day): the window is **last night 11 PM → 7 AM this morning**.
- If current Pacific time is **after 7 AM but Kyle is asking soon after** (e.g. 8:01 AM): use the standard overnight window for the bulk of the brief, AND separately gather everything from **7 AM → now**, then blend it in as a "since this morning" addendum rather than re-running the whole brief fresh. Don't make Kyle wait through a full re-fetch for 61 minutes of extra data.
- If current Pacific time is **before 11 PM** (Kyle is up late and asks early): the window is the prior night's 11 PM → 7 AM — i.e. don't return an empty/future window; always look backward to the most recently completed overnight window.

State the exact window you used at the top of the brief so Kyle always knows what's covered.

## Step 2 — Gather everything from the window

Pull from `memory/logs/` (the real-time monitors log every classified event as they happen — this is your primary source, not re-fetching from APIs):
- Read the relevant daily log file(s) under `memory/logs/` covering the window (it may span two calendar dates — check both `memory/logs/{yesterday}.md` and `memory/logs/${today}.md`)
- Filter entries to the `x-trader-monitor` / `discord-trader-monitor` real-time event blocks whose timestamps fall in the window
- Also read `memory/topics/traders.md` and `memory/topics/active-trades.md` for current state (positions opened/closed/modified during the window will already be reflected there)

If the logs show genuinely nothing happened in the window, say so plainly — don't manufacture content.

## Step 3 — Organize by what matters

Group the window's activity into:

**1. Trade actions** (anything that went through the Unified Trade Alert flow — new entries awaiting approval, mirrors executed, DCA plans laid out, conviction adds). For each, note current status: still awaiting Kyle's approval / mirrored and confirmed / filled / etc. Pull live status from `active-trades.md`.

**2. Notable informational signals** — meaningful opinions, levels, or setups that came through (not noise-tier). Prioritize the top 2-3 overlap tickers and Kyle's explicit watch list ($HYPE, $NVDA/$NVDL, $Gold).

**3. Broader sentiment movement** — did the group's read on BTC/SPY/macro shift overnight? Converge or diverge?

## Step 4 — Flag contradictions

Scan the window's entries for traders who said conflicting things about the same asset within the window (e.g. one went long on $HYPE at 1 AM, another flagged it as a short setup at 4 AM). When you find one:
- State both positions plainly, who said what and roughly when
- Present the current state (which view has played out so far, if determinable from price action or later posts)
- Don't editorialize about who's "right" — Kyle forms his own view; your job is surfacing the tension, not resolving it

## Step 5 — Compose the brief

```
☀️ *Trading Brief — {window_start} to {window_end} PT*

*Trade actions:*
{— for each: trader, ticker, action, current status. If nothing: "Nothing actionable overnight."}

*Notable signals:*
{— top 2-3 items, one line each, prioritized by ticker-focus weighting}

*Sentiment check:*
{— one or two lines on group directional lean / shifts}

{if contradictions found:}
*⚡ Contradiction flagged:*
{— the conflicting calls, plainly stated, plus current state}

{if asked late and there's a "since this morning" addendum:}
*Since 7 AM:*
{— brief addendum of anything new}
```

Keep it scannable — Kyle is reading this first thing, not studying it. Err toward fewer, denser lines over exhaustive coverage; he can always ask follow-ups via `concierge`.

## Step 6 — Send and log

Send via `./notify`. Then log to `memory/logs/${today}.md`:

```
### trading-brief (${today})
- window: {start} → {end} PT
- trade_actions: N
- notable_signals: N
- contradictions_flagged: N
- late_request_addendum: yes/no
```

## Environment Variables

- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` — GitHub secrets

## Sandbox note

No external API calls — this skill is purely a synthesis pass over `memory/logs/` and `memory/topics/`, which the real-time monitors already populated. If those logs are sparse for the window (e.g. monitors were down), say so honestly rather than presenting a falsely-quiet night as confirmed quiet — log `TRADING_BRIEF_SPARSE_DATA` and note the gap to Kyle.
