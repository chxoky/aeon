/**
 * Symbol → venue resolution.
 *
 * DELIBERATELY STRICT. A wrong guess here sends a real order to the wrong venue
 * or the wrong instrument, so there is no clever heuristic: a symbol either
 * resolves through an explicit entry or the alert is rejected. "BTC" is three
 * uppercase letters and so is "IBM" — any length/shape heuristic is a coin flip
 * with money on it.
 *
 * To add an instrument, add a line. That friction is the point.
 */

/** Crypto → Kraken. `pair` is the AddOrder pair; `asset` is the balance code. */
export const KRAKEN_SYMBOLS = {
  BTC:   { pair: 'XBTUSD',  asset: 'XBT'  },
  XBT:   { pair: 'XBTUSD',  asset: 'XBT'  },
  ETH:   { pair: 'ETHUSD',  asset: 'ETH'  },
  SOL:   { pair: 'SOLUSD',  asset: 'SOL'  },
  HYPE:  { pair: 'HYPEUSD', asset: 'HYPE' },
  LINK:  { pair: 'LINKUSD', asset: 'LINK' },
  AVAX:  { pair: 'AVAXUSD', asset: 'AVAX' },
  DOGE:  { pair: 'XDGUSD',  asset: 'XDG'  },
  XRP:   { pair: 'XRPUSD',  asset: 'XRP'  },
  ADA:   { pair: 'ADAUSD',  asset: 'ADA'  },
  SUI:   { pair: 'SUIUSD',  asset: 'SUI'  },
};

/** US equities / ETFs → Alpaca. Value is the Alpaca symbol. */
export const ALPACA_SYMBOLS = {
  BITX: 'BITX',   // Volatility Shares 2x Bitcoin Strategy ETF
  NVDL: 'NVDL',   // GraniteShares 2x Long NVDA
  MSTR: 'MSTR',
  COIN: 'COIN',
  NVDA: 'NVDA',
  TSLA: 'TSLA',
  SPY:  'SPY',
  QQQ:  'QQQ',
  IBIT: 'IBIT',
  MSTX: 'MSTX',
};

/**
 * @param {string} symbol  ticker from the alert, e.g. "BITX"
 * @param {string} [venueHint]  explicit `venue` from the alert payload
 * @param {string} [pairOverride]  explicit `pair` from the alert payload
 */
export function resolve(symbol, venueHint, pairOverride) {
  const s = String(symbol || '').trim().toUpperCase().replace(/^\$/, '');
  if (!s) throw new Error('alert is missing `symbol`');

  const wantsKraken = venueHint === 'kraken';
  const wantsAlpaca = venueHint === 'alpaca';

  if (wantsKraken || (!wantsAlpaca && KRAKEN_SYMBOLS[s])) {
    const entry = KRAKEN_SYMBOLS[s];
    if (!entry && !pairOverride) {
      throw new Error(`unknown Kraken symbol "${s}" — add it to KRAKEN_SYMBOLS or pass an explicit "pair"`);
    }
    return {
      venue: 'kraken',
      symbol: s,
      pair: pairOverride || entry.pair,
      asset: entry?.asset || s,
    };
  }

  if (wantsAlpaca || ALPACA_SYMBOLS[s]) {
    const mapped = ALPACA_SYMBOLS[s];
    if (!mapped && !wantsAlpaca) {
      throw new Error(`unknown Alpaca symbol "${s}" — add it to ALPACA_SYMBOLS`);
    }
    return { venue: 'alpaca', symbol: mapped || s };
  }

  throw new Error(
    `cannot resolve "${s}" to a venue — add it to KRAKEN_SYMBOLS or ALPACA_SYMBOLS, ` +
    `or set "venue" explicitly in the alert payload`,
  );
}
