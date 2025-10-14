# Guía de Ejecución Secuencial de Tests

**Versión:** 2025-10-14  
**Autor:** Andres Gomez (AngocA)

## Introducción

Esta guía te permite ejecutar las pruebas **por partes**, organizadas por
prioridad, complejidad y categoría funcional. Ideal para:

- Verificación rápida durante desarrollo
- Debugging de componentes específicos
- Ejecución controlada con recursos limitados
- Identificación temprana de errores

---

## Organización por Niveles

### 📊 Resumen de Niveles

| Nivel | Suites | Tests Aprox. | Tiempo | Descripción |
|-------|--------|--------------|--------|-------------|
| **Nivel 1 - Básico** | 15 | ~150 | 5-10 min | Tests fundamentales y rápidos |
| **Nivel 2 - Validación** | 20 | ~250 | 10-15 min | Validación de datos y formato |
| **Nivel 3 - Procesamiento** | 18 | ~220 | 15-20 min | Lógica de procesamiento |
| **Nivel 4 - Integración** | 25 | ~350 | 20-30 min | Integración de componentes |
| **Nivel 5 - Avanzado** | 18 | ~220 | 15-25 min | Tests avanzados y performance |
| **Nivel 6 - DWH** | 4 | ~45 | 8-15 min | Data Warehouse Enhanced |
| **Nivel 7 - Completo** | 8 | ~68 | 10-20 min | End-to-End Integration |
| **TOTAL** | **108** | **~1,303** | **83-135 min** | |

---

## Nivel 1 - Tests Básicos (5-10 minutos)

### Objetivo

Verificar funcionalidad básica, logging, y estructura de código.

### Suites Incluidas

```bash
# 1.1 - Logging básico (18 tests, ~2 min)
bats tests/unit/bash/bash_logger_enhanced.test.bats

# 1.2 - Variables de base de datos (15 tests, ~1 min)
bats tests/unit/bash/database_variables.test.bats

# 1.3 - Formato y lint (tests estáticos, ~2 min)
bats tests/unit/bash/format_and_lint.test.bats

# 1.4 - Convenciones de nombres - funciones (tests estáticos, ~1 min)
bats tests/unit/bash/function_naming_convention.test.bats

# 1.5 - Convenciones de nombres - variables (tests estáticos, ~1 min)
bats tests/unit/bash/variable_naming_convention.test.bats

# 1.6 - Validación de ayuda en scripts (tests estáticos, ~1 min)
bats tests/unit/bash/script_help_validation.test.bats

# 1.7 - Detección de variables duplicadas (tests estáticos, ~1 min)
bats tests/unit/bash/variable_duplication.test.bats
bats tests/unit/bash/variable_duplication_detection.test.bats

# 1.8 - Consolidación de funciones (tests estáticos, ~1 min)
bats tests/unit/bash/function_consolidation.test.bats
```

### Comando Consolidado Nivel 1

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Ejecutar todos los tests básicos
bats tests/unit/bash/bash_logger_enhanced.test.bats \
     tests/unit/bash/database_variables.test.bats \
     tests/unit/bash/format_and_lint.test.bats \
     tests/unit/bash/function_naming_convention.test.bats \
     tests/unit/bash/variable_naming_convention.test.bats \
     tests/unit/bash/script_help_validation.test.bats \
     tests/unit/bash/variable_duplication.test.bats \
     tests/unit/bash/variable_duplication_detection.test.bats \
     tests/unit/bash/function_consolidation.test.bats
```

**Resultado esperado:** ✅ ~50-60 tests pasando en 5-10 minutos

---

## Nivel 2 - Tests de Validación (10-15 minutos)

### Objetivo

Validar entrada de datos, coordenadas, fechas, y formatos.

### Suites Incluidas

```bash
# 2.1 - Validación centralizada (10 tests, ~1 min)
bats tests/unit/bash/centralized_validation.test.bats

