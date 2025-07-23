#!/bin/bash
# =============================================================================
# Script para ejecutar pruebas de casos especiales
# =============================================================================

set -euo pipefail

# =============================================================================
# Variables de configuración
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"
SPECIAL_CASES_DIR="$PROJECT_ROOT/tests/fixtures/special_cases"
VERBOSE="${VERBOSE:-false}"
PARALLEL="${PARALLEL:-false}"
FAIL_FAST="${FAIL_FAST:-false}"

# =============================================================================
# Colores para output
# =============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# =============================================================================
# Funciones de logging
# =============================================================================
__log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

__log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

__log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

__log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

__log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[DEBUG] $*"
    fi
}

# =============================================================================
# Función de ayuda
# =============================================================================
__show_help() {
    cat << EOF
Uso: $0 [OPTIONS]

Opciones:
  --help, -h     Mostrar esta ayuda
  --verbose      Modo verbose
  --parallel     Ejecutar pruebas en paralelo
  --fail-fast    Detener en el primer fallo
  --case CASE    Ejecutar solo un caso específico

Variables de entorno:
  VERBOSE        Modo verbose
  PARALLEL       Ejecutar en paralelo
  FAIL_FAST      Detener en el primer fallo

Ejemplos:
  $0 --verbose
  $0 --parallel --fail-fast
  $0 --case zero_notes
EOF
}

# =============================================================================
# Función para verificar prerequisitos
# =============================================================================
__check_prerequisites() {
    __log_info "Verificando prerequisitos..."
    
    # Verificar que existe el directorio de casos especiales
    if [[ ! -d "$SPECIAL_CASES_DIR" ]]; then
        __log_error "Directorio de casos especiales no encontrado: $SPECIAL_CASES_DIR"
        return 1
    fi
    
    # Verificar que existe el script de procesamiento
    if [[ ! -f "$PROJECT_ROOT/bin/process/processAPINotes.sh" ]]; then
        __log_error "Script de procesamiento no encontrado: $PROJECT_ROOT/bin/process/processAPINotes.sh"
        return 1
    fi
    
    __log_success "Prerequisitos verificados"
    return 0
}

# =============================================================================
# Función para ejecutar un caso de prueba
# =============================================================================
__run_test_case() {
    local xml_file="$1"
    local case_name=$(basename "$xml_file" .xml)
    
    __log_info "Ejecutando caso: $case_name"
    __log_debug "Archivo: $xml_file"
    
    # Ejecutar el script de procesamiento
    if "$PROJECT_ROOT/bin/process/processAPINotes.sh" "$xml_file" >/dev/null 2>&1; then
        __log_success "Caso $case_name completado exitosamente"
        return 0
    else
        __log_error "Caso $case_name falló"
        return 1
    fi
}

# =============================================================================
# Función para ejecutar todos los casos
# =============================================================================
__run_all_cases() {
    __log_info "Ejecutando todos los casos especiales..."
    
    local success_count=0
    local total_count=0
    local failed_cases=()
    
    # Encontrar todos los archivos XML
    local xml_files=()
    while IFS= read -r -d '' file; do
        xml_files+=("$file")
    done < <(find "$SPECIAL_CASES_DIR" -name "*.xml" -type f -print0)
    
    if [[ ${#xml_files[@]} -eq 0 ]]; then
        __log_warning "No se encontraron archivos XML para probar"
        return 0
    fi
    
    __log_info "Encontrados ${#xml_files[@]} casos para probar"
    
    # Ejecutar casos
    for xml_file in "${xml_files[@]}"; do
        local case_name=$(basename "$xml_file" .xml)
        ((total_count++))
        
        if __run_test_case "$xml_file"; then
            ((success_count++))
        else
            failed_cases+=("$case_name")
            if [[ "$FAIL_FAST" == "true" ]]; then
                __log_error "Deteniendo en el primer fallo: $case_name"
                break
            fi
        fi
    done
    
    # Mostrar resumen
    __log_info "Resumen de pruebas:"
    __log_info "  Total: $total_count"
    __log_info "  Exitosos: $success_count"
    __log_info "  Fallidos: $((total_count - success_count))"
    
    if [[ ${#failed_cases[@]} -gt 0 ]]; then
        __log_warning "Casos fallidos: ${failed_cases[*]}"
        return 1
    else
        __log_success "Todos los casos completados exitosamente"
        return 0
    fi
}

# =============================================================================
# Función para ejecutar un caso específico
# =============================================================================
__run_specific_case() {
    local case_name="$1"
    local xml_file="$SPECIAL_CASES_DIR/${case_name}.xml"
    
    if [[ ! -f "$xml_file" ]]; then
        __log_error "Caso no encontrado: $case_name"
        __log_info "Casos disponibles:"
        find "$SPECIAL_CASES_DIR" -name "*.xml" -exec basename {} .xml \; | sort
        return 1
    fi
    
    __run_test_case "$xml_file"
}

# =============================================================================
# Procesamiento de argumentos
# =============================================================================
SPECIFIC_CASE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            __show_help
            exit 0
            ;;
        --verbose)
            VERBOSE="true"
            shift
            ;;
        --parallel)
            PARALLEL="true"
            shift
            ;;
        --fail-fast)
            FAIL_FAST="true"
            shift
            ;;
        --case)
            SPECIFIC_CASE="$2"
            shift 2
            ;;
        *)
            __log_error "Opción desconocida: $1"
            __show_help
            exit 1
            ;;
    esac
done

# =============================================================================
# Función principal
# =============================================================================
__main() {
    __log_info "Iniciando pruebas de casos especiales..."
    
    # Verificar prerequisitos
    if ! __check_prerequisites; then
        exit 1
    fi
    
    # Ejecutar caso específico o todos los casos
    if [[ -n "$SPECIFIC_CASE" ]]; then
        __log_info "Ejecutando caso específico: $SPECIFIC_CASE"
        if __run_specific_case "$SPECIFIC_CASE"; then
            __log_success "Caso específico completado exitosamente"
            exit 0
        else
            __log_error "Caso específico falló"
            exit 1
        fi
    else
        __run_all_cases
    fi
}

# Ejecutar función principal
__main "$@" 