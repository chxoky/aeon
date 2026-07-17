# Active Trades

## Crypto_Chase

### GOOG (Google) — LONG (CLOSED)
- **Entry zone**: 330s (initial resting bid filled 2026-06-23T13:31Z at ~330-342 zone)
- **Final size**: 0% (fully closed 2026-07-16T12:38:19Z)
- **Position history**:
  - 2026-06-23T13:31Z: Filled at 342, entered into 330s zone
  - Initial size: 70% of target position
  - 2026-06-23T13:31Z: Partial TP at 342 → reduced from 70% to 50%
  - 2026-06-25T13:34Z: Conviction add at 336 → scaled from 50% back up to 60%
  - 2026-06-26T03:02Z: Partial TP at 336 → reduced from 60% to 40%
  - 2026-06-30T12:58:46Z: Partial TP at 352.84 → reduced from 40% to 25% (conditional trim target HIT)
  - 2026-07-16T12:38:19Z: FINAL CLOSE — remaining 25% position closed at high TP guidance level; "officially closed" per trader confirmation
- **Final resting bids**: Cancelled (position fully exited)
- **Status**: CLOSED — all 25% core position exited, trade cycle complete
- **Thesis**: Patient, multi-level DCA strategy; average entry ~338, profitable position; conditional trim threshold 352.83 was swept overnight (06-30), triggering 15% reduction to 25% core. Final 25% core held through Jul 14-16 window, closed at high TP level suggested Jul 15
- **Average entry**: ~338 (confirmed profitable across all TP executions: 342→336→352.84→high close)
- **Hold period**: 24 days (Jun 23 entry → Jul 16 final close)
- **Last update**: 2026-07-16T12:38:19Z (message_id=1527293303068819607, final position closure, fast-path alerted)

### LPTH (Loopring) — LONG (partial position reduction)
- **Entry**: Unknown date (position was existing prior to 2026-06-30)
- **Current size**: 50% (after partial exit)
- **Position history**:
  - 2026-06-30T19:16:20Z: Partial TP → sold 50% at/above breakeven (BEP)
  - Remainder: 50% held as lottery/run ticket
- **Status**: ACTIVE — 50% closed, 50% remainder held
- **Thesis**: Pragmatic capital discipline; position "takes forever" to move (low volatility frustration); maintains remainder despite ambivalence ("don't want to miss if it runs either")
- **Conviction**: MEDIUM (ambivalent on remainder — neither bullish enough to add nor bearish enough to fully exit)
- **Last update**: 2026-06-30T19:16:20Z (message_id=1521595260629946561, partial TP at breakeven, fast-path alerted)