# 2.2 - Validación de coordenadas (11 tests, ~2 min)
bats tests/unit/bash/coordinate_validation_enhanced.test.bats

# 2.3 - Validación de fechas (15 tests, ~2 min)
bats tests/unit/bash/date_validation.test.bats

# 2.4 - Validación de fechas UTC (tests, ~1 min)
bats tests/unit/bash/date_validation_utc.test.bats

# 2.5 - Validación de fechas - integración (8 tests, ~1 min)
bats tests/unit/bash/date_validation_integration.test.bats

# 2.6 - Validación de boundaries (7 tests, ~1 min)
bats tests/unit/bash/boundary_validation.test.bats

# 2.7 - Validación de checksums (9 tests, ~1 min)
bats tests/unit/bash/checksum_validation.test.bats

# 2.8 - Validación de entrada (tests, ~1 min)
bats tests/unit/bash/input_validation.test.bats

# 2.9 - Validación extendida (tests, ~2 min)
bats tests/unit/bash/extended_validation.test.bats

# 2.10 - Validación de casos edge (tests, ~1 min)
bats tests/unit/bash/edge_cases_validation.test.bats

# 2.11 - Validación de SQL (tests, ~2 min)
bats tests/unit/bash/sql_validation_integration.test.bats

# 2.12 - Validación de constraints SQL (tests, ~2 min)
bats tests/unit/bash/sql_constraints_validation.test.bats
```

### Comando Consolidado Nivel 2

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Ejecutar todos los tests de validación
bats tests/unit/bash/centralized_validation.test.bats \
     tests/unit/bash/coordinate_validation_enhanced.test.bats \
     tests/unit/bash/date_validation.test.bats \
     tests/unit/bash/date_validation_utc.test.bats \
     tests/unit/bash/date_validation_integration.test.bats \
     tests/unit/bash/boundary_validation.test.bats \
     tests/unit/bash/checksum_validation.test.bats \
     tests/unit/bash/input_validation.test.bats \
     tests/unit/bash/extended_validation.test.bats \
     tests/unit/bash/edge_cases_validation.test.bats \
     tests/unit/bash/sql_validation_integration.test.bats \
     tests/unit/bash/sql_constraints_validation.test.bats
```

**Resultado esperado:** ✅ ~100-120 tests pasando en 10-15 minutos

---

## Nivel 3 - Tests de XML/XSLT (8-12 minutos)

### Objetivo

Validar procesamiento de XML y transformaciones XSLT.

### Suites Incluidas

```bash
# 3.1 - Validación de enum en CSV (9 tests, ~1 min)
bats tests/unit/bash/csv_enum_validation.test.bats

# 3.2 - Formato de enum en XSLT (tests, ~2 min)
bats tests/unit/bash/xslt_enum_format.test.bats

# 3.3 - Validación de enum en XSLT (tests, ~2 min)
bats tests/unit/bash/xslt_enum_validation.test.bats

# 3.4 - XSLT simple (tests, ~1 min)
bats tests/unit/bash/xslt_simple.test.bats

# 3.5 - XSLT formato CSV (tests, ~2 min)
bats tests/unit/bash/xslt_csv_format.test.bats

# 3.6 - XSLT recursión en notas grandes (tests, ~2 min)
bats tests/unit/bash/xslt_large_notes_recursion.test.bats

# 3.7 - Validación XML simple (tests, ~2 min)
bats tests/unit/bash/xml_validation_simple.test.bats

# 3.8 - Validación XML mejorada (tests, ~2 min)
bats tests/unit/bash/xml_validation_enhanced.test.bats

# 3.9 - Funciones de validación XML (tests, ~2 min)
bats tests/unit/bash/xml_validation_functions.test.bats

# 3.10 - Validación XML archivos grandes (tests, ~3 min)
bats tests/unit/bash/xml_validation_large_files.test.bats

# 3.11 - Procesamiento XML mejorado (tests, ~2 min)
bats tests/unit/bash/xml_processing_enhanced.test.bats

# 3.12 - Recuperación de corrupción XML (tests, ~2 min)
bats tests/unit/bash/xml_corruption_recovery.test.bats

# 3.13 - Límites de recursos XML (tests, ~2 min)
bats tests/unit/bash/resource_limits.test.bats
```

### Comando Consolidado Nivel 3

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Ejecutar todos los tests de XML/XSLT
bats tests/unit/bash/csv_enum_validation.test.bats \
     tests/unit/bash/xslt_enum_format.test.bats \
     tests/unit/bash/xslt_enum_validation.test.bats \
     tests/unit/bash/xslt_simple.test.bats \
     tests/unit/bash/xslt_csv_format.test.bats \
     tests/unit/bash/xslt_large_notes_recursion.test.bats \
     tests/unit/bash/xml_validation_simple.test.bats \
     tests/unit/bash/xml_validation_enhanced.test.bats \
     tests/unit/bash/xml_validation_functions.test.bats \
     tests/unit/bash/xml_validation_large_files.test.bats \
     tests/unit/bash/xml_processing_enhanced.test.bats \
     tests/unit/bash/xml_corruption_recovery.test.bats \
     tests/unit/bash/resource_limits.test.bats
```

**Resultado esperado:** ✅ ~80-100 tests pasando en 8-12 minutos

---

## Nivel 4 - Tests de Procesamiento (15-25 minutos)

### Objetivo

Validar procesamiento de datos API y Planet.

### Suites Incluidas

```bash
# 4.1 - ProcessAPI básico (tests, ~2 min)
bats tests/unit/bash/processAPINotes.test.bats

# 4.2 - ProcessAPI integración (tests, ~3 min)
bats tests/unit/bash/processAPINotes_integration.test.bats

# 4.3 - ProcessAPI error handling mejorado (tests, ~2 min)
bats tests/unit/bash/processAPINotes_error_handling_improved.test.bats

# 4.4 - ProcessAPI parallel error (tests, ~2 min)
bats tests/unit/bash/processAPINotes_parallel_error.test.bats

# 4.5 - ProcessAPI validación histórica (tests, ~2 min)
bats tests/unit/bash/historical_data_validation.test.bats

# 4.6 - ProcessAPI integración histórica (tests, ~2 min)
bats tests/unit/bash/processAPI_historical_integration.test.bats

# 4.7 - API download verification (6 tests, ~2 min)
bats tests/unit/bash/api_download_verification.test.bats

# 4.8 - ProcessPlanet básico (tests, ~2 min)
bats tests/unit/bash/processPlanetNotes.test.bats

# 4.9 - ProcessPlanet integración (tests, ~3 min)
bats tests/unit/bash/processPlanetNotes_integration.test.bats

# 4.10 - ProcessPlanet integración fixed (tests, ~3 min)
bats tests/unit/bash/processPlanetNotes_integration_fixed.test.bats

# 4.11 - Mock planet functions (tests, ~2 min)
bats tests/unit/bash/mock_planet_functions.test.bats
```

### Comando Consolidado Nivel 4

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Ejecutar todos los tests de procesamiento
bats tests/unit/bash/processAPINotes.test.bats \
     tests/unit/bash/processAPINotes_integration.test.bats \
     tests/unit/bash/processAPINotes_error_handling_improved.test.bats \
     tests/unit/bash/processAPINotes_parallel_error.test.bats \
     tests/unit/bash/historical_data_validation.test.bats \
     tests/unit/bash/processAPI_historical_integration.test.bats \
     tests/unit/bash/api_download_verification.test.bats \
     tests/unit/bash/processPlanetNotes.test.bats \
     tests/unit/bash/processPlanetNotes_integration.test.bats \
     tests/unit/bash/processPlanetNotes_integration_fixed.test.bats \
     tests/unit/bash/mock_planet_functions.test.bats
```

**Resultado esperado:** ✅ ~120-150 tests pasando en 15-25 minutos

