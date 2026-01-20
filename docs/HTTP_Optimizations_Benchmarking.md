# HTTP Optimizations Benchmarking Guide

## Overview

This guide explains how to test and measure the performance improvements from HTTP optimizations
(keep-alive, HTTP/2, compression, conditional caching).

**Version:** 2025-12-20

## Quick Start

### Run Automated Benchmarks

```bash
# Run benchmark script
./bin/scripts/benchmark_http_optimizations.sh

# With custom iterations
./bin/scripts/benchmark_http_optimizations.sh --iterations 10

# Custom output directory
./bin/scripts/benchmark_http_optimizations.sh --output-dir ./my_results
```

### Run BATS Tests

```bash
# Run HTTP optimization tests
bats tests/unit/bash/http_optimizations.test.bats

# Run benchmark tests (requires network access)
bats tests/unit/bash/http_optimizations_benchmark.test.bats
```

## Test Suites

### 1. Unit Tests (`http_optimizations.test.bats`)

Tests the functionality of HTTP optimizations:

- **HTTP Keep-Alive**: Verifies keep-alive headers are sent
- **HTTP/2 Support**: Tests HTTP/2 detection and fallback
- **Compression**: Verifies compression is requested
- **Conditional Caching**: Tests If-Modified-Since header
- **Configuration**: Tests enable/disable options
- **Error Handling**: Tests graceful error handling
- **Compatibility**: Ensures backward compatibility

**Note:** Some tests require network access and are skipped if unavailable.

### 2. Benchmark Tests (`http_optimizations_benchmark.test.bats`)

Performance comparison tests:

- **OSM API Performance**: Compares with/without optimizations
- **Overpass API Performance**: Compares with/without optimizations
- **Conditional Caching**: Measures 304 response performance
- **Connection Reuse**: Tests multiple sequential requests

**Note:** These tests require network access to OSM/Overpass APIs.

### 3. Benchmark Script (`benchmark_http_optimizations.sh`)

Standalone script for detailed performance analysis:

- Runs multiple iterations for statistical accuracy
- Generates JSON results for analysis
- Compares with/without optimizations
- Tests connection reuse with multiple requests

## Metrics Collected

### Time Metrics

- **`osm_api_time_with`**: OSM API request time with optimizations (seconds)
- **`osm_api_time_without`**: OSM API request time without optimizations (seconds)
- **`overpass_api_time_with`**: Overpass API request time with optimizations (seconds)
- **`overpass_api_time_without`**: Overpass API request time without optimizations (seconds)
- **`multiple_requests_time_with`**: Time for multiple requests with optimizations (seconds)
- **`multiple_requests_time_without`**: Time for multiple requests without optimizations (seconds)

### Improvement Metrics

- **`osm_api_improvement_percent`**: Percentage improvement for OSM API
- **`overpass_api_improvement_percent`**: Percentage improvement for Overpass API
- **`connection_reuse_improvement_percent`**: Improvement from connection reuse
- **`conditional_cache_improvement_percent`**: Improvement from conditional caching

### Success Metrics

- **`success_count`**: Number of successful requests
- **`total_time`**: Total time for all iterations

## Expected Results

### Single Request Performance

**Typical improvements:**

- **Connection reuse**: 50-200ms saved per request
- **HTTP/2**: 10-30% improvement on high-latency connections
- **Compression**: 60-80% bandwidth reduction
- **Total improvement**: 10-40% faster

**Example:**

```
With optimizations:    0.300s
Without optimizations: 0.500s
Improvement:           40%
```

### Multiple Requests (Connection Reuse)

**Typical improvements:**

- **First request**: Same as single request (connection setup)
- **Subsequent requests**: 50-200ms saved per request (no connection setup)
- **Total improvement**: 20-50% for 5+ requests

**Example (5 requests):**

```
With optimizations:    1.200s
Without optimizations: 2.000s
Improvement:           40%
```

