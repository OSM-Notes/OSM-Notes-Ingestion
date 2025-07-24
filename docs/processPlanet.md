# Descripción Completa de processPlanetNotes.sh

## Propósito General

El script `processPlanetNotes.sh` es el componente central del sistema de procesamiento de notas de OpenStreetMap. Su función principal es descargar, procesar y cargar en una base de datos PostgreSQL todas las notas del planeta OSM, ya sea desde cero o solo las nuevas notas.

## Argumentos de Entrada

El script acepta tres tipos de argumentos:

### 1. Sin argumento (procesamiento incremental)
```bash
./processPlanetNotes.sh
```
- **Propósito**: Procesa solo las notas nuevas del archivo planet
- **Comportamiento**: 
  - Descarga el archivo planet más reciente
  - Compara con las notas existentes en la base de datos
  - Inserta solo las notas que no existen
  - Actualiza comentarios y textos de comentarios

### 2. Argumento `--base` (procesamiento completo)
```bash
./processPlanetNotes.sh --base
```
- **Propósito**: Procesa todas las notas desde cero
- **Comportamiento**:
  - Elimina todas las tablas existentes
  - Descarga y procesa límites de países y áreas marítimas
  - Descarga el archivo planet completo
  - Procesa todas las notas del planeta
  - Crea la estructura completa de la base de datos

### 3. Argumento `--boundaries` (solo límites)
```bash
./processPlanetNotes.sh --boundaries
```
- **Propósito**: Procesa únicamente los límites geográficos
- **Comportamiento**:
  - Descarga límites de países y áreas marítimas
  - Procesa y organiza las áreas geográficas
  - No procesa notas del planeta

## Arquitectura de Tablas

### Tablas Base (Permanentes)
Las tablas base almacenan el historial completo de todas las notas:

- **`notes`**: Almacena todas las notas del planeta
  - `note_id`: ID único de la nota OSM
  - `latitude/longitude`: Coordenadas geográficas
  - `created_at`: Fecha de creación
  - `status`: Estado (abierta/cerrada)
  - `closed_at`: Fecha de cierre (si aplica)
  - `id_country`: ID del país donde se ubica

- **`note_comments`**: Comentarios asociados a las notas
  - `id`: ID secuencial generado
  - `note_id`: Referencia a la nota
  - `sequence_action`: Orden del comentario
  - `event`: Tipo de acción (abrir, comentar, cerrar, etc.)
  - `created_at`: Fecha del comentario
  - `id_user`: ID del usuario OSM

- **`note_comments_text`**: Texto de los comentarios
  - `id`: ID del comentario
  - `note_id`: Referencia a la nota
  - `sequence_action`: Orden del comentario
  - `body`: Contenido textual del comentario

### Tablas Sync (Temporales)
Las tablas sync son temporales y se usan para el procesamiento incremental:

- **`notes_sync`**: Versión temporal de `notes`
- **`note_comments_sync`**: Versión temporal de `note_comments`
- **`note_comments_text_sync`**: Versión temporal de `note_comments_text`

**¿Por qué existen las tablas sync?**
1. **Procesamiento Paralelo**: Permiten procesar grandes volúmenes de datos en paralelo
2. **Validación**: Permiten verificar la integridad antes de mover a las tablas principales
3. **Rollback**: En caso de error, es más fácil revertir cambios en tablas temporales
4. **Deduplicación**: Permiten eliminar duplicados antes de la inserción final

## Flujo de Procesamiento

### 1. Preparación del Entorno
- Verificación de prerrequisitos (PostgreSQL, herramientas)
- Creación de directorios temporales
- Configuración de logging

### 2. Gestión de Tablas
**Para `--base`**:
- Elimina todas las tablas existentes
- Crea tablas base desde cero

**Para procesamiento incremental**:
- Elimina tablas sync
- Verifica existencia de tablas base
- Crea tablas sync para nuevo procesamiento

### 3. Procesamiento de Límites Geográficos
- Descarga IDs de países y áreas marítimas desde Overpass
- Descarga geometrías de límites
- Importa límites a la base de datos
- Organiza áreas por zonas geográficas

### 4. Procesamiento de Notas
- Descarga archivo planet de OSM
- Valida estructura XML
- Transforma XML a CSV usando XSLT
- Procesa en paralelo usando particiones
- Consolida resultados en tablas sync

### 5. Integración de Datos
- Elimina duplicados entre datos nuevos y existentes
- Asigna países a notas basado en coordenadas
- Mueve datos de tablas sync a tablas base
- Actualiza estadísticas y optimiza base de datos

## Procesamiento Paralelo

El script implementa procesamiento paralelo para manejar grandes volúmenes de datos:

1. **Particionamiento**: Divide el archivo XML en partes
2. **Procesamiento Concurrente**: Procesa cada parte en paralelo
3. **Consolidación**: Combina resultados en tablas principales

## Variables de Entorno Importantes

- **`LOG_LEVEL`**: Nivel de logging (DEBUG, INFO, WARN, ERROR)
- **`CLEAN`**: Si eliminar archivos temporales (true/false)
- **`BACKUP_COUNTRIES`**: Usar datos de respaldo para límites
- **`MAX_THREADS`**: Número de hilos para procesamiento paralelo

## Casos de Uso Típicos

### Primera Ejecución
```bash
export LOG_LEVEL=DEBUG
./processPlanetNotes.sh --base
```

### Actualización Diaria
```bash
export LOG_LEVEL=INFO
./processPlanetNotes.sh
```

### Solo Actualizar Límites
```bash
./processPlanetNotes.sh --boundaries
```

## Monitoreo y Debugging

### Seguimiento del Progreso
```bash
tail -40f $(ls -1rtd /tmp/processPlanetNotes_* | tail -1)/processPlanetNotes.log
```

### Consultas Útiles
```sql
-- Verificar notas por país
SELECT country_name_en, COUNT(*) FROM notes n 
JOIN countries c ON n.id_country = c.country_id 
GROUP BY country_name_en ORDER BY COUNT(*) DESC;

-- Verificar procesamiento paralelo
SELECT table_name, COUNT(*) FROM information_schema.tables 
WHERE table_name LIKE '%_part_%' GROUP BY table_name;
```

## Consideraciones Técnicas

### Limitaciones Conocidas
- Austria: Problemas de geometría con ogr2ogr
- Taiwan: Filas muy largas que requieren truncamiento
- Gaza Strip: No está al mismo nivel que países (ID hardcodeado)
- No todos los países tienen límites marítimos definidos

### Requisitos del Sistema
- PostgreSQL con extensiones PostGIS y btree_gist
- Herramientas: wget, xsltproc, ogr2ogr, psql
- Espacio suficiente para archivos temporales
- Conexión a internet para descargas

Esta arquitectura permite procesar eficientemente millones de notas de OSM manteniendo la integridad de los datos y proporcionando flexibilidad para diferentes tipos de procesamiento.
