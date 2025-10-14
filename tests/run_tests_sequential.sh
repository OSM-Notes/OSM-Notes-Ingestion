#!/bin/bash

# Sequential Test Runner for OSM-Notes-Ingestion
# Author: Andres Gomez (AngocA)
# Version: 2025-10-14
#
# Ejecuta tests en secuencia organizada por niveles

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Counters
TOTAL_LEVELS=10
CURRENT_LEVEL=0
PASSED_LEVELS=0
FAILED_LEVELS=0
TOTAL_TESTS_PASSED=0
TOTAL_TESTS_FAILED=0

# Logging functions
__log_info() {
 echo -e "${BLUE}[INFO]${NC} $1"
}

__log_success() {
 echo -e "${GREEN}[SUCCESS]${NC} $1"
}

__log_warning() {
 echo -e "${YELLOW}[WARNING]${NC} $1"
}

__log_error() {
 echo -e "${RED}[ERROR]${NC} $1"
}

__log_level() {
 echo -e "${MAGENTA}[LEVEL $1]${NC} $2"
}

# Show banner
__show_banner() {
 echo ""
 echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
 echo -e "${CYAN}║                                                            ║${NC}"
 echo -e "${CYAN}║       OSM-Notes-Ingestion Sequential Test Runner          ║${NC}"
 echo -e "${CYAN}║                                                            ║${NC}"
 echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
 echo ""
}

# Show level header
__show_level_header() {
 local -r level=$1
 local -r description=$2
 local -r estimated_time=$3
 
 CURRENT_LEVEL=$level
 
 echo ""
 echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
 echo -e "${CYAN}║${NC} Nivel ${level}/${TOTAL_LEVELS}: ${description}"
 echo -e "${CYAN}║${NC} Tiempo estimado: ${estimated_time}"
 echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
 echo ""
}

# Show level footer
__show_level_footer() {
 local -r level=$1
 local -r status=$2
 
 echo ""
 if [[ "$status" == "success" ]]; then
  echo -e "${GREEN}✅ Nivel ${level} completado exitosamente${NC}"
  PASSED_LEVELS=$((PASSED_LEVELS + 1))
 else
  echo -e "${RED}❌ Nivel ${level} falló${NC}"
  FAILED_LEVELS=$((FAILED_LEVELS + 1))
 fi
 echo ""
}

# Run bats tests
__run_bats() {
 local tests_passed=0
 local tests_failed=0
 
 if bats "$@"; then
  __log_success "Tests pasaron correctamente"
  return 0
 else
  __log_error "Algunos tests fallaron"
  return 1
 fi
}

# Show help
__show_help() {
 cat << EOF
Sequential Test Runner for OSM-Notes-Ingestion

Usage: $0 [MODE]

Modes:
  quick         Ejecutar solo tests críticos (15-20 min)
  basic         Ejecutar niveles 1-3 (20-35 min)
  standard      Ejecutar niveles 1-6 (45-75 min)
  full          Ejecutar todos los niveles (90-135 min)
  level N       Ejecutar solo el nivel N (1-10)
  help          Mostrar esta ayuda

Examples:
  $0 quick                # Verificación rápida
  $0 basic                # Tests básicos y validación
  $0 level 5              # Solo procesamiento paralelo
  $0 full                 # Suite completa

EOF
}

# Quick mode - critical tests only
__run_quick() {
 __show_banner
 __log_info "Modo QUICK: Ejecutando solo tests críticos"
 __log_info "Tiempo estimado: 15-20 minutos"
 echo ""
 
 __show_level_header "QUICK" "Tests Críticos" "15-20 min"
 
 if __run_bats \
  "${SCRIPT_DIR}/unit/bash/bash_logger_enhanced.test.bats" \
  "${SCRIPT_DIR}/unit/bash/format_and_lint.test.bats" \
  "${SCRIPT_DIR}/unit/bash/centralized_validation.test.bats" \
  "${SCRIPT_DIR}/unit/bash/coordinate_validation_enhanced.test.bats" \
  "${SCRIPT_DIR}/unit/bash/date_validation.test.bats" \
  "${SCRIPT_DIR}/unit/bash/csv_enum_validation.test.bats" \
  "${SCRIPT_DIR}/unit/bash/processAPINotes.test.bats" \
  "${SCRIPT_DIR}/unit/bash/processPlanetNotes.test.bats" \
  "${SCRIPT_DIR}/parallel_processing_test_suite.bats" \
  "${SCRIPT_DIR}/unit/bash/error_handling_consolidated.test.bats"
 then
  __show_level_footer "QUICK" "success"
  return 0
 else
  __show_level_footer "QUICK" "failed"
  return 1
 fi
}

