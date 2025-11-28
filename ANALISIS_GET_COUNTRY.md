# Optimización Propuesta: Función get_country()

**Fecha:** 2025-11-27  
**Autor:** Andres Gomez (AngocA)

## Contexto

La función `get_country()` actualmente usa un loop PL/pgSQL para iterar sobre países y ejecutar `ST_Contains()` hasta encontrar el país correcto. Aunque ya se implementó la optimización de bounding box (ST_Intersects antes de ST_Contains), existe una oportunidad adicional de optimización.

---

## Optimización Propuesta: Consulta SQL Directa en lugar de Loop

### Estrategia Actual

La función actualmente usa un loop PL/pgSQL:

```sql
FOR m_record IN EXECUTE format(
  'SELECT geom, country_id,
          ST_MakeEnvelope(...) AS bbox
   FROM countries
   WHERE country_id != %L
   ORDER BY %I NULLS LAST',
  COALESCE(m_current_country, -1),
  m_order_column
)
LOOP
  IF ST_Intersects(m_record.bbox, ...) THEN
    m_contains := ST_Contains(m_record.geom, ...);
    IF (m_contains) THEN
      m_id_country := m_record.country_id;
      EXIT;
    END IF;
  END IF;
END LOOP;
```

### Problema

- El loop PL/pgSQL ejecuta `ST_Intersects()` y `ST_Contains()` una iteración a la vez
- PostgreSQL no puede optimizar el loop completo como una sola consulta
- Cada iteración tiene overhead de PL/pgSQL

### Solución Propuesta

Reemplazar el loop con una consulta SQL directa que PostgreSQL puede optimizar mejor:

```sql
-- Reemplazar el loop FOR con una consulta SQL directa:
SELECT country_id INTO m_id_country
FROM countries
WHERE country_id != COALESCE(m_current_country, -1)
  -- First filter by bounding box (fast)
  AND ST_Intersects(
    ST_MakeEnvelope(
      ST_XMin(geom), ST_YMin(geom),
      ST_XMax(geom), ST_YMax(geom),
      4326
    ),
    ST_SetSRID(ST_Point(lon, lat), 4326)
  )
  -- Then check exact containment (expensive, but only for filtered countries)
  AND ST_Contains(
    geom,
    ST_SetSRID(ST_Point(lon, lat), 4326)
  )
ORDER BY 
  -- Priority: current country first (if exists)
  CASE 
    WHEN country_id = m_current_country THEN 0
    ELSE 1
  END,
  -- Then by zone priority (dynamic column)
  CASE m_order_column
    WHEN 'zone_western_europe' THEN zone_western_europe
    WHEN 'zone_eastern_europe' THEN zone_eastern_europe
    WHEN 'zone_northern_europe' THEN zone_northern_europe
    WHEN 'zone_southern_europe' THEN zone_southern_europe
    WHEN 'zone_us_canada' THEN zone_us_canada
    WHEN 'zone_mexico_central_america' THEN zone_mexico_central_america
    WHEN 'zone_caribbean' THEN zone_caribbean
    WHEN 'zone_northern_south_america' THEN zone_northern_south_america
    WHEN 'zone_southern_south_america' THEN zone_southern_south_america
    WHEN 'zone_northern_africa' THEN zone_northern_africa
    WHEN 'zone_western_africa' THEN zone_western_africa
    WHEN 'zone_eastern_africa' THEN zone_eastern_africa
    WHEN 'zone_southern_africa' THEN zone_southern_africa
    WHEN 'zone_middle_east' THEN zone_middle_east
    WHEN 'zone_arctic' THEN zone_arctic
    WHEN 'zone_antarctic' THEN zone_antarctic
    WHEN 'zone_russia_north' THEN zone_russia_north
    WHEN 'zone_russia_south' THEN zone_russia_south
    WHEN 'zone_central_asia' THEN zone_central_asia
    WHEN 'zone_india_south_asia' THEN zone_india_south_asia
    WHEN 'zone_southeast_asia' THEN zone_southeast_asia
    WHEN 'zone_eastern_asia' THEN zone_eastern_asia
    WHEN 'zone_australia_nz' THEN zone_australia_nz
    WHEN 'zone_pacific_islands' THEN zone_pacific_islands
    ELSE NULL
  END NULLS LAST
LIMIT 1;
```

### Ventajas

1. **Mejor optimización de PostgreSQL**: El optimizador puede planificar toda la consulta de una vez
2. **Uso eficiente de índices**: PostgreSQL puede usar índices espaciales de manera más eficiente
3. **Menos overhead**: Elimina el overhead del loop PL/pgSQL
4. **Paralelización potencial**: PostgreSQL puede paralelizar partes de la consulta si es beneficioso

### Desafíos

1. **Columna ORDER BY dinámica**: Requiere un `CASE` grande para manejar todas las columnas de zona
2. **Validación**: Necesita pruebas para confirmar que es más rápido que el loop actual
3. **Compatibilidad**: Asegurar que funciona igual que el loop (mismo comportamiento)

### Impacto Esperado

- **Reducción adicional del 30-40%** en tiempo de ejecución
- Combinado con la optimización de bounding box ya implementada, podría reducir el tiempo total de **~314ms a <30ms** por llamada

### Consideraciones de Implementación

1. **Pruebas**: Validar que la consulta SQL directa produce los mismos resultados que el loop
2. **Performance**: Medir el tiempo de ejecución antes y después
3. **Casos edge**: Verificar que maneja correctamente todos los casos (NULLs, países sin zona, etc.)

### Estado

**Pendiente de implementación** - Requiere análisis y pruebas antes de aplicar.

---

## Notas Adicionales

- La optimización de bounding box (ST_Intersects antes de ST_Contains) ya está implementada y funcionando
- Esta optimización sería complementaria a la anterior
- Se recomienda implementar después de validar la optimización actual en producción
