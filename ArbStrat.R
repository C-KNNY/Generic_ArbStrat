# ==============================================================
# Bond Arbitrage Screener  —  Law of One Price
# https://www.investopedia.com/terms/l/law-one-price.asp
#
# augment (system of linear eq.) --> gaussian elim. --> RREF
# take updated constant matrix to determine price diff. (long/short strat.)
# ==============================================================


# Libraries ---------------------------------------------------------------
library(quantmod)


# INPUTS (interchangeable) ------------------------------------------------
target_cash_flows <- c(5, 5, 105)   # target bond pays $5, $5, $105 at t = 1, 2, 3 yrs
target_market_price <- 92.00        # observed market price today
tolerance <- 0.01                   # price gap smaller than this = "fairly priced"

# Benchmark bonds used to replicate the target (rows = year 1/2/3 cash flow,
# columns = Benchmark Bond 1/2/3)
benchmarks <- matrix(c(
  100,   5,   6,
  0, 105,   6,
  0,   0, 106
), nrow = 3, byrow = TRUE)


# 1. PULL DATA (FRED) -----------------------------------------------------
getSymbols(c("DGS1", "DGS2", "DGS3"), src = "FRED")

latest_yield <- function(series) as.numeric(tail(na.omit(series), 1)) / 100

yields <- c(r1 = latest_yield(DGS1),
            r2 = latest_yield(DGS2),
            r3 = latest_yield(DGS3))

as_of <- tail(index(na.omit(DGS1)), 1)
cat(sprintf("Treasury yields as of %s:  1Y %.2f%%  2Y %.2f%%  3Y %.2f%%\n",
            as_of, yields["r1"] * 100, yields["r2"] * 100, yields["r3"] * 100))


# 2. ANNUAL YIELDS --> Zero-Coupon Discount factor ------------------------
# d_t = 1 / (1 + r_t)^t   (treats CMT yields as zero-coupon rates)
discount_factors <- 1 / (1 + yields) ^ c(1, 2, 3)


# 3. THE "FAIR VAL." -------------------------------------------------------
# Law of One Price: a bond is worth the present value of its own
# cash flows — this is the fair value we compare to the market.
fair_value <- sum(target_cash_flows * discount_factors)
mispricing <- target_market_price - fair_value


# 4. MISPRICINGS ----------------------------------------------------------
# Solve benchmarks %*% weights = target_cash_flows for the portfolio
# of benchmark bonds that replicates the target bond's payouts.
weights <- solve(benchmarks, target_cash_flows)


# 5. FINAL REP. -----------------------------------------------------------

cat(sprintf("Fair value (no-arbitrage):  $%.2f\n", fair_value))
cat(sprintf("Market price:                $%.2f\n", target_market_price))

if (abs(mispricing) < tolerance) {
  cat("\nSIGNAL: Fairly priced. No arbitrage available.\n")
} else {
  
  trade_line <- function(w, i) {
    action <- if (w >= 0) "BUY  " else "SHORT"
    sprintf("-> %s %.4f units of Benchmark Bond %d\n", action, abs(w), i)
  }
  
  if (mispricing > 0) {
    cat(sprintf("\nSIGNAL: TARGET OVERPRICED by $%.2f\n", mispricing))
    cat(sprintf("-> SHORT 1.0000 unit of Target Bond (Collect $%.2f)\n", target_market_price))
    for (i in seq_along(weights)) cat(trade_line(weights[i], i))
  } else {
    cat(sprintf("\nSIGNAL: TARGET UNDERPRICED by $%.2f\n", abs(mispricing)))
    cat(sprintf("-> BUY   1.0000 unit of Target Bond (Pay $%.2f)\n", target_market_price))
    for (i in seq_along(weights)) cat(trade_line(-weights[i], i))
  }
  
  cat(sprintf("Net Arbitrage Profit Locked In Today: $%.2f\n", abs(mispricing)))
}