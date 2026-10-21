# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
"""Python twin of Cdl.mqh: 13 candlestick patterns on closed bars (the rules are in the README). This file is the exact
rule book; the MQL5 and MQL4 engines are checked against it bar by bar (tests/check_parity.py).

    from reference import run, NAMES
    rows = run(o, h, l, c)         # rows[k] = dict(ev=[(pattern, dir), ...], mask=bit mask, ema=EMA(20) or None)
"""
NAMES = ["Bullish Engulfing", "Bearish Engulfing", "Hammer", "Hanging Man", "Inverted Hammer", "Shooting Star",
         "Doji", "Morning Star", "Evening Star", "Bullish Harami", "Bearish Harami", "Piercing Line",
         "Dark Cloud Cover"]
NP = len(NAMES)
ALL = (True,) * NP
# fixed direction per pattern (Doji: by the trend before it, 0 here)
DIR = [1, -1, 1, -1, 1, -1, 0, 1, -1, 1, -1, 1, -1]
EMA_N, AVG_N = 20, 10


def run(o, h, l, c, use=ALL):
    n = len(c)
    ema = [None] * n
    s, cnt = 0.0, 0
    for k in range(n):                         # EMA(20) of closes, SMA-seeded
        cnt += 1
        if cnt < EMA_N:
            s += c[k]
        elif cnt == EMA_N:
            s += c[k]
            ema[k] = s / EMA_N
        else:
            ema[k] = ema[k - 1] + 2.0 / (EMA_N + 1) * (c[k] - ema[k - 1])
    body = [abs(c[k] - o[k]) for k in range(n)]
    rng = [h[k] - l[k] for k in range(n)]
    up = [h[k] - max(o[k], c[k]) for k in range(n)]
    lo = [min(o[k], c[k]) - l[k] for k in range(n)]
    bull = [c[k] > o[k] for k in range(n)]
    bear = [c[k] < o[k] for k in range(n)]

    def avg(arr, k):                           # SMA of the AVG_N bars before k
        return sum(arr[k - AVG_N:k]) / AVG_N if k >= AVG_N else None

    rows = []
    for k in range(n):
        ev = []                                 # (pattern, dir)
        ab, ar = avg(body, k), avg(rng, k)
        if ab is not None and k >= 3:
            b, r, u, w = body[k], rng[k], up[k], lo[k]
            tol = 1e-9 * abs(c[k])                # ties within 1e-9 x price count as equal (rounding noise decides nothing)

            def GE(x, y):
                return x >= y - tol

            def LE(x, y):
                return x <= y + tol

            def GT(x, y):
                return x > y + tol

            def LT(x, y):
                return x < y - tol

            def tr(j):                          # +1 up / -1 down / 0 unknown, at bar j
                if j < 0 or ema[j] is None:
                    return 0
                return 1 if GT(c[j], ema[j]) else (-1 if LT(c[j], ema[j]) else 0)

            t1, t2, t3 = tr(k - 1), tr(k - 2), tr(k - 3)
            p = k - 1
            # 0/1 engulfing
            if bear[p] and bull[k] and LE(o[k], c[p]) and GE(c[k], o[p]) and GT(b, body[p]) and t2 < 0:
                ev.append((0, 1))
            if bull[p] and bear[k] and GE(o[k], c[p]) and LE(c[k], o[p]) and GT(b, body[p]) and t2 > 0:
                ev.append((1, -1))
            if GT(r, 0):
                hammer = GE(w, 2 * b) and LE(u, 0.1 * r) and GE(w, 0.6 * r)
                inv = GE(u, 2 * b) and LE(w, 0.1 * r) and GE(u, 0.6 * r)
                if hammer and t1 < 0:
                    ev.append((2, 1))
                if hammer and t1 > 0:
                    ev.append((3, -1))
                if inv and t1 < 0:
                    ev.append((4, 1))
                if inv and t1 > 0:
                    ev.append((5, -1))
                if LE(b, 0.05 * r) and GE(r, 0.5 * ar) and t1 != 0:
                    ev.append((6, -t1))
            # 7/8 stars
            q = k - 2
            if bear[q] and GE(body[q], ab) and LE(body[p], 0.3 * body[q]) and LE(min(o[p], c[p]), c[q]) and bull[k] \
                    and GT(c[k], (o[q] + c[q]) / 2) and t3 < 0:
                ev.append((7, 1))
            if bull[q] and GE(body[q], ab) and LE(body[p], 0.3 * body[q]) and GE(max(o[p], c[p]), c[q]) and bear[k] \
                    and LT(c[k], (o[q] + c[q]) / 2) and t3 > 0:
                ev.append((8, -1))
            # 9/10 harami
            if bear[p] and GE(body[p], ab) and bull[k] and GE(o[k], c[p]) and LE(c[k], o[p]) and LT(b, body[p]) and t2 < 0:
                ev.append((9, 1))
            if bull[p] and GE(body[p], ab) and bear[k] and LE(o[k], c[p]) and GE(c[k], o[p]) and LT(b, body[p]) and t2 > 0:
                ev.append((10, -1))
            # 11/12 piercing, dark cloud
            if bear[p] and GE(body[p], ab) and bull[k] and LE(o[k], c[p]) and GT(c[k], (o[p] + c[p]) / 2) and LT(c[k], o[p]) and t2 < 0:
                ev.append((11, 1))
            if bull[p] and GE(body[p], ab) and bear[k] and GE(o[k], c[p]) and LT(c[k], (o[p] + c[p]) / 2) and GT(c[k], o[p]) and t2 > 0:
                ev.append((12, -1))
        ev = [e for e in ev if use[e[0]]]
        ev.sort()
        rows.append(dict(ev=ev, mask=sum(1 << pt for pt, _ in ev), ema=ema[k]))
    return rows
