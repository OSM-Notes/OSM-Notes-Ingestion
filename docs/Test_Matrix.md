# Matriz de Pruebas - OSM Notes Ingestion

**Versión:** 2025-10-14  
**Autor:** Andres Gomez (AngocA)

## Tabla Resumen - Tipos de Ejecución

| Tipo de Ejecución | Requisitos | Scripts | Descripción |
|-------------------|------------|---------|-------------|
| **Local (Host)** | PostgreSQL local, BATS, herramientas XML | `run_all_tests.sh --mode host` | Ejecución directa en el sistema host |
| **Docker** | Docker, Docker Compose | `run_all_tests.sh --mode docker` | Ejecución en contenedores aislados |
| **GitHub Actions** | GitHub repository, workflows configurados | `.github/workflows/*.yml` | Ejecución automática en CI/CD |
| **Mock** | BATS, comandos mock | `run_all_tests.sh --mode mock` | Ejecución sin dependencias externas |

---

## Matriz Principal - Suites de Pruebas por Tipo de Ejecución

### Resumen de Cobertura

| Suite de Pruebas | Archivos | Tests | Local | Docker | GitHub | Mock | Tiempo Estimado |
|------------------|----------|-------|-------|--------|--------|------|-----------------|
| **Unit Tests (Bash)** | 86 | ~946 | ✅ | ✅ | ✅ | ✅ | 15-30 min |
| **Unit Tests (SQL)** | 6 | ~120 | ✅ | ✅ | ✅ | ❌ | 5-10 min |
| **Integration Tests** | 8 | 68 | ✅ | ✅ | ✅ | ⚠️ | 10-20 min |
| **Parallel Processing** | 1 | 21 | ✅ | ✅ | ✅ | ✅ | 5-10 min |
| **DWH Enhanced** | 4 | ~45 | ✅ | ✅ | ✅ | ❌ | 8-15 min |
| **Advanced - Coverage** | - | - | ✅ | ✅ | ✅ | ❌ | 10-15 min |
| **Advanced - Security** | - | - | ✅ | ✅ | ✅ | ✅ | 3-5 min |
| **Advanced - Quality** | - | - | ✅ | ✅ | ✅ | ✅ | 5-10 min |
| **Advanced - Performance** | - | - | ✅ | ✅ | ✅ | ⚠️ | 5-10 min |
| **Docker Integration** | 15+ | varies | ❌ | ✅ | ✅ | ❌ | 10-20 min |
| **WMS Tests** | 3 | ~20 | ✅ | ✅ | ✅ | ⚠️ | 5-8 min |
| **XSLT Tests** | 5 | ~35 | ✅ | ✅ | ✅ | ✅ | 3-5 min |
| **TOTAL** | **128+** | **~1,290+** | - | - | - | - | **84-163 min** |

**Leyenda:**

- ✅ Completamente soportado
- ⚠️ Parcialmente soportado (requiere configuración adicional)
- ❌ No soportado en este entorno

---

## Detalle de Suites de Pruebas Unitarias (Bash)

### Categorías de Pruebas Unitarias

| Categoría | Archivos | Tests Aprox. | Descripción |
|-----------|----------|--------------|-------------|
| **ProcessAPI** | 7 | ~85 | Procesamiento de API incremental |
| **ProcessPlanet** | 6 | ~75 | Procesamiento de Planet dump completo |
| **Parallel Processing** | 6 | ~68 | Procesamiento paralelo y optimización |
| **XML Processing** | 9 | ~95 | Validación y transformación XML/XSLT |
| **Validation** | 12 | ~140 | Validación de datos (coordenadas, fechas, etc.) |
| **Error Handling** | 8 | ~82 | Manejo de errores y recuperación |
| **Cleanup** | 7 | ~60 | Limpieza y mantenimiento |
| **WMS** | 3 | ~28 | Web Map Service integration |
| **Monitoring** | 5 | ~48 | Monitoreo y verificación |
| **Database** | 4 | ~50 | Variables y funciones de base de datos |
| **Integration** | 10 | ~115 | Pruebas de integración de scripts |
| **Quality & Format** | 9 | ~100 | Calidad de código y formato |
| **TOTAL** | **86** | **~946** | |

### Top 20 Suites de Pruebas Unitarias (por cantidad de tests)