---

## Nivel 5 - Tests de Procesamiento Paralelo (10-15 minutos)

### Objetivo

Validar optimización y procesamiento paralelo.

### Suites Incluidas

```bash
# 5.1 - Suite completa de parallel processing (21 tests, ~5 min)
bats tests/parallel_processing_test_suite.bats

# 5.2 - Parallel processing robusto (tests, ~2 min)
bats tests/unit/bash/parallel_processing_robust.test.bats

# 5.3 - Parallel processing optimización (tests, ~2 min)
bats tests/unit/bash/parallel_processing_optimization.test.bats

# 5.4 - Parallel processing validación (tests, ~2 min)
bats tests/unit/bash/parallel_processing_validation.test.bats

# 5.5 - Parallel threshold (tests, ~1 min)
bats tests/unit/bash/parallel_threshold.test.bats

# 5.6 - Parallel delay test (tests, ~2 min)
bats tests/unit/bash/parallel_delay_test.bats

# 5.7 - Parallel delay test simple (tests, ~1 min)
bats tests/unit/bash/parallel_delay_test_simple.bats

# 5.8 - Parallel failed file (tests, ~1 min)
bats tests/unit/bash/parallel_failed_file.test.bats

# 5.9 - Binary division performance (14 tests, ~2 min)
bats tests/unit/bash/binary_division_performance.test.bats
```

### Comando Consolidado Nivel 5

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Ejecutar todos los tests de procesamiento paralelo
bats tests/parallel_processing_test_suite.bats \
     tests/unit/bash/parallel_processing_robust.test.bats \
     tests/unit/bash/parallel_processing_optimization.test.bats \
     tests/unit/bash/parallel_processing_validation.test.bats \
     tests/unit/bash/parallel_threshold.test.bats \
     tests/unit/bash/parallel_delay_test.bats \
     tests/unit/bash/parallel_delay_test_simple.bats \
     tests/unit/bash/parallel_failed_file.test.bats \
     tests/unit/bash/binary_division_performance.test.bats
```

**Resultado esperado:** ✅ ~80-100 tests pasando en 10-15 minutos

---

## Nivel 6 - Tests de Cleanup y Error Handling (12-18 minutos)

### Objetivo

Validar limpieza de recursos y manejo de errores.

### Suites Incluidas

```bash
# 6.1 - CleanupAll integración (16 tests, ~3 min)
bats tests/unit/bash/cleanupAll_integration.test.bats

# 6.2 - CleanupAll básico (10 tests, ~2 min)
bats tests/unit/bash/cleanupAll.test.bats

# 6.3 - Clean flag handling (6 tests, ~1 min)
bats tests/unit/bash/clean_flag_handling.test.bats

# 6.4 - Clean flag simple (5 tests, ~1 min)
bats tests/unit/bash/clean_flag_simple.test.bats

# 6.5 - Clean flag exit trap (5 tests, ~1 min)
bats tests/unit/bash/clean_flag_exit_trap.test.bats

# 6.6 - Cleanup behavior (5 tests, ~1 min)
bats tests/unit/bash/cleanup_behavior.test.bats

# 6.7 - Cleanup behavior simple (3 tests, ~1 min)
bats tests/unit/bash/cleanup_behavior_simple.test.bats

# 6.8 - Cleanup order (7 tests, ~1 min)
bats tests/unit/bash/cleanup_order.test.bats

# 6.9 - Cleanup dependency fix (4 tests, ~1 min)
bats tests/unit/bash/cleanup_dependency_fix.test.bats

# 6.10 - Error handling (tests, ~2 min)
bats tests/unit/bash/error_handling.test.bats

# 6.11 - Error handling enhanced (tests, ~2 min)
bats tests/unit/bash/error_handling_enhanced.test.bats