### MU (Micron Technology) — LONG (CLOSED 2026-07-16T19:02:25Z)
- **Entry setup**: Conditional dual-entry plan articulated 2026-06-29T14:25:41Z
  - Trade 1: 1:1 risk/reward, risk 2% portfolio → CLOSED (TP hit 2026-07-02)
  - Trade 2: 1% risk → CLOSED (final remainder TP'd 2026-07-16 over 1000 level)
  - Max total loss thesis: 3% portfolio if both SL hit (original risk framework)
- **Entry date**: Unknown (first trade entry point not explicitly disclosed; plan was conditional on MU weakness)
- **TP hit**: 2026-07-02T17:47:32Z — "MU first trade hit" (first trade's 1:1 R:R target achieved)
- **Final close**: 2026-07-16T19:02:25Z — Crypto_Chase TP'd MU over 1000. Final remainder (1% risk position) closed.
- **Position history**:
  - 2026-06-29T14:25Z: Dual-entry plan codified with specific risk parameters
  - 2026-06-24T00:12Z: Resting bid context — "earnings stink bids below built-up lows"; technical floor 650
  - 2026-06-24T13:32Z: Pre-earnings awareness — "MU earnings today, chop expected"
  - 2026-06-25T13:51Z: Post-earnings observation — "SFP'd high and everything dumped"
  - 2026-07-02T17:47Z: First trade TP hit
  - 2026-07-06T22:58Z: Trim action on second trade — "Trimmed another 17% of MU, now down to 1% risk from the original 2% risk. All trims done in small profits so far." (message_id=1523825621443153920, fast-path alerted)
  - 2026-07-07T01:44Z: Re-add consideration — "920's to add back some MU, but keeping total risk at 2% or so, leaves room to add 1% more if both go lower, gn." (message_id=1523867283854987345, fast-path alerted, discord-trader-monitor)
  - 2026-07-16T19:02Z: FINAL CLOSE — remaining 1% risk position TP'd over 1000 level
- **Final exit price**: Over 1000 level (final TP execution)
- **Overall position result**: Multi-phase profitable trade over 18-day hold (approx Jun 29-30 initial entry → Jul 16 close). Dual-trade structure with disciplined trim management (first trade closed at 1:1 R:R, second trade trimmed to 1% then finally closed at 1000+ level) demonstrates risk-managed profit-taking approach. Both trade legs profitable, supporting original thesis thesis on earnings-driven volatility + technical structure play.
- **Status**: CLOSED — entire position exited, both trade legs closed profitably
- **Conviction**: HIGH throughout (waiting months for sub-850 level per 06-23 message); both TP hit and trim management confirm disciplined execution; final close at 1000+ level validates multi-tier entry strategy and ongoing technical setup favorability thesis
- **Last update**: 2026-07-16T19:02:25Z (final position closed, TP'd over 1000, X post tweet_id=2077831237566169306, fast-path alerted via ./notify)

### MU (Micron Technology) — LONG (NEW ENTRY — 2026-07-17)
- **Entry**: 2026-07-17T13:46:04Z — "I started about a third of my Micron bag around 800" (Discord message_id=1527672741509988483, fast-path-alerted=true)
- **Entry level**: ~$800 (market-order execution or limit fill)
- **Entry size**: ~33% (fractional position: "about a third" of intended full position; implies multi-tranche accumulation plan)
- **Entry context**: Fresh entry after previous MU position fully closed 2026-07-16T19:02:25Z above 1000 level. New position initiated at $800, representing ~200-point pullback from prior TP level. Fractional sizing language ("about a third") suggests trader planning 2-3 tranche accumulation (similar to prior dual-entry structure). Entry timing: next session morning UTC after overnight consolidation.
- **Thesis**: Likely continuation of multi-level DCA strategy on MU. Previous position: dual-entry framework with 1:1 R:R first trade + 1% risk second trade, both profitable. Fresh $800 entry suggests: (1) pullback buying opportunity, (2) accumulation into support level, or (3) restart of disciplined position building after prior successful cycle close.
- **Status**: PENDING APPROVAL — awaiting Kyle response (`approve MU` to mirror on Kraken spot), or ignore to skip
- **Trade alert format**: Step 5a (new entry requiring approval, fast-path already notified Kyle via Telegram ~13:46-13:48 UTC)
- **Mirror instructions**: Upon Kyle approval, mirror MU LONG position on Kraken spot (size to be specified by Kyle via `approve MU <size_or_percentage>` reply)
- **Alerted**: YES (2026-07-17T13:46:04Z, discord-trader-monitor real-time event, fast-path-alerted via Telegram)
- **Last update**: 2026-07-17T13:46:04Z (new entry execution, awaiting approval, Discord message_id=1527672741509988483, discord-trader-monitor real-time, fast-path-alerted=true)

### SNDK (Structural) — LONG (PREVIOUS POSITION CLOSED 2026-07-16T19:02:25Z)
- **Previous entry**: 2026-07-07T13:25:08Z (pullback tactical entry on HTF flush setup, CLOSED JUL 16)
- **Status**: CLOSED
- **Last update**: 2026-07-16T19:02:25Z (final position closed, TP'd 1700-1830, X post tweet_id=2077831237566169306, fast-path alerted via ./notify)

### SNDK (Structural) — LONG (NEW ENTRY — PENDING APPROVAL)
- **Entry**: 2026-07-16T22:54:55Z (execution of pre-planned limit-bid fill)
- **Entry message**: "$SNDK\n\nBought some here at 1366~" (X post, tweet_id=2077889748111159491)
- **Entry level**: ~$1366 (market-order execution or tight fill on resting limit bid 1366.97 from Jul 16 18:43:03 UTC setup)
- **Entry context**: Crypto_Chase had set conditional limit-bid order at 1366.97 on Discord 2026-07-16T18:43:03Z ("Will start my next SNDK position at 1366.97~ if market offers") and gone offline with explanation message at 22:33:43Z predicting overnight fill. Current X post confirms fill execution ~21 minutes later.
- **Thesis**: Generational-bottom accumulation play. Supporting technical context (from prior Discord messages):
  - Jul 15 13:57:47Z: Identified generational bottom ~1350, worst case 1K (capitulation level)
  - Jul 16 14:14:17Z: Expressed uncertainty ("tough to read at the moment") + lower contingency thinking (1300s if crash continues)
  - Jul 16 15:30:36Z: Teaching moment on TP discipline from closed prior profitable position (TP'd 1700-1855)
  - Jul 16 18:43:03Z: Conditional entry bid setup at 1366.97, described as "logical level"
  - Jul 16 22:33:43Z: Offline explanation emphasizing SNDK down 42% ~1 month into 0.5-0.618 Fib support zone = "good area to take a risk on"
- **Technical context**: Stock currently at 0.5-0.618 Fibonacci retracement level after 42% 1-month decline. Support zones identified: 1350 (base generational bottom), 1300s (crash scenario), ~1000 (capitulation). Entry at 1366 sits slightly above base-case 1350, aligns with thesis on "patience rewarded" and accumulated buying into foundational support structure.
- **Status**: PENDING APPROVAL — awaiting Kyle response (`approve SNDK` to mirror on Kraken spot), or ignore to skip
- **Trade alert format**: Step 5a (new entry requiring approval)
- **Mirror instructions**: Upon Kyle approval, mirror $SNDK LONG position on Kraken spot (size to be specified by Kyle via `approve SNDK <size_or_percentage>` reply)
- **Alerted**: YES (2026-07-16T22:54:55Z, X-trader-monitor real-time event, fast-path-alerted via Telegram)
- **Last update**: 2026-07-16T22:54:55Z (new entry execution, awaiting approval, X post tweet_id=2077889748111159491, x-trader-monitor real-time, fast-path-alerted=true)

## ES (S&P 500 E-mini Futures) — LONG
- **Entry**: 2026-06-21T23:23Z (dream/gut feeling conviction entry)
- **Size/Targets**: Not explicitly disclosed
- **Status**: ACTIVE
- **Context**: Entered on dream conviction after being patient/flat through FOMC window. Subsequently expressed 50/50 uncertainty as of 06-22T01:16Z, frustrated with "giga chop" market structure. 2026-07-09T14:49Z: Posted technical observation "ES tightening / trapped" with chart in TradFi supporting channel — first update on ES in 18 days; suggests he's actively monitoring structure (likely related to position management or intraday trading approach from 06-11 strategy note).
- **Last update**: 2026-07-09T14:49:32Z (discord-trader-monitor real-time, technical observation, message_id=1524789609450569858, fast-path alerted)

## KillaXBT

### BTC — LONG (multi-timeframe, primary conviction + near-term DCA)
- **Status**: ACTIVE (long-horizon HTF swing + spot accumulation)
- **Holdings**: 
  - **2X swing long** (HTF): open since 06-13, "the bear cycle is coming to an end" thesis
  - **Spot position**: ~11 Bitcoin notional at avg entry 65897
- **Position history**:
  - Small LTF long (CLOSED 06-24T16:49Z with -15k loss) — was tactical hedge, conviction targets 60.7K sweep, 68-69K next month (failed to materialize)
  - LTF scalp short (CLOSED 06-20T21:12:55Z) — de-hedged after HTF conviction strengthened
- **DCA Plan**: Targeting ~20 Bitcoin total notional over 3-4 months on dips (especially sub-50k level where willing to liquidate ISA stock holdings)
- **Current conviction**: HIGH on BTC structure (bear market ~80% complete per 06-22 analysis); willing to add significantly at lower levels
- **Technical thesis**: Monday High pattern in play; 60.7K initial sweep target, then 68-69K push expected next month; sub-50k triggers ISA liquidation for additional conviction add
- **Last update**: 2026-06-25T14:50:04Z (position confirmation + DCA plan, message_id=1519716314996805654, fast-path alerted)

### BTC — SHORT (scalp hedge, ACTIVE entry 2026-07-14)
- **Status**: ACTIVE — LADDER ENTRY INITIATED 2026-07-14T15:38:48Z
- **Entry range**: 64.8K–65.8K (laddering gradual, small-position entry)
- **Position size**: Small (~30% hedge of total BTC holdings on separate account)
- **Entry signal**: Execution on conditional scalp-short plan from Discord 14:08:41 UTC message ("Hoping we get a sweep above the highs so I can start laddering into some scalp shorts")
- **Invalidation**: 66.5–66.8K
- **Thesis**: Tactical hedge against HTF 2x long conviction (same message: "Remember I am still swing long on the HTF. So this current short serves as somewhat of a hedge against my holdings"). NOT a standalone bearish conviction; rather, a portfolio hedge to cap drawdown risk on core long if market stalls into 65–66K zone.
- **Context**: Execution reply following earlier conditional plan setup and "Checkmate" X post at 15:34Z. Chart attachment support execution structure. Message_id: 1526613949217509600, fast-path alerted by Cloudflare Worker (Telegram already sent 2-5s after message).
- **Last update**: 2026-07-14T15:38:48Z (discord-trader-monitor real-time, trade-new-entry; message_id=1526613949217509600)

### BTC — SHORT (tactical position, fully closed with small profits — PRIOR ENTRY)
- **Status**: CLOSED — SHORT POSITION FULLY EXITED 2026-07-06T13:30:11Z → 2026-07-06T16:47:59Z
- **Position evolution**:
  - 2026-07-02T16:38Z: Filled small BTC short at market
  - 2026-07-03T11:33Z: Planned derisk 50% at entry, re-add 50% at 62.9K
  - 2026-07-05T12:13Z: Confirmed still in position, waiting for 60.6 pivot test for re-add
  - **2026-07-06T12:01Z: Abandoned re-add plan, closing conviction-add 50%, retaining core entry 50%** (message_id=1523660156997734463)
  - **2026-07-06T13:30Z: EXECUTION CONFIRMED — "Closed 50% of small pos, we can see a bounce around NY open back upto 62.3K"** (message_id=1523682478618050701, is_reply=true, attachment: price/position chart)
  - **2026-07-06T16:47Z: FINAL CLOSE — "Closing out the remaining 25% of the short position here at 63.7k. Ended up overall in small profits on the short"** (message_id=1523732256555012227, is_reply=true, fast-path alerted)
- **Final position size**: 0% — fully exited
- **Exit prices**: 50% closed at 62.3K, 25% closed at 63.7K
- **Outcome**: SMALL PROFITS overall ("Ended up overall in small profits on the short, I forgot to ping to put stops at entry. All good.")
- **Conviction**: Post-close assessment indicates satisfied with risk management despite initial plan complications; searching for higher re-entry point
- **Market context**: Original entry implied 63-65k zone; derisk/re-add plan expected 62.9K re-entry level, but de-risked early when plan didn't materialize; eventual closes at 62.3K-63.7K bracket suggest tactical success despite missed re-entry opportunity
- **Comparison**: "The 67k short was in a much better area than here" — earlier assessment acknowledged current short entry was suboptimal
- **Technical thesis**: Tactical position management with scale-box deviation pattern; conservative sizing due to macro bottom proximity; price structure confirmation through multi-leg close
- **Next action**: "Will search for a higher entry!" — plans to re-enter short at better technical level
- **Last update**: 2026-07-06T16:47:59Z (position fully closed, message_id=1523732256555012227, fast-path alerted)

## HeartCanHodl

### BTC/ETH/SOL — SHORTS (ACTIVE — PARTIAL PROFIT-TAKING 2026-07-08)
- **Status**: ACTIVE — SHORT POSITIONS SCALED OUT PARTIALLY 2026-07-08T09:06:01Z — "Take 7.5%-3.5%-3.5%-1%-1% off from btc,eth,sol,hype,zec here"
- **Current position sizes** (PROFIT-TAKING 2026-07-08T09:06:01Z): BTC short 0% (FULLY CLOSED — took 7.5% off), ETH short 2.25% (REDUCED from 5.75% — took 3.5% off), SOL short 0.25% (REDUCED from 3.75% — took 3.5% off), HYPE short 2% (REDUCED from 3% — took 1% off)
- **Position history**:
  - 2026-07-03T04:08:17Z: Initial entry — BTC 5%, ETH 2.5%, SOL 2.5%, HYPE 2%
  - 2026-07-03T06:20:35Z: Scale-in intent clarification — "Keeping a room to add to the local highs"
  - 2026-07-03T08:50:27Z: Conviction add (50% scale) — "Add half of that here on all of them" (message_id=1522524915574640651, fast-path alerted)
  - 2026-07-03T20:38:54Z: Second tranche price specification — "Add other half here at 62.8kish tag" (pending/resting order at 62.8k for remaining 50% scale; message_id=1522703206847873127, fast-path alerted)
  - 2026-07-04T15:27:59Z: Conviction add — "Add 2% more to eth short" (message_id=1522987346298142780, fast-path alerted, discord-trader-monitor)
  - 2026-07-06T14:21:43Z: AMBIGUOUS FOLLOW-UP — "Fc btc 1hr" (reply to 2026-07-03T20:38:54Z pending 62.8k order; cryptic abbreviation "Fc" unclear — could mean filled confirmation, chart check, or other. Status of 62.8k second tranche add pending clarification; message_id=1523695448827891712, fast-path alerted, discord-trader-monitor)
  - **2026-07-08T09:06:01Z: PROFIT-TAKING / POSITION SCALE-OUT — "Take 7.5%-3.5%-3.5%-1%-1% off from btc,eth,sol,hype,zec here"** — HCH closes/reduces all major short positions after ~5 days of holding (entered 07-03, closed/reduced 07-08). BTC short fully exited (7.5% taken off = 0% remaining), ETH short reduced (3.5% taken off = 2.25% remaining), SOL short reduced (3.5% taken off = 0.25% remaining), HYPE short reduced (1% taken off = 2% remaining), ZEC short reduced (1% taken off, size TBD). Interpretation: Disciplined profit-taking after risk/reward exhausted or technical structure invalidated further downside conviction (5-day hold suggests trade played out as intended). Fast-path alerted at event time by Cloudflare Worker (~2-5s latency). Message_id: 1524340774735450112, channel: 1279738718680256553 (HCH — Trades, ★most important).
- **Entry details** (PRE-PROFIT-TAKING 2026-07-04 through 2026-07-08T09:06Z): 
  - BTC short: 7.5% position size (5% initial + 2.5% first conviction add), closed in full at 2026-07-08T09:06:01Z
  - ETH short: 5.75% position size (2.5% initial + 1.25% first conviction add + 2% conviction add 07-04), reduced to 2.25% at 2026-07-08T09:06:01Z
  - SOL short: 3.75% position size (2.5% initial + 1.25% first conviction add), reduced to 0.25% at 2026-07-08T09:06:01Z
  - HYPE short: 3% (2% initial + 1% conviction add), reduced to 2% at 2026-07-08T09:06:01Z
- **Scaling strategy**: Multi-phase tactical conviction adds → profit-taking exit pattern. (1) Initial entry at market (07-03 04:08Z), (2) first 50% scale at market (07-03 08:50Z), (3) second 50% scale pending at 62.8k price trigger (07-03 20:38Z, resting order/pending execution), (4) ETH additional 2% conviction add (07-04 15:27Z), (5) PROFIT-TAKING SCALE-OUT (07-08 09:06Z after ~5-day hold, taking profits on all legs: BTC fully closed, ETH/SOL/HYPE partially reduced, ZEC reduced by 1%). Remaining positions: ETH 2.25%, SOL 0.25%, HYPE 2%, ZEC [reduced size]. Strategy shift: From conviction-add accumulation phase → profit-taking scale-out phase, suggesting HCH satisfied with risk/reward on initial tranche and locking in gains while maintaining core remainder positions for potential further downside participation.
- **Context**: HCH closed major longs (BTC 5%, ETH 2%, SOL 2%) on 2026-07-02T10:25:13Z, confirmed re-evaluation mode on 2026-07-02T11:15:47Z ("Scaled out from majors. Will re-evaluate now"). New short entry message 2026-07-03T04:08:17Z initiates SHORT conviction on major pairs — thesis shift from neutral re-evaluation to bearish positioning. Multi-phase escalation (08:50Z market add, 20:38Z pending 62.8k add, 07-04 ETH conviction add) suggests high conviction on downside move with tactical price-level scaling strategy. **Profit-taking execution (07-08 09:06Z)**: After 5-day hold and likely favorable price movement (BTC shorts entered ~60k+, trading context 62.8k zone suggests entry was profitable; 07-08 profit-taking indicates price moved enough to justify closing major legs), HCH scales out. BTC full exit (likely highest R:R achieved) vs. ETH/SOL/HYPE partial exits (retaining core remainder for continued downside if structure confirms) = disciplined graduated profit-taking approach. ZEC reduced by 1% (maintaining high-conviction short thesis but trimming edge).
- **Short basket evolution**: Initial basket (07-03) = BTC/ETH/SOL/HYPE shorts + existing ZEC high-conviction short + other alts (LAB, TAO, SPCX, VVV, XPL, TON, SYN). Peak allocation (07-04 post-ETH add): BTC 7.5%, ETH 5.75%, SOL 3.75%, HYPE 3% + ZEC + alts. **Current allocation (post-profit-taking 07-08)**: BTC 0%, ETH 2.25%, SOL 0.25%, HYPE 2%, ZEC reduced. Remainder represents HCH's core long-term short conviction on alts (smallest SOL remainder 0.25% suggests mostly closed; ZEC reduced but likely still material as high-conviction short). Alt-short basket (LAB/TAO/SPCX/VVV/XPL/TON/SYN) status unknown — likely still held unless closed separately.
- **Trade result**: Profit-taking on 5-day hold (entered 07-03 early morning, exited 07-08 early morning). Estimated holding period: 5 full calendar days ≈ 105 hours. Entry context (BTC near 60k+, SOL/ETH corresponding levels, HYPE at tactical levels) vs. 07-08 exit context (BTC at 62.8k zone or below, consolidating without "concrete flip" per 07-06 observations) suggests shorts likely profitable on scale-out (entry was bearish thesis capitalization; 5-day hold without major reversal = profitable trade management). Full BTC exit + partial ETH/SOL/HYPE exits = tiered profit-taking with remainder positions maintaining downside participation. HCH's discipline evident: take profits when risk exhausted, retain core for continuation.
- **Last update**: 2026-07-08T09:06:01Z (discord-trader-monitor, fast-path alerted, PROFIT-TAKING / POSITION SCALE-OUT; message_id=1524340774735450112)

### BTC/ETH/SOL/HYPE/ZEC SHORTS — RE-ENTRY (2026-07-10) & CONVICTION ADD (2026-07-14 — Triple-phase escalation)
- **Status**: ACTIVE — CONVICTION ADD ON SEPARATE ACCOUNT (2026-07-14T11:13:44Z) + FOLLOW-UP CONFIRMATION (2026-07-14T12:47:29Z) + PRIMARY CHANNEL ADD (2026-07-14T13:27:56Z)
- **Entry**: 2026-07-10T08:21:41Z — "Enter half of that on the short side here" (is_reply to 07-08 profit-taking message)
- **Re-entry context**: HCH took profits on the 07-03→07-08 short basket (BTC 7.5% taken off, ETH 3.5% off, SOL 3.5% off, HYPE 1% off, ZEC 1% off). Two days later, re-entering HALF of what was closed:
  - **BTC**: Re-enter ~3.75% (half of 7.5% closed)
  - **ETH**: Re-enter ~1.75% (half of 3.5% closed)
  - **SOL**: Re-enter ~1.75% (half of 3.5% closed)
  - **HYPE**: Re-enter ~0.5% (half of 1% closed)
  - **ZEC**: Re-enter ~0.5% (half of 1% closed)
- **Conviction Add Phase 1 (Jul 14, 11:13:44Z)**: "on separate account: add 3% to btc short, 2% to eth short and 2% to sol short, and 1% to uni short" (is_reply to "Enter half of that on the short side here")
  - **BTC**: +3% (separate account allocation)
  - **ETH**: +2% (separate account)
  - **SOL**: +2% (separate account)
  - **UNI**: +1% (NEW TICKER — first short mention)
  - Total allocation on separate account: 8% across 4 tickers
  - **Message_id**: 1526547243564269689 (fast-path alerted by Cloudflare Worker; Telegram alert already sent, memory/logging only)
- **Follow-up Confirmation (Jul 14, 12:47:29Z)**: "Add the same size here more post solid print PA\n\non separate account: add 3% to btc short, 2% to eth short and 2% to sol short, and 1% to uni short" (message_id=1526570836973326346, fast-path alerted by Cloudflare Worker; reiteration of 11:13:44 message with opening context "Add the same size here more post solid print PA" — likely response to member question or confirmation of intent)
  - Same allocations as 11:13:44: BTC +3%, ETH +2%, SOL +2%, UNI +1%
  - Fast-path alerted; Telegram already sent; follow-up message logged for position certainty
- **Conviction Add Phase 2 (Jul 14, 13:27:56Z)**: "Add 2% more to eth short" (direct execution call on primary Trades channel, message_id=1526581013701066873)
  - **ETH**: +2% (primary account / combined allocation)
  - Simple, direct language; no secondary account label → primary position allocation
  - Fast-path alerted; Cloudflare Worker pre-notified Kyle within 2-5s; no duplicate Telegram sent
- **Total ETH short adds (07-04 through 07-14)**: 
  - 07-04 +2% (initial conviction add)
  - 07-14 11:13:44Z +2% (secondary account)
  - 07-14 12:47:29Z: (confirmation/reiteration of 11:13:44)
  - 07-14 13:27:56Z +2% (primary account follow-up)
  - Total additional: ~6-8% ETH short in 10-day window (plus earlier position from 07-03 initial basket)
- **Position interpretation**: Extreme multi-phase escalation pattern — HCH satisfied with 07-08 profit-taking discipline, now re-accumulating aggressively with redundant confirmation across channels + accounts. 07-10 re-entry + 07-14 triple-message conviction add (4 days, 3 messages, 2 accounts) = ultra-high conviction bearish thesis validation on ETH. Staging suggests: (1) primary account re-accumulation (07-10), (2) secondary account allocated adds (07-14 AM, explicitly sized), (3) follow-up confirmation same-message protocol (07-14 midday), (4) primary discretionary add as structural conviction rises (07-14 afternoon). Pattern indicates either: (a) intraday price weakness validating short thesis in real time, (b) accumulation plan executed on schedule with no hesitation, or (c) member conviction/questions triggered explicit restatement + action. Core remainder positions (ETH baseline + adds, SOL 0.25%, HYPE 2%, ZEC [reduced]) + seven-day escalation creates highly-leveraged multi-account short exposure.
- **Conviction**: EXTREMELY HIGH (three-phase re-entry within 4 days of TP + explicit dual-account add + triple same-day confirmation + primary channel follow-up = quintuple+ conviction signal; breadth of messaging suggests both confidence AND public commitment to thesis)
- **Channel Evolution**: 11:13:44 (reply context, secondary account), 12:47:29 (reply + reiteration), 13:27:56 (main-channel standalone call)
- **Last update**: 2026-07-14T13:27:56Z (discord-trader-monitor, fast-path alerted by Cloudflare Worker, PRIMARY TRADES CHANNEL CONVICTION ADD; message_id=1526581013701066873)

### BTC/ETH/SOL Spot — LONGS (CLOSED)
- **Status**: CLOSED at market 2026-07-02T10:25:13Z — "Close majors fully here"
- **Final position sizes** (at close): BTC 0%, ETH 0%, SOL 0% (fully exited)
- **Position history**: Re-entered above 60k support on 2026-06-26T07:23:30Z with BTC +5%, ETH +2%, SOL +2%. Held through technical contingency planning (2026-07-01: "No fixed price target. We'll scale out manually and re-evaluate the setup once 60+ breakout happens"). Closed fully on 2026-07-02T10:25:13Z as BTC approached/reached key technical levels (60k arrived 2026-07-01T14:27:07Z).
- **Thesis/Execution**: Managed hedged book with active rebalancing through June, trimmed at 67k strength (06-16), re-added through multiple conviction dips (06-18 through 06-25), closed underside-59k tranche on 06-25, re-entered above 60k on 06-26, then fully closed majors above 60k on 07-02 per manual scaling plan contingency.
- **Short basket**: HYPE (2% shorts, current hedge), ZEC (scaling conviction), TAO, SPCX, VVV, XPL, TON, LAB, SYN (1% short, added 2026-06-30T13:36:08Z) — maintained as hedges; no closure announced yet for these
- **Last update**: 2026-07-02T10:25:13Z (discord-trader-monitor, fast-path alerted, MAJORS LONGS FULLY CLOSED; message_id=1522186380598448128)

### LAB — SHORT (ACTIVE — PARTIAL PROFIT-TAKING 2026-07-08)
- **Status**: ACTIVE — part of high-conviction alt-short basket, managing positions with disciplined TP scaling
- **Position history**:
  - 06-16T13:23Z: Re-entry / conviction add — "Add 1x 1% lab short. Will add to it" (message_id prior to 06-16 window; re-added after prior position closure)
  - 06-17T13:09:44Z: Partial TP — "Tp 1% from altcoins shorts except for beat" (batch TP action covering ZEC, TAO, SPCX, VVV, XPL, TON, LAB; message_id=1517000083437260883)
  - **2026-07-08T15:17:50Z: Partial TP execution — "Take 1% off from lab short here at $1"** (is_reply to earlier message "Take 1% off from lab short here at $4"; message_id=1524434343978733658, fast-path alerted)
- **Current size**: Unknown exact %, but actively managed (re-added +1% on 06-16, TP'd -1% on 06-17, TP'd -1% on 07-08; current size likely ≥2-3% if multiple adds occurred between 06-16 and 07-08)
- **Entry levels**: Unknown (position predates detailed tracking; re-entry on 06-16 suggests prior closure and fresh accumulation)
- **Context**: LAB is part of HCH's rotating alt-short basket (alongside ZEC high-conviction, TAO, SPCX, VVV, XPL, TON, SYN). Re-added 06-16 with intent to scale further ("Will add to it"); participated in 06-17 batch TP; now actively scaled again 07-08. Profit-taking pattern across multiple sessions (06-17, 07-08) suggests favorable short thesis execution with consistent position management. 07-08 TP timing aligns with broader multi-asset profit-taking wave (BTC/ETH/SOL/HYPE/ZEC scale-out at 09:06Z same day), indicating coordinated portfolio rebalancing.
- **Conviction**: MEDIUM-HIGH (maintained position through multiple TP actions rather than full exit; continues to hold core LAB short within alt-basket allocation)
- **Last update**: 2026-07-08T15:17:50Z (discord-trader-monitor, fast-path alerted, PARTIAL TP; message_id=1524434343978733658)

### ZEC — SHORT (ONGOING SCALING / CONVICTION ADD)
- **Status**: ACTIVE — highest-conviction short, actively scaled and added throughout the window
- **Position history**:
  - 06-15T07:40Z: Scaling after low-400 take-profits — "scaling again in zec short after low-400 tps… add 2% short"
  - 06-15T11:14Z: Additional add — "add 1% more on zec, 2x" (second 1% add same session)
  - 2026-07-03T09:21:56Z: Conviction add — "Add 1% zec short too" (part of broader short-basket escalation morning session; message_id=1522532840686747658, fast-path alerted)
  - 2026-07-08T09:06:01Z: Profit-taking / scale-out — "Take 7.5%-3.5%-3.5%-1%-1% off from btc,eth,sol,hype,zec here" (reduced ZEC by 1%; message_id=1524340774735450112, fast-path alerted)
  - 2026-07-15T07:35:08Z: Conviction add — "Add 1% zec short" (re-escalation following prior profit-taking; message_id=1526854616547852298, fast-path alerted)
- **Current size**: Estimated 2-3%+ (after reducing 1% on 07-08, re-added 1% on 07-15 @ 07:35, re-added +1% on 07-15 @ 11:22; base position predates tracked window with multiple adds/trims)
- **Entry levels**: Unknown (position predates tracked window; lows referenced around 400 level for TP management)
- **Context**: ZEC remains HCH's highest-conviction short despite volatile market conditions. Pattern shows disciplined profit-taking (07-08 trim 1%) followed by immediate re-accumulation (07-15 morning add 1% + 07-15 late-morning add 1%), indicating sustained structural bearish thesis on ZEC. Dual adds within single session (07-35 + 11:22) suggest intraday conviction escalation — likely price weakness validating short thesis or acceleration of pre-planned accumulation. Multi-day escalation pattern (06-15 through 07-15) confirms ZEC as cornerstone of HCH's alt-short basket. Ticker-focus notes ZEC as "CONTESTED" (HCH short vs trading_axe treating strength as market-health tell), reinforcing need for close monitoring as sentiment signal.
- **Last update**: 2026-07-15T11:22:31Z (discord-trader-monitor, fast-path alerted, CONVICTION ADD; message_id=1526911839001251870)

### UNI — SHORT (NEW ENTRY — CONVICTION ADD 2026-07-16)
- **Status**: ACTIVE — trade-new-entry 2026-07-16T05:06:02Z
- **Entry**: 2026-07-16T05:06:02Z — "Add 1% to uni short"
- **Ticker**: UNI (Uniswap protocol governance token)
- **Position size**: 1% portfolio allocation
- **Entry type**: Direct execution call on primary Trades channel
- **Context**: NEW TICKER for HCH's short basket. First mention of UNI short (previously documented shorts: BTC/ETH/SOL/HYPE/ZEC). Entry extends HCH's macro crypto bearish positioning from major pairs into protocol governance tokens. Terse execution format consistent with documented conviction-add pattern ("Add 1% to uni short" mirrors prior calls "Add 2% eth short", "Add 3% btc short"). FAST-PATH ALERTED by Cloudflare Worker ~2-5s after event; memory-only processing per skill protocol.
- **Thesis**: Expansion of structural bearish crypto thesis to secondary tokens. UNI represents protocol narrative plays (DeFi sector risk, governance token volatility). Entry timing: immediately following "Short maxxing" X post at 04:16:37 UTC same day, suggesting coordinated escalation of short conviction across basket. Portfolio allocation trajectory: HCH achieved ~35% short basket target (Jul 15 07:49:35 UTC), now expanding into UNI as sixth ticker in constellation (after BTC/ETH/SOL/HYPE/ZEC reaches ~36-40% estimated allocation post-UNI entry).
- **Conviction**: HIGH — direct execution call on ★most important primary channel; terse format matches prior high-conviction adds; timing suggests macro bearish acceleration into new session (pre-US market open entry at 05:06 UTC = Asia morning, likely price action validating overnight setup).
- **Approval/Alert status**: FAST-PATH ALERTED (Telegram already sent by Worker); no duplicate send by skill. Await Kyle signal on whether to mirror UNI short on Kraken or monitor as memory-only entry.
- **Last update**: 2026-07-16T05:06:02Z (discord-trader-monitor, fast-path alerted, TRADE-CONVICTION-ADD; message_id=1527179482090311790)

## Wild_Randomness

### NVDA — SHORT (PUT) — ACTIVE (entry 2026-07-14)
- **Status**: ACTIVE — trade-new-entry with approval pending
- **Entry**: 2026-07-14T21:55:29Z — "Bought some August puts"
- **Expiry**: August (standard monthly options)
- **Entry type**: Market-filled ("bought")
- **Position size**: Small (willing to add on bounces/pops)
- **Exit criteria**: Hard exit if weekly closes above 215
- **Thesis**: Mean-reversion vol play on NVDA (trader notes pattern: "chart looks good today = chart looks bad tomorrow")
- **Context**: Wild_Randomness previously held/closed July calls on NVDA (per prior thesis). This is a fresh entry with opposite directional bias (puts vs. calls) and extended expiry (August vs. July). Position reflects tactical short-vol / mean-reversion conviction on a specific price level (215 weekly close).
- **Conviction**: MEDIUM (small position + willing to scale, but not maximum conviction on hard entry)
- **Approval status**: AWAITING KYLE APPROVAL (trade signal 5a alert sent, awaiting "approve NVDA" confirmation before mirror on Kraken)
- **Last update**: 2026-07-14T21:55:29Z (X, tweet_id=2077150011847016918, fast-path alerted, awaiting approval)

## t_in_crypto

### BTC — LONG (conviction add 2026-07-14)
- **Status**: ACTIVE — conviction add 2026-07-14T16:15:38Z
- **Entry**: 
  - **Initial entry**: 58.4K (100% position, held since at least Jul 12)
  - **Conviction add**: 2026-07-14T16:15:38Z — "took x2 volume" at 62K (doubled exposure)
- **Current size**: 200%+ notional (2x original at 58.4K equivalent)
- **Thesis**: Lunar/moon-cycle bull. High-conviction diamond-hand long through consolidation. Expects Jul 14–15 new moon pivot to validate patience thesis ("The market favors the patient"). Belief that reversal is coming but "not just yet" — playing through chop into later rally.
- **Conviction**: EXTREMELY HIGH — adding at pivot time despite macro chop/uncertainty across broader group (KillaXBT scalp-short hedge, HCH/Wild_Randomness shorting, only structural bulls participating). Solo-long positioning. Action-oriented execution call (not just holding).
- **Execution language**: "I took x2 volume to my position... today in my pivot time" — first-person, intraday action confirmation, tied to technical pivot calendar (3D candles, moon phases).
- **Context**: t_in_crypto stands alone in the group conviction map (see traders.md regime note: "Structural bulls (Killa, t_in_crypto) vs tactical bears"). Killa is also long (2x swing HTF from 62.6K) but with hedged scalp shorts; t_in_crypto is pure conviction long with ADD into strength/chop (inverse to HCH/Wild_Randomness scalp-short thinking). Pattern suggests belief in structural bottom closer than consensus estimates.
- **Last update**: 2026-07-14T16:15:38Z (X, fast-path alerted; tweet_id=2077064489598374073)

## swarmister

### BTC — LONG (new entry 2026-07-17, partial position opened)
- **Entry**: 2026-07-17T06:09:26Z (X post, tweet_id=2077999097949102104)
- **Entry message**: "$BTC D1 + H4 timeframes. Analysis results + update... I've now opened a partial position and am ready to add to my long position with a final target of 70.7k per Bitcoin."
- **Entry type**: Market order (partial position already filled, price TBD)
- **Entry zones for adds**: 62.4k, 61.2k (ready to scale in at liquidity zones)
- **Final target**: 70.7k per Bitcoin
- **Current size**: Partial position (amount unspecified, awaiting Kyle approval for mirror sizing)
- **Status**: PENDING APPROVAL — awaiting Kyle response (`approve BTC` to mirror on Kraken spot)
- **Thesis**: Bullish D1/H4 structure; currently in zone of interest with expected bounce. Sees 62.4k–61.2k as near-term support zones with downside liquidity risk. Continuation of Jul 16 15:36:42 UTC forecast (62.2–62.8k correction zone entry, 70.5k target).
- **Risk**: Acknowledges downside liquidity still present and market following it (caution flag)
- **Convergence**: Aligns with structural bull group thesis (KillaXBT 2x HTF long @62.6K, t_in_crypto x2 volume conviction add @62K). BTC overlap ticker on Kyle's watch list.
- **Alert sent**: Yes, trade signal 5a format (2026-07-17T06:10Z via ./notify)
- **Last update**: 2026-07-17T06:09:26Z (x-trader-monitor real-time event, awaiting approval)

## Wild_Randomness

### VIX calls — LONG (new entry 2026-07-15)
- **Status**: AWAITING_APPROVAL — trade signal 5a alert sent, awaiting "approve VIX" confirmation
- **Entry**: 2026-07-15T15:30:29Z
- **Instrument**: $VIX calls (December 2031 expiration)
- **Entry type**: Market order (no limit price specified in tweet)
- **Position size**: Not disclosed
- **Exit criterion**: Not specified
- **Thesis**: Aligns with documented macro/vol thesis: watching "$VIX/$VIXN AI-vol dispersion"; expects "spot up, vol up then broader top" scenario. VIX calls position hedges long equity exposure (SPY averaging-in) against volatility spike/correlation pickup risk.
- **Execution language**: "Ok buying 2031 VIX calls" — direct first-person execution call, market-order implied
- **Approval status**: AWAITING KYLE APPROVAL (trade signal 5a alert sent via notify; awaiting "approve VIX" confirmation before mirror on Kraken)
- **Last update**: 2026-07-15T15:30:29Z (X, tweet_id=2077415514746318933, fast-path alerted via notify)

### NVDA — LONG (EQUITY) — CONVICTION ADD (2026-07-15)
- **Status**: ACTIVE — multiple conviction adds executed (15:47:46Z doubled at 213, 19:20:02Z re-added at 211)
- **Entry history**:
  - 2026-07-15T15:47:46Z: Doubled position at $213 (market open pop) — "Was able to double the position"
  - 2026-07-15T19:20:02Z: Re-added at $211 (intraday pullback dip) — "Ok I'm re-adding here at 211 lol"
- **Entry levels**: 213 (market open), 211 (intraday dip, 2 points lower)
- **Entry type**: Market-filled entries at both levels
- **Position action**: LAYERED CONVICTION ADD (doubled at 213, re-added at 211 on dip)
- **Exit criteria**: Hard stop at $215 weekly close (invalidation level); price action contingent on daily bearish divergence formation
- **Thesis**: Mean-reversion vol play using pattern recognition: "chart looks good today = chart looks bad tomorrow". Trader expecting near-term pullback after pop to set up mean-reversion upside bounce. "Hoping for a red close" = expecting today's downside (211 entry captures additional dip), which validates setup for tomorrow's recovery. Position aligned with $NVDA watching for weakness back into prior levels while adding on dips.
- **Execution language**: 
  - 15:47:46Z: "Got what I wanted— a pop at the open above 213. Was able to double the position." — first-person execution confirmation
  - 19:20:02Z: "Ok I'm re-adding here at 211 lol. Hoping for a red close" — first-person re-add with tactical dip buying conviction
- **Context**: Wild_Randomness previously held July calls on NVDA (TP'd), was sidelined. Fresh entry into NVDA equities on pop (213 open), then adding to position on intraday pullback (211 dip). Layered entry strategy reflects disciplined accumulation on tactical levels within mean-reversion framework. $NVDA is on Kyle's explicit watch list (chart constructive into resistance).
- **Conviction**: HIGH — dual-entry same-day with explicit execution language, layered accumulation at support levels, defined invalidation level at 215
- **Approval/Alert status**: CONVICTION ADD signals sent for both entries (Step 5d format: "Want to add to your position too?" awaiting Kyle's response on whether to mirror)
- **Last update**: 2026-07-15T19:20:02Z (X, tweet_id=2077473282195071203, fast-path alerted via notify)

---

> Last bootstrapped: 2026-06-25 (discord-trader-monitor real-time event). GOOG (Chase) updated from recent conviction-add; HCH BTC/ETH/SOL position closed near 59k with stated re-entry thesis above 60k.
