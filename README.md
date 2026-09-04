# GrowthOS_Product_Analytics
Production style GA4 product analytics and experimentation platform built with BigQuery, dbt, and Tableau.

## Experimentation and Statistical Decision Lab

The GrowthOS project includes an experimentation layer for designing and evaluating a proposed desktop checkout optimization.

### Experiment Target

Desktop was selected as the experiment segment because it had the highest observed checkout traffic and the lowest checkout-to-purchase conversion among device categories.

### Baseline

- Desktop checkout sessions: 3,109
- Desktop purchase sessions: 1,601
- Desktop checkout-to-purchase conversion: 51.50%
- Overall checkout-to-purchase conversion: 52.33%

### Experiment Design

- Control: current desktop checkout experience
- Treatment: simplified desktop checkout experience
- Primary metric: checkout-to-purchase conversion
- Allocation: 50/50
- Significance level: 5%
- Statistical power: 80%

### Sample Size Scenarios

| Relative Lift | Sample Size per Variant | Total Sample Size | Estimated Duration |
|---|---:|---:|---:|
| 5% | 4,648 | 9,296 | 276 days |
| 10% | 1,157 | 2,314 | 69 days |
| 15% | 512 | 1,024 | 31 days |

### Simulated Experiment Result

For the 10% relative-lift scenario:

- Observed control conversion: 52.72%
- Observed treatment conversion: 59.12%
- Absolute lift: 6.40 percentage points
- Relative lift: 12.13%
- One-sided p-value: 0.0010
- 95% confidence interval: 2.36% to 10.43%
- Modeled incremental conversions: 74
- Modeled incremental revenue: $5,170.09

### Experiment Artifacts

- `docs/experiment_design.md`
- `docs/experiment_recommendation.md`
- `notebooks/GrowthOS_Experiment_Lab.ipynb`
- `notebooks/README.md`

### Important Limitation

The public GA4 dataset does not contain a real randomized experiment.

Historical behavior is used to establish the baseline and estimate experiment feasibility. Treatment outcomes, statistical significance, confidence intervals, and modeled revenue impact are simulated and must not be interpreted as observed causal business impact.
