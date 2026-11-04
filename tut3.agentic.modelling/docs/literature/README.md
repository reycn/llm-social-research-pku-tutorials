# Literature

`Card1993_Using-Geographic-Variation-in-College-Proximity.pdf` is the scanned
NBER Working Paper No. 4483 (October 1993) version of:

> Card, D. (1993). *Using geographic variation in college proximity to estimate
> the return to schooling* (NBER Working Paper No. 4483). National Bureau of
> Economic Research. https://doi.org/10.3386/w4483

The PDF is image-only (no text layer). Relevant material for the replication:

- Table 1, final column: the 3,010-man "valid wage & education" subsample used
  in the paper (mean schooling 13.3 years; 68.2% grew up near a four-year
  college).
- Table 3, column (5): structural 2SLS estimate of the return to schooling,
  0.132 (0.055), n = 3,010.
- Conclusion (p. 25): IV estimates of 10–14% versus an OLS estimate of 7.3%.

The data extract analyzed here is distributed as the `card` data set in the
**wooldridge** R package. The `card` documentation credits Card (1995), the
published book-chapter version of the same analysis; the estimates are
numerically identical for the specification used in this project.
