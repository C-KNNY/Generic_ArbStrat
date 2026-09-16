# Bond Arbitrage Screener — Law of One Price

A small R script that pulls the live U.S. Treasury yield curve, prices a
target bond off that curve, and — if the market price disagrees with the
no-arbitrage fair value — computes the exact benchmark-bond portfolio needed
to lock in a riskless profit.

Reference: [Investopedia — Law of One Price](https://www.investopedia.com/terms/l/law-one-price.asp)

---

## 1. Overview

The [**Law of One Price**](https://www.investopedia.com/terms/l/law-one-price.asp)
says that two assets producing identical future cash flows must trade at the
same price today. If they don't, there is a riskless arbitrage: buy the
cheap one, sell the expensive one, and collect the difference with zero net
exposure to the future.

This script applies that idea to a coupon bond:

1. Build a risk-free discount curve from Treasury yields.
2. Price the target bond's own cash flows off that curve (**fair value**).
3. Compare fair value to the observed market price (**mispricing**).
4. If mispriced, solve for the portfolio of tradable benchmark bonds that
   replicates the target's cash flows, so the arbitrage can actually be
   executed.

---

## 2. Step 1 — Discount curve from Treasury yields

Given annual Treasury yields $r_1, r_2, r_3$ (1, 2, and 3-year constant
maturity), the corresponding **discount factors** are:

$$
d_t = \frac{1}{(1 + r_t)^{t}}, \qquad t = 1, 2, 3
$$

$d_t$ answers: *"what is $1 paid at time $t$ worth today, if I could invest
risk-free instead?"* This vector $\vec{d} = (d_1, d_2, d_3)$ is the backbone
of the whole model — every price in this script is derived from it.

---

## 3. Step 2 — Fair value of the target bond

Let the target bond pay cash flows $\vec{CF} = (CF_1, CF_2, CF_3)$ at years
1, 2, 3 (e.g. coupon, coupon, coupon + principal). By the Law of One Price,
a bond is worth nothing more or less than the present value of its own cash
flows:

$$
\text{Fair Value} = \sum_{t=1}^{3} CF_t \cdot d_t
$$

Comparing this to the observed market price $P_{\text{market}}$ gives the
**mispricing**:

$$
\varepsilon = P_{\text{market}} - \text{Fair Value}
$$

- $\varepsilon > 0$: the bond is **overpriced** — the market is paying more
  than the discounted cash flows justify.
- $\varepsilon < 0$: the bond is **underpriced**.
- $|\varepsilon| \approx 0$ (within tolerance): fairly priced, no trade.

---

## 4. Step 3 — Replicating the cash flows with tradable bonds

Fair value alone tells you *that* an arbitrage exists, not *how to trade
it* — you generally can't buy or sell a discount factor directly. Instead,
you replicate the target's cash flows using a basket of liquid **benchmark
bonds**.

Let $A$ be the $3 \times 3$ matrix whose column $j$ holds Benchmark Bond
$j$'s cash flows at years 1, 2, 3:

$$
A =
\begin{pmatrix}
100 & 5 & 6 \\
0 & 105 & 6 \\
0 & 0 & 106
\end{pmatrix}
$$

We solve for portfolio weights $\vec{w} = (w_1, w_2, w_3)$ such that holding
$w_j$ units of each benchmark bond reproduces the target's cash flow stream
exactly:

$$
A \vec{w} = \vec{CF} \quad \Longrightarrow \quad \vec{w} = A^{-1}\vec{CF}
$$

Because $A$ is square and invertible, this has a unique solution. In R,
`solve(A, CF)` performs this (equivalent to Gaussian elimination /
back-substitution under the hood, since $A$ here is already close to
lower-triangular by construction).

Since the replicating portfolio has *identical* future cash flows to the
target bond, the Law of One Price guarantees it must also have the *same*
fair value. Any price gap between the target and the portfolio is therefore
pure arbitrage.

---

## 5. Step 4 — Constructing the trade

| Mispricing | Action |
|---|---|
| $\varepsilon > 0$ (target overpriced) | **Short** 1 unit of the target bond, **buy** the replicating portfolio ($w_j \geq 0 \Rightarrow$ buy, $w_j < 0 \Rightarrow$ short) |
| $\varepsilon < 0$ (target underpriced) | **Buy** 1 unit of the target bond, **short** the replicating portfolio (signs flipped) |

Both legs pay off identically at every future date, so the position is
**cash-flow neutral going forward** — the only P&L is the price gap
captured *today*, equal to $|\varepsilon|$.

---

## 6. Usage

```r
# Requires: quantmod (pulls yields from FRED)
install.packages("quantmod")

source("bond_arbitrage_screener.R")
```

Edit the inputs at the top of the script to price a different bond:

```r
target_cash_flows <- c(5, 5, 105)   # coupon, coupon, coupon + principal
target_market_price <- 92.00        # observed market price
tolerance <- 0.01                   # threshold for "fairly priced"
```

### Example output

```
SIGNAL: TARGET UNDERPRICED by $8.76
-> BUY   1.0000 unit of Target Bond (Pay $92.00)
-> BUY   0.0090 units of Benchmark Bond 1
-> BUY   0.0090 units of Benchmark Bond 2
-> SHORT 0.9906 units of Benchmark Bond 3
Net Arbitrage Profit Locked In Today: $8.76
```

---

## 7. Caveats

This is a teaching/screening tool, not a trading system. In practice:

- Treasury CMT yields are not literally zero-coupon rates; a proper
  bootstrap would strip coupons out first.
- Transaction costs, bid/ask spreads, and financing costs will erode or
  eliminate small mispricings.
- The benchmark bonds must actually be tradable in the sizes implied by
  $\vec{w}$.

---

## License

MIT
