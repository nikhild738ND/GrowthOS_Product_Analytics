# GrowthOS Metric Dictionary

## Executive metrics

### Total sessions

Number of unique GA4 sessions.

### Daily active users

Distinct anonymous users observed within one calendar date.

This metric must not be summed across dates because the same user
can be active on multiple dates.

### Observed session conversion rate

Sessions containing a purchase event divided by total sessions.

### Sequential completion rate

Sessions completing product view, add to cart, checkout, and purchase
in the correct order divided by total sessions.

### Order count

Number of unique transaction IDs after duplicate purchase events
are consolidated.

### Revenue

Transaction-level purchase revenue after duplicate purchase events
are consolidated.

### Average order value

Revenue divided by unique orders.

### Revenue per session

Revenue divided by total sessions.

## Product metrics

### View-item sessions

Distinct sessions containing a view_item event for the product.

### Add-to-cart sessions

Distinct sessions containing an add_to_cart event for the product.

### Same-day view-to-cart rate

Same-day add-to-cart sessions divided by same-day product-view sessions.

### Same-day view-session-to-order rate

Orders on the date divided by product-view sessions on the same date.

This is descriptive and should not be interpreted as a causal
user-level conversion rate.

### Product revenue

Revenue from canonical purchased product lines.

## Acquisition terminology

First-user source and first-user medium represent how the user was
first acquired. They do not necessarily represent the source or medium
of every individual session.