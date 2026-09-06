## Summary

**traders.md:** 213,354 → 54,482 bytes (74% reduction)

**What was done:**
- Merged 3 duplicate sections: KillaXBT, bull_genius, trading_axe (newest state won for all position/thesis fields)
- Collapsed Wild_Randomness and HeartCanHodl's fragmented multi-block layout (multiple "Last seen:" lines) into single canonical sections
- Trimmed all 12 traders to max 25 rolling events, newest last; dropped per-run machinery, skip events, and redundant informational noise
- Regenerated `trader-baseline-10d.md` — window Aug 27–Sep 06, all 12 traders, ≤1KB each
- Marked ISS-004 (traders.md oversize standing issue) resolved in `issues/INDEX.md` and `ISS-004.md`
- Committed: `ce6e743`
