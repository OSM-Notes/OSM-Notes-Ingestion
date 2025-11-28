# Análisis del Problema de Verificación de Integridad

**Fecha:** 2025-11-28  
**Autor:** Andres Gomez (AngocA)

## Problema Identificado

El proceso de verificación de integridad está bloqueado después de 20+ minutos sin completar ningún chunk (0/51 completados).

## Comparación de Versiones

### Versión Original (2025-11-25)

```sql
WITH notes_to_verify AS (
  SELECT n.note_id, n.id_country, n.longitude, n.latitude
  FROM notes AS n
  WHERE n.id_country IS NOT NULL
    AND ${SUB_START} <= n.note_id AND n.note_id < ${SUB_END}
),
countries_to_check AS (
  SELECT DISTINCT c.country_id, c.geom
  FROM countries c
  INNER JOIN notes_to_verify ntv ON c.country_id = ntv.id_country
),
verified AS (
  SELECT ntv.note_id,
         ntv.id_country AS current_country,
         CASE
           WHEN c.geom IS NOT NULL AND ST_Contains(...)
           THEN ntv.id_country
           ELSE -1
         END AS verified_country
  FROM notes_to_verify ntv
  LEFT JOIN countries_to_check c ON c.country_id = ntv.id_country
)
```

**Problemas:**
1. `countries_to_check` carga todas las geometrías de países únicos en memoria
2. `DISTINCT` requiere ordenamiento masivo (~5 GB para 20k notas)
3. `work_mem` insuficiente (16 MB) causa swap masivo a disco
4. Tiempo estimado: 6-8 minutos por chunk

### Versión Optimizada (2025-11-27) - ACTUAL

```sql
WITH notes_to_verify AS (...),
assigned_country_check AS (
  SELECT ntv.note_id, ...
  FROM notes_to_verify ntv
  INNER JOIN countries c ON c.country_id = ntv.id_country
),
matched_notes AS (...),
unmatched_notes AS (...),
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

**Mejoras:**
1. ✅ `INNER JOIN` directo con `country_id` (clave primaria) - rápido
2. ✅ Separa notas coincidentes de no coincidentes
3. ✅ Solo busca espacialmente las notas sin coincidencia

**Problema Identificado:**
- La subconsulta correlacionada en `spatial_verified` (líneas 67-70) puede no estar usando el índice espacial eficientemente
- PostgreSQL puede estar evaluando `ST_Contains` sin usar el índice `countries_spatial` correctamente
- El `LIMIT 1` dentro de la subconsulta puede causar problemas de planificación

## Análisis del Índice Espacial

```sql
-- Índice existe y está correcto
CREATE INDEX countries_spatial ON countries USING gist (geom)

-- Prueba de uso del índice:
EXPLAIN ANALYZE SELECT c.country_id 
FROM countries c 
WHERE ST_Contains(c.geom, ST_SetSRID(ST_Point(-74.0, 4.6), 4326)) 
LIMIT 1;

-- Resultado: Usa Index Scan (correcto), pero tarda 86ms
```

**Observación:** El índice funciona, pero la subconsulta correlacionada puede no estar optimizada.

## Solución Propuesta

Usar `LATERAL JOIN` para forzar el uso eficiente del índice espacial:

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

**Ventajas de LATERAL JOIN:**
1. Fuerza a PostgreSQL a usar el índice espacial para cada fila
2. Evita escaneos completos de la tabla `countries`
3. Mejor planificación de consultas
4. Más eficiente que subconsultas correlacionadas

## Próximos Pasos

1. Implementar versión con `LATERAL JOIN`
2. Probar en servidor de desarrollo
3. Comparar tiempos de ejecución
4. Desplegar si mejora significativamente

