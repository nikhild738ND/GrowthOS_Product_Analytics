# GrowthOS Experiment Design

## Business Problem

GrowthOS funnel analysis identified desktop users as a segment with
meaningful checkout traffic and below-benchmark checkout-to-purchase
conversion.

## Proposed Intervention

Test a simplified checkout experience intended to reduce friction
between checkout initiation and purchase completion.

## Control

Current desktop checkout experience.

## Treatment

Simplified desktop checkout experience.

## Primary Metric

Checkout-to-purchase conversion rate.

Formula:

Purchase sessions / Checkout sessions

## Null Hypothesis

The treatment does not improve checkout-to-purchase conversion.

H0: p_treatment <= p_control

## Alternative Hypothesis

The treatment improves checkout-to-purchase conversion.

H1: p_treatment > p_control

## Significance Level

Alpha = 0.05

## Statistical Power

80%

## Allocation

50% Control
50% Treatment

## Guardrail Metrics

- Average order value
- Revenue per checkout
- Purchase-event tracking quality

## Important Limitation

The public GA4 dataset does not contain a randomized experiment.

Historical GA4 behavior is used only to estimate baseline behavior
and design the experiment.

Any treatment outcomes demonstrated in this project are simulated
and must not be interpreted as observed causal business impact.