# Level 1 - Basic tests
__run_level_1() {
 __show_level_header 1 "Tests Básicos" "5-10 min"
 
 if __run_bats \
  "${SCRIPT_DIR}/unit/bash/bash_logger_enhanced.test.bats" \
  "${SCRIPT_DIR}/unit/bash/database_variables.test.bats" \
  "${SCRIPT_DIR}/unit/bash/format_and_lint.test.bats" \
  "${SCRIPT_DIR}/unit/bash/function_naming_convention.test.bats" \
  "${SCRIPT_DIR}/unit/bash/variable_naming_convention.test.bats" \
  "${SCRIPT_DIR}/unit/bash/script_help_validation.test.bats" \
  "${SCRIPT_DIR}/unit/bash/variable_duplication.test.bats" \
  "${SCRIPT_DIR}/unit/bash/variable_duplication_detection.test.bats" \
  "${SCRIPT_DIR}/unit/bash/function_consolidation.test.bats"
 then
  __show_level_footer 1 "success"
  return 0
 else
  __show_level_footer 1 "failed"
  return 1
 fi
}

# Level 2 - Validation tests
__run_level_2() {
 __show_level_header 2 "Tests de Validación" "10-15 min"
 
 if __run_bats \
  "${SCRIPT_DIR}/unit/bash/centralized_validation.test.bats" \
  "${SCRIPT_DIR}/unit/bash/coordinate_validation_enhanced.test.bats" \
  "${SCRIPT_DIR}/unit/bash/date_validation.test.bats" \
  "${SCRIPT_DIR}/unit/bash/date_validation_utc.test.bats" \
  "${SCRIPT_DIR}/unit/bash/date_validation_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/boundary_validation.test.bats" \
  "${SCRIPT_DIR}/unit/bash/checksum_validation.test.bats" \
  "${SCRIPT_DIR}/unit/bash/input_validation.test.bats" \
  "${SCRIPT_DIR}/unit/bash/extended_validation.test.bats" \
  "${SCRIPT_DIR}/unit/bash/edge_cases_validation.test.bats" \
  "${SCRIPT_DIR}/unit/bash/sql_validation_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/sql_constraints_validation.test.bats"
 then
  __show_level_footer 2 "success"
  return 0
 else
  __show_level_footer 2 "failed"
  return 1
 fi
}

# Level 3 - XML/XSLT tests
__run_level_3() {
 __show_level_header 3 "Tests de XML/XSLT" "8-12 min"
 
 if __run_bats \
  "${SCRIPT_DIR}/unit/bash/csv_enum_validation.test.bats" \
  "${SCRIPT_DIR}/unit/bash/xslt_enum_format.test.bats" \
  "${SCRIPT_DIR}/unit/bash/xslt_enum_validation.test.bats" \
  "${SCRIPT_DIR}/unit/bash/xslt_simple.test.bats" \
  "${SCRIPT_DIR}/unit/bash/xslt_csv_format.test.bats" \
  "${SCRIPT_DIR}/unit/bash/xslt_large_notes_recursion.test.bats" \
  "${SCRIPT_DIR}/unit/bash/xml_validation_simple.test.bats" \
  "${SCRIPT_DIR}/unit/bash/xml_validation_enhanced.test.bats" \
  "${SCRIPT_DIR}/unit/bash/xml_validation_functions.test.bats" \
  "${SCRIPT_DIR}/unit/bash/xml_validation_large_files.test.bats" \
  "${SCRIPT_DIR}/unit/bash/xml_processing_enhanced.test.bats" \
  "${SCRIPT_DIR}/unit/bash/xml_corruption_recovery.test.bats" \
  "${SCRIPT_DIR}/unit/bash/resource_limits.test.bats"
 then
  __show_level_footer 3 "success"
  return 0
 else
  __show_level_footer 3 "failed"
  return 1
 fi
}

# Level 4 - Processing tests
__run_level_4() {
 __show_level_header 4 "Tests de Procesamiento" "15-25 min"
 
 if __run_bats \
  "${SCRIPT_DIR}/unit/bash/processAPINotes.test.bats" \
  "${SCRIPT_DIR}/unit/bash/processAPINotes_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/processAPINotes_error_handling_improved.test.bats" \
  "${SCRIPT_DIR}/unit/bash/processAPINotes_parallel_error.test.bats" \
  "${SCRIPT_DIR}/unit/bash/historical_data_validation.test.bats" \
  "${SCRIPT_DIR}/unit/bash/processAPI_historical_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/api_download_verification.test.bats" \
  "${SCRIPT_DIR}/unit/bash/processPlanetNotes.test.bats" \
  "${SCRIPT_DIR}/unit/bash/processPlanetNotes_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/processPlanetNotes_integration_fixed.test.bats" \
  "${SCRIPT_DIR}/unit/bash/mock_planet_functions.test.bats"
 then
  __show_level_footer 4 "success"
  return 0
 else
  __show_level_footer 4 "failed"
  return 1
 fi
}

# Level 5 - Parallel processing tests
__run_level_5() {
 __show_level_header 5 "Tests de Procesamiento Paralelo" "10-15 min"
 
 if __run_bats \
  "${SCRIPT_DIR}/parallel_processing_test_suite.bats" \
  "${SCRIPT_DIR}/unit/bash/parallel_processing_robust.test.bats" \
  "${SCRIPT_DIR}/unit/bash/parallel_processing_optimization.test.bats" \
  "${SCRIPT_DIR}/unit/bash/parallel_processing_validation.test.bats" \
  "${SCRIPT_DIR}/unit/bash/parallel_threshold.test.bats" \
  "${SCRIPT_DIR}/unit/bash/parallel_delay_test.bats" \
  "${SCRIPT_DIR}/unit/bash/parallel_delay_test_simple.bats" \
  "${SCRIPT_DIR}/unit/bash/parallel_failed_file.test.bats" \
  "${SCRIPT_DIR}/unit/bash/binary_division_performance.test.bats"
 then
  __show_level_footer 5 "success"
  return 0
 else
  __show_level_footer 5 "failed"
  return 1
 fi
}

# Level 6 - Cleanup and error handling tests
__run_level_6() {
 __show_level_header 6 "Tests de Cleanup y Error Handling" "12-18 min"
 
 if __run_bats \
  "${SCRIPT_DIR}/unit/bash/cleanupAll_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/cleanupAll.test.bats" \
  "${SCRIPT_DIR}/unit/bash/clean_flag_handling.test.bats" \
  "${SCRIPT_DIR}/unit/bash/clean_flag_simple.test.bats" \
  "${SCRIPT_DIR}/unit/bash/clean_flag_exit_trap.test.bats" \
  "${SCRIPT_DIR}/unit/bash/cleanup_behavior.test.bats" \
  "${SCRIPT_DIR}/unit/bash/cleanup_behavior_simple.test.bats" \
  "${SCRIPT_DIR}/unit/bash/cleanup_order.test.bats" \
  "${SCRIPT_DIR}/unit/bash/cleanup_dependency_fix.test.bats" \
  "${SCRIPT_DIR}/unit/bash/error_handling.test.bats" \
  "${SCRIPT_DIR}/unit/bash/error_handling_enhanced.test.bats" \
  "${SCRIPT_DIR}/unit/bash/error_handling_consolidated.test.bats"
 then
  __show_level_footer 6 "success"
  return 0
 else
  __show_level_footer 6 "failed"
  return 1
 fi
}

# Level 7 - Monitoring and WMS tests
__run_level_7() {
 __show_level_header 7 "Tests de Monitoreo y WMS" "8-12 min"
 
 if __run_bats \
  "${SCRIPT_DIR}/unit/bash/monitoring.test.bats" \
  "${SCRIPT_DIR}/unit/bash/notesCheckVerifier_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/processCheckPlanetNotes_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/wmsManager.test.bats" \
  "${SCRIPT_DIR}/unit/bash/wmsManager_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/wmsConfigExample_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/geoserverConfig_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/updateCountries_integration.test.bats"
 then
  __show_level_footer 7 "success"
  return 0
 else
  __show_level_footer 7 "failed"
  return 1
 fi
}

# Level 8 - Advanced and edge case tests
__run_level_8() {
 __show_level_header 8 "Tests Avanzados y Casos Edge" "10-15 min"
 
 if __run_bats \
  "${SCRIPT_DIR}/unit/bash/performance_edge_cases.test.bats" \
  "${SCRIPT_DIR}/unit/bash/performance_edge_cases_simple.test.bats" \
  "${SCRIPT_DIR}/unit/bash/performance_edge_cases_quick.test.bats" \
  "${SCRIPT_DIR}/unit/bash/edge_cases_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/real_data_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/hybrid_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/script_execution_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/profile_integration.test.bats" \
  "${SCRIPT_DIR}/unit/bash/functionsProcess.test.bats" \
  "${SCRIPT_DIR}/unit/bash/functionsProcess_enhanced.test.bats" \
  "${SCRIPT_DIR}/unit/bash/prerequisites_enhanced.test.bats" \
  "${SCRIPT_DIR}/unit/bash/logging_improvements.test.bats" \
  "${SCRIPT_DIR}/unit/bash/logging_pattern_validation.test.bats"
 then
  __show_level_footer 8 "success"
  return 0
 else
  __show_level_footer 8 "failed"
  return 1
 fi
}

# Level 9 - Integration tests
__run_level_9() {
 __show_level_header 9 "Tests de Integración End-to-End" "10-20 min"
 
 if __run_bats \
  "${SCRIPT_DIR}/integration/boundary_processing_error_integration.test.bats" \
  "${SCRIPT_DIR}/integration/wms_integration.test.bats" \
  "${SCRIPT_DIR}/integration/logging_pattern_validation_integration.test.bats" \
  "${SCRIPT_DIR}/integration/mock_planet_processing.test.bats" \
  "${SCRIPT_DIR}/integration/processAPINotes_parallel_error_integration.test.bats" \
  "${SCRIPT_DIR}/integration/xslt_integration.test.bats" \
  "${SCRIPT_DIR}/integration/end_to_end.test.bats" \
  "${SCRIPT_DIR}/integration/processAPI_historical_e2e.test.bats"
 then
  __show_level_footer 9 "success"
  return 0
 else
  __show_level_footer 9 "failed"
  return 1
 fi
}

# Level 10 - DWH tests
__run_level_10() {
 __show_level_header 10 "Tests de DWH Enhanced" "10-15 min"
 
 __log_info "Ejecutando tests de DWH..."
 
 if [[ -f "${SCRIPT_DIR}/run_dwh_tests.sh" ]]; then
  if "${SCRIPT_DIR}/run_dwh_tests.sh"; then
   __show_level_footer 10 "success"
   return 0
  else
   __show_level_footer 10 "failed"
   return 1
  fi
 else
  __log_warning "Script run_dwh_tests.sh no encontrado, saltando nivel 10"
  __show_level_footer 10 "skipped"
  return 0
 fi
}

# Show summary
__show_summary() {
 echo ""
 echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
 echo -e "${CYAN}║                                                            ║${NC}"
 echo -e "${CYAN}║                    RESUMEN DE EJECUCIÓN                    ║${NC}"
 echo -e "${CYAN}║                                                            ║${NC}"
 echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
 echo ""
 echo -e "  Niveles ejecutados:  ${CURRENT_LEVEL}"
 echo -e "  ${GREEN}Niveles exitosos:    ${PASSED_LEVELS}${NC}"
 echo -e "  ${RED}Niveles fallidos:    ${FAILED_LEVELS}${NC}"
 echo ""
 
 if [[ ${FAILED_LEVELS} -eq 0 ]]; then
  echo -e "${GREEN}✅ ¡Todos los tests pasaron exitosamente!${NC}"
  return 0
 else
  echo -e "${RED}❌ Algunos tests fallaron${NC}"
  return 1
 fi
}

# Main execution
main() {
 local -r mode="${1:-help}"
 
 case "$mode" in
 quick)
  __run_quick
  ;;
 basic)
  __show_banner
  __log_info "Modo BASIC: Niveles 1-3"
  __run_level_1 || true
  __run_level_2 || true
  __run_level_3 || true
  __show_summary
  ;;
 standard)
  __show_banner
  __log_info "Modo STANDARD: Niveles 1-6"
  __run_level_1 || true
  __run_level_2 || true
  __run_level_3 || true
  __run_level_4 || true
  __run_level_5 || true
  __run_level_6 || true
  __show_summary
  ;;
 full)
  __show_banner
  __log_info "Modo FULL: Todos los niveles"
  __run_level_1 || true
  __run_level_2 || true
  __run_level_3 || true
  __run_level_4 || true
  __run_level_5 || true
  __run_level_6 || true
  __run_level_7 || true
  __run_level_8 || true
  __run_level_9 || true
  __run_level_10 || true
  __show_summary
  ;;
 level)
  if [[ -z "${2:-}" ]]; then
   __log_error "Debes especificar el número de nivel (1-10)"
   __show_help
   exit 1
  fi
  local -r level_num="$2"
  __show_banner
  __log_info "Ejecutando solo Nivel ${level_num}"
  "__run_level_${level_num}" || true
  __show_summary
  ;;
 help | --help | -h)
  __show_help
  ;;
 *)
  __log_error "Modo desconocido: $mode"
  __show_help
  exit 1
  ;;
 esac
}

# Run main
main "$@"


