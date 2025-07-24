# Descripción Completa de processAPINotes.sh

## Propósito General

El script `processAPINotes.sh` es el componente de sincronización incremental del sistema de procesamiento de notas de OpenStreetMap. Su función principal es descargar las notas más recientes desde la API de OSM y sincronizarlas con la base de datos local que mantiene el historial completo.

## Características Principales

- **Procesamiento Incremental**: Solo descarga y procesa notas nuevas o modificadas
- **Sincronización Inteligente**: Determina automáticamente cuándo hacer sincronización completa desde Planet
- **Procesamiento Paralelo**: Utiliza particionamiento para procesar grandes volúmenes eficientemente
- **Integración con Planet**: Se integra con `processPlanetNotes.sh` cuando es necesario

## Argumentos de Entrada

El script **NO acepta argumentos** para su ejecución normal. Solo acepta:

```bash
./processAPINotes.sh --help
# o
./processAPINotes.sh -h
```

**¿Por qué no acepta argumentos?**
- Está diseñado para ejecutarse automáticamente (cron job)
- La lógica de decisión es interna basada en el estado de la base de datos
- La configuración se hace mediante variables de entorno

## Arquitectura de Tablas

### Tablas API (Temporales)
Las tablas API almacenan temporalmente los datos descargados de la API:

- **`notes_api`**: Notas descargadas de la API
  - `note_id`: ID único de la nota OSM
  - `latitude/longitude`: Coordenadas geográficas
  - `created_at`: Fecha de creación
  - `status`: Estado (abierta/cerrada)
  - `closed_at`: Fecha de cierre (si aplica)
  - `id_country`: ID del país donde se ubica
  - `part_id`: ID de partición para procesamiento paralelo

- **`note_comments_api`**: Comentarios descargados de la API
  - `id`: ID secuencial generado
  - `note_id`: Referencia a la nota
  - `sequence_action`: Orden del comentario
  - `event`: Tipo de acción (abrir, comentar, cerrar, etc.)
  - `created_at`: Fecha del comentario
  - `id_user`: ID del usuario OSM
  - `username`: Nombre del usuario OSM
  - `part_id`: ID de partición para procesamiento paralelo

- **`note_comments_text_api`**: Texto de comentarios descargados de la API
  - `id`: ID del comentario
  - `note_id`: Referencia a la nota
  - `sequence_action`: Orden del comentario
  - `body`: Contenido textual del comentario
  - `part_id`: ID de partición para procesamiento paralelo

### Tablas Base (Permanentes)
Utiliza las mismas tablas base que `processPlanetNotes.sh`:
- `notes`, `note_comments`, `note_comments_text`

## Flujo de Procesamiento

### 1. Verificación de Prerrequisitos
- Verifica que no esté ejecutándose `processPlanetNotes.sh`
- Comprueba existencia de tablas base
- Valida archivos SQL y XSLT necesarios

### 2. Gestión de Tablas API
- Elimina tablas API existentes
- Crea nuevas tablas API con particionamiento
- Crea tabla de propiedades para seguimiento

### 3. Descarga de Datos
- Obtiene timestamp de última actualización desde la base de datos
- Construye URL de API con parámetros de filtrado
- Descarga notas nuevas/modificadas desde la API de OSM
- Valida estructura XML descargada

### 4. Decisión de Procesamiento
**Si las notas descargadas >= MAX_NOTES (configurable)**:
- Ejecuta sincronización completa desde Planet
- Llama a `processPlanetNotes.sh`

**Si las notas descargadas < MAX_NOTES**:
- Procesa las notas descargadas localmente
- Utiliza procesamiento paralelo con particionamiento

### 5. Procesamiento Paralelo
- Divide el archivo XML en partes
- Procesa cada parte en paralelo usando XSLT
- Consolida resultados de todas las particiones

### 6. Integración de Datos
- Inserta nuevas notas y comentarios en tablas base
- Procesa en chunks si hay muchos datos (>1000 notas)
- Actualiza timestamp de última actualización
- Limpia archivos temporales

## Lógica de Sincronización Inteligente

### Criterios para Sincronización Completa
- Número de notas descargadas >= MAX_NOTES
- Problemas de conectividad con la API
- Errores en el procesamiento incremental

### Ventajas de la Sincronización Inteligente
1. **Eficiencia**: Evita descargas innecesarias del archivo planet completo
2. **Velocidad**: Procesamiento incremental es mucho más rápido
3. **Recursos**: Menor uso de ancho de banda y almacenamiento
4. **Confiabilidad**: Fallback automático a sincronización completa

## Procesamiento Paralelo

### Particionamiento Dinámico
- Crea particiones basadas en `MAX_THREADS`
- Cada partición procesa una porción del archivo XML
- Consolidación automática de resultados

### Inserción Paralela
- Para grandes volúmenes (>1000 notas): inserción en chunks paralelos
- Para volúmenes pequeños: inserción secuencial
- Control de concurrencia mediante locks de base de datos

## Variables de Entorno Importantes

- **`LOG_LEVEL`**: Nivel de logging (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
- **`CLEAN`**: Si eliminar archivos temporales (true/false)
- **`MAX_NOTES`**: Umbral para decidir sincronización completa
- **`MAX_THREADS`**: Número de hilos para procesamiento paralelo
- **`OSM_API`**: URL base de la API de OSM

## Casos de Uso Típicos

### Ejecución Manual
```bash
export LOG_LEVEL=DEBUG
./processAPINotes.sh
```

### Configuración en Cron
```bash
# Ejecutar cada hora
0 * * * * /path/to/processAPINotes.sh >> /var/log/osm-notes.log 2>&1
```

### Monitoreo del Progreso
```bash
tail -40f $(ls -1rtd /tmp/processAPINotes_* | tail -1)/processAPINotes.log
```

## Consultas Útiles

```sql
-- Verificar última actualización
SELECT timestamp FROM max_note_timestamp;

-- Verificar notas descargadas de API
SELECT COUNT(*) FROM notes_api;

-- Verificar procesamiento paralelo
SELECT table_name, COUNT(*) FROM information_schema.tables 
WHERE table_name LIKE '%_api%' GROUP BY table_name;

-- Verificar sincronización reciente
SELECT COUNT(*) as new_notes, 
       MIN(created_at) as earliest_note,
       MAX(created_at) as latest_note
FROM notes 
WHERE created_at > (SELECT timestamp FROM max_note_timestamp);
```

## Integración con processPlanetNotes.sh

### Llamadas Automáticas
- Cuando se detecta que se necesita sincronización completa
- Cuando las tablas base no existen
- Cuando hay errores en el procesamiento incremental

### Coordinación
- Verifica que `processPlanetNotes.sh` no esté ejecutándose
- Espera a que termine antes de continuar
- Maneja errores de sincronización completa

## Consideraciones Técnicas

### Limitaciones de la API
- Rate limiting de la API de OSM
- Tamaño máximo de respuesta
- Disponibilidad de la API

### Optimizaciones
- Procesamiento paralelo para grandes volúmenes
- Inserción en chunks para evitar timeouts
- Limpieza automática de archivos temporales

### Requisitos del Sistema
- PostgreSQL con extensiones necesarias
- Herramientas: wget, xsltproc, psql
- Conexión a internet para API de OSM
- Espacio suficiente para archivos temporales

Esta arquitectura proporciona un sistema robusto de sincronización incremental que maximiza la eficiencia mientras mantiene la integridad de los datos.