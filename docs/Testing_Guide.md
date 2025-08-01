# Guía de Testing - OSM-Notes-profile

## Resumen

Esta guía proporciona información completa sobre las pruebas de integración implementadas, casos de uso y troubleshooting para el proyecto OSM-Notes-profile.

## Tipos de Pruebas

### 1. Pruebas de Integración

Las pruebas de integración ejecutan realmente los scripts para detectar problemas reales como:

- `log_info: orden no encontrada`
- `Notes are not yet on the database`
- `FAIL! (1) - __validation error`

#### Scripts Cubiertos:

**Scripts de Procesamiento:**
- `processAPINotes.sh` - Procesamiento de notas API
- `processPlanetNotes.sh` - Procesamiento de notas Planet
- `updateCountries.sh` - Actualización de países

**Scripts de Limpieza:**
- `cleanupAll.sh` - Limpieza completa
- `cleanupPartitions.sh` - Limpieza de particiones

**Scripts de DWH (Data Warehouse):**
- `ETL.sh` - Proceso ETL completo
- `profile.sh` - Perfil de datos
- `datamartUsers/datamartUsers.sh` - Datamart de usuarios
- `datamartCountries/datamartCountries.sh` - Datamart de países

**Scripts de WMS (Web Map Service):**
- `wmsManager.sh` - Gestor WMS
- `geoserverConfig.sh` - Configuración GeoServer
- `wmsConfigExample.sh` - Ejemplo de configuración

**Scripts de Monitor:**
- `processCheckPlanetNotes.sh` - Verificación de notas
- `notesCheckVerifier.sh` - Verificador de notas

### 2. Pruebas de Casos Edge

Las pruebas de casos edge cubren situaciones límite:

- Archivos XML muy grandes
- Archivos XML malformados
- Base de datos vacía
- Base de datos corrupta
- Problemas de conectividad de red
- Espacio insuficiente en disco
- Problemas de permisos
- Acceso concurrente
- Restricciones de memoria
- Configuración inválida
- Dependencias faltantes
- Escenarios de timeout
- Corrupción de datos
- Valores extremos

## Casos de Uso

### Caso de Uso 1: Desarrollo Local

**Objetivo:** Verificar que los cambios funcionan correctamente antes de hacer commit.

**Pasos:**
1. Ejecutar pruebas de integración locales:
   ```bash
   ./tests/run_integration_tests.sh --all
   ```

2. Ejecutar pruebas específicas:
   ```bash
   ./tests/run_integration_tests.sh --process-api
   ./tests/run_integration_tests.sh --process-planet
   ```

3. Ejecutar pruebas de casos edge:
   ```bash
   bats tests/unit/bash/edge_cases_integration.test.bats
   ```

**Resultado Esperado:** Todas las pruebas pasan sin errores.

### Caso de Uso 2: CI/CD Pipeline

**Objetivo:** Verificar automáticamente la calidad del código en cada commit.

**Pasos:**
1. El workflow de GitHub Actions se ejecuta automáticamente
2. Se ejecutan todas las pruebas de integración
3. Se ejecutan pruebas de calidad y seguridad
4. Se generan reportes automáticos

**Resultado Esperado:** Pipeline exitoso con todas las pruebas pasando.

### Caso de Uso 3: Debugging de Problemas

**Objetivo:** Identificar y resolver problemas específicos.

**Pasos:**
1. Ejecutar pruebas específicas que fallan:
   ```bash
   bats tests/unit/bash/processAPINotes_integration.test.bats
   ```

2. Revisar logs detallados:
   ```bash
   ./tests/run_integration_tests.sh --process-api --verbose
   ```

3. Ejecutar pruebas de casos edge para identificar problemas:
   ```bash
   bats tests/unit/bash/edge_cases_integration.test.bats
   ```

**Resultado Esperado:** Identificación del problema específico.

### Caso de Uso 4: Validación de Configuración

**Objetivo:** Verificar que la configuración del sistema es correcta.

**Pasos:**
1. Verificar conectividad a base de datos:
   ```bash
   psql -h localhost -p 5432 -U postgres -d osm_notes_test -c "SELECT 1;"
   ```

2. Verificar herramientas requeridas:
   ```bash
   command -v bats && echo "BATS OK"
   command -v psql && echo "PostgreSQL OK"
   command -v xmllint && echo "XML tools OK"
   ```

3. Ejecutar pruebas de configuración:
   ```bash
   ./tests/run_integration_tests.sh --all
   ```

**Resultado Esperado:** Todas las verificaciones pasan.

## Troubleshooting

### Problema 1: "log_info: orden no encontrada"

**Síntomas:**
- Error de logging al ejecutar scripts
- Funciones de logging no disponibles

**Causas:**
- Logger no inicializado correctamente
- Funciones de logging no definidas
- Problemas de sourcing de scripts

**Soluciones:**
1. Verificar que `bash_logger.sh` está disponible:
   ```bash
   ls -la lib/bash_logger.sh
   ```

2. Verificar inicialización del logger:
   ```bash
   source bin/commonFunctions.sh
   __start_logger
   ```

3. Verificar funciones de logging:
   ```bash
   declare -f __log_info
   declare -f __log_error
   ```

### Problema 2: "Notes are not yet on the database"

**Síntomas:**
- Error al ejecutar scripts SQL
- Tablas no encontradas

**Causas:**
- Base de datos vacía
- Tablas no creadas
- Scripts SQL con errores

**Soluciones:**
1. Verificar que las tablas existen:
   ```bash
   psql -d osm_notes_test -c "SELECT COUNT(*) FROM information_schema.tables;"
   ```

2. Crear tablas si no existen:
   ```bash
   psql -d osm_notes_test -f sql/process/processPlanetNotes_22_createBaseTables_tables.sql
   ```

3. Verificar scripts SQL:
   ```bash
   psql -d osm_notes_test -f sql/process/processAPINotes_23_createPropertiesTables.sql
   ```

### Problema 3: "FAIL! (1) - __validation error"

**Síntomas:**
- Error en funciones de validación
- Bucles infinitos en traps

**Causas:**
- Funciones de validación no definidas
- Problemas en traps de error
- Recursión en funciones

**Soluciones:**
1. Verificar funciones de validación:
   ```bash
   declare -f __validation
   ```

2. Verificar traps:
   ```bash
   trap -p
   ```

3. Revisar funciones recursivas:
   ```bash
   grep -r "function __" bin/
   ```

### Problema 4: Scripts no se pueden cargar (código 127)

**Síntomas:**
- Error al sourcear scripts
- Comandos no encontrados

**Causas:**
- Dependencias faltantes
- Problemas de permisos
- Scripts malformados

**Soluciones:**
1. Verificar dependencias:
   ```bash
   command -v psql
   command -v xmllint
   command -v bats
   ```

2. Verificar permisos:
   ```bash
   ls -la bin/*.sh
   chmod +x bin/*.sh
   ```

3. Verificar sintaxis:
   ```bash
   bash -n bin/process/processAPINotes.sh
   ```

### Problema 5: Pruebas de integración fallan

**Síntomas:**
- Pruebas de integración no pasan
- Errores en CI/CD

**Causas:**
- Configuración incorrecta
- Dependencias faltantes
- Problemas de red

**Soluciones:**
1. Verificar configuración de pruebas:
   ```bash
   cat tests/properties.sh
   ```

2. Ejecutar pruebas con verbose:
   ```bash
   ./tests/run_integration_tests.sh --all --verbose
   ```

3. Verificar conectividad:
   ```bash
   pg_isready -h localhost -p 5432
   ```

## Comandos Útiles

### Ejecutar Todas las Pruebas
```bash
./tests/run_integration_tests.sh --all
```

### Ejecutar Pruebas Específicas
```bash
./tests/run_integration_tests.sh --process-api
./tests/run_integration_tests.sh --process-planet
./tests/run_integration_tests.sh --cleanup
./tests/run_integration_tests.sh --wms
./tests/run_integration_tests.sh --etl
```

### Ejecutar Pruebas Individuales
```bash
bats tests/unit/bash/processAPINotes_integration.test.bats
bats tests/unit/bash/edge_cases_integration.test.bats
```

### Verificar Configuración
```bash
# Verificar base de datos
psql -d osm_notes_test -c "SELECT version();"

# Verificar herramientas
command -v bats && echo "BATS OK"
command -v psql && echo "PostgreSQL OK"

# Verificar archivos
ls -la bin/*.sh
ls -la sql/process/*.sql
```

### Debugging
```bash
# Ejecutar con verbose
./tests/run_integration_tests.sh --all --verbose

# Ejecutar con debug
LOG_LEVEL=DEBUG ./tests/run_integration_tests.sh --all

# Ver logs detallados
tail -f tests/tmp/*.log
```

## Mejores Prácticas

### 1. Desarrollo
- Ejecutar pruebas antes de cada commit
- Usar pruebas específicas para debugging
- Mantener pruebas actualizadas

### 2. CI/CD
- Integrar pruebas en pipeline automático
- Generar reportes de cobertura
- Notificar fallos inmediatamente

### 3. Monitoreo
- Ejecutar pruebas regularmente
- Revisar logs de errores
- Mantener documentación actualizada

### 4. Mantenimiento
- Actualizar pruebas cuando cambie el código
- Agregar nuevos casos edge
- Optimizar tiempo de ejecución

## Conclusión

Las pruebas de integración son esenciales para detectar problemas reales antes de que lleguen a producción. Esta guía proporciona las herramientas y conocimientos necesarios para:

- ✅ **Ejecutar pruebas efectivamente**
- ✅ **Debuggear problemas rápidamente**
- ✅ **Mantener calidad del código**
- ✅ **Integrar con CI/CD**

**Recomendación:** Usar esta guía como referencia para mantener la calidad y confiabilidad del proyecto OSM-Notes-profile. 