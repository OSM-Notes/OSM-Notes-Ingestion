# Mapeo de Scripts de Análisis a Procesos Principales

Este documento mapea cada script de análisis de rendimiento a su proceso principal correspondiente.

## Resumen por Proceso

### 📦 `processPlanetNotes.sh` - Procesamiento de Notas del Planet

Este es el proceso principal para cargar notas históricas desde el dump completo del Planet.

**Scripts de análisis relacionados:**

1. **`analyze_partition_loading_performance.sql`**
   - **SQL relacionado**: `sql/process/processPlanetNotes_41_loadPartitionedSyncNotes.sql`
   - **Función bash**: `__loadPartitionedSyncNotes()` en `bin/lib/functionsProcess.sh`
   - **Qué analiza**: Rendimiento de operaciones COPY masivas para cargar particiones
   - **Cuándo se ejecuta**: Durante la carga inicial de notas del Planet en particiones paralelas

2. **`analyze_partition_consolidation_performance.sql`**
   - **SQL relacionado**: `sql/process/processPlanetNotes_42_consolidatePartitions.sql`
   - **Función bash**: `__consolidatePartitions()` en `bin/lib/functionsProcess.sh`
   - **Qué analiza**: Rendimiento de operaciones INSERT masivas para consolidar particiones
   - **Cuándo se ejecuta**: Después de cargar todas las particiones, cuando se consolidan en tablas sync

3. **`analyze_integrity_verification_performance.sql`**
   - **SQL relacionado**: `sql/functionsProcess_33_verifyNoteIntegrity.sql`
   - **Función bash**: `__getLocationNotes()` → `__getLocationNotes_impl()` en `bin/lib/noteProcessingFunctions.sh`
   - **Qué analiza**: Rendimiento de verificación de integridad de ubicación de notas
   - **Cuándo se ejecuta**: Durante la verificación de integridad (proceso que lleva horas)
   - **Llamado desde**: `processPlanetNotes.sh` después de asignar países

4. **`analyze_country_assignment_performance.sql`**
   - **SQL relacionado**: `sql/functionsProcess_37_assignCountryToNotesChunk.sql`
   - **Función bash**: `__getLocationNotes()` → `__getLocationNotes_impl()` en `bin/lib/noteProcessingFunctions.sh`
   - **Qué analiza**: Rendimiento de asignación de países a notas (UPDATE masivo con get_country())
   - **Cuándo se ejecuta**: Durante la asignación inicial de países a notas del Planet
   - **Llamado desde**: `processPlanetNotes.sh` (automáticamente)

---

### 🔄 `processAPINotes.sh` - Procesamiento de Notas desde API

Este es el proceso principal para sincronizar notas recientes desde la API de OSM.

**Scripts de análisis relacionados:**

1. **`analyze_partition_loading_performance.sql`**
   - **SQL relacionado**: `sql/process/processAPINotes_31_loadApiNotes.sql`
   - **Función bash**: `__loadApiNotes()` en `bin/lib/processAPIFunctions.sh`
   - **Qué analiza**: Rendimiento de operaciones COPY masivas para cargar datos de API en particiones
   - **Cuándo se ejecuta**: Durante la carga de notas desde la API en particiones paralelas

2. **`analyze_api_insertion_performance.sql`**
   - **SQL relacionado**: `sql/process/processAPINotes_32_insertNewNotesAndComments.sql`
   - **Función bash**: `__insertNewNotesAndComments()` en `bin/process/processAPINotes.sh`
   - **Qué analiza**: Rendimiento de inserción de notas usando cursores y procedimientos almacenados
   - **Cuándo se ejecuta**: Cuando se insertan nuevas notas y comentarios desde las tablas API a las tablas principales

3. **`analyze_partition_consolidation_performance.sql`**
   - **SQL relacionado**: `sql/process/processAPINotes_35_consolidatePartitions.sql`
   - **Función bash**: `__consolidatePartitions()` en `bin/process/processAPINotes.sh`
   - **Qué analiza**: Rendimiento de consolidación de particiones de API
   - **Cuándo se ejecuta**: Después de cargar particiones de API, cuando se consolidan en tablas API principales

---

### 🌍 `updateCountries.sh` - Actualización de Fronteras de Países

Este proceso actualiza las fronteras de países cuando cambian en OSM.

**Scripts de análisis relacionados:**

1. **`analyze_country_reassignment_performance.sql`**
   - **SQL relacionado**: `sql/functionsProcess_36_reassignAffectedNotes.sql`
   - **Función bash**: `__reassignAffectedNotes()` en `bin/process/updateCountries.sh`
   - **Qué analiza**: Rendimiento de reasignación de países usando consultas espaciales con bounding box
   - **Cuándo se ejecuta**: Cuando se actualizan fronteras de países y se necesitan reasignar notas afectadas

