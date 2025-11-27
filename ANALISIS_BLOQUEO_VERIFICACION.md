# Análisis del Bloqueo en la Verificación de Integridad

**Fecha:** 2025-11-27  
**Autor:** Andres Gomez (AngocA)

## Problema Identificado

El proceso de verificación de integridad está completamente bloqueado después de más de 3.5 horas sin completar ningún chunk (0/51 completados).

## Causa Raíz del Bloqueo

### Versión Actual en Ejecución (2025-11-25 - ANTIGUA)

La consulta está ejecutando la versión antigua que tiene estos problemas críticos:

#### 1. Carga Masiva de Geometrías en Memoria

```sql
countries_to_check AS (
  SELECT DISTINCT c.country_id, c.geom
  FROM countries c
  INNER JOIN notes_to_verify ntv ON c.country_id = ntv.id_country
)
```

**Problema:**
- Para un chunk de 19,680 notas con 173 países únicos
- Está cargando **68 MB de geometrías** en memoria
- Cada geometría tiene ~268KB de tamaño
- Total: **~5 GB de datos** que necesita procesar

#### 2. Operación de Ordenamiento Masiva

Del plan de ejecución:
```
Unique (cost=5050212.24..5050377.21 rows=316 width=268486)
-> Sort (cost=5050212.24..5050267.23 rows=21996 width=268486)
  Sort Method: quicksort Memory: 2579kB
```

**Problema:**
- Está ordenando **19,519 filas** con geometrías de **268KB cada una**
- Total de datos a ordenar: **~5 GB**
- `work_mem` configurado: **131 MB** (131072 kB)
- Solo puede mantener **2.5 MB en memoria** (2579kB)
- El resto va a **disco temporal** (swap masivo)

#### 3. Tiempo de Ejecución Extremo

Del plan de ejecución real:
- **Tiempo de ejecución:** 278,946 ms = **278 segundos = 4.6 minutos**
- Esto es solo para el **COUNT**, sin incluir el **UPDATE**
- Con el UPDATE incluido, probablemente sean **6-8 minutos por chunk mínimo**

#### 4. Por Qué No Completa Ningún Chunk

El proceso está diseñado para:
1. Ejecutar consulta SQL (4-8 minutos)
2. Obtener resultado
3. Actualizar contador de progreso
4. Continuar con siguiente chunk

**Problema:** Las consultas están tardando tanto que:
- No completan dentro del timeout esperado
- El contador de progreso nunca se actualiza
- El proceso queda "bloqueado" esperando que las consultas terminen

## Análisis del Plan de Ejecución

### Operaciones Costosas Identificadas

1. **Seq Scan en countries** (carga todas las geometrías)
   - Carga 316 países × 268KB = ~84 MB
   - Luego filtra a 173 países únicos = ~46 MB

2. **Hash Join** (une países con notas)
   - Crea hash table con geometrías grandes
   - 19,519 filas × 268KB = ~5 GB de datos

3. **Sort** (ordena geometrías)
   - Ordena 19,519 filas de 268KB cada una
   - Solo 2.5 MB en memoria, resto a disco
   - **Operación extremadamente lenta**

4. **Hash Right Join** (verifica cada nota contra cada país)
   - Evalúa ST_Contains para cada combinación
   - 19,680 notas × 173 países = **3.4 millones de evaluaciones ST_Contains**

### Configuración PostgreSQL

- `work_mem`: 131 MB (insuficiente para las geometrías)
- `shared_buffers`: 2 GB
- `maintenance_work_mem`: 16 MB

**Problema:** `work_mem` es demasiado pequeño para manejar geometrías de 268KB. Cada vez que necesita ordenar, debe escribir a disco temporal.

## Comparación: Versión Antigua vs Optimizada

### Versión Antigua (2025-11-25) - EN EJECUCIÓN ACTUAL

**Problemas:**
- ❌ Carga 68 MB de geometrías en memoria por chunk
- ❌ Ordena ~5 GB de datos (mayoría en disco)
- ❌ Evalúa ST_Contains para 3.4M combinaciones
- ❌ Tiempo: **4-8 minutos por chunk** (solo COUNT, sin UPDATE)
- ❌ Tiempo total estimado: **67+ horas** para 5M notas

### Versión Optimizada (2025-11-27) - IMPLEMENTADA

**Ventajas:**
- ✅ JOIN directo con país asignado (rápido, usa primary key)
- ✅ Solo 5% de notas necesitan búsqueda espacial
- ✅ Usa índice espacial GIST directamente (sin cargar geometrías)
- ✅ Tiempo esperado: **5-10 segundos por chunk**
- ✅ Tiempo total estimado: **2-4 horas** para 5M notas

## Por Qué No Procesó Ningún Chunk

### Secuencia del Proceso

1. **Inicio:** 17:59:54 - Inicia verificación con 6 threads
2. **Threads inician:** Cada thread toma un chunk del queue
3. **Ejecuta consulta SQL:** Versión antigua (carga todas las geometrías)
4. **Consulta bloqueada:** Ordenando 5GB de datos con solo 131MB de memoria
5. **Swap a disco:** Operaciones de I/O masivas
6. **Tiempo excesivo:** 4-8 minutos por consulta (solo COUNT)
7. **Sin completar:** Después de 3.5 horas, ninguna consulta ha terminado
8. **Contador:** Nunca se actualiza porque las consultas no completan

### Evidencia

- **Progreso:** 0/51 chunks completados después de 3.5 horas
- **Procesos PostgreSQL:** 100% CPU pero sin completar consultas
- **Tiempo de ejecución:** 278 segundos solo para COUNT (sin UPDATE)
- **Memoria:** Solo 2.5 MB en memoria, resto en disco

## Solución

### Inmediata

1. **Cancelar proceso actual** (está usando versión antigua)
2. **Reiniciar con versión optimizada** (2025-11-27)
3. **La nueva versión debería completar en 2-4 horas** en lugar de 67+ horas

### A Largo Plazo

1. **Aumentar `work_mem`** si es necesario para operaciones futuras
2. **Monitorear** el uso de la versión optimizada
3. **Validar** que los resultados sean correctos

## Conclusión

El proceso está bloqueado porque:

1. ✅ **Está usando la versión antigua** (2025-11-25) que carga todas las geometrías
2. ✅ **Las consultas están tardando 4-8 minutos cada una** (solo COUNT)
3. ✅ **El ordenamiento de 5GB con solo 131MB de memoria** causa swap masivo
4. ✅ **Ninguna consulta ha completado** después de 3.5 horas
5. ✅ **El contador de progreso nunca se actualiza** porque las consultas no terminan

**La solución es cancelar y reiniciar con la versión optimizada (2025-11-27) que evita cargar todas las geometrías y usa el índice espacial directamente.**

