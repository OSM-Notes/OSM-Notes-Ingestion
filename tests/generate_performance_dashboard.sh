#!/bin/bash

# Performance Dashboard Generator
# Generates HTML dashboard from benchmark results
# Author: Andres Gomez (AngocA)
# Version: 2026-01-02

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-${SCRIPT_DIR}/benchmark_results}"
BASELINE_FILE="${BASELINE_FILE:-${RESULTS_DIR}/baseline.json}"
OUTPUT_DIR="${OUTPUT_DIR:-${RESULTS_DIR}/dashboard}"
OUTPUT_HTML="${OUTPUT_DIR}/index.html"
OUTPUT_MARKDOWN="${OUTPUT_DIR}/README.md"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

###############################################################################
# Helper Functions
###############################################################################

log_info() {
 echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
 echo -e "${YELLOW}[WARN]${NC} $*"
}

# Check dependencies
check_dependencies() {
 if ! command -v jq > /dev/null 2>&1; then
  log_warn "jq is recommended for better dashboard generation"
 fi
}

# Get latest benchmark value for a test and metric
# Handles both JSONL format (multiple JSON objects separated by newlines)
# and single JSON object/array format
get_latest_value() {
 local test_name="${1}"
 local metric_name="${2}"
 local result_file="${RESULTS_DIR}/${test_name}.json"
 
 if [[ ! -f "${result_file}" ]]; then
  echo ""
  return 0
 fi
 
 if command -v jq > /dev/null 2>&1; then
  # Try to read as JSONL (multiple JSON objects) first
  # If that fails, try as single JSON object or array
  jq -r -s '.[] | select(.metric == "'"${metric_name}"'") | .value' \
   "${result_file}" 2>/dev/null | tail -1 || \
  jq -r 'select(.metric == "'"${metric_name}"'") | .value' \
   "${result_file}" 2>/dev/null | tail -1 || \
  jq -r '.[] | select(.metric == "'"${metric_name}"'") | .value' \
   "${result_file}" 2>/dev/null | tail -1 || echo ""
 else
  # Fallback: use grep and awk
  grep "\"metric\":\"${metric_name}\"" "${result_file}" 2>/dev/null | \
   tail -1 | grep -o '"value":[0-9.]*' | cut -d: -f2 || echo ""
 fi
}

# Get baseline value
get_baseline_value() {
 local test_name="${1}"
 local metric_name="${2}"
 
 if [[ ! -f "${BASELINE_FILE}" ]]; then
  echo ""
  return 0
 fi
 
 if command -v jq > /dev/null 2>&1; then
  jq -r ".[] | select(.test_name == \"${test_name}\" and .metric == \"${metric_name}\") | .value" \
   "${BASELINE_FILE}" 2>/dev/null | tail -1 || echo ""
 else
  grep -A 5 "\"test_name\":\"${test_name}\"" "${BASELINE_FILE}" 2>/dev/null | \
   grep "\"metric\":\"${metric_name}\"" | grep -o '"value":[0-9.]*' | cut -d: -f2 || echo ""
 fi
}

# Calculate percentage change
calculate_percent_change() {
 local baseline="${1}"
 local current="${2}"
 
 if [[ -z "${baseline}" ]] || [[ -z "${current}" ]]; then
  echo "N/A"
  return 0
 fi
 
 if command -v bc > /dev/null 2>&1; then
  if [[ $(echo "${baseline} > 0" | bc -l) -eq 1 ]]; then
   local change
   change=$(echo "scale=2; (${current} - ${baseline}) / ${baseline} * 100" | bc -l)
   echo "${change}"
  else
   echo "N/A"
  fi
 else
  echo "N/A"
 fi
}

# Format value with unit
format_value() {
 local value="${1}"
 local unit="${2:-}"
 
 if [[ -z "${value}" ]] || [[ "${value}" == "N/A" ]]; then
  echo "N/A"
  return 0
 fi
 
 if command -v bc > /dev/null 2>&1; then
  # Format to 4 decimal places if it's a decimal
  if [[ "${value}" =~ \. ]]; then
   value=$(echo "scale=4; ${value}" | bc -l | sed 's/0*$//' | sed 's/\.$//')
  fi
 fi
 
 if [[ -n "${unit}" ]]; then
  echo "${value} ${unit}"
 else
  echo "${value}"
 fi
}