| # | Archivo | Tests | Categoría | Prioridad |
|---|---------|-------|-----------|-----------|
| 1 | `bash_logger_enhanced.test.bats` | 18 | Logging | Alta |
| 2 | `cleanupAll_integration.test.bats` | 16 | Cleanup | Alta |
| 3 | `date_validation.test.bats` | 15 | Validation | Alta |
| 4 | `database_variables.test.bats` | 15 | Database | Media |
| 5 | `binary_division_performance.test.bats` | 14 | Performance | Media |
| 6 | `coordinate_validation_enhanced.test.bats` | 11 | Validation | Alta |
| 7 | `centralized_validation.test.bats` | 10 | Validation | Alta |
| 8 | `cleanupAll.test.bats` | 10 | Cleanup | Alta |
| 9 | `checksum_validation.test.bats` | 9 | Validation | Media |
| 10 | `csv_enum_validation.test.bats` | 9 | XSLT | Alta |
| 11 | `date_validation_integration.test.bats` | 8 | Validation | Alta |
| 12 | `boundary_validation.test.bats` | 7 | Validation | Media |
| 13 | `cleanup_order.test.bats` | 7 | Cleanup | Media |
| 14 | `api_download_verification.test.bats` | 6 | ProcessAPI | Alta |
| 15 | `clean_flag_handling.test.bats` | 6 | Cleanup | Media |
| 16 | `clean_flag_exit_trap.test.bats` | 5 | Cleanup | Media |
| 17 | `clean_flag_simple.test.bats` | 5 | Cleanup | Media |
| 18 | `cleanup_behavior.test.bats` | 5 | Cleanup | Media |
| 19 | `cleanup_dependency_fix.test.bats` | 4 | Cleanup | Media |
| 20 | `cleanup_behavior_simple.test.bats` | 3 | Cleanup | Media |

---

## Detalle de Suites de Pruebas de Integración

| # | Archivo | Tests | Descripción | Componentes |
|---|---------|-------|-------------|-------------|
| 1 | `boundary_processing_error_integration.test.bats` | 16 | Procesamiento de boundaries con errores | ProcessPlanet, Boundaries |
| 2 | `wms_integration.test.bats` | 10 | Integración con WMS | WMS, GeoServer |
| 3 | `logging_pattern_validation_integration.test.bats` | 9 | Validación de patrones de logging | Logging, Validation |
| 4 | `mock_planet_processing.test.bats` | 8 | Procesamiento Planet con mocks | ProcessPlanet, Mock |
| 5 | `processAPINotes_parallel_error_integration.test.bats` | 7 | ProcessAPI con errores paralelos | ProcessAPI, Parallel |
| 6 | `xslt_integration.test.bats` | 7 | Integración de transformaciones XSLT | XSLT, XML |
| 7 | `end_to_end.test.bats` | 6 | Flujo completo de ingesta | Full workflow |
| 8 | `processAPI_historical_e2e.test.bats` | 5 | ProcessAPI con datos históricos | ProcessAPI, Historical |
| **TOTAL** | **8** | **68** | | |

---

## Detalle de Pruebas DWH (Data Warehouse Enhanced)

| Tipo | Archivos | Tests Aprox. | Descripción |
|------|----------|--------------|-------------|
| **SQL Unit Tests** | 2 | ~30 | Dimensiones y funciones DWH |
| **Integration Tests** | 2 | ~15 | ETL y Datamarts mejorados |
| **TOTAL** | **4** | **~45** | |

### Archivos DWH

1. `tests/unit/sql/dwh_dimensions_enhanced.test.sql` (~15 tests)
   - Nuevas dimensiones (timezones, seasons, continents)
   - Dimensiones mejoradas (time_of_week, users SCD2)
   - Validación de estructura

2. `tests/unit/sql/dwh_functions_enhanced.test.sql` (~15 tests)
   - Nuevas funciones (timezone, season, application version)
   - Funciones mejoradas (date, time_of_week)
   - Bridge tables (hashtags)

3. `tests/integration/ETL_enhanced_integration.test.bats` (~8 tests)
   - Validación de ETL mejorado
   - SCD2 implementation
   - Staging procedures

4. `tests/integration/datamart_enhanced_integration.test.bats` (~7 tests)
   - DatamartUsers enhanced
   - DatamartCountries enhanced
   - Integración con nuevas dimensiones

---

## Detalle de Pruebas Avanzadas

### Coverage Tests

| Tipo | Herramienta | Descripción | Local | Docker | GitHub |
|------|-------------|-------------|-------|--------|--------|
| Bash Coverage | kcov | Cobertura de scripts Bash | ✅ | ✅ | ✅ |
| SQL Coverage | pgtap | Cobertura de funciones SQL | ✅ | ✅ | ✅ |
| Coverage Report | custom | Reporte consolidado | ✅ | ✅ | ✅ |

### Security Tests

| Tipo | Herramienta | Descripción | Local | Docker | GitHub |
|------|-------------|-------------|-------|--------|--------|
| ShellCheck | shellcheck | Análisis estático de Bash | ✅ | ✅ | ✅ |
| Security Scan | custom | Búsqueda de credenciales hardcoded | ✅ | ✅ | ✅ |
| Permission Check | custom | Verificación de permisos de archivos | ✅ | ✅ | ✅ |

### Quality Tests

| Tipo | Herramienta | Descripción | Local | Docker | GitHub |
|------|-------------|-------------|-------|--------|--------|
| Format Check | shfmt | Formato de código Bash | ✅ | ✅ | ✅ |
| Naming Convention | custom | Validación de nombres de variables/funciones | ✅ | ✅ | ✅ |
| Variable Duplication | custom | Detección de variables duplicadas | ✅ | ✅ | ✅ |
| Script Help | custom | Validación de mensajes de ayuda | ✅ | ✅ | ✅ |

### Performance Tests

| Tipo | Descripción | Local | Docker | GitHub |
|------|-------------|-------|--------|--------|
| Binary Division | Optimización de división binaria | ✅ | ✅ | ✅ |
| Parallel Processing | Performance de procesamiento paralelo | ✅ | ✅ | ✅ |
| Large Files | Procesamiento de archivos grandes | ✅ | ✅ | ⚠️ |
| Edge Cases | Casos extremos de performance | ✅ | ✅ | ⚠️ |

---

## Workflows de GitHub Actions

### Workflow: tests.yml (Principal)

| Job | Tests | Tiempo Aprox. | Dependencias |
|-----|-------|---------------|--------------|
| `unit-tests` | ~946 | 20-30 min | PostgreSQL 16 |
| `dwh-enhanced-tests` | ~45 | 10-15 min | PostGIS 16 |
| `integration-tests` | varies | 15-25 min | Docker |
| `performance-tests` | varies | 10-15 min | PostgreSQL 16 |
| `security-tests` | static | 5-8 min | shellcheck |
| `advanced-tests` | varies | 15-20 min | PostGIS 15, kcov |
| `test-summary` | - | 2-3 min | Todos los jobs |
| **TOTAL** | - | **77-116 min** | |

### Workflow: integration-tests.yml

| Job | Tests | Tiempo Aprox. | Descripción |
|-----|-------|---------------|-------------|
| `integration-tests` | 68 | 15-25 min | Todas las pruebas de integración |

### Workflow: quality-tests.yml

| Job | Tests | Tiempo Aprox. | Descripción |
|-----|-------|---------------|-------------|
| `shellcheck` | static | 5-8 min | Análisis estático de todos los scripts |
| `bats-tests` | varies | 10-15 min | Pruebas BATS críticas |
| `integration-tests-quick` | subset | 8-12 min | Subset de pruebas de integración |
| `security-scan` | static | 3-5 min | Escaneo de seguridad |
| `code-quality` | static | 3-5 min | Validación de formato |
| **TOTAL** | - | **29-45 min** | |

---

## Scripts de Ejecución

### Scripts Principales

| Script | Modo | Descripción | Uso |
|--------|------|-------------|-----|
| `run_all_tests.sh` | Universal | Runner maestro consolidado | `./tests/run_all_tests.sh --mode [host\|mock\|docker\|ci] --type [all\|unit\|integration\|quality\|dwh]` |
| `run_tests.sh` | Host | Runner maestro original | `./tests/run_tests.sh [--db\|--mock\|--simple\|--all]` |
| `run_tests_simple.sh` | Host | Pruebas básicas sin Docker | `./tests/run_tests_simple.sh` |
| `run_mock_tests.sh` | Mock | Pruebas con mocks | `./tests/run_mock_tests.sh [--unit\|--integration\|--all]` |
| `run_integration_tests.sh` | Host/Docker | Pruebas de integración | `./tests/run_integration_tests.sh [--all\|--process-api\|--process-planet\|--cleanup\|--wms]` |
| `run_dwh_tests.sh` | Host | Pruebas DWH enhanced | `./tests/run_dwh_tests.sh [--skip-sql\|--skip-integration]` |

