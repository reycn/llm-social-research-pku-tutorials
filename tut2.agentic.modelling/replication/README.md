# Replication record

The single script `script/01_card1993_replication.R` reproduces the estimates
in Card (1993) from the 3,010-man NLS Young Men extract distributed with the
**wooldridge** R package. This note records the comparison with the published
paper and the exact commands used.

## Published target

Card, D. (1993). *Using Geographic Variation in College Proximity to Estimate
the Return to Schooling* (NBER Working Paper No. 4483). National Bureau of
Economic Research.

- Table 3, column (5): structural estimate of the return to education,
  `educ` = 0.132 (0.055), n = 3,010, no family-background controls.
- Conclusion: IV estimates of 10–14% versus a conventional OLS estimate of
  7.3%.

## Comparison

| Quantity | Card (1993) | This replication |
|---|---|---|
| OLS return, with controls | 0.073 | 0.075 |
| 2SLS return, `nearc4`, with controls | 0.132 | 0.132 |
| 2SLS standard error | 0.055 | 0.055 |
| N | 3,010 | 3,010 |

The 2SLS coefficient and standard error match Card's Table 3, column (5), to
three decimals. The OLS estimate is within 0.002 of the 7.3% figure reported in
Card's conclusion; small differences are expected because the published OLS
figure comes from a slightly different specification/rounding.

The comparison is written by R to `data/result/replication_comparison.csv`.

## How to reproduce

```bash
Rscript script/01_card1993_replication.R
./sync_results.sh
cd paper && latexmk -pdf main.tex
```

Expected console output:

```
Models: OLS = 0.052; OLS + controls = 0.075; 2SLS = 0.132 (first-stage F = 13.26)
```

## Scope and deviations

- The exercise uses classical (homoskedastic) standard errors to match the
  published precision; robust standard errors are not reported.
- The models use the covariate set requested for this project, which matches
  Card's main specification but omits the family-background controls used in
  Card's Table 3, column (6).
- The instrument is the binary `nearc4` indicator. Card also reports models
  using `nearc2` and interactions with family background; these are outside the
  scope of this minimal replication.
- The data are the public extract distributed with **wooldridge**, not a fresh
  build from the original NLS files.
