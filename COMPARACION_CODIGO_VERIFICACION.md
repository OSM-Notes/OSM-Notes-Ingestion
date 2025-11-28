# Comparación de Código: Verificación de Integridad

**Fecha:** 2025-11-28  
**Autor:** Andres Gomez (AngocA)

## Resumen Ejecutivo

Se identificó que la versión optimizada (2025-11-27) tenía un problema con la subconsulta correlacionada que no estaba usando el índice espacial eficientemente. Se implementó una mejora usando `LATERAL JOIN` para forzar el uso correcto del índice.

## Diferencias Clave

### Versión Original (2025-11-25)

**Problema Principal:** Carga todas las geometrías en memoria y las ordena.

```sql
countries_to_check AS (
  SELECT DISTINCT c.country_id, c.geom
  FROM countries c
  INNER JOIN notes_to_verify ntv ON c.country_id = ntv.id_country
)
```

- ❌ Carga ~68 MB de geometrías por chunk
- ❌ Ordena ~5 GB de datos con solo 16 MB de `work_mem`
- ❌ Swap masivo a disco
- ❌ Tiempo: 6-8 minutos por chunk

### Versión Optimizada (2025-11-27) - PROBLEMÁTICA

**Problema:** Subconsulta correlacionada no usa índice espacial eficientemente.

```sql
spatial_verified AS (
  SELECT un.note_id, un.current_country,
    COALESCE(
      (SELECT c.country_id
       FROM countries c
       WHERE ST_Contains(c.geom, ST_SetSRID(ST_Point(...), 4326))
       LIMIT 1),
      -1
    ) AS verified_country
  FROM unmatched_notes un
)
```

- ✅ No carga todas las geometrías
- ✅ Usa JOIN directo con clave primaria (rápido)
- ⚠️ Subconsulta correlacionada puede no usar índice espacial
- ⚠️ Bloqueado después de 20+ minutos

### Versión Mejorada (2025-11-28) - ACTUAL

**Solución:** Usa `LATERAL JOIN` para forzar uso del índice espacial.

```sql
spatial_verified AS (
  SELECT un.note_id,
         un.current_country,
         COALESCE(c.country_id, -1) AS verified_country
  FROM unmatched_notes un
  LEFT JOIN LATERAL (
    SELECT c.country_id
    FROM countries c
    WHERE ST_Contains(c.geom, ST_SetSRID(ST_Point(un.longitude, un.latitude), 4326))
    LIMIT 1
  ) c ON true
)
```

- ✅ No carga todas las geometrías
- ✅ Usa JOIN directo con clave primaria (rápido)
- ✅ `LATERAL JOIN` fuerza uso del índice espacial `countries_spatial`
- ✅ Mejor planificación de consultas por PostgreSQL
- ✅ Esperado: 5-10 segundos por chunk

## Cambios Técnicos

### 1. Reemplazo de Subconsulta Correlacionada

**Antes:**
```sql
COALESCE(
  (SELECT c.country_id FROM countries c WHERE ST_Contains(...) LIMIT 1),
  -1
)
```

**Después:**
```sql
LEFT JOIN LATERAL (
  SELECT c.country_id
  FROM countries c
  WHERE ST_Contains(c.geom, ST_SetSRID(ST_Point(un.longitude, un.latitude), 4326))
  LIMIT 1
) c ON true
```

### 2. Ventajas de LATERAL JOIN

1. **Planificación Mejorada:** PostgreSQL puede optimizar mejor el uso del índice espacial
2. **Ejecución Eficiente:** El índice `countries_spatial` se usa directamente para cada fila
3. **Sin Escaneos Completos:** Evita escanear toda la tabla `countries` para cada nota
4. **Mejor Paralelización:** PostgreSQL puede paralelizar mejor las operaciones

## Pruebas Recomendadas

1. Ejecutar `EXPLAIN (ANALYZE, BUFFERS)` en la nueva consulta
2. Verificar que usa `Index Scan using countries_spatial`
3. Medir tiempo de ejecución para un chunk de 20k notas
4. Comparar con versión anterior

## Próximos Pasos

1. ✅ Código mejorado implementado
2. ⏳ Probar en servidor de desarrollo
3. ⏳ Desplegar en producción
4. ⏳ Monitorear progreso