### Scripts Docker

| Script | Descripción | Ubicación |
|--------|-------------|-----------|
| `docker-compose.yml` | Ambiente Docker estándar | `tests/docker/` |
| `docker-compose.ci.yml` | Ambiente Docker para CI | `tests/docker/` |
| `docker-compose.test.yml` | Ambiente Docker para tests | `tests/docker/` |
| `run_ci_tests.sh` | Ejecución de tests en Docker CI | `tests/docker/` |
| `run_integration_tests.sh` | Ejecución de integración en Docker | `tests/docker/` |

---

## Matriz de Comandos por Tipo de Ejecución

### Ejecución Local (Host)

```bash
# Todas las pruebas
./tests/run_all_tests.sh --mode host --type all

# Solo pruebas unitarias
./tests/run_all_tests.sh --mode host --type unit

# Solo pruebas de integración
./tests/run_all_tests.sh --mode host --type integration

# Solo pruebas DWH
./tests/run_all_tests.sh --mode host --type dwh

# Solo pruebas de calidad
./tests/run_all_tests.sh --mode host --type quality
```

**Requisitos:**

- PostgreSQL instalado y corriendo
- Usuario `postgres` o `notes` con permisos
- BATS instalado
- Herramientas XML (xmllint, xsltproc)
- shellcheck, shfmt

**Tiempo estimado:** 84-163 minutos para todas las pruebas

---

### Ejecución Docker

```bash
# Todas las pruebas
./tests/run_all_tests.sh --mode docker --type all

# Solo pruebas unitarias
./tests/run_all_tests.sh --mode docker --type unit

# Solo pruebas de integración
./tests/run_all_tests.sh --mode docker --type integration
```

**Requisitos:**

- Docker instalado
- Docker Compose instalado
- Usuario en grupo `docker` (o usar sudo)

**Tiempo estimado:** 90-180 minutos para todas las pruebas (incluye tiempo de setup de contenedores)

---

### Ejecución Mock (Sin Base de Datos)

```bash
# Todas las pruebas
./tests/run_all_tests.sh --mode mock --type all

# Solo pruebas unitarias
./tests/run_all_tests.sh --mode mock --type unit

# Solo pruebas de integración (limitadas)
./tests/run_all_tests.sh --mode mock --type integration
```

**Requisitos:**

- BATS instalado
- Comandos mock en `tests/mock_commands/`

**Tiempo estimado:** 30-60 minutos (no todas las pruebas son compatibles)

---

### Ejecución CI/CD (GitHub Actions)

```bash
# Push a main/develop dispara automáticamente
git push origin main

# O manualmente desde GitHub UI:
# Actions → Tests → Run workflow
```

**Workflows disponibles:**

- `tests.yml` - Suite completa de pruebas
- `integration-tests.yml` - Pruebas de integración
- `quality-tests.yml` - Pruebas de calidad

**Tiempo estimado:** 77-116 minutos (workflow completo)

---

## Matriz de Compatibilidad de Características

| Característica | Local | Docker | GitHub | Mock |
|----------------|-------|--------|--------|------|
| **Database tests** | ✅ | ✅ | ✅ | ❌ |
| **XSLT tests** | ✅ | ✅ | ✅ | ✅ |
| **Parallel processing** | ✅ | ✅ | ✅ | ✅ |
| **WMS integration** | ✅ | ✅ | ✅ | ⚠️ |
| **DWH enhanced** | ✅ | ✅ | ✅ | ❌ |
| **Coverage reports** | ✅ | ✅ | ✅ | ❌ |
| **Security scans** | ✅ | ✅ | ✅ | ✅ |
| **Performance tests** | ✅ | ✅ | ⚠️ | ⚠️ |
| **Large file tests** | ✅ | ✅ | ❌ | ❌ |
| **End-to-end tests** | ✅ | ✅ | ✅ | ⚠️ |

