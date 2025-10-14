# Estrategia de Pruebas de Integración - Repositorios Separados

**Fecha:** 2025-10-13  
**Versión:** 1.0  
**Estado:** Propuesta

---

## 📊 Situación Actual

### Problema Identificado

Después de la separación de repositorios:
- ✅ OSM-Notes-profile tiene tests de integración para **Ingestion + WMS**
- ✅ OSM-Notes-Analytics tiene tests de integración para **ETL + Datamarts**
- ❌ El workflow de OSM-Notes-profile aún referencia tests de ETL/datamart que ya no existen
- ❌ No hay tests de integración **cross-repository** (Ingestion → Analytics)

### Tests Actuales por Repositorio

#### OSM-Notes-profile (`tests/integration/`)
```
✅ end_to_end.test.bats                     # E2E de ingestion
✅ processAPI_historical_e2e.test.bats      # API E2E
✅ processAPINotes_parallel_error_integration.test.bats
✅ boundary_processing_error_integration.test.bats
✅ wms_integration.test.bats                # WMS
✅ xslt_integration.test.bats
✅ mock_planet_processing.test.bats
✅ logging_pattern_validation_integration.test.bats
```
**Total:** 8 tests de integración ✅

#### OSM-Notes-Analytics (`tests/integration/`)
```
✅ ETL_enhanced_integration.test.bats       # ETL
✅ datamart_enhanced_integration.test.bats  # Datamarts
```
**Total:** 2 tests de integración ✅

---

## 🎯 Estrategia Propuesta: Tests Independientes por Repositorio

### Principio Fundamental

**Cada repositorio prueba SU funcionalidad de forma independiente**

```
OSM-Notes-profile Tests        OSM-Notes-Analytics Tests
┌─────────────────────┐       ┌──────────────────────┐
│                     │       │                      │
│ ✓ Ingesta Planet    │       │ ✓ ETL desde BD       │
│ ✓ Ingesta API       │       │ ✓ Datamarts          │
│ ✓ WMS               │       │ ✓ Profile generation │
│ ✓ Monitoreo         │       │ ✓ Star schema        │
│                     │       │                      │
└─────────────────────┘       └──────────────────────┘
         │                              │
         │                              │
         └──────────┬───────────────────┘
                    │
                    ▼
         ┌──────────────────────┐
         │  Database (shared)   │
         │                      │
         │  • public schema     │
         │  • wms schema        │
         │  • dwh schema        │
         └──────────────────────┘
```

---

## 📋 Tests por Repositorio (Definición Clara)

### 1. OSM-Notes-profile (Ingestion & WMS)

#### Responsabilidad de Testing
Probar que los datos se **ingresan correctamente** a la base de datos:

**Tests de Integración:**
```bash
tests/integration/
├── end_to_end.test.bats
│   └── Prueba: Planet → BD (schema public)
│       ✓ Descarga planet
│       ✓ Procesa XML
│       ✓ Inserta en notes, note_comments
│       ✓ Verifica integridad de datos
│
├── processAPI_historical_e2e.test.bats
│   └── Prueba: API → BD (schema public)
│       ✓ Descarga desde API
│       ✓ Sincroniza con BD
│       ✓ Verifica datos actualizados
│
├── wms_integration.test.bats
│   └── Prueba: BD → WMS (schema wms)
│       ✓ Triggers funcionan
│       ✓ Datos en wms.notes_wms
│       ✓ Geometrías correctas
│
└── ...otros tests de ingestion
```

**Contrato de Salida:**
- ✅ Tablas `notes`, `note_comments`, `note_comments_text` pobladas
- ✅ Schema `public` listo para consumo
- ✅ Schema `wms` actualizado via triggers
- ✅ Datos válidos y consistentes

---

### 2. OSM-Notes-Analytics (DWH & Analytics)

#### Responsabilidad de Testing
Probar que los datos se **transforman y analizan correctamente**:

**Tests de Integración:**
```bash
tests/integration/
├── ETL_enhanced_integration.test.bats
│   └── Prueba: BD public → BD dwh
│       ✓ Lee de notes, note_comments
│       ✓ Transforma a star schema
│       ✓ Inserta en dwh.facts
│       ✓ Popula dimensiones
│       ✓ Verifica integridad referencial
│
└── datamart_enhanced_integration.test.bats
    └── Prueba: dwh → datamarts
        ✓ Procesa dwh.facts
        ✓ Genera datamart_countries
        ✓ Genera datamart_users
        ✓ Verifica agregaciones
```

**Contrato de Entrada:**
- ✅ Asume que tablas `notes`, `note_comments` tienen datos válidos
- ✅ No prueba la ingestion (eso es responsabilidad de Profile)

**Contrato de Salida:**
- ✅ Schema `dwh` poblado correctamente
- ✅ Datamarts generados
- ✅ Perfiles disponibles

---

## 🔄 Tests de Integración Cross-Repository (OPCIONAL)

### Opción A: Test en Repositorio Separado (Recomendado)

Crear un **tercer repositorio** para tests end-to-end completos:

```
OSM-Notes-E2E-Tests/
├── README.md
├── .github/workflows/
│   └── e2e-complete.yml
├── tests/
│   ├── complete_flow.test.bats
│   │   └── Planet → Ingestion → ETL → Datamarts → Profile
│   └── cross_repo_integration.test.bats
│       └── Verifica flujo completo
└── setup/
    └── setup_both_repos.sh
```

**Ventajas:**
- ✅ No acopla los repositorios
- ✅ Puede ejecutarse independientemente
- ✅ Simula el flujo de producción completo
- ✅ Detecta problemas de integración entre repos

**Desventajas:**
- ⚠️ Requiere clonar ambos repos
- ⚠️ Setup más complejo
- ⚠️ Más lento de ejecutar

---

### Opción B: Tests de Contrato (Contract Testing)

Cada repositorio verifica su **contrato** con el otro:

#### En OSM-Notes-profile
```bash
tests/integration/contract_output.test.bats
└── Verifica que la salida cumple el contrato:
    ✓ Tablas notes tienen columnas esperadas
    ✓ Datos en formato esperado por Analytics
    ✓ Constraints cumplidos
    ✓ Schema público no cambia sin aviso
```

#### En OSM-Notes-Analytics
```bash
tests/integration/contract_input.test.bats
└── Verifica que puede leer el contrato:
    ✓ Puede leer de notes
    ✓ Columnas esperadas existen
    ✓ Tipos de datos correctos
    ✓ No depende de columnas no documentadas
```

**Ventajas:**
- ✅ Detecta cambios que rompen integración
- ✅ Cada repo es independiente
- ✅ Tests rápidos y simples
- ✅ Fácil de mantener

**Desventajas:**
- ⚠️ No prueba el flujo completo
- ⚠️ Requiere mantener documentación del contrato

---

## 🚀 Implementación Recomendada (Fases)

### Fase 1: Limpiar Workflows Actuales (AHORA) ⚡

#### En OSM-Notes-profile

**Actualizar** `.github/workflows/integration-tests.yml`:

```yaml
# ELIMINAR estas líneas (ya no existen estos tests):
- echo "- ✅ ETL_integration.test.bats" >> $GITHUB_STEP_SUMMARY
- echo "- ✅ datamartUsers_integration.test.bats" >> $GITHUB_STEP_SUMMARY
- echo "- ✅ datamartCountries_integration.test.bats" >> $GITHUB_STEP_SUMMARY

# ACTUALIZAR esta línea:
test_categories=("process-api" "process-planet" "cleanup" "wms")
# Eliminar "etl" de la lista
```

**Actualizar** `tests/run_integration_tests.sh`:

```bash
# ELIMINAR o COMENTAR la función:
__run_etl_tests() {
  # Esta función ya no aplica - tests movidos a OSM-Notes-Analytics
  log_warn "ETL tests are now in OSM-Notes-Analytics repository"
  return 0
}
```

---

### Fase 2: Crear Tests de Contrato (CORTO PLAZO) 📝

#### En OSM-Notes-profile
```bash
# Crear nuevo test
tests/integration/output_contract.test.bats
```

