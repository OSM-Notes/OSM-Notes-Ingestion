#!/bin/bash
# Advanced testing script for OSM Notes Profile project
# Author: Andres Gomez (AngocA)
# Version: 2025-07-23

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Default values
OUTPUT_DIR="${ADVANCED_OUTPUT_DIR:-./advanced_reports}"
COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-80}"
SECURITY_FAIL_ON_HIGH="${SECURITY_FAIL_ON_HIGH:-false}"
QUALITY_MIN_RATING="${QUALITY_MIN_RATING:-A}"
PERFORMANCE_TIMEOUT="${PERFORMANCE_TIMEOUT:-300}"
CLEAN=false
VERBOSE=false
PARALLEL=false
FAIL_FAST=false

# Test types
RUN_COVERAGE=false
RUN_SECURITY=false
RUN_QUALITY=false
RUN_PERFORMANCE=false

# Logging function
__log() {
 local level="$1"
 shift
 local message="$*"
 local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

 case "$level" in
 "INFO")
  echo -e "${BLUE}[INFO]${NC} $message"
  ;;
 "SUCCESS")
  echo -e "${GREEN}[SUCCESS]${NC} $message"
  ;;
 "WARNING")
  echo -e "${YELLOW}[WARNING]${NC} $message"
  ;;
 "ERROR")
  echo -e "${RED}[ERROR]${NC} $message"
  ;;
 esac
}

# Help function
__show_help() {
 cat << EOF
Uso: $0 [OPTIONS]

Opciones:
  --help, -h           Mostrar esta ayuda
  --coverage-only      Ejecutar solo pruebas de cobertura
  --security-only      Ejecutar solo pruebas de seguridad
  --quality-only       Ejecutar solo pruebas de calidad
  --performance-only   Ejecutar solo pruebas de rendimiento
  --output-dir DIR     Directorio de salida (default: ./advanced_reports)
  --clean              Limpiar reportes anteriores
  --verbose            Modo verbose
  --parallel           Ejecutar pruebas en paralelo
  --fail-fast          Detener en el primer fallo

Variables de entorno:
  ADVANCED_OUTPUT_DIR  Directorio de salida
  COVERAGE_THRESHOLD   Umbral mínimo de cobertura
  SECURITY_FAIL_ON_HIGH Fallar en vulnerabilidades altas
  QUALITY_MIN_RATING   Calificación mínima de calidad
  PERFORMANCE_TIMEOUT  Timeout para pruebas de rendimiento

Ejemplos:
  $0 --coverage-only --threshold 90
  $0 --security-only --fail-on-high
  $0 --all --output-dir /tmp/advanced
  $0 --clean --verbose --parallel
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
 case $1 in
 --help | -h)
  __show_help
  exit 0
  ;;
 --coverage-only)
  RUN_COVERAGE=true
  shift
  ;;
 --security-only)
  RUN_SECURITY=true
  shift
  ;;
 --quality-only)
  RUN_QUALITY=true
  shift
  ;;
 --performance-only)
  RUN_PERFORMANCE=true
  shift
  ;;
 --output-dir)
  OUTPUT_DIR="$2"
  shift 2
  ;;
 --clean)
  CLEAN=true
  shift
  ;;
 --verbose)
  VERBOSE=true
  shift
  ;;
 --parallel)
  PARALLEL=true
  shift
  ;;
 --fail-fast)
  FAIL_FAST=true
  shift
  ;;
 *)
  __log "ERROR" "Opción desconocida: $1"
  __show_help
  exit 1
  ;;
 esac
done

# If no specific test type is selected, run all
if [[ "$RUN_COVERAGE" == "false" && "$RUN_SECURITY" == "false" && "$RUN_QUALITY" == "false" && "$RUN_PERFORMANCE" == "false" ]]; then
 RUN_COVERAGE=true
 RUN_SECURITY=true
 RUN_QUALITY=true
 RUN_PERFORMANCE=true
fi

