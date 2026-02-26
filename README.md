# Tripla Dynamic Pricing Proxy

## Goal

The upstream dynamic pricing model is computationally expensive. This service introduces a caching layer to reduce redundant calls while maintaining rate validity.

## Solution

I implemented a centralized caching layer using Redis. This ensures that room rates are cached for the 5-minute validity window, protecting the Rate API from redundant requests.

## Cache design considerations

### Cache Key Design

I implemented a granular key strategy using the combination of period, hotel, and room, including a versioning prefix for easy cache clearing if the data schema changes: "pricing:v1:#{@period}:#{@hotel}:#{@room}"

### Cache Duration & Validity

- Expires In: 5 minutes (matching the business constraint for rate validity).
- Race Condition TTL: Set to 10 seconds. This allows the system to serve "stale" data for a very brief window while one process fetches the fresh rate. This prevents a "Cache Stampede" (Thundering Herd) where multiple concurrent requests overload the model during a cache miss. The 10-second stale window is negligible for hotel pricing but provides significant system stability. In the future, this value could be tuned based on observed traffic patterns.
- Why this over Distributed Locks?
  - race_condition_ttl sufficiently mitigates the use case.
  - improves availability without introducing distributed coordination complexity
  - simpler implementation, which improves reliability

### Handling Null Values

The service uses skip_nil: true. We do not cache empty or null results. This ensures that if the Rate API has a momentary failure or data gap, the system can retry immediately rather than locking in a "not found" error for 5 minutes.

## Infrastructure: Redis vs. MemoryStore

I evaluated Rails' built-in MemoryStore vs. a standalone Redis instance.
| Feature | MemoryStore (Local in-Memory) | Redis (Distributed cache) |
|---|---|---|
| Complexity | Low | High (new distributed component to handle) |
| Scalability | Poor(cache local to each server) | Excellent (central cache for all server) |
| Efficiency | Higher Rate API load (Cache misses per node) | Lower Rate API load (Global cache hits) |
| Consistency | Risk of different nodes showing different prices | High consistency across |

Conclusion: For the specific goal of preserving Rate API compute resources, Redis is the clear winner. It ensures that regardless of how many web servers we scale to, we only hit the model once every 5 minutes per unique request. Furthermore it's futureproof as the system scales and grows

## Implementation highlight

- Network resilient: added explicit timeouts and rescued network errors to prevent the service from hanging.
- Error handling and messages: Refined error handling to return descriptive messages and accurate HTTP status codes (e.g., 503 Service Unavailable for timeouts vs. 400 Bad Request for invalid input).
- Testing: Comprehensive tests covering cache behavior and network failures.

## Future Improvements

- Proactive Cache Warming: For "hot" hotels or peak seasons, we could implement a background worker to refresh the cache before it expires. This would result in 0ms wait times for users while maintaining 100% cache hit rates.
- Observability: Implement telemetry to track Cache Hit/Miss ratios. This data would allow us to optimize the TTL and identify patterns in user search behavior to further refine the pricing strategy.

## AI Assistant Usage

As part of my standard development workflow, I utilized Gemini (Google's LLM) to assist in the development of this project.

- Architecture & Design: I used the assistant to brainstorm the trade-offs between different caching strategies (Redis vs. In-Memory) and to refine the error-handling logic for upstream API failures.
- Testing: The assistant helped generate the boilerplate for the unit, which I then customized to cover specific edge cases like race_condition_ttl behavior.
- Documentation: It helped me refine this document and make it more articulate.

## Quick Start Guide

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
