
set.seed(1)

# generate artificial BG/CNBD-k data 
n      <- 8000 # no. of customers
T.cal  <- 28   # 4 weeks of calibration period
T.star <- 42   # 6 weeks of hold-out period
params <- c(k=3,                # regularity in interpurchase-times (Erlang-k)
            r=0.85, alpha=1.45, # purchase frequency lambda_i ~ Gamma(r, alpha)
            a=0.79, b=2.42)     # dropout probability p_i ~ Beta(a, b)

data <- bgcnbd.GenerateData(n, T.cal, T.star, params, return.elog=TRUE)
cbs  <- data$cbs  # CBS summary - one record per customer
elog <- data$elog # Event log - one row per event/purchase

# estimate regularity from event log
(k.est <- estimateRegularity(elog))
# 2.985917; interpurchase-times indicate Erlang-3

# estimate parameters, and compare to true parameters
est  <- bgcnbd.EstimateParameters(cbs[, c("x", "t.x", "T.cal", "litt")])
est1 <- BTYD::bgnbd.EstimateParameters(cbs[, c("x", "t.x", "T.cal", "litt")])
rbind("actual"=params, "bg/cnbd-k"=round(est, 2), "bg/nbd"=c(1, round(est1, 2)))
#           k    r alpha    a    b
# actual    3 0.85  1.45 0.79 2.42
# bg/cnbd-k 3 0.85  1.47 0.76 2.33
# bg/nbd    1 0.92  6.19 0.55 2.14
# -> underlying parameters are successfully identified via Maximum Likelihood Estimation

# plot aggregate fit in calibration; and compare to BG/NBD fit
op <- par(mfrow=c(1,2))
nil <- bgcnbd.PlotFrequencyInCalibration(est, cbs, censor = 7)
nil <- bgcnbd.PlotFrequencyInCalibration(c(1, est1), cbs, censor = 7)
par(op)

# plot incremental transactions;
op <- par(mfrow=c(1,2))
elog <- data.table::setDT(elog)
inc.tracking <- elog[t>0, .N, keyby=ceiling(t/7)]$N
inc <- bgcnbd.PlotTrackingInc(est, cbs$T.cal/7, (28+42), inc.tracking)
nil <- bgcnbd.PlotTrackingInc(c(1, est1), cbs$T.cal/7, (28+42), inc.tracking, ymax = max(inc) * 1.05)
par(op)

# estimate future transactions in holdout-period
cbs$x.est  <- bgcnbd.ConditionalExpectedTransactions(est, cbs$T.star, cbs$x, cbs$t.x, cbs$T.cal)
cbs$x.est1 <- BTYD::bgnbd.ConditionalExpectedTransactions(est1, cbs$T.star, cbs$x, cbs$t.x, cbs$T.cal)

# compare forecast accuracy to bg/nbd and naive forecast
rbind("bg/cnbd-k" = mean(abs(cbs$x.star-cbs$x.est)),
      "bg/nbd"    = mean(abs(cbs$x.star-cbs$x.est1)),
      "naive"     = mean(abs(cbs$x.star-cbs$x)))
# bg/cnbd-k 1.452800
# bg/nbd    1.678846
# naive     2.175875
# -> BG/CNBD-k forecast better than BG/NBD and naive forecast

# estimate P(alive)
cbs$palive  <- bgcnbd.PAlive(est, cbs$x, cbs$t.x, cbs$T.cal)
cbs$palive1 <- BTYD::bgnbd.PAlive(est1, cbs$x, cbs$t.x, cbs$T.cal)

# compare to true (usually unobserved) alive status
prop.table(table(cbs$palive>.5, cbs$alive))
#            FALSE     TRUE
#   FALSE 0.338125 0.044125
#   TRUE  0.095125 0.522625
# -> 86% of customers are correctly classified

# Brier score for P(alive)
rbind("bg/cnbd-k" = sqrt(mean((cbs$palive-cbs$alive)^2)),
      "bg/nbd"    = sqrt(mean((cbs$palive1-cbs$alive)^2)))
# bg/cnbd-k 0.3163118
# bg/nbd    0.3441937
# -> P(alive) is more accurate for BG/CNBD-k than for BG/NBD when regularity
# is present in the data


# compare estimated with actual distributions in lambda & churn probability
par(mfrow=c(2,1), mar=c(2,1,2,1))
xlim <- 1.5
x <- seq(0, xlim, len=1000)[-1]
y <- dgamma(x, shape=params[2], rate=params[3]*params[1])
plot(x, y, typ="l", col="black", lwd=2, main="Heterogeneity in Intertransaction Times", ylab="", xlab="", axes=FALSE, xlim=c(0, xlim))
lines(x, dgamma(x, shape=est[2], rate=est[3]*est[1]), col="red", lwd=2)
lines(x, dgamma(x, shape=est1[1], rate=est1[2]), col="blue", lwd=2)
axis(1, pos=0, labels=round(1/(xlim*(0:10/10)), 1), at=xlim*(0:10/10))
legend(xlim*.6, max(y)*.9, c("Actual", "BG/CNBD-k", "BG/NBD"), col=c("black", "red", "blue"), pch=15, bty="n")

xlim <- 1
x <- seq(0.05, xlim, len=1000)
y <- dbeta(x, params[4], params[5])
plot(x, y, typ="l", col="black", lwd=2, main="Heterogeneity in Churn Probability", ylab="", xlab="", axes=FALSE, xlim=c(0, xlim))
lines(x, dbeta(x, est[4], est[5]), col="red", lwd=2)
lines(x, dbeta(x, est1[3], est1[4]), col="blue", lwd=2)
axis(1, pos=0)
legend(xlim*.6, max(y)*.9, c("Actual", "BG/CNBD-k", "BG/NBD"), col=c("black", "red", "blue"), pch=15, bty="n")