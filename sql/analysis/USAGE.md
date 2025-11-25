# Uso de Scripts de Análisis de Rendimiento

## Ejecución Automática

### Script Principal: `analyzeDatabasePerformance.sh`

El script `bin/monitor/analyzeDatabasePerformance.sh` ejecuta todos los scripts de análisis y genera un reporte resumen.

#### Uso Básico

```bash
# Ejecutar con base de datos desde propiedades
./bin/monitor/analyzeDatabasePerformance.sh

# Ejecutar con base de datos específica
./bin/monitor/analyzeDatabasePerformance.sh --db osm_notes

# Ejecutar con salida detallada
./bin/monitor/analyzeDatabasePerformance.sh --verbose
```

#### Opciones

- `--db DATABASE`: Especifica la base de datos (sobrescribe DBNAME de propiedades)
- `--output DIR`: Directorio de salida para resultados (por defecto: `/tmp/analyzeDatabasePerformance_*/analysis_results`)
- `--verbose`: Muestra salida detallada de cada script de análisis
- `--help`: Muestra ayuda

#### Salida

El script genera:

1. **Reporte en consola**: Resumen con códigos de color
   - ✓ Verde: Scripts que pasaron
   - ⚠ Amarillo: Scripts con advertencias
   - ✗ Rojo: Scripts que fallaron

2. **Archivo de reporte**: `performance_report.txt` en el directorio de salida
   - Resumen ejecutivo
   - Estado de cada script
   - Lista de archivos de salida detallados

3. **Archivos individuales**: Un archivo `.txt` por cada script ejecutado
   - Contiene toda la salida del script SQL
   - Incluye EXPLAIN ANALYZE, estadísticas, etc.

#### Ejemplo de Salida

```
==============================================================================
DATABASE PERFORMANCE ANALYSIS
==============================================================================
Database: osm_notes
Output directory: /tmp/analyzeDatabasePerformance_12345/analysis_results
==============================================================================

Running analysis: analyze_integrity_verification_performance.sql
  ✓ analyze_integrity_verification_performance.sql - PASSED
Running analysis: analyze_partition_loading_performance.sql
  ✓ analyze_partition_loading_performance.sql - PASSED
Running analysis: analyze_api_insertion_performance.sql
  ⚠ analyze_api_insertion_performance.sql - WARNING

==============================================================================
DATABASE PERFORMANCE ANALYSIS REPORT
==============================================================================
Database: osm_notes
Date: 2025-11-25 10:30:45
Total Scripts: 6

Results Summary:
  Passed:   4 (✓)
  Warnings: 1 (⚠)
  Failed:   1 (✗)
```

#### Códigos de Salida

- `0`: Análisis completado (puede tener advertencias)
- `1`: Análisis completado con errores

## Ejecución Manual de Scripts Individuales

También puedes ejecutar scripts individuales directamente:

```bash
# Script específico
psql -d "${DBNAME}" -f sql/analysis/analyze_integrity_verification_performance.sql

# Guardar salida en archivo
psql -d "${DBNAME}" -f sql/analysis/analyze_integrity_verification_performance.sql > results.txt 2>&1
```

## Seguridad en Producción

**✅ SEGURO PARA PRODUCCIÓN**

Todos los scripts de análisis son seguros para ejecutar en bases de datos de producción porque:

1. **Usan ROLLBACK**: Todos los scripts que modifican datos usan `ROLLBACK` al final
2. **Solo lectura**: La mayoría de las operaciones son consultas de solo lectura
3. **Sin modificaciones permanentes**: No se realizan cambios permanentes en los datos

### Verificación

Puedes verificar que un script es seguro revisando que contenga:

```sql
-- Al final del script
ROLLBACK;
```

O que solo contenga consultas de lectura (SELECT, EXPLAIN, etc.).

## Interpretación de Resultados

### Estado: PASSED ✓

- Todos los umbrales de rendimiento se cumplen
- Los índices se están usando correctamente
- No se detectaron problemas

### Estado: WARNING ⚠

- Se detectaron advertencias pero no errores críticos
- Puede indicar:
  - Uso de sequential scan en lugar de index scan
  - Tiempos de ejecución cerca de los umbrales
  - Índices no utilizados aún (normal si no se han ejecutado consultas)

### Estado: FAILED ✗

- Se detectaron errores críticos
- Puede indicar:
  - Índices faltantes
  - Errores de ejecución SQL
  - Problemas de conectividad

## Programación Regular

Para monitoreo continuo, puedes programar la ejecución regular:

```bash
# Crontab para ejecutar diariamente a las 2 AM
0 2 * * * /ruta/al/proyecto/bin/monitor/analyzeDatabasePerformance.sh --db osm_notes > /var/log/db_performance.log 2>&1
```

## Integración con Monitoreo

El script puede integrarse con sistemas de monitoreo:

```bash
# Ejecutar y enviar alerta si hay fallos
if ! ./bin/monitor/analyzeDatabasePerformance.sh --db osm_notes; then
  # Enviar alerta (email, Slack, etc.)
  echo "Performance analysis failed" | mail -s "DB Performance Alert" admin@example.com
fi
```

## Troubleshooting

### Error: "Cannot connect to database"

- Verifica que `DBNAME` esté configurado en `etc/properties.sh`
- Verifica permisos de conexión a PostgreSQL
- Verifica que la base de datos exista

### Error: "No analysis scripts found"

- Verifica que el directorio `sql/analysis/` exista
- Verifica que los scripts tengan extensión `.sql`

### Scripts fallan con errores SQL

- Verifica que todas las tablas requeridas existan
- Verifica que las extensiones necesarias estén instaladas (PostGIS, etc.)
- Revisa los archivos de salida individuales para detalles

## Autor

Andres Gomez (AngocA)  
Versión: 2025-11-25