---

## Recomendaciones de Uso

### Para Desarrollo Local

```bash
# Quick check antes de commit
./tests/run_all_tests.sh --mode mock --type unit

# Verificación completa
./tests/run_all_tests.sh --mode host --type all
```

### Para Integración Continua

```bash
# En GitHub Actions (automático)
# Se ejecuta tests.yml en cada push/PR

# Para debugging local de CI
./tests/run_all_tests.sh --mode docker --type all
```

### Para Testing de Características Específicas

```bash
# Testing de ProcessAPI
bats tests/unit/bash/processAPINotes*.bats

# Testing de ProcessPlanet
bats tests/unit/bash/processPlanetNotes*.bats

# Testing de XSLT
bats tests/unit/bash/xslt*.bats

# Testing de Parallel Processing
bats tests/parallel_processing_test_suite.bats

# Testing de DWH
./tests/run_dwh_tests.sh
```

---

## Métricas de Cobertura

### Cobertura por Componente

| Componente | Tests | Cobertura Estimada |
|------------|-------|--------------------|
| **ProcessAPI** | ~85 | 85-90% |
| **ProcessPlanet** | ~75 | 80-85% |
| **XSLT** | ~35 | 90-95% |
| **Parallel Processing** | ~68 | 85-90% |
| **Validation** | ~140 | 80-85% |
| **Cleanup** | ~60 | 75-80% |
| **WMS** | ~28 | 70-75% |
| **DWH** | ~45 | 75-80% |
| **Error Handling** | ~82 | 80-85% |
| **Database** | ~50 | 75-80% |

### Cobertura Global

- **Total de Tests:** ~1,290+
- **Cobertura de Código Estimada:** 80-85%
- **Cobertura de Funciones:** 85-90%
- **Cobertura de Casos de Error:** 75-80%

---

## Troubleshooting

### Problemas Comunes por Tipo de Ejecución

#### Local

```bash
# PostgreSQL no accesible
sudo systemctl start postgresql

# Usuario sin permisos
sudo -u postgres createuser -s $USER

# BATS no encontrado
sudo apt-get install bats
```

#### Docker

```bash
# Docker no disponible
sudo apt-get install docker.io docker-compose

# Permisos insuficientes
sudo usermod -aG docker $USER
# (logout/login required)

# Contenedores no inician
cd tests/docker
docker compose down -v
docker compose up -d --build
```

#### Mock

```bash
# Comandos mock no ejecutables
chmod +x tests/mock_commands/*

# Variables de entorno faltantes
source tests/properties.sh
```

#### GitHub Actions

```bash
# Workflow no se ejecuta
# - Verificar permisos de Actions en Settings
# - Verificar sintaxis YAML
# - Revisar logs en Actions tab
```

---

## Recursos Adicionales

### Documentación

- [Testing Guide](Testing_Guide.md) - Guía completa de testing
- [Testing Workflows Overview](Testing_Workflows_Overview.md) - Descripción de workflows
- [Testing Suites Reference](Testing_Suites_Reference.md) - Referencia de suites
- [CI Troubleshooting](CI_Troubleshooting.md) - Solución de problemas CI/CD

### Scripts de Utilidad

- `tests/setup_ci_environment.sh` - Setup de ambiente CI
- `tests/verify_ci_environment.sh` - Verificación de ambiente
- `tests/install_shfmt.sh` - Instalación de shfmt
- `tests/setup_mock_environment.sh` - Setup de ambiente mock

---

## Conclusiones

### Resumen Ejecutivo

- **Total de Suites:** 128+ archivos de pruebas
- **Total de Tests:** ~1,290+ tests individuales
- **Tipos de Ejecución:** 4 (Local, Docker, GitHub, Mock)
- **Categorías:** 12+ categorías de pruebas
- **Tiempo Total:** 84-163 minutos (local), 77-116 minutos (CI)
- **Cobertura:** 80-85% del código

### Próximos Pasos

1. Ejecutar matriz completa localmente antes de cada release
2. Monitorear tiempos de ejecución en CI/CD
3. Expandir cobertura de performance tests
4. Agregar más pruebas de large files en Docker
5. Mejorar compatibilidad de Mock mode

---

**Última actualización:** 2025-10-14  
**Mantenedor:** Andres Gomez (AngocA)
