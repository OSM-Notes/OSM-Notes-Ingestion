# Cómo Continuar la Verificación de Integridad

**Fecha:** 2025-11-28  
**Autor:** Andres Gomez (AngocA)

## Resumen

**SÍ, puedes continuar desde donde se quedó sin comenzar desde cero.**

El proceso de verificación de integridad está diseñado para ser **idempotente** y **resumible**.

## Cómo Funciona

### 1. Estado en la Base de Datos

El proceso verifica solo las notas que tienen `id_country IS NOT NULL`:

```sql
SELECT COALESCE(MAX(note_id), 0) 
FROM notes 
WHERE id_country IS NOT NULL
```

### 2. Proceso de Invalidación

Cuando una nota no pertenece a su país asignado, se invalida:

```sql
UPDATE notes 
SET id_country = NULL
WHERE note_id = ...
```

### 3. Continuación Automática

Al reiniciar el proceso:

1. ✅ Lee `MAX_NOTE_ID_NOT_NULL` desde la base de datos
2. ✅ Solo procesa notas con `id_country IS NOT NULL`
3. ✅ Las notas ya invalidadas (`id_country = NULL`) se saltan automáticamente
4. ✅ Continúa desde donde se quedó

## Pasos para Continuar

### Paso 1: Cancelar Procesos Bloqueados

```bash
# Cancelar procesos de processPlanetNotes
sudo -u notes pkill -TERM -f processPlanetNotes.sh

# Cancelar consultas PostgreSQL bloqueadas
psql -d notes -c "SELECT pg_cancel_backend(pid) 
FROM pg_stat_activity 
WHERE state = 'active' 
AND (query LIKE '%verifyNoteIntegrity%' OR query LIKE '%Notes-integrity%');"
```

### Paso 2: Verificar Estado Actual

```bash
# Ver cuántas notas quedan por verificar
psql -d notes -c "
SELECT 
  COUNT(*) as total_notes,
  COUNT(id_country) as notes_with_country,
  COUNT(*) - COUNT(id_country) as notes_without_country
FROM notes;"
```

### Paso 3: Reiniciar el Proceso

```bash
cd /home/notes/OSM-Notes-Ingestion
./bin/process/processPlanetNotes.sh --base
```

El proceso automáticamente:
- Detectará que hay notas con `id_country IS NOT NULL`
- Procesará solo esas notas
- Continuará desde donde se quedó

## Ventajas de Este Diseño

1. **Idempotente:** Puede ejecutarse múltiples veces sin duplicar trabajo
2. **Resumible:** Si se interrumpe, puede continuar sin perder progreso
3. **Eficiente:** Solo procesa lo que falta
4. **Seguro:** No duplica invalidaciones

## Notas Importantes

- ⚠️ **No reinicies desde cero** (`--base` limpia todo)
- ✅ **Solo reinicia el proceso** y continuará automáticamente
- ✅ Las notas ya invalidadas (`id_country = NULL`) no se procesan de nuevo
- ✅ El progreso se guarda implícitamente en la base de datos

## Ejemplo de Continuación

**Estado antes de cancelar:**
- Total notas: 4,926,282
- Con país: 4,845,211 (pendientes de verificar)
- Sin país: 81,071 (ya invalidadas)

**Después de cancelar y reiniciar:**
- El proceso procesará solo las 4,845,211 notas con país
- Las 81,071 ya invalidadas se saltan automáticamente
- Continúa desde donde se quedó

