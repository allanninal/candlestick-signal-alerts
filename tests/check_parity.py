# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
"""Compare what the indicator drew (DumpIndicator CSVs on MT5, Dump4 CSVs on MT4) with tests/reference.py, bar by bar.

    python3 tests/check_parity.py <dump dir>             (needs numpy and pandas; looks in <dump dir>/dump)
    python3 tests/check_parity.py <dump dir> --mt4       (the MT4 edition, dumps from the MT4 tester)
Buffers: b0 bullish arrow (at the low), b1 bearish arrow (at the high), b2/b3 bullish/bearish pattern bit masks.
Pass: the masks equal the reference exactly on every closed bar; the arrows are set on the same bars (on MT4 the
arrow sits a fraction of ATR away from the candle, so only where it is set is compared)."""
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
from reference import ALL, NP, run  # noqa: E402

NODOJI = tuple(i != 6 for i in range(NP))
# tag: (patterns on, closed bars scanned (InpHistory), DumpIndicator InpParams for MT5 in input order; groups count)
CONFIGS = {
    "cd_default": (ALL, 2000, "s:Patterns|b:true|b:true|b:true|b:true|b:true|b:true|b:true|s:Display|i:2000|b:true|"
                              "c:6465062|c:4606690|i:7|s:Alerts|b:false|b:false|s:alert.wav|b:false|b:false"),
    "cd_long": (NODOJI, 6000, "s:Patterns|b:true|b:true|b:true|b:false|b:true|b:true|b:true|s:Display|i:6000|b:true|"
                              "c:6465062|c:4606690|i:7|s:Alerts|b:false|b:false|s:alert.wav|b:false|b:false"),
}


def num(col):
    return pd.to_numeric(col, errors="coerce").to_numpy(float)


def check(csv: Path, use, hist, mt4=False):
    d = pd.read_csv(csv)
    n = len(d)
    # MT4 tester: the indicator was attached with far fewer than InpHistory bars, so it scans from bar 0 and keeps
    # feeding, which is why the scan starts at bar 0 there
    start = 0 if mt4 else max(0, n - 1 - hist)
    o, h, l, c = (d[k].to_numpy(float)[start:n - 1] for k in ("open", "high", "low", "close"))
    rows = run(o, h, l, c, use=use)
    exp = {b: np.full(n, np.nan) for b in ("b0", "b1", "b2", "b3")}
    for i, r in enumerate(rows):
        k = start + i
        mb = sum(1 << p for p, dr in r["ev"] if dr > 0)
        ms = sum(1 << p for p, dr in r["ev"] if dr < 0)
        if mb:
            exp["b0"][k], exp["b2"][k] = l[i], mb
        if ms:
            exp["b1"][k], exp["b3"][k] = h[i], ms
    ok, msgs = True, []
    for b in exp:
        if mt4 and b in ("b0", "b1"):
            good = np.isnan(num(d[b])[:n - 1]) == np.isnan(exp[b][:n - 1])
        else:
            good = np.isclose(num(d[b])[:n - 1], exp[b][:n - 1], rtol=1e-12, atol=0, equal_nan=True)
        ok &= bool(good.all())
        msgs.append(f"{b} {'OK' if good.all() else f'{(~good).sum()} differ (first bar {int(np.flatnonzero(~good)[0])})'}")
    npat = int(sum(1 for r in rows if r["ev"]))
    return ok, f"{csv.stem:30} bars {n:>6} scanned {n - 1 - start:>5} pattern bars {npat:>5}  " + " ".join(msgs)


if __name__ == "__main__":
    mt4 = "--mt4" in sys.argv
    root = Path([a for a in sys.argv[1:] if a != "--mt4"][0])
    allok, k = True, 0
    for tag, (use, hist, _) in CONFIGS.items():
        for f in sorted(root.glob(f"dump/{tag}_*.csv")):
            ok, msg = check(f, use, hist, mt4)
            allok &= ok
            k += 1
            print(("PASS " if ok else "FAIL ") + msg)
    print(f"\n{'ALL PASS' if allok and k else 'FAILURES'} ({k} files)")
    sys.exit(0 if allok and k else 1)
