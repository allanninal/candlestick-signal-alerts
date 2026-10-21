# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
"""Count pattern marks per 1,000 closed bars from the OHLC columns of dump CSVs (aggregate numbers only).

    python3 tests/frequency.py <dump dir> H1 > docs/data/pattern-frequency.json
Reads <dump dir>/dump/cd_default_<SYMBOL>_<TF>.csv; every closed bar is scanned with tests/reference.py."""
import json
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
from reference import NAMES, NP, run  # noqa: E402

root, tf = Path(sys.argv[1]), sys.argv[2]
tot = [0] * NP
bars = 0
per_symbol = {}
for f in sorted(root.glob(f"dump/cd_default_*_{tf}.csv")):
    d = pd.read_csv(f)
    o, h, l, c = (d[k].to_numpy(float)[:-1] for k in ("open", "high", "low", "close"))
    rows = run(o, h, l, c)
    cnt = [0] * NP
    for r in rows:
        for p, _ in r["ev"]:
            cnt[p] += 1
    sym = f.stem.split("_")[2]
    per_symbol[sym] = dict(bars=len(c), marks=sum(cnt))
    bars += len(c)
    tot = [a + b for a, b in zip(tot, cnt)]
out = dict(timeframe=tf, closed_bars=bars, per_symbol=per_symbol,
           marks_per_1000_bars={NAMES[i]: round(1000 * tot[i] / bars, 1) for i in range(NP)},
           marks_per_1000_bars_total=round(1000 * sum(tot) / bars, 1))
print(json.dumps(out, indent=1))