# 6.12 - Error handling consolidated (tests, ~2 min)
bats tests/unit/bash/error_handling_consolidated.test.bats
```

### Comando Consolidado Nivel 6

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Ejecutar todos los tests de cleanup y error handling
bats tests/unit/bash/cleanupAll_integration.test.bats \
     tests/unit/bash/cleanupAll.test.bats \
     tests/unit/bash/clean_flag_handling.test.bats \
     tests/unit/bash/clean_flag_simple.test.bats \
     tests/unit/bash/clean_flag_exit_trap.test.bats \
     tests/unit/bash/cleanup_behavior.test.bats \
     tests/unit/bash/cleanup_behavior_simple.test.bats \
     tests/unit/bash/cleanup_order.test.bats \
     tests/unit/bash/cleanup_dependency_fix.test.bats \
     tests/unit/bash/error_handling.test.bats \
     tests/unit/bash/error_handling_enhanced.test.bats \
     tests/unit/bash/error_handling_consolidated.test.bats
```

**Resultado esperado:** ✅ ~100-120 tests pasando en 12-18 minutos

---

## Nivel 7 - Tests de Monitoreo y WMS (8-12 minutos)

### Objetivo

Validar monitoreo, WMS, y otros componentes.

### Suites Incluidas

```bash
# 7.1 - Monitoring (tests, ~2 min)
bats tests/unit/bash/monitoring.test.bats

# 7.2 - Notes check verifier integración (tests, ~2 min)
bats tests/unit/bash/notesCheckVerifier_integration.test.bats

# 7.3 - Process check planet notes integración (tests, ~2 min)
bats tests/unit/bash/processCheckPlanetNotes_integration.test.bats

# 7.4 - WMS Manager (tests, ~2 min)
bats tests/unit/bash/wmsManager.test.bats

# 7.5 - WMS Manager integración (tests, ~2 min)
bats tests/unit/bash/wmsManager_integration.test.bats

# 7.6 - WMS config example integración (tests, ~1 min)
bats tests/unit/bash/wmsConfigExample_integration.test.bats

# 7.7 - GeoServer config integración (tests, ~1 min)
bats tests/unit/bash/geoserverConfig_integration.test.bats

# 7.8 - Update countries integración (tests, ~1 min)
bats tests/unit/bash/updateCountries_integration.test.bats
```

### Comando Consolidado Nivel 7

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Ejecutar todos los tests de monitoreo y WMS
bats tests/unit/bash/monitoring.test.bats \
     tests/unit/bash/notesCheckVerifier_integration.test.bats \
     tests/unit/bash/processCheckPlanetNotes_integration.test.bats \
     tests/unit/bash/wmsManager.test.bats \
     tests/unit/bash/wmsManager_integration.test.bats \
     tests/unit/bash/wmsConfigExample_integration.test.bats \
     tests/unit/bash/geoserverConfig_integration.test.bats \
     tests/unit/bash/updateCountries_integration.test.bats
```

**Resultado esperado:** ✅ ~50-70 tests pasando en 8-12 minutos

---

## Nivel 8 - Tests Avanzados y Casos Edge (10-15 minutos)

### Objetivo

Validar casos edge, performance, y funcionalidad avanzada.

### Suites Incluidas

```bash
# 8.1 - Performance edge cases (tests, ~3 min)
bats tests/unit/bash/performance_edge_cases.test.bats

# 8.2 - Performance edge cases simple (tests, ~2 min)
bats tests/unit/bash/performance_edge_cases_simple.test.bats

# 8.3 - Performance edge cases quick (tests, ~2 min)
bats tests/unit/bash/performance_edge_cases_quick.test.bats

# 8.4 - Edge cases integration (tests, ~2 min)
bats tests/unit/bash/edge_cases_integration.test.bats

# 8.5 - Real data integration (tests, ~2 min)
bats tests/unit/bash/real_data_integration.test.bats

# 8.6 - Hybrid integration (tests, ~2 min)
bats tests/unit/bash/hybrid_integration.test.bats

# 8.7 - Script execution integration (tests, ~2 min)
bats tests/unit/bash/script_execution_integration.test.bats

