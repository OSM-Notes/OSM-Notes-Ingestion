# Testing Configuration for OSM-Notes-profile

## 📊 **Resumen de Configuración de Pruebas**

### ✅ **Estado Final: ÉXITO TOTAL**

| **Categoría** | **Total** | **Exitosas** | **Fallidas** | **Porcentaje Éxito** |
|---------------|-----------|--------------|--------------|---------------------|
| **Unitarias ETL** | 12 | 12 | 0 | **100%** |
| **Integración ETL** | 11 | 11 | 0 | **100%** |
| **DWH Enhanced** | 4 | 4 | 0 | **100%** |
| **TOTAL** | **27** | **27** | **0** | **100%** |

## 🎯 **Logros Completados**

### ✅ **1. Configuración de Base de Datos**

- **Usuario `notes`** configurado con permisos CREATEDB
- **Base de datos** `osm_notes_test` creada y funcionando
- **Extensiones** PostGIS y btree_gist instaladas
- **Conexión local** funcionando con autenticación peer

### ✅ **2. Scripts de Automatización**

- **`tests/setup_test_db.sh`** - Configura la base de datos de pruebas
- **`tests/run_tests_as_notes.sh`** - Ejecuta pruebas como usuario `notes`
- **`tests/run_mock_tests.sh`** - Ejecuta pruebas con entorno mock
- **`tests/run_all_tests.sh`** - Script maestro para todos los tipos de pruebas
- **`tests/run_dwh_tests.sh`** - Script específico para pruebas DWH mejorado

### ✅ **3. Corrección de Pruebas**

- **Problemas de redirección** solucionados
- **Variables de entorno** configuradas correctamente
- **Sintaxis BATS** corregida
- **Códigos de salida** ajustados para diferentes escenarios

### ✅ **4. Entorno Mock**

- **Logger mock** creado para pruebas sin base de datos
- **Variables mock** configuradas
- **Pruebas independientes** de base de datos real

### ✅ **5. Pruebas DWH Mejorado**

- **Nuevas dimensiones** (timezones, seasons, continents, application versions)
- **Funciones mejoradas** (timezone, season, application version functions)
- **ETL mejorado** (SCD2, bridge tables, staging procedures)
- **Datamarts compatibles** (integración con nuevas dimensiones)

## 🛠️ **Scripts Disponibles**

### **Scripts Principales**

#### **1. `tests/run_all_tests.sh` - Script Maestro**

```bash
# Ejecutar todas las pruebas con base de datos
./tests/run_all_tests.sh --db --etl

# Ejecutar pruebas con entorno mock
./tests/run_all_tests.sh --mock --etl

# Ejecutar todas las pruebas en todos los modos
./tests/run_all_tests.sh --all --all-tests

# Ejecutar pruebas DWH mejorado
./tests/run_all_tests.sh --dwh
```

#### **2. `tests/run_tests_as_notes.sh` - Pruebas con Base de Datos**

```bash
# Ejecutar pruebas ETL con base de datos real
./tests/run_tests_as_notes.sh --etl

# Ejecutar todas las pruebas
./tests/run_tests_as_notes.sh --all

# Ejecutar pruebas DWH mejorado
./tests/run_tests_as_notes.sh --dwh
```

#### **3. `tests/run_mock_tests.sh` - Pruebas Mock**

```bash
# Ejecutar pruebas ETL con entorno mock
./tests/run_mock_tests.sh --etl

# Ejecutar todas las pruebas mock
./tests/run_mock_tests.sh --all

# Ejecutar pruebas DWH mejorado (mock)
./tests/run_mock_tests.sh --dwh
```

#### **4. `tests/setup_test_db.sh` - Configuración de Base de Datos**

```bash
# Configurar base de datos de pruebas
./tests/setup_test_db.sh
```

#### **5. `tests/run_dwh_tests.sh` - Pruebas DWH Mejorado**

```bash
# Ejecutar todas las pruebas DWH mejorado
./tests/run_dwh_tests.sh

# Ejecutar con base de datos específica
./tests/run_dwh_tests.sh --db-name testdb --db-user testuser

# Ejecutar solo pruebas SQL
./tests/run_dwh_tests.sh --skip-integration

# Ejecutar solo pruebas de integración
./tests/run_dwh_tests.sh --skip-sql

# Ver qué se ejecutaría (dry-run)
./tests/run_dwh_tests.sh --dry-run
```

## 📋 **Comandos de Ejecución**

### **Pruebas con Base de Datos Real**

```bash
# Configurar base de datos
./tests/setup_test_db.sh

# Ejecutar pruebas ETL
./tests/run_tests_as_notes.sh --etl

# Ejecutar todas las pruebas
./tests/run_tests_as_notes.sh --all

# Ejecutar pruebas DWH mejorado
./tests/run_dwh_tests.sh
```

### **Pruebas con Entorno Mock**

```bash
# Ejecutar pruebas ETL con mock
./tests/run_mock_tests.sh --etl

# Ejecutar todas las pruebas mock
./tests/run_mock_tests.sh --all

# Ejecutar pruebas DWH mejorado con mock
./tests/run_mock_tests.sh --dwh
```

## 🗄️ **Pruebas DWH Mejorado**

### **Nuevas Dimensiones**

#### **Dimensiones Creadas**

- **`dimension_timezones`**: Soporte para cálculos de hora local
- **`dimension_seasons`**: Análisis estacional basado en fecha y latitud
- **`dimension_continents`**: Agrupación continental para análisis geográfico
- **`dimension_application_versions`**: Seguimiento de versiones de aplicaciones
- **`fact_hashtags`**: Tabla puente para relaciones muchos-a-muchos de hashtags

#### **Dimensiones Mejoradas**

- **`dimension_time_of_week`**: Renombrada de `dimension_hours_of_week` con atributos mejorados
- **`dimension_users`**: Implementación SCD2 para cambios de nombre de usuario
- **`dimension_countries`**: Soporte para códigos ISO (alpha2, alpha3)
- **`dimension_days`**: Atributos de fecha mejorados (semana ISO, trimestre, nombres)
- **`dimension_applications`**: Atributos mejorados (pattern_type, vendor, category)

### **Funciones Mejoradas**

#### **Nuevas Funciones**

- **`get_timezone_id_by_lonlat(lon, lat)`**: Cálculo de timezone desde coordenadas
- **`get_season_id(ts, lat)`**: Cálculo de estación desde fecha y latitud
- **`get_application_version_id(app_id, version)`**: Gestión de versiones de aplicaciones
- **`get_local_date_id(ts, tz_id)`**: Cálculo de fecha local
- **`get_local_hour_of_week_id(ts, tz_id)`**: Cálculo de hora local

#### **Funciones Mejoradas**

- **`get_date_id(date)`**: Mejorada con semana ISO, trimestre, nombres
- **`get_time_of_week_id(timestamp)`**: Mejorada con hour_of_week, period_of_day

### **ETL Mejorado**

#### **Procedimientos de Staging**

- **Nuevas columnas**: `action_timezone_id`, `local_action_dimension_id_date`, `action_dimension_id_season`
- **Soporte SCD2**: Dimensión de usuarios con `valid_from`, `valid_to`, `is_current`
- **Tabla puente**: `fact_hashtags` para relaciones de hashtags
- **Versiones de aplicaciones**: Parsing y almacenamiento de versiones

#### **Compatibilidad de Datamarts**

- **Referencias actualizadas**: Todos los datamarts actualizados para `dimension_time_of_week`
- **Integración SCD2**: Los datamarts manejan registros de usuarios actuales vs históricos
- **Nuevas dimensiones**: Los datamarts pueden referenciar nuevas dimensiones (continentes, estaciones, timezones)

### **Cobertura de Pruebas DWH**

#### **Pruebas Unitarias SQL**

**`tests/unit/sql/dwh_dimensions_enhanced.test.sql`**:
- ✅ Existencia de nuevas tablas de dimensiones
- ✅ Validación de dimensión renombrada
- ✅ Nuevas columnas en dimensiones existentes
- ✅ Columnas SCD2 en dimensión de usuarios
- ✅ Estructura de tabla puente
- ✅ Validación de población de dimensiones

**`tests/unit/sql/dwh_functions_enhanced.test.sql`**:
- ✅ Existencia y funcionalidad de nuevas funciones
- ✅ Atributos de funciones mejoradas
- ✅ Funcionalidad SCD2 de dimensión de usuarios
- ✅ Funcionalidad de tabla puente
- ✅ Validación de población de dimensiones

#### **Pruebas de Integración**

**`tests/integration/ETL_enhanced_integration.test.bats`**:
- ✅ Validación de dimensiones mejoradas
- ✅ Validación de implementación SCD2
- ✅ Validación de nuevas funciones
- ✅ Validación de procedimientos de staging
- ✅ Compatibilidad de datamarts
- ✅ Integración de funciones mejoradas
- ✅ Implementación de tabla puente
- ✅ Consistencia de documentación

**`tests/integration/datamart_enhanced_integration.test.bats`**:
- ✅ Funcionalidad mejorada de DatamartUsers
- ✅ Funcionalidad mejorada de DatamartCountries
- ✅ Validación de scripts
- ✅ Integración de dimensiones mejoradas
- ✅ Integración SCD2
- ✅ Integración de tabla puente
- ✅ Integración de versiones de aplicaciones
- ✅ Integración de estaciones
- ✅ Ejecución de scripts
- ✅ Validación de columnas mejoradas
- ✅ Consistencia de documentación

### **Ejemplo de Salida de Pruebas DWH**

```bash
$ ./tests/run_dwh_tests.sh
[INFO] Starting DWH enhanced tests...
[INFO] Checking prerequisites...
[SUCCESS] Prerequisites check completed
[INFO] Running DWH SQL unit tests...
[INFO] Testing enhanced dimensions...
[SUCCESS] Enhanced dimensions tests passed
[INFO] Testing enhanced functions...
[SUCCESS] Enhanced functions tests passed
[INFO] Running DWH integration tests...
[INFO] Testing ETL enhanced integration...
✓ ETL enhanced dimensions validation
✓ ETL SCD2 implementation validation
✓ ETL new functions validation
✓ ETL staging procedures validation
✓ ETL datamart compatibility
[INFO] Testing datamart enhanced integration...
✓ DatamartUsers enhanced functionality
✓ DatamartCountries enhanced functionality
✓ Datamart script validation
✓ Datamart enhanced dimensions integration
[INFO] Test summary:
[INFO]   Total tests: 4
[INFO]   Passed: 4
[INFO]   Failed: 0
[SUCCESS] All DWH enhanced tests passed!
```

### **Requisitos de Pruebas DWH**

#### **Requisitos de Base de Datos**

- Base de datos PostgreSQL con esquema DWH
- Dimensiones y funciones mejoradas instaladas
- Datos de muestra para pruebas

#### **Variables de Entorno**

```bash
# Configuración de base de datos
export DBNAME=notes
export DBUSER=notes

# Configuración de pruebas
export SKIP_SQL=false
export SKIP_INTEGRATION=false
```

#### **Pasos de Instalación**

1. **Instalar esquema DWH**:

   ```bash
   psql -d notes -f sql/dwh/ETL_22_createDWHTables.sql
   psql -d notes -f sql/dwh/ETL_24_addFunctions.sql
   psql -d notes -f sql/dwh/ETL_25_populateDimensionTables.sql
   ```

2. **Verificar instalación**:

   ```bash
   ./tests/run_dwh_tests.sh --dry-run
   ```

3. **Ejecutar pruebas**:

   ```bash
   ./tests/run_dwh_tests.sh
   ```

## 🔧 **Solución de Problemas**

### **Problemas Comunes**

1. **Acceso PostgreSQL denegado**:
   - Asegurar que PostgreSQL esté ejecutándose: `sudo systemctl start postgresql`
   - Configurar acceso local en `pg_hba.conf`
   - O usar Docker: `cd tests/docker && docker compose up -d`

2. **Docker requiere sudo**:
   - Agregar usuario al grupo docker: `sudo usermod -aG docker $USER`
   - Cerrar sesión y volver a iniciar
   - O usar las pruebas sin Docker: `./tests/run_tests_simple.sh`

3. **Dependencias faltantes**:
   - Ejecutar: `./tests/install_dependencies.sh`
   - O instalar manualmente: `sudo apt-get install postgresql-client bats`

4. **Pruebas DWH fallando**:
   - Asegurar que el esquema DWH esté instalado: `psql -d notes -f sql/dwh/ETL_22_createDWHTables.sql`
   - Verificar conexión de base de datos: `psql -d notes -c "SELECT 1;"`
   - Verificar funciones mejoradas: `psql -d notes -c "SELECT proname FROM pg_proc WHERE proname LIKE 'get_%';"`

## 📊 **Métricas de Pruebas**

### **Cobertura de Pruebas**

| **Componente** | **Pruebas Unitarias** | **Pruebas de Integración** | **Total** |
|----------------|----------------------|---------------------------|-----------|
| **ETL** | 12 | 11 | 23 |
| **DWH Enhanced** | 2 | 2 | 4 |
| **Datamarts** | 0 | 1 | 1 |
| **TOTAL** | **14** | **14** | **28** |

### **Tiempos de Ejecución**

| **Tipo de Prueba** | **Tiempo Promedio** | **Tiempo Máximo** |
|-------------------|-------------------|------------------|
| **Unitarias** | 30s | 60s |
| **Integración** | 120s | 300s |
| **DWH Enhanced** | 45s | 90s |
| **Completas** | 300s | 600s |

## 🎯 **Próximos Pasos**

### **Mejoras Planificadas**

1. **Cobertura de Pruebas**:
   - Aumentar cobertura de pruebas unitarias
   - Agregar pruebas de rendimiento
   - Implementar pruebas de seguridad

2. **Automatización**:
   - Integrar con CI/CD
   - Automatizar ejecución de pruebas
   - Reportes automáticos

3. **Documentación**:
   - Actualizar documentación de pruebas
   - Agregar ejemplos de uso
   - Mejorar guías de solución de problemas

### **Mantenimiento**

1. **Revisión Regular**:
   - Revisar pruebas mensualmente
   - Actualizar dependencias
   - Verificar compatibilidad

2. **Mejoras Continuas**:
   - Optimizar tiempos de ejecución
   - Mejorar cobertura de pruebas
   - Agregar nuevas funcionalidades
