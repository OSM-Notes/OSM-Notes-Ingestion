# Benchmark Results Directory

**Purpose:** Store performance benchmark results for version comparison

**Author:** Andres Gomez (AngocA)  
**Version:** 2025-12-15

## Overview

This directory stores JSON files containing performance benchmark results. Each benchmark test generates a JSON file with metrics that can be compared across versions.

## File Format

Each benchmark result file (`{test_name}.json`) contains JSON entries with the following structure:

```json
{
  "test_name": "xml_validation",
  "metric": "validation_time",
  "value": 0.123,
  "unit": "seconds",
  "timestamp": "2025-12-15T10:30:00",
  "version": "2025-12-15"
}
```

## Metrics Collected

### XML Processing
- `validation_time`: Time to validate XML files (seconds)
- `parse_time`: Time to parse XML files (seconds)
- `throughput`: Notes processed per second

### Database Operations
- `query_time`: Time to execute SELECT queries (seconds)
- `insert_time`: Time to execute INSERT operations (seconds)
- `insert_throughput`: Inserts per second

### File I/O
- `read_time`: Time to read files (seconds)
- `write_time`: Time to write files (seconds)
- `read_throughput`: Read speed in MB/s
- `write_throughput`: Write speed in MB/s

### Memory Usage
- `initial_memory`: Initial memory usage (KB)
- `peak_memory`: Peak memory usage (KB)
- `memory_increase`: Memory increase during processing (KB)

### Parallel Processing
- `parallel_time`: Time for parallel operations (seconds)
- `throughput`: Jobs per second

### String Processing
- `process_time`: Time to process strings (seconds)
- `throughput`: Strings processed per second

### Network Operations
- `network_time`: Time for network requests (seconds)

## Version Comparison

The benchmark suite automatically compares current results with previous versions:

- **baseline**: First run (no previous data)
- **improvement**: Performance improved (lower time or higher throughput)
- **regression**: Performance degraded (higher time or lower throughput)
- **stable**: Performance unchanged

## Usage

### Running Benchmarks

```bash
# Run all benchmarks
bats tests/unit/bash/performance_benchmarks.test.bats

# Run specific benchmark
bats tests/unit/bash/performance_benchmarks.test.bats -f "BENCHMARK: XML validation performance"
```

### Viewing Results

```bash
# List all benchmark results
ls -lh tests/benchmark_results/

# View specific benchmark results
cat tests/benchmark_results/xml_validation.json | jq .

# Compare versions
jq -s 'group_by(.version) | .[] | {version: .[0].version, metrics: .}' tests/benchmark_results/xml_validation.json
```

### Analyzing Trends

```bash
# Extract all validation_time metrics
jq -r 'select(.metric == "validation_time") | "\(.version) \(.value)"' tests/benchmark_results/xml_validation.json | sort
```

## Best Practices

1. **Run benchmarks regularly**: After significant changes to identify performance regressions
2. **Compare versions**: Use the built-in comparison to track performance trends
3. **Document changes**: When performance changes significantly, document the reason
4. **Baseline establishment**: Run benchmarks on a clean system for accurate baselines

## Notes

- Results are stored in JSON format for easy parsing and comparison
- Each test run appends to the result file (does not overwrite)
- Results include timestamp and version for tracking
- The directory is gitignored by default to avoid committing benchmark data

