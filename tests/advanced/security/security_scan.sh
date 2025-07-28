#!/bin/bash
# Security scanning script for OSM Notes Profile project
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
OUTPUT_DIR="${SECURITY_OUTPUT_DIR:-./security_reports}"
SCAN_TYPE="all"
FAIL_ON_HIGH="${FAIL_ON_HIGH:-false}"
FAIL_ON_CRITICAL="${FAIL_ON_CRITICAL:-false}"
CLEAN=false
VERBOSE=false

# Tool paths
SHELLCHECK_PATH="${SHELLCHECK_PATH:-shellcheck}"
TRIVY_PATH="${TRIVY_PATH:-trivy}"
# Removed bandit - not needed for mock Python files

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
  --output-dir DIR     Directorio de salida (default: ./security_reports)
  --scan-type TYPE     Tipo de escaneo (shellcheck, trivy, all)
  --fail-on-high       Fallar si se encuentran vulnerabilidades altas
  --fail-on-critical   Fallar si se encuentran vulnerabilidades críticas
  --clean              Limpiar reportes anteriores
  --verbose            Modo verbose

Variables de entorno:
  SECURITY_OUTPUT_DIR  Directorio de salida
  FAIL_ON_HIGH         Fallar en vulnerabilidades altas
  FAIL_ON_CRITICAL     Fallar en vulnerabilidades críticas
  SHELLCHECK_PATH      Ruta al ejecutable shellcheck
  TRIVY_PATH           Ruta al ejecutable trivy
  # Removed BANDIT_PATH - not needed

Ejemplos:
  $0 --scan-type shellcheck --fail-on-high
  $0 --scan-type all --output-dir /tmp/security
  $0 --clean --verbose
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
 case $1 in
  --help | -h)
   __show_help
   exit 0
   ;;
  --output-dir)
   OUTPUT_DIR="$2"
   shift 2
   ;;
  --scan-type)
   SCAN_TYPE="$2"
   shift 2
   ;;
  --fail-on-high)
   FAIL_ON_HIGH=true
   shift
   ;;
  --fail-on-critical)
   FAIL_ON_CRITICAL=true
   shift
   ;;
  --clean)
   CLEAN=true
   shift
   ;;
  --verbose)
   VERBOSE=true
   shift
   ;;
  *)
   __log "ERROR" "Opción desconocida: $1"
   __show_help
   exit 1
   ;;
 esac
done