```bash
#!/usr/bin/env bats

# Contract Test: Verify output format for Analytics
# Author: Andres Gomez (AngocA)
# Version: 2025-10-13

@test "Contract: notes table has expected columns" {
  # Verifica que Analytics puede leer lo que Profile produce
  run psql -d osm_notes -c "\d notes"
  [ "$status" -eq 0 ]
  [[ "$output" == *"note_id"* ]]
  [[ "$output" == *"created_at"* ]]
  [[ "$output" == *"closed_at"* ]]
}

@test "Contract: note_comments table has expected structure" {
  run psql -d osm_notes -c "\d note_comments"
  [ "$status" -eq 0 ]
  [[ "$output" == *"id"* ]]
  [[ "$output" == *"note_id"* ]]
  [[ "$output" == *"event"* ]]
}

@test "Contract: Data types are compatible with Analytics" {
  # Verifica tipos de datos que Analytics espera
  run psql -d osm_notes -c "
    SELECT 
      data_type 
    FROM information_schema.columns 
    WHERE table_name = 'notes' 
    AND column_name = 'created_at';"
  
  [[ "$output" == *"timestamp"* ]]
}
```

#### En OSM-Notes-Analytics
```bash
# Crear nuevo test
tests/integration/input_contract.test.bats
```

```bash
#!/usr/bin/env bats

# Contract Test: Verify input from Ingestion
# Author: Andres Gomez (AngocA)
# Version: 2025-10-13

@test "Contract: Can read from notes table" {
  # Verifica que puede leer lo que Profile produce
  run psql -d osm_notes -c "SELECT COUNT(*) FROM notes LIMIT 1;"
  [ "$status" -eq 0 ]
}

@test "Contract: Required columns exist in notes" {
  # Verifica que las columnas que ETL necesita existen
  run psql -d osm_notes -c "
    SELECT 
      note_id, 
      created_at, 
      closed_at, 
      id_country 
    FROM notes 
    LIMIT 1;"
  
  [ "$status" -eq 0 ]
}

@test "Contract: Can read from note_comments" {
  run psql -d osm_notes -c "
    SELECT 
      id, 
      note_id, 
      event, 
      created_at 
    FROM note_comments 
    LIMIT 1;"
  
  [ "$status" -eq 0 ]
}
```

---

### Fase 3: Documentar Contrato (MEDIANO PLAZO) 📚

Crear documento que especifique el contrato entre repositorios:

**En ambos repos:** `docs/DATA_CONTRACT.md`

```markdown
# Data Contract: Ingestion ↔ Analytics

## Schema: public (Managed by OSM-Notes-profile)

### Table: notes
| Column | Type | Nullable | Description | Used by Analytics |
|--------|------|----------|-------------|-------------------|
| note_id | INTEGER | NOT NULL | OSM note ID | ✅ YES (PK in DWH) |
| created_at | TIMESTAMP | NOT NULL | Creation date | ✅ YES (dimension) |
| closed_at | TIMESTAMP | NULL | Closing date | ✅ YES (dimension) |
| lat | DOUBLE | NOT NULL | Latitude | ✅ YES (location) |
| lon | DOUBLE | NOT NULL | Longitude | ✅ YES (location) |
| id_country | INTEGER | NULL | Country FK | ✅ YES (dimension) |
| status | VARCHAR | NOT NULL | open/closed | ✅ YES (filter) |

### Table: note_comments
| Column | Type | Nullable | Description | Used by Analytics |
|--------|------|----------|-------------|-------------------|
| id | SERIAL | NOT NULL | Comment ID | ✅ YES |
| note_id | INTEGER | NOT NULL | Note FK | ✅ YES |
| event | note_event_enum | NOT NULL | Action type | ✅ YES |
| created_at | TIMESTAMP | NOT NULL | Action date | ✅ YES |
| id_user | INTEGER | NULL | User ID | ✅ YES (dimension) |

## Schema: wms (Managed by OSM-Notes-profile)

**Not used by Analytics** ❌

## Schema: dwh (Managed by OSM-Notes-Analytics)

**Not used by Ingestion** ❌

## Breaking Changes Policy

### Major Changes (Require Coordination)
- ❌ Removing columns used by Analytics
- ❌ Changing column types
- ❌ Renaming tables/columns
- ❌ Changing enum values

### Minor Changes (Backward Compatible)
- ✅ Adding new columns
- ✅ Adding new tables
- ✅ Adding indexes
- ✅ Changing column order

### Process for Breaking Changes
1. Discuss in GitHub issue (both repos)
2. Update Analytics to handle both old and new format
3. Deploy Analytics first
4. Deploy Ingestion with changes
5. Remove compatibility code from Analytics
```

