# XSLT Performance Profiling Guide

## Overview

This guide explains how to use the XSLT performance profiling functionality to analyze and optimize XSLT transformations in the OSM-Notes-profile project.

## What is XSLT Profiling?

XSLT profiling provides detailed performance metrics for XSLT transformations, including:
- **Execution time** for each template
- **Number of calls** to each template
- **Memory usage** patterns
- **Performance bottlenecks** identification

## Configuration

### Enable Profiling

Set the environment variable to enable profiling:

```bash
export ENABLE_XSLT_PROFILING=true
```

Or modify `etc/properties.sh`:

```bash
declare -r ENABLE_XSLT_PROFILING="true"
```

### Profile File Location

When profiling is enabled, profile files are saved with `.profile` extension:
- `output.csv.profile` - Performance data for the transformation
- Contains detailed timing information for analysis

## Usage Examples

### 1. Process XML with Profiling

```bash
# Enable profiling globally
export ENABLE_XSLT_PROFILING=true

# Run normal processing (profiling will be automatic)
./processAPINotes.sh
./processPlanetNotes.sh
```

### 2. Use the Profile Analyzer Script

```bash
# Analyze a single profile file
bin/xslt_profile_analyzer.sh analyze output.csv.profile

# Generate detailed analysis
bin/xslt_profile_analyzer.sh analyze output.csv.profile detailed

# Generate CSV format for data analysis
bin/xslt_profile_analyzer.sh analyze output.csv.profile csv
```

### 3. Generate Performance Reports

```bash
# Generate report from all profiles in a directory
bin/xslt_profile_analyzer.sh report /tmp/profiles/ performance_report.txt

# Display report on console
bin/xslt_profile_analyzer.sh report /tmp/profiles/
```

### 4. Process Specific Files with Profiling

```bash
# Process a single XML file with profiling
bin/xslt_profile_analyzer.sh enable input.xml transform.xslt

# Specify output file
bin/xslt_profile_analyzer.sh enable input.xml transform.xslt output.csv
```

### 5. Compare Performance Between Runs

```bash
# Compare two processing directories
bin/xslt_profile_analyzer.sh compare /tmp/run1/ /tmp/run2/
```

## Understanding Profile Output

### Profile File Format

Profile files contain lines like:
```
    1      1234      1234  template_name
    |       |         |     |
    |       |         |     └── Template name
    |       |         └──────── Time per call (ms)
    |       └────────────────── Total time (ms)
    └────────────────────────── Number of calls
```

### Analysis Output

#### Summary Format
```
=== XSLT PERFORMANCE PROFILE SUMMARY ===
Total processing time: 1.234s
Templates executed: 15
Slowest template: process_note (0.456s)
Average time per template: 0.082s
```

#### Detailed Format
```
=== XSLT PERFORMANCE PROFILE DETAILED ===
Total processing time: 1.234s
Templates executed: 15
Slowest template: process_note (0.456s)
Profile file: output.csv.profile
Use 'cat output.csv.profile' for full details
```

#### CSV Format
```csv
total_time,template_count,slowest_template,slowest_time
1.234,15,"process_note",0.456
```

## Optimization Strategies

### 1. Identify Slow Templates

Look for templates with high execution times:
```bash
bin/xslt_profile_analyzer.sh analyze output.csv.profile detailed
```

### 2. Analyze Call Patterns

Check for templates called excessively:
```bash
cat output.csv.profile | sort -k2 -nr | head -10
```

### 3. Compare Before/After

```bash
# Before optimization
export ENABLE_XSLT_PROFILING=true
./processAPINotes.sh
mv /tmp/profiles/ /tmp/before/

# After optimization
./processAPINotes.sh
mv /tmp/profiles/ /tmp/after/

# Compare results
bin/xslt_profile_analyzer.sh compare /tmp/before/ /tmp/after/
```

## Integration with Existing Workflows

### Automatic Profiling

When `ENABLE_XSLT_PROFILING=true`:
- All XSLT transformations automatically generate profile files
- No changes needed to existing scripts
- Profile files are saved alongside output files

### Selective Profiling

For specific analysis:
```bash
# Enable profiling for one run
ENABLE_XSLT_PROFILING=true ./processAPINotes.sh

# Disable for normal operation
unset ENABLE_XSLT_PROFILING
./processAPINotes.sh
```

## Best Practices

### 1. Use Profiling During Development

```bash
# Enable profiling when testing XSLT changes
export ENABLE_XSLT_PROFILING=true
./processAPINotes.sh

# Analyze results
bin/xslt_profile_analyzer.sh analyze output.csv.profile
```

### 2. Monitor Performance Trends

```bash
# Generate reports for tracking
bin/xslt_profile_analyzer.sh report /tmp/profiles/ $(date +%Y%m%d)_performance.txt
```

### 3. Optimize Iteratively

1. Run with profiling enabled
2. Identify slowest templates
3. Optimize XSLT code
4. Re-run and compare
5. Repeat until performance targets are met

## Troubleshooting

### Common Issues

#### Profile Files Not Generated
- Check `ENABLE_XSLT_PROFILING` is set to `true`
- Verify `xsltproc --profile` is available
- Check file permissions for output directory

#### Analysis Script Errors
- Ensure all required functions are sourced
- Check profile file format is correct
- Verify `bc` command is available for calculations

#### Performance Degradation
- Profiling adds minimal overhead (~2-5%)
- Disable profiling in production if needed
- Use profiling only for analysis runs

### Debug Commands

```bash
# Check if profiling is enabled
echo "ENABLE_XSLT_PROFILING: ${ENABLE_XSLT_PROFILING:-false}"

# Verify xsltproc supports profiling
xsltproc --help | grep profile

# Test profile generation manually
xsltproc --profile test.profile transform.xslt input.xml
```

## Advanced Usage

### Custom Analysis Scripts

```bash
#!/bin/bash
# Custom profile analysis
source bin/parallelProcessingFunctions.sh

# Analyze multiple profiles
for profile in *.profile; do
  echo "=== $profile ==="
  __analyze_xslt_profile "$profile" "summary"
done
```

### Integration with CI/CD

```bash
# Add profiling to CI pipeline
export ENABLE_XSLT_PROFILING=true
./processAPINotes.sh

# Generate performance report
bin/xslt_profile_analyzer.sh report /tmp/profiles/ ci_performance_report.txt

# Fail if performance degrades
if grep -q "Total processing time: [0-9]\{2,\}" ci_performance_report.txt; then
  echo "Performance degradation detected"
  exit 1
fi
```

## Conclusion

XSLT profiling provides valuable insights for optimizing transformation performance. Use it during development and testing to identify bottlenecks and measure improvements. The integrated tools make it easy to analyze performance and track optimization progress.

For more information, see the main project documentation and the `bin/xslt_profile_analyzer.sh` script help.