# 8.8 - Profile integration (tests, ~1 min)
bats tests/unit/bash/profile_integration.test.bats

# 8.9 - Functions process (tests, ~2 min)
bats tests/unit/bash/functionsProcess.test.bats

# 8.10 - Functions process enhanced (tests, ~2 min)
bats tests/unit/bash/functionsProcess_enhanced.test.bats

# 8.11 - Prerequisites enhanced (tests, ~2 min)
bats tests/unit/bash/prerequisites_enhanced.test.bats

# 8.12 - Logging improvements (tests, ~2 min)
bats tests/unit/bash/logging_improvements.test.bats

# 8.13 - Logging pattern validation (tests, ~2 min)
bats tests/unit/bash/logging_pattern_validation.test.bats
```

### Comando Consolidado Nivel 8

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Ejecutar todos los tests avanzados
bats tests/unit/bash/performance_edge_cases.test.bats \
     tests/unit/bash/performance_edge_cases_simple.test.bats \
     tests/unit/bash/performance_edge_cases_quick.test.bats \
     tests/unit/bash/edge_cases_integration.test.bats \
     tests/unit/bash/real_data_integration.test.bats \
     tests/unit/bash/hybrid_integration.test.bats \
     tests/unit/bash/script_execution_integration.test.bats \
     tests/unit/bash/profile_integration.test.bats \
     tests/unit/bash/functionsProcess.test.bats \
     tests/unit/bash/functionsProcess_enhanced.test.bats \
     tests/unit/bash/prerequisites_enhanced.test.bats \
     tests/unit/bash/logging_improvements.test.bats \
     tests/unit/bash/logging_pattern_validation.test.bats
```

**Resultado esperado:** ✅ ~100-130 tests pasando en 10-15 minutos

---

## Nivel 9 - Tests de Integración End-to-End (10-20 minutos)

### Objetivo

Validar flujos completos de ingesta y procesamiento.

### Suites Incluidas

```bash
# 9.1 - Boundary processing error integration (16 tests, ~4 min)
bats tests/integration/boundary_processing_error_integration.test.bats

# 9.2 - WMS integration (10 tests, ~3 min)
bats tests/integration/wms_integration.test.bats

# 9.3 - Logging pattern validation integration (9 tests, ~2 min)
bats tests/integration/logging_pattern_validation_integration.test.bats

# 9.4 - Mock planet processing (8 tests, ~2 min)
bats tests/integration/mock_planet_processing.test.bats

# 9.5 - ProcessAPI parallel error integration (7 tests, ~2 min)
bats tests/integration/processAPINotes_parallel_error_integration.test.bats

# 9.6 - XSLT integration (7 tests, ~2 min)
bats tests/integration/xslt_integration.test.bats

# 9.7 - End to end (6 tests, ~3 min)
bats tests/integration/end_to_end.test.bats

# 9.8 - ProcessAPI historical e2e (5 tests, ~2 min)
bats tests/integration/processAPI_historical_e2e.test.bats
```

### Comando Consolidado Nivel 9

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Ejecutar todos los tests de integración
bats tests/integration/boundary_processing_error_integration.test.bats \
     tests/integration/wms_integration.test.bats \
     tests/integration/logging_pattern_validation_integration.test.bats \
     tests/integration/mock_planet_processing.test.bats \
     tests/integration/processAPINotes_parallel_error_integration.test.bats \
     tests/integration/xslt_integration.test.bats \
     tests/integration/end_to_end.test.bats \
     tests/integration/processAPI_historical_e2e.test.bats