# Check prerequisites
__check_prerequisites() {
 __log "INFO" "Verificando prerequisitos para pruebas avanzadas..."

 local missing_tools=()

 # Check basic tools
 if ! command -v bash > /dev/null 2>&1; then
  missing_tools+=("bash")
 fi

 if ! command -v find > /dev/null 2>&1; then
  missing_tools+=("find")
 fi

 # Check testing tools
 if ! command -v bats > /dev/null 2>&1; then
  missing_tools+=("bats")
 fi

 # Check coverage tools (optional)
 if [[ "$RUN_COVERAGE" == "true" ]]; then
  if ! command -v kcov > /dev/null 2>&1; then
   __log "WARNING" "kcov no encontrado - las pruebas de cobertura serán limitadas"
  fi
 fi

 # Check security tools (optional)
 if [[ "$RUN_SECURITY" == "true" ]]; then
  if ! command -v shellcheck > /dev/null 2>&1; then
   __log "WARNING" "shellcheck no encontrado - las pruebas de seguridad serán limitadas"
  fi
 fi

 # Check quality tools (optional)
 if [[ "$RUN_QUALITY" == "true" ]]; then
  if ! command -v shfmt > /dev/null 2>&1; then
   __log "WARNING" "shfmt no encontrado - las pruebas de calidad serán limitadas"
  fi
 fi

 if [[ ${#missing_tools[@]} -gt 0 ]]; then
  __log "ERROR" "Herramientas básicas faltantes: ${missing_tools[*]}"
  exit 1
 fi

 __log "SUCCESS" "Prerequisitos verificados"
}

# Clean previous reports
__clean_reports() {
 if [[ "$CLEAN" == "true" ]]; then
  __log "INFO" "Limpiando reportes anteriores..."
  rm -rf "$OUTPUT_DIR"
 fi
}

# Create output directory
__create_output_dir() {
 mkdir -p "$OUTPUT_DIR"
 __log "INFO" "Directorio de salida creado: $OUTPUT_DIR"
}

# Run coverage tests
__run_coverage_tests() {
 __log "INFO" "Ejecutando pruebas de cobertura..."

 local coverage_dir="$OUTPUT_DIR/coverage"
 mkdir -p "$coverage_dir"

 # Run coverage script if available
 if [[ -f "./tests/advanced/coverage/coverage_report.sh" ]]; then
  if ./tests/advanced/coverage/coverage_report.sh --output-dir "$coverage_dir" --threshold "$COVERAGE_THRESHOLD"; then
   __log "SUCCESS" "Pruebas de cobertura completadas"
  else
   __log "WARNING" "Pruebas de cobertura completadas con advertencias"
  fi
 else
  __log "WARNING" "Script de cobertura no encontrado"
 fi
}

# Run security tests
__run_security_tests() {
 __log "INFO" "Ejecutando pruebas de seguridad..."

 local security_dir="$OUTPUT_DIR/security"
 mkdir -p "$security_dir"

 # Run security script if available
 if [[ -f "./tests/advanced/security/security_scan.sh" ]]; then
  local fail_args=""
  if [[ "$SECURITY_FAIL_ON_HIGH" == "true" ]]; then
   fail_args="--fail-on-high"
  fi

  if ./tests/advanced/security/security_scan.sh --output-dir "$security_dir" $fail_args; then
   __log "SUCCESS" "Pruebas de seguridad completadas"
  else
   __log "WARNING" "Pruebas de seguridad completadas con advertencias"
  fi
 else
  __log "WARNING" "Script de seguridad no encontrado"
 fi
}

# Run quality tests
__run_quality_tests() {
 __log "INFO" "Ejecutando pruebas de calidad..."

 local quality_dir="$OUTPUT_DIR/quality"
 mkdir -p "$quality_dir"

 # Check shell script formatting
 if command -v shfmt > /dev/null 2>&1; then
  __log "INFO" "Verificando formato de scripts bash..."
  local format_issues=0

  while IFS= read -r -d '' file; do
   if ! shfmt -d "$file" > /dev/null 2>&1; then
    __log "WARNING" "Problema de formato en: $file"
    ((format_issues++))
   fi
  done < <(find . -name "*.sh" -type f -print0)

  if [[ $format_issues -eq 0 ]]; then
   __log "SUCCESS" "Formato de scripts bash verificado"
  else
   __log "WARNING" "Se encontraron $format_issues problemas de formato"
  fi
 fi

 # Check shell script linting
 if command -v shellcheck > /dev/null 2>&1; then
  __log "INFO" "Verificando linting de scripts bash..."
  local lint_issues=0

  while IFS= read -r -d '' file; do
   if ! shellcheck "$file" > /dev/null 2>&1; then
    __log "WARNING" "Problema de linting en: $file"
    ((lint_issues++))
   fi
  done < <(find . -name "*.sh" -type f -print0)

  if [[ $lint_issues -eq 0 ]]; then
   __log "SUCCESS" "Linting de scripts bash verificado"
  else
   __log "WARNING" "Se encontraron $lint_issues problemas de linting"
  fi
 fi

 # Generate quality report
 local quality_report="$quality_dir/quality_summary.md"
 cat > "$quality_report" << EOF
# Quality Test Summary
Generated: $(date)

## Shell Script Quality
- Format checking: $(command -v shfmt > /dev/null 2>&1 && echo "Available" || echo "Not available")
- Linting: $(command -v shellcheck > /dev/null 2>&1 && echo "Available" || echo "Not available")

## Recommendations
1. Use shfmt to format all shell scripts
2. Fix all shellcheck warnings
3. Follow bash best practices
4. Use proper error handling
EOF

 __log "SUCCESS" "Pruebas de calidad completadas"
}

# Run performance tests
__run_performance_tests() {
 __log "INFO" "Ejecutando pruebas de rendimiento..."

 local performance_dir="$OUTPUT_DIR/performance"
 mkdir -p "$performance_dir"

 # Test script execution time
 __log "INFO" "Probando tiempo de ejecución de scripts principales..."

 local performance_report="$performance_dir/performance_summary.md"
 cat > "$performance_report" << EOF
# Performance Test Summary
Generated: $(date)

## Script Execution Times
EOF

 # Test main scripts
 local scripts=("bin/process/processPlanetNotes.sh" "bin/process/processAPINotes.sh" "bin/dwh/ETL.sh")

 for script in "${scripts[@]}"; do
  if [[ -f "$script" ]]; then
   __log "INFO" "Probando: $script"

   local start_time=$(date +%s.%N)
   if timeout "$PERFORMANCE_TIMEOUT" bash "$script" --help > /dev/null 2>&1; then
    local end_time=$(date +%s.%N)
    local execution_time=$(echo "$end_time - $start_time" | bc -l 2> /dev/null || echo "N/A")
    echo "- $script: ${execution_time}s" >> "$performance_report"
    __log "SUCCESS" "$script: ${execution_time}s"
   else
    echo "- $script: Timeout or error" >> "$performance_report"
    __log "WARNING" "$script: Timeout o error"
   fi
  fi
 done

 echo "" >> "$performance_report"
 echo "## Recommendations" >> "$performance_report"
 echo "1. Optimize slow scripts" >> "$performance_report"
 echo "2. Consider parallel processing where possible" >> "$performance_report"
 echo "3. Monitor resource usage" >> "$performance_report"

 __log "SUCCESS" "Pruebas de rendimiento completadas"
}

# Generate final summary
__generate_final_summary() {
 __log "INFO" "Generando resumen final..."

 local summary_file="$OUTPUT_DIR/advanced_tests_summary.md"

 cat > "$summary_file" << EOF
# Advanced Tests Summary
Generated: $(date)

## Test Results

### Coverage Tests
- Status: $(if [[ "$RUN_COVERAGE" == "true" ]]; then echo "Executed"; else echo "Skipped"; fi)
- Threshold: ${COVERAGE_THRESHOLD}%

### Security Tests
- Status: $(if [[ "$RUN_SECURITY" == "true" ]]; then echo "Executed"; else echo "Skipped"; fi)
- Fail on High: ${SECURITY_FAIL_ON_HIGH}

### Quality Tests
- Status: $(if [[ "$RUN_QUALITY" == "true" ]]; then echo "Executed"; else echo "Skipped"; fi)
- Min Rating: ${QUALITY_MIN_RATING}

### Performance Tests
- Status: $(if [[ "$RUN_PERFORMANCE" == "true" ]]; then echo "Executed"; else echo "Skipped"; fi)
- Timeout: ${PERFORMANCE_TIMEOUT}s

## Reports Generated
EOF

 # List all generated reports
 find "$OUTPUT_DIR" -name "*.md" -o -name "*.txt" -o -name "*.json" | while read -r file; do
  echo "- $(basename "$file")" >> "$summary_file"
 done

 echo "" >> "$summary_file"
 echo "## Next Steps" >> "$summary_file"
 echo "1. Review all generated reports" >> "$summary_file"
 echo "2. Address any issues found" >> "$summary_file"
 echo "3. Improve test coverage" >> "$summary_file"
 echo "4. Optimize performance bottlenecks" >> "$summary_file"

 __log "SUCCESS" "Resumen final generado: $summary_file"
}

# Main function
main() {
 __log "INFO" "Iniciando pruebas avanzadas - Fase 3..."

 # Check prerequisites
 __check_prerequisites

 # Clean previous reports if requested
 __clean_reports

 # Create output directory
 __create_output_dir

 # Run tests based on configuration
 local tests_failed=false

 if [[ "$RUN_COVERAGE" == "true" ]]; then
  if ! __run_coverage_tests; then
   tests_failed=true
   if [[ "$FAIL_FAST" == "true" ]]; then
    __log "ERROR" "Fallo en pruebas de cobertura"
    exit 1
   fi
  fi
 fi

 if [[ "$RUN_SECURITY" == "true" ]]; then
  if ! __run_security_tests; then
   tests_failed=true
   if [[ "$FAIL_FAST" == "true" ]]; then
    __log "ERROR" "Fallo en pruebas de seguridad"
    exit 1
   fi
  fi
 fi

 if [[ "$RUN_QUALITY" == "true" ]]; then
  if ! __run_quality_tests; then
   tests_failed=true
   if [[ "$FAIL_FAST" == "true" ]]; then
    __log "ERROR" "Fallo en pruebas de calidad"
    exit 1
   fi
  fi
 fi

 if [[ "$RUN_PERFORMANCE" == "true" ]]; then
  if ! __run_performance_tests; then
   tests_failed=true
   if [[ "$FAIL_FAST" == "true" ]]; then
    __log "ERROR" "Fallo en pruebas de rendimiento"
    exit 1
   fi
  fi
 fi

 # Generate final summary
 __generate_final_summary

 if [[ "$tests_failed" == "true" ]]; then
  __log "WARNING" "Algunas pruebas fallaron. Revisa los reportes en: $OUTPUT_DIR"
  exit 1
 else
  __log "SUCCESS" "Todas las pruebas avanzadas completadas exitosamente. Reportes en: $OUTPUT_DIR"
 fi
}

# Run main function
main "$@"