---

### Fase 4: CI/CD Separado (LARGO PLAZO) 🔄

#### Workflow para cada repo

**OSM-Notes-profile:**
```yaml
on:
  push:
  pull_request:
  schedule:
    - cron: '0 2 * * *'  # Daily

jobs:
  integration-tests:
    - Run ingestion tests
    - Run WMS tests
    - Run contract output tests ✨
```

**OSM-Notes-Analytics:**
```yaml
on:
  push:
  pull_request:
  schedule:
    - cron: '0 3 * * *'  # Daily (1h after Ingestion)

jobs:
  integration-tests:
    - Run ETL tests
    - Run datamart tests
    - Run contract input tests ✨
```

---

## 📊 Matriz de Decisión

| Tipo de Test | Dónde | Frecuencia | Duración | Prioridad |
|--------------|-------|------------|----------|-----------|
| **Unit tests** (Profile) | OSM-Notes-profile | Cada push | 5-10 min | 🔴 Alta |
| **Unit tests** (Analytics) | OSM-Notes-Analytics | Cada push | 5-10 min | 🔴 Alta |
| **Integration** (Profile) | OSM-Notes-profile | Cada push | 15-20 min | 🟠 Media |
| **Integration** (Analytics) | OSM-Notes-Analytics | Cada push | 20-25 min | 🟠 Media |
| **Contract tests** | Ambos repos | Cada push | 2-3 min | 🟡 Media-Baja |
| **E2E cross-repo** | Repo separado | Nightly | 45-60 min | 🟢 Baja |

---

## ✅ Recomendaciones Finales

### Para OSM-Notes-profile (AHORA)

1. **✅ Actualizar** `.github/workflows/integration-tests.yml`
   - Eliminar referencias a ETL/datamart
   - Actualizar lista de tests
   
2. **✅ Actualizar** `tests/run_integration_tests.sh`
   - Eliminar función `__run_etl_tests`
   - Actualizar help message

3. **📝 Crear** `tests/integration/output_contract.test.bats` (opcional)
   - Verifica que salida cumple contrato
   
4. **📚 Crear** `docs/DATA_CONTRACT.md` (opcional)
   - Documenta esquema público

### Para OSM-Notes-Analytics (AHORA)

1. **✅ Verificar** que workflows no referencian Profile
   
2. **📝 Crear** `tests/integration/input_contract.test.bats` (opcional)
   - Verifica que puede leer entrada
   
3. **📚 Crear** `docs/DATA_CONTRACT.md` (opcional)
   - Documenta expectativas de entrada

### Para Futuro (OPCIONAL)

1. **🔄 Crear** OSM-Notes-E2E-Tests (si es necesario)
   - Solo si hay problemas recurrentes de integración
   
2. **📊 Monitoreo** de integración en producción
   - Alertas si Ingestion falla
   - Alertas si Analytics no puede leer datos

---

## 🎯 TL;DR - Resumen Ejecutivo

### Estrategia Recomendada: **Tests Independientes por Repositorio**

1. **OSM-Notes-profile** prueba: Ingestion → Database ✅
2. **OSM-Notes-Analytics** prueba: Database → Analytics ✅
3. **Contract tests** (opcional): Verifica compatibilidad ✅
4. **E2E completo** (opcional): Solo si es realmente necesario ⚠️

### Acción Inmediata

```bash
# 1. Actualizar workflow en OSM-Notes-profile
# 2. Eliminar referencias a tests que no existen
# 3. Listo - cada repo prueba su funcionalidad
```

**La clave:** Cada repositorio es **independiente y autónomo** en sus tests. La integración se garantiza mediante el **contrato de base de datos compartida**.

---

**Documento creado:** 2025-10-13  
**Autor:** Andres Gomez (AngocA)  
**Estado:** Propuesta para revisión

