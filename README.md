# Tripla Dynamic Pricing Proxy

## Goal

The upstream dynamic pricing model is computationally expensive. This service acts as a high-performance proxy designed to minimize API calls while maintaining data accuracy.

## Solution

I implemented a centralized caching layer using Redis. This ensures that room rates are cached for the 5-minute validity window, protecting the Rate API from redundant requests.

## Key design considerations

### Cache Key Design

I implemented a granular key strategy using the combination of period, hotel, and room, including a versioning prefix for easy cache clearing if the data schema changes: "pricing:v1:#{@period}:#{@hotel}:#{@room}"

### Cache Duration & Validity

- Expires In: 5 minutes (matching the business constraint for rate validity).
- Race Condition TTL: Set to 10 seconds. This allows the system to serve "stale" data for a very brief window while one process fetches the fresh rate. This prevents a "Cache Stampede" (Thundering Herd) where multiple concurrent requests overload the model during a cache miss.
- Why this over Distributed Locks?
  ** one
  ** two

### Quick Start Guide

Here is a list of common commands for building, running, and interacting with the Dockerized environment.

```bash

# --- 1. Build & Run The Main Application ---
# Build and run the Docker compose
docker compose up -d --build

# --- 2. Test The Endpoint ---
# Send a sample request to your running service
curl 'http://localhost:3000/api/v1/pricing?period=Summer&hotel=FloatingPointResort&room=SingletonRoom'

# --- 3. Run Tests ---
# Run the full test suite
docker compose exec interview-dev ./bin/rails test

# Run a specific test file
docker compose exec interview-dev ./bin/rails test test/controllers/pricing_controller_test.rb

# Run a specific test by name
docker compose exec interview-dev ./bin/rails test test/controllers/pricing_controller_test.rb -n test_should_get_pricing_with_all_parameters
```

Good luck, and we look forward to seeing what you build\!