---

### 📍 Asignación de Países a Notas (Integrado en processPlanetNotes.sh)

Este proceso asigna países a notas que no tienen país asignado. Se ejecuta automáticamente durante `processPlanetNotes.sh`.

**Scripts de análisis relacionados:**

1. **`analyze_country_assignment_performance.sql`**
   - **SQL relacionado**: `sql/functionsProcess_37_assignCountryToNotesChunk.sql`
   - **Función bash**: `__getLocationNotes()` → `__getLocationNotes_impl()` en `bin/lib/noteProcessingFunctions.sh`
   - **Qué analiza**: Rendimiento de asignación de países a notas (UPDATE masivo con get_country())
   - **Cuándo se ejecuta**: Automáticamente durante `processPlanetNotes.sh` después de crear la función `get_country()`

---

## Tabla Resumen

| Script de Análisis | Proceso Principal | SQL Relacionado | Función Bash |
|-------------------|-------------------|-----------------|--------------|
| `analyze_partition_loading_performance.sql` | `processPlanetNotes.sh` | `processPlanetNotes_41_loadPartitionedSyncNotes.sql` | `__loadPartitionedSyncNotes()` |
| `analyze_partition_loading_performance.sql` | `processAPINotes.sh` | `processAPINotes_31_loadApiNotes.sql` | `__loadApiNotes()` |
| `analyze_partition_consolidation_performance.sql` | `processPlanetNotes.sh` | `processPlanetNotes_42_consolidatePartitions.sql` | `__consolidatePartitions()` |
| `analyze_partition_consolidation_performance.sql` | `processAPINotes.sh` | `processAPINotes_35_consolidatePartitions.sql` | `__consolidatePartitions()` |
| `analyze_api_insertion_performance.sql` | `processAPINotes.sh` | `processAPINotes_32_insertNewNotesAndComments.sql` | `__insertNewNotesAndComments()` |
| `analyze_integrity_verification_performance.sql` | `processPlanetNotes.sh` | `functionsProcess_33_verifyNoteIntegrity.sql` | `__getLocationNotes()` |
| `analyze_country_assignment_performance.sql` | `processPlanetNotes.sh` | `functionsProcess_37_assignCountryToNotesChunk.sql` | `__getLocationNotes()` |
| `analyze_country_reassignment_performance.sql` | `updateCountries.sh` | `functionsProcess_36_reassignAffectedNotes.sql` | `__reassignAffectedNotes()` |

---

## Cuándo Ejecutar los Análisis

### Análisis para `processPlanetNotes.sh`

Ejecutar después de:

- ✅ Carga inicial de notas del Planet
- ✅ Consolidación de particiones
- ✅ Asignación de países
- ✅ Verificación de integridad

**Comando:**

```bash
# Ejecutar análisis específicos para Planet
./bin/monitor/analyzeDatabasePerformance.sh --db osm_notes
```

### Análisis para `processAPINotes.sh`

Ejecutar después de:

- ✅ Cada sincronización de API (cada 15 minutos típicamente)
- ✅ Carga de particiones de API
- ✅ Consolidación de particiones de API
- ✅ Inserción de nuevas notas

**Comando:**

```bash
# Ejecutar análisis específicos para API
./bin/monitor/analyzeDatabasePerformance.sh --db osm_notes
```

### Análisis para `updateCountries.sh`

Ejecutar después de:

- ✅ Actualización de fronteras de países
- ✅ Reasignación de notas afectadas

**Comando:**

```bash
# Ejecutar análisis específicos para actualización de países
./bin/monitor/analyzeDatabasePerformance.sh --db osm_notes
```

---

## Notas Importantes

1. **Algunos análisis son compartidos**:

   - `analyze_partition_loading_performance.sql` se usa tanto para Planet como para API
   - `analyze_partition_consolidation_performance.sql` se usa tanto para Planet como para API
   - `analyze_country_assignment_performance.sql` se usa en múltiples procesos

2. **Análisis más críticos**:

   - `analyze_integrity_verification_performance.sql`: Proceso que lleva horas, crítico optimizar
   - `analyze_country_assignment_performance.sql`: Se ejecuta frecuentemente, afecta rendimiento general

3. **Frecuencia recomendada**:

   - **Planet**: Después de cada carga completa (semanas/meses)
   - **API**: Después de cada sincronización o diariamente
   - **Países**: Después de cada actualización de fronteras