```

**Resultado esperado:** ✅ ~68 tests pasando en 10-20 minutos

---

## Nivel 10 - Tests de DWH Enhanced (10-15 minutos)

### Objetivo

Validar funcionalidad de Data Warehouse mejorado.

### Prerequisito

```bash
# Asegurar que el esquema DWH esté instalado
export PGPASSWORD=your_password
psql -U notes -d notes -f sql/dwh/ETL_22_createDWHTables.sql
psql -U notes -d notes -f sql/dwh/ETL_24_addFunctions.sql
psql -U notes -d notes -f sql/dwh/ETL_25_populateDimensionTables.sql
```

### Suites Incluidas

```bash
# 10.1 - DWH dimensions enhanced (SQL, ~5 min)
psql -U notes -d notes -f tests/unit/sql/dwh_dimensions_enhanced.test.sql

# 10.2 - DWH functions enhanced (SQL, ~5 min)
psql -U notes -d notes -f tests/unit/sql/dwh_functions_enhanced.test.sql

# 10.3 - ETL enhanced integration (BATS, ~5 min)
bats tests/integration/ETL_enhanced_integration.test.bats

# 10.4 - Datamart enhanced integration (BATS, ~5 min)
bats tests/integration/datamart_enhanced_integration.test.bats
```

### Comando Consolidado Nivel 10

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Opción A: Usar el script consolidado
./tests/run_dwh_tests.sh

# Opción B: Ejecutar manualmente
psql -U notes -d notes -f tests/unit/sql/dwh_dimensions_enhanced.test.sql
psql -U notes -d notes -f tests/unit/sql/dwh_functions_enhanced.test.sql
bats tests/integration/ETL_enhanced_integration.test.bats
bats tests/integration/datamart_enhanced_integration.test.bats
```

**Resultado esperado:** ✅ ~45 tests pasando en 10-15 minutos

---

## Secuencia Rápida (Quick Check - 15-20 minutos)

Para una verificación rápida antes de commit:

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Suite rápida - tests críticos
bats tests/unit/bash/bash_logger_enhanced.test.bats \
     tests/unit/bash/format_and_lint.test.bats \
     tests/unit/bash/centralized_validation.test.bats \
     tests/unit/bash/coordinate_validation_enhanced.test.bats \
     tests/unit/bash/date_validation.test.bats \
     tests/unit/bash/csv_enum_validation.test.bats \
     tests/unit/bash/processAPINotes.test.bats \
     tests/unit/bash/processPlanetNotes.test.bats \
     tests/parallel_processing_test_suite.bats \
     tests/unit/bash/error_handling_consolidated.test.bats
```

**Resultado esperado:** ✅ ~150-180 tests críticos en 15-20 minutos

---

## Secuencia Completa (Full Test Suite)

### Opción 1: Ejecutar nivel por nivel

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Nivel 1 - Básico
bats tests/unit/bash/bash_logger_enhanced.test.bats \
     tests/unit/bash/database_variables.test.bats \
     tests/unit/bash/format_and_lint.test.bats

# Nivel 2 - Validación
bats tests/unit/bash/centralized_validation.test.bats \
     tests/unit/bash/coordinate_validation_enhanced.test.bats \
     tests/unit/bash/date_validation.test.bats

# ... continuar con cada nivel ...
```

### Opción 2: Script automatizado

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Crear y ejecutar script de secuencia completa
cat > run_tests_sequential.sh << 'EOF'
#!/bin/bash

set -euo pipefail

echo "=== Nivel 1: Tests Básicos ==="
bats tests/unit/bash/bash_logger_enhanced.test.bats \
     tests/unit/bash/database_variables.test.bats \
     tests/unit/bash/format_and_lint.test.bats

echo "=== Nivel 2: Tests de Validación ==="
bats tests/unit/bash/centralized_validation.test.bats \
     tests/unit/bash/coordinate_validation_enhanced.test.bats

# ... agregar más niveles según necesidad ...

echo "=== ✅ Secuencia completa finalizada ==="
EOF

chmod +x run_tests_sequential.sh
./run_tests_sequential.sh
```

---

## Scripts de Ejecución por Categoría

### Por Funcionalidad

```bash
# ProcessAPI completo
bats tests/unit/bash/processAPINotes*.bats \
     tests/unit/bash/api_download_verification.test.bats \
     tests/unit/bash/historical_data_validation.test.bats