### Conditional Caching (304 Response)

**Typical improvements:**

- **Full download**: 300-500ms
- **304 response**: 50-100ms
- **Improvement**: 80-90% when no changes

**Example:**

```
First request:         0.400s
Conditional request:   0.080s
Improvement:           80%
```

## Interpreting Results

### JSON Results Format

Results are stored in JSON format:

```json
{
  "test_name": "http_optimizations",
  "metric": "osm_api_time_with",
  "value": 0.3,
  "unit": "seconds",
  "timestamp": "2025-12-20T10:30:00",
  "version": "2025-12-20"
}
```

### Analyzing Results

1. **View results:**

   ```bash
   cat benchmark_results/http_optimizations_benchmark_*.json | jq '.'
   ```

2. **Compare metrics:**

   ```bash
   # Extract specific metric
   jq 'select(.metric == "osm_api_improvement_percent")' \
     benchmark_results/http_optimizations_benchmark_*.json
   ```

3. **Calculate averages:**
   ```bash
   # Average improvement across runs
   jq -s 'map(select(.metric == "osm_api_improvement_percent") | .value) |
          add / length' \
     benchmark_results/http_optimizations_benchmark_*.json
   ```

## Factors Affecting Results

### Network Conditions

- **Latency**: Higher latency = larger improvement from connection reuse
- **Bandwidth**: Lower bandwidth = larger improvement from compression
- **Stability**: Unstable connections may show variable results

### Server Configuration

- **HTTP/2 Support**: Only improves if server supports HTTP/2
- **Compression**: Only improves if server supports compression
- **Conditional Requests**: Only improves if server supports If-Modified-Since

### Test Environment

- **Location**: Distance to servers affects latency
- **Time of Day**: Network congestion varies
- **Iterations**: More iterations = more accurate results

## Troubleshooting

### Tests Skipped

If tests are skipped:

- Check network connectivity
- Verify OSM/Overpass APIs are accessible
- Check if curl supports HTTP/2: `curl --version`

### No Improvement Detected

If no improvement is detected:

- Verify optimizations are enabled: `echo $ENABLE_HTTP_OPTIMIZATIONS`
- Check if server supports optimizations
- Run more iterations for statistical accuracy
- Check network conditions (may be too fast to measure)

### Negative Improvement

If results show negative improvement (slower with optimizations):

- May be within measurement variance
- Run more iterations
- Check for network issues during test
- Verify test configuration

## Best Practices

### Running Benchmarks

1. **Run multiple iterations** (default: 5, recommended: 10+)
2. **Run at different times** to account for network variance
3. **Compare against baseline** from previous versions
4. **Document environment** (location, network, time)

### Interpreting Results

1. **Look for trends** across multiple runs
2. **Consider variance** - single runs may vary
3. **Focus on averages** - outliers may be network issues
4. **Compare similar conditions** - same time, same network

### Reporting Results

Include in reports:

- Number of iterations
- Average improvement percentage
- Network conditions (if known)
- Server capabilities (HTTP/2, compression support)
- Test environment details

## Continuous Monitoring

### Automated Benchmarking

Add to CI/CD pipeline:

```bash
# Run benchmarks in CI
./bin/scripts/benchmark_http_optimizations.sh --iterations 3 \
  --output-dir ./ci_benchmarks

# Compare with baseline
# (implement comparison logic)
```

### Tracking Over Time

Store results with version tags:

```bash
# Run benchmark
VERSION=$(git describe --tags) \
  ./bin/scripts/benchmark_http_optimizations.sh

# Results include version for comparison
```

## References

- [HTTP Optimizations Documentation](./HTTP_Optimizations.md)
- [Performance Benchmarks](../tests/unit/bash/performance_benchmarks.test.bats)
- [Benchmark Results Format](../tests/benchmark_results/README.md)

## Author

Andres Gomez (AngocA) OSM-LatAm, OSM-Colombia, MaptimeBogota