# Get status badge (regression, improvement, stable)
get_status_badge() {
 local percent_change="${1}"
 
 if [[ "${percent_change}" == "N/A" ]]; then
  echo '<span class="badge badge-info">Baseline</span>'
  return 0
 fi
 
 if command -v bc > /dev/null 2>&1; then
  # Check if it's a regression (>10% slower for time metrics, or <-10% for throughput)
  if [[ $(echo "${percent_change} > 10" | bc -l 2>/dev/null || echo "0") -eq 1 ]] || \
     [[ $(echo "${percent_change} < -10" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
   echo '<span class="badge badge-danger">⚠️ Regression</span>'
  elif [[ $(echo "${percent_change} < -5" | bc -l 2>/dev/null || echo "0") -eq 1 ]] || \
       [[ $(echo "${percent_change} > 5" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
   echo '<span class="badge badge-success">✅ Improvement</span>'
  else
   echo '<span class="badge badge-secondary">➡️ Stable</span>'
  fi
 else
  echo '<span class="badge badge-secondary">➡️ Unknown</span>'
 fi
}

# Generate HTML dashboard
generate_html_dashboard() {
 log_info "Generating HTML dashboard..."
 
 mkdir -p "${OUTPUT_DIR}"
 
 # Find all benchmark result files
 local result_files
 result_files=$(find "${RESULTS_DIR}" -name "*.json" -type f ! -name "baseline.json" ! -name "regression_report.json" 2>/dev/null || true)
 
 # Collect all tests and metrics
 declare -A tests_metrics
 local test_names=()
 
 while IFS= read -r result_file; do
  [[ -z "${result_file}" ]] && continue
  local test_name
  test_name=$(basename "${result_file}" .json)
  test_names+=("${test_name}")
  
  # Extract metrics from file
  # Handle both JSONL format (multiple JSON objects) and single JSON object/array
  if command -v jq > /dev/null 2>&1; then
   local metrics
   metrics=$(jq -r -s '.[] | .metric' "${result_file}" 2>/dev/null | sort -u || \
             jq -r '.metric' "${result_file}" 2>/dev/null | sort -u || \
             jq -r '.[] | .metric' "${result_file}" 2>/dev/null | sort -u || true)
   while IFS= read -r metric; do
    [[ -z "${metric}" ]] && continue
    tests_metrics["${test_name}.${metric}"]=1
   done <<< "${metrics}"
  fi
 done <<< "${result_files}"
 
 # Generate HTML
 cat > "${OUTPUT_HTML}" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OSM Notes Ingestion - Performance Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: #f5f5f5;
            color: #333;
            line-height: 1.6;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            margin-bottom: 10px;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        .subtitle {
            color: #7f8c8d;
            margin-bottom: 30px;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .summary-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }
        .summary-card h3 {
            font-size: 14px;
            text-transform: uppercase;
            opacity: 0.9;
            margin-bottom: 10px;
        }
        .summary-card .value {
            font-size: 32px;
            font-weight: bold;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
            background: white;
        }
        th {
            background: #34495e;
            color: white;
            padding: 12px;
            text-align: left;
            font-weight: 600;
        }
        td {
            padding: 10px 12px;
            border-bottom: 1px solid #e0e0e0;
        }
        tr:hover {
            background: #f8f9fa;
        }
        .badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
        }
        .badge-danger { background: #e74c3c; color: white; }
        .badge-success { background: #27ae60; color: white; }
        .badge-secondary { background: #95a5a6; color: white; }
        .badge-info { background: #3498db; color: white; }
        .metric-value {
            font-family: 'Courier New', monospace;
            font-weight: 600;
        }
        .change-positive { color: #e74c3c; }
        .change-negative { color: #27ae60; }
        .change-neutral { color: #7f8c8d; }
        footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #e0e0e0;
            text-align: center;
            color: #7f8c8d;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Performance Dashboard</h1>
        <p class="subtitle">OSM Notes Ingestion - Benchmark Results</p>
        
        <div class="summary">
            <div class="summary-card">
                <h3>Total Tests</h3>
                <div class="value" id="total-tests">-</div>
            </div>
            <div class="summary-card" style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);">
                <h3>Regressions</h3>
                <div class="value" id="regressions">-</div>
            </div>
            <div class="summary-card" style="background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);">
                <h3>Improvements</h3>
                <div class="value" id="improvements">-</div>
            </div>
            <div class="summary-card" style="background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);">
                <h3>Stable</h3>
                <div class="value" id="stable">-</div>
            </div>
        </div>
        
        <h2>Benchmark Results</h2>
        <table>
            <thead>
                <tr>
                    <th>Test</th>
                    <th>Metric</th>
                    <th>Current Value</th>
                    <th>Baseline Value</th>
                    <th>Change</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody id="results-table">
EOF

 # Generate table rows
 local total_tests=0
 local regressions=0
 local improvements=0
 local stable=0
 
 for test_metric in "${!tests_metrics[@]}"; do
  local test_name metric_name
  test_name=$(echo "${test_metric}" | cut -d'.' -f1)
  metric_name=$(echo "${test_metric}" | cut -d'.' -f2-)
  
  local current_value baseline_value
  current_value=$(get_latest_value "${test_name}" "${metric_name}")
  baseline_value=$(get_baseline_value "${test_name}" "${metric_name}")
  
  if [[ -z "${current_value}" ]]; then
   continue
  fi
  
  total_tests=$((total_tests + 1))
  
  # Get unit from result file
  # Handle both JSONL format (multiple JSON objects) and single JSON object/array
  local unit
  if command -v jq > /dev/null 2>&1; then
   unit=$(jq -r -s '.[] | select(.metric == "'"${metric_name}"'") | .unit' \
    "${RESULTS_DIR}/${test_name}.json" 2>/dev/null | tail -1 || \
    jq -r "select(.metric == \"${metric_name}\") | .unit" \
    "${RESULTS_DIR}/${test_name}.json" 2>/dev/null | tail -1 || \
    jq -r '.[] | select(.metric == "'"${metric_name}"'") | .unit' \
    "${RESULTS_DIR}/${test_name}.json" 2>/dev/null | tail -1 || echo "")
  fi
  
  # Calculate change
  local percent_change
  percent_change=$(calculate_percent_change "${baseline_value}" "${current_value}")
  
  # Determine status
  local status_badge
  status_badge=$(get_status_badge "${percent_change}")
  
  # Determine change class
  local change_class="change-neutral"
  if [[ "${percent_change}" != "N/A" ]] && command -v bc > /dev/null 2>&1; then
   if [[ $(echo "${percent_change} > 10" | bc -l 2>/dev/null || echo "0") -eq 1 ]] || \
      [[ $(echo "${percent_change} < -10" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
    change_class="change-positive"
    regressions=$((regressions + 1))
   elif [[ $(echo "${percent_change} < -5" | bc -l 2>/dev/null || echo "0") -eq 1 ]] || \
        [[ $(echo "${percent_change} > 5" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
    change_class="change-negative"
    improvements=$((improvements + 1))
   else
    stable=$((stable + 1))
   fi
  else
   stable=$((stable + 1))
  fi
  
  # Format values
  local current_formatted baseline_formatted change_formatted
  current_formatted=$(format_value "${current_value}" "${unit}")
  baseline_formatted=$(format_value "${baseline_value}" "${unit}")
  
  if [[ "${percent_change}" == "N/A" ]]; then
   change_formatted="N/A"
  else
   if command -v bc > /dev/null 2>&1; then
    local abs_change
    abs_change=$(echo "scale=2; ${percent_change}" | bc -l | sed 's/^-//')
    if [[ $(echo "${percent_change} > 0" | bc -l) -eq 1 ]]; then
     change_formatted="+${abs_change}%"
    else
     change_formatted="-${abs_change}%"
    fi
   else
    change_formatted="${percent_change}%"
   fi
  fi
  
  # Write row
  cat >> "${OUTPUT_HTML}" << EOF
                <tr>
                    <td><strong>${test_name}</strong></td>
                    <td>${metric_name}</td>
                    <td class="metric-value">${current_formatted}</td>
                    <td class="metric-value">${baseline_formatted}</td>
                    <td class="${change_class}"><strong>${change_formatted}</strong></td>
                    <td>${status_badge}</td>
                </tr>
EOF
 done
 
 # Close HTML
 cat >> "${OUTPUT_HTML}" << EOF
            </tbody>
        </table>
        
        <footer>
            <p>Generated on $(date '+%Y-%m-%d %H:%M:%S UTC')</p>
            <p>OSM Notes Ingestion - Performance Monitoring</p>
        </footer>
    </div>
    
    <script>
        // Update summary cards
        document.getElementById('total-tests').textContent = '${total_tests}';
        document.getElementById('regressions').textContent = '${regressions}';
        document.getElementById('improvements').textContent = '${improvements}';
        document.getElementById('stable').textContent = '${stable}';
    </script>
</body>
</html>
EOF
 
 log_info "HTML dashboard generated: ${OUTPUT_HTML}"
}

# Generate Markdown report
generate_markdown_report() {
 log_info "Generating Markdown report..."
 
 mkdir -p "${OUTPUT_DIR}"
 
 # Find all benchmark result files
 local result_files
 result_files=$(find "${RESULTS_DIR}" -name "*.json" -type f ! -name "baseline.json" ! -name "regression_report.json" 2>/dev/null || true)
 
 # Collect all tests and metrics
 declare -A tests_metrics
 local test_names=()
 
 while IFS= read -r result_file; do
  [[ -z "${result_file}" ]] && continue
  local test_name
  test_name=$(basename "${result_file}" .json)
  test_names+=("${test_name}")
  
  # Extract metrics from file
  # Handle both JSONL format (multiple JSON objects) and single JSON object/array
  if command -v jq > /dev/null 2>&1; then
   local metrics
   metrics=$(jq -r -s '.[] | .metric' "${result_file}" 2>/dev/null | sort -u || \
             jq -r '.metric' "${result_file}" 2>/dev/null | sort -u || \
             jq -r '.[] | .metric' "${result_file}" 2>/dev/null | sort -u || true)
   while IFS= read -r metric; do
    [[ -z "${metric}" ]] && continue
    tests_metrics["${test_name}.${metric}"]=1
   done <<< "${metrics}"
  fi
 done <<< "${result_files}"
 
 # Generate Markdown
 cat > "${OUTPUT_MARKDOWN}" << EOF
# Performance Dashboard

**Generated:** $(date '+%Y-%m-%d %H:%M:%S UTC')

## Summary

EOF

 # Calculate summary
 local total_tests=0
 local regressions=0
 local improvements=0
 local stable=0
 
 for test_metric in "${!tests_metrics[@]}"; do
  local test_name metric_name
  test_name=$(echo "${test_metric}" | cut -d'.' -f1)
  metric_name=$(echo "${test_metric}" | cut -d'.' -f2-)
  
  local current_value baseline_value
  current_value=$(get_latest_value "${test_name}" "${metric_name}")
  
  if [[ -z "${current_value}" ]]; then
   continue
  fi
  
  total_tests=$((total_tests + 1))
  
  baseline_value=$(get_baseline_value "${test_name}" "${metric_name}")
  local percent_change
  percent_change=$(calculate_percent_change "${baseline_value}" "${current_value}")
  
  if [[ "${percent_change}" != "N/A" ]] && command -v bc > /dev/null 2>&1; then
   if [[ $(echo "${percent_change} > 10" | bc -l 2>/dev/null || echo "0") -eq 1 ]] || \
      [[ $(echo "${percent_change} < -10" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
    regressions=$((regressions + 1))
   elif [[ $(echo "${percent_change} < -5" | bc -l 2>/dev/null || echo "0") -eq 1 ]] || \
        [[ $(echo "${percent_change} > 5" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
    improvements=$((improvements + 1))
   else
    stable=$((stable + 1))
   fi
  else
   stable=$((stable + 1))
  fi
 done
 
 cat >> "${OUTPUT_MARKDOWN}" << EOF
- **Total Tests:** ${total_tests}
- **Regressions:** ${regressions}
- **Improvements:** ${improvements}
- **Stable:** ${stable}

## Benchmark Results

| Test | Metric | Current Value | Baseline Value | Change | Status |
|------|--------|--------------|----------------|--------|--------|
EOF

 # Generate table rows
 for test_metric in "${!tests_metrics[@]}"; do
  local test_name metric_name
  test_name=$(echo "${test_metric}" | cut -d'.' -f1)
  metric_name=$(echo "${test_metric}" | cut -d'.' -f2-)
  
  local current_value baseline_value
  current_value=$(get_latest_value "${test_name}" "${metric_name}")
  baseline_value=$(get_baseline_value "${test_name}" "${metric_name}")
  
  if [[ -z "${current_value}" ]]; then
   continue
  fi
  
  # Get unit
  local unit
  if command -v jq > /dev/null 2>&1; then
   unit=$(jq -r "select(.metric == \"${metric_name}\") | .unit" \
    "${RESULTS_DIR}/${test_name}.json" 2>/dev/null | tail -1 || echo "")
  fi
  
  # Calculate change
  local percent_change
  percent_change=$(calculate_percent_change "${baseline_value}" "${current_value}")
  
  # Format values
  local current_formatted baseline_formatted change_formatted status_badge
  current_formatted=$(format_value "${current_value}" "${unit}")
  baseline_formatted=$(format_value "${baseline_value}" "${unit}")
  
  if [[ "${percent_change}" == "N/A" ]]; then
   change_formatted="N/A"
   status_badge="📊 Baseline"
  else
   if command -v bc > /dev/null 2>&1; then
    local abs_change
    abs_change=$(echo "scale=2; ${percent_change}" | bc -l | sed 's/^-//')
    if [[ $(echo "${percent_change} > 10" | bc -l 2>/dev/null || echo "0") -eq 1 ]] || \
       [[ $(echo "${percent_change} < -10" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
     change_formatted="**+${abs_change}%**"
     status_badge="⚠️ Regression"
    elif [[ $(echo "${percent_change} < -5" | bc -l 2>/dev/null || echo "0") -eq 1 ]] || \
         [[ $(echo "${percent_change} > 5" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
     if [[ $(echo "${percent_change} > 0" | bc -l) -eq 1 ]]; then
      change_formatted="+${abs_change}%"
     else
      change_formatted="-${abs_change}%"
     fi
     status_badge="✅ Improvement"
    else
     if [[ $(echo "${percent_change} > 0" | bc -l) -eq 1 ]]; then
      change_formatted="+${abs_change}%"
     else
      change_formatted="-${abs_change}%"
     fi
     status_badge="➡️ Stable"
    fi
   else
    change_formatted="${percent_change}%"
    status_badge="➡️ Unknown"
   fi
  fi
  
  # Write row
  cat >> "${OUTPUT_MARKDOWN}" << EOF
| ${test_name} | ${metric_name} | ${current_formatted} | ${baseline_formatted} | ${change_formatted} | ${status_badge} |
EOF
 done
 
 cat >> "${OUTPUT_MARKDOWN}" << EOF

## Notes

- **Regressions:** Performance degraded by >10%
- **Improvements:** Performance improved by >5%
- **Stable:** Performance change within ±10%

For detailed analysis, see \`regression_report.json\` in the benchmark results directory.
EOF
 
 log_info "Markdown report generated: ${OUTPUT_MARKDOWN}"
}

###############################################################################
# Main
###############################################################################

main() {
 log_info "Generating performance dashboard..."
 
 check_dependencies
 
 # Check if results directory exists
 if [[ ! -d "${RESULTS_DIR}" ]]; then
  log_warn "Results directory not found: ${RESULTS_DIR}"
  log_info "Creating directory..."
  mkdir -p "${RESULTS_DIR}"
 fi
 
 # Generate both HTML and Markdown
 generate_html_dashboard
 generate_markdown_report
 
 log_info "Dashboard generation complete!"
 log_info "HTML: ${OUTPUT_HTML}"
 log_info "Markdown: ${OUTPUT_MARKDOWN}"
}

main "$@"