# ProcessPlanet completo
bats tests/unit/bash/processPlanetNotes*.bats \
     tests/unit/bash/mock_planet_functions.test.bats

# XML/XSLT completo
bats tests/unit/bash/xml*.bats tests/unit/bash/xslt*.bats

# Parallel Processing completo
bats tests/parallel_processing_test_suite.bats \
     tests/unit/bash/parallel*.bats

# Cleanup completo
bats tests/unit/bash/cleanup*.bats tests/unit/bash/clean*.bats

# WMS completo
bats tests/unit/bash/wms*.bats tests/integration/wms_integration.test.bats
```

---

## Monitoreo de Progreso

### Script con indicadores de progreso

```bash
#!/bin/bash

TOTAL_LEVELS=10
CURRENT_LEVEL=0

run_level() {
  local level=$1
  local description=$2
  CURRENT_LEVEL=$level
  
  echo ""
  echo "╔════════════════════════════════════════╗"
  echo "║  Nivel $level/$TOTAL_LEVELS: $description"
  echo "╚════════════════════════════════════════╝"
  echo ""
}

# Nivel 1
run_level 1 "Tests Básicos"
bats tests/unit/bash/bash_logger_enhanced.test.bats

# Nivel 2
run_level 2 "Tests de Validación"
bats tests/unit/bash/centralized_validation.test.bats

# ... continuar ...

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✅ Todos los niveles completados!"
echo "╚════════════════════════════════════════╝"
```

---

## Recomendaciones de Uso

### Durante Desarrollo Activo

1. **Commit rápido:** Nivel 1 + Nivel 2 (~15 min)
2. **Antes de push:** Niveles 1-5 (~45 min)
3. **Antes de merge:** Niveles 1-9 (~90 min)
4. **Release:** Todos los niveles (~135 min)

### Para Debugging

1. Ejecutar nivel específico de la funcionalidad afectada
2. Ejecutar suite específica del componente
3. Ejecutar test individual: `bats archivo.bats -f "nombre del test"`

### Para CI/CD

1. GitHub Actions ejecuta todos automáticamente
2. Para testing local de CI: `./tests/run_all_tests.sh --mode docker`

---

## Troubleshooting

### Test falla en un nivel

```bash
# Re-ejecutar solo ese nivel con verbose
bats -t tests/unit/bash/archivo_que_fallo.test.bats

# Ver detalles de un test específico
bats tests/unit/bash/archivo.test.bats -f "nombre exacto del test"
```

### PostgreSQL no disponible

```bash
# Verificar que PostgreSQL esté corriendo
sudo systemctl status postgresql

# Iniciar PostgreSQL
sudo systemctl start postgresql

# Verificar conexión
psql -U notes -d notes -c "SELECT 1;"
```

### Tests muy lentos

```bash
# Ejecutar solo quick check
bats tests/unit/bash/format_and_lint.test.bats

# Usar modo mock para tests sin BD
./tests/run_all_tests.sh --mode mock --type unit
```

---

## Resumen de Comandos Clave

```bash
# Verificación rápida (15-20 min)
./tests/run_tests_sequential.sh quick

# Nivel específico (ejemplo: Nivel 3 - XML/XSLT)
bats tests/unit/bash/xml*.bats tests/unit/bash/xslt*.bats

# Suite específica
bats tests/unit/bash/processAPINotes.test.bats

# Test individual
bats tests/unit/bash/processAPINotes.test.bats -f "test_nombre_especifico"

# Todos los tests unitarios
bats tests/unit/bash/*.bats

# Todos los tests de integración
bats tests/integration/*.bats

# DWH completo
./tests/run_dwh_tests.sh

# Todo (no recomendado localmente, usar CI)
./tests/run_all_tests.sh --mode host --type all
```

---

**Última actualización:** 2025-10-14  
**Mantenedor:** Andres Gomez (AngocA)
