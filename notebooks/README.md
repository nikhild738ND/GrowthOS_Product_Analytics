# GrowthOS Experiment Lab

This notebook implements the experimentation and statistical decision layer for the GrowthOS analytics project.

## What it includes

- Historical checkout-to-purchase baseline estimation
- Device-level experiment targeting
- Minimum detectable effect scenarios
- Statistical power and sample-size calculations
- Experiment duration estimates using observed eligible traffic
- Simulated A/B test outcomes
- Two-proportion z-test
- 95% confidence interval
- Modeled incremental conversion and revenue impact
- Experiment decision framework
- Guardrail metrics
- Sample ratio mismatch considerations
- Experiment limitations

## Selected Experiment Segment

Desktop users were selected because they had the highest checkout traffic and the lowest checkout-to-purchase conversion among the observed device segments.

## Important Limitation

The public GA4 dataset does not contain a real randomized experiment.

Historical GA4 behavior is used to establish baseline behavior and experiment feasibility.

Treatment outcomes in the notebook are simulated and must not be interpreted as observed causal business impact.