# Check prerequisites
__check_prerequisites() {
 __log "INFO" "Verificando prerequisitos..."

 local missing_tools=()

 # Check shellcheck
 if ! command -v "$SHELLCHECK_PATH" > /dev/null 2>&1; then
  missing_tools+=("shellcheck")
 fi

 # Check trivy
 if ! command -v "$TRIVY_PATH" > /dev/null 2>&1; then
  missing_tools+=("trivy")
 fi

 # Removed bandit check - not needed for mock Python files

 if [[ ${#missing_tools[@]} -gt 0 ]]; then
  __log "ERROR" "Herramientas faltantes: ${missing_tools[*]}"
  __log "INFO" "Instale las herramientas faltantes:"
  for tool in "${missing_tools[@]}"; do
   case "$tool" in
    "shellcheck")
     echo "  - shellcheck: sudo apt-get install shellcheck"
     ;;
         "trivy")
      echo "  - trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
      ;;
   esac
  done
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

# Run shellcheck scan
__run_shellcheck() {
 __log "INFO" "Ejecutando ShellCheck..."

 local shellcheck_output="$OUTPUT_DIR/shellcheck_report.txt"
 local shellcheck_json="$OUTPUT_DIR/shellcheck_report.json"

 # Find all shell scripts
 local shell_files=($(find . -name "*.sh" -type f))

 if [[ ${#shell_files[@]} -eq 0 ]]; then
  __log "WARNING" "No se encontraron archivos .sh para analizar"
  return 0
 fi

 # Run shellcheck with different outputs
 if "$SHELLCHECK_PATH" --version > /dev/null 2>&1; then
  # Text output
  "$SHELLCHECK_PATH" --color=never "${shell_files[@]}" > "$shellcheck_output" 2>&1 || true

  # JSON output (if supported)
  if "$SHELLCHECK_PATH" --format=json "${shell_files[@]}" > "$shellcheck_json" 2>&1; then
   __log "SUCCESS" "ShellCheck completado - Reporte guardado en: $shellcheck_output"
  else
   __log "WARNING" "ShellCheck completado (solo texto) - Reporte guardado en: $shellcheck_output"
  fi

  # Check for high/critical issues
  local error_count=$(grep -c "SC[0-9]" "$shellcheck_output" || echo "0")
  if [[ "$error_count" -gt 0 ]]; then
   __log "WARNING" "ShellCheck encontró $error_count problemas"
   if [[ "$FAIL_ON_HIGH" == "true" ]]; then
    __log "ERROR" "Fallo configurado para problemas altos"
    return 1
   fi
  fi
 else
  __log "ERROR" "ShellCheck no está disponible"
  return 1
 fi
}

# Run trivy scan
__run_trivy() {
 __log "INFO" "Ejecutando Trivy..."

 local trivy_output="$OUTPUT_DIR/trivy_report.txt"
 local trivy_json="$OUTPUT_DIR/trivy_report.json"

 # Scan for vulnerabilities in dependencies and files
 if "$TRIVY_PATH" --version > /dev/null 2>&1; then
  # Scan filesystem
  "$TRIVY_PATH" fs --format table . > "$trivy_output" 2>&1 || true

  # JSON output
  "$TRIVY_PATH" fs --format json . > "$trivy_json" 2>&1 || true

  __log "SUCCESS" "Trivy completado - Reporte guardado en: $trivy_output"

  # Check for high/critical vulnerabilities
  local high_count=$(grep -c "HIGH" "$trivy_output" || echo "0")
  local critical_count=$(grep -c "CRITICAL" "$trivy_output" || echo "0")

  if [[ "$critical_count" -gt 0 ]]; then
   __log "ERROR" "Trivy encontró $critical_count vulnerabilidades críticas"
   if [[ "$FAIL_ON_CRITICAL" == "true" ]]; then
    return 1
   fi
  fi

  if [[ "$high_count" -gt 0 ]]; then
   __log "WARNING" "Trivy encontró $high_count vulnerabilidades altas"
   if [[ "$FAIL_ON_HIGH" == "true" ]]; then
    return 1
   fi
  fi
 else
  __log "ERROR" "Trivy no está disponible"
  return 1
 fi
}

# Removed bandit function - not needed for mock Python files

# Generate consolidated report
__generate_consolidated_report() {
 __log "INFO" "Generando reporte consolidado..."

 local consolidated_report="$OUTPUT_DIR/security_scan_summary.md"

 cat > "$consolidated_report" << EOF
# Security Scan Summary
Generated: $(date)

## Overview
This report contains the results of security scanning for the OSM Notes Profile project.

## Tools Used
- ShellCheck: Static analysis for shell scripts
- Trivy: Vulnerability scanner for dependencies and filesystem
- Removed Bandit - not needed for mock Python files

## Reports Generated
EOF

 # List generated reports
 for report in "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json; do
  if [[ -f "$report" ]]; then
   echo "- $(basename "$report")" >> "$consolidated_report"
  fi
 done

 echo "" >> "$consolidated_report"
 echo "## Recommendations" >> "$consolidated_report"
 echo "1. Review all ShellCheck warnings and errors" >> "$consolidated_report"
 echo "2. Address any high or critical vulnerabilities found by Trivy" >> "$consolidated_report"
 echo "3. Review and address any security issues found in shell scripts" >> "$consolidated_report"
 echo "4. Regularly update dependencies to patch known vulnerabilities" >> "$consolidated_report"

 __log "SUCCESS" "Reporte consolidado generado: $consolidated_report"
}

# Main function
main() {
 __log "INFO" "Iniciando escaneo de seguridad..."

 # Check prerequisites
 __check_prerequisites

 # Clean previous reports if requested
 __clean_reports

 # Create output directory
 __create_output_dir

 # Run scans based on type
 case "$SCAN_TYPE" in
  "shellcheck")
   __run_shellcheck
   ;;
       "trivy")
      __run_trivy
      ;;
  "all")
        __run_shellcheck
     __run_trivy
   ;;
  *)
   __log "ERROR" "Tipo de escaneo no válido: $SCAN_TYPE"
   exit 1
   ;;
 esac

 # Generate consolidated report
 __generate_consolidated_report

 __log "SUCCESS" "Escaneo de seguridad completado. Reportes guardados en: $OUTPUT_DIR"
}

# Run main function
main "$@"
