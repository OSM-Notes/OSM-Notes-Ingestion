# Casos Especiales de Pruebas Unitarias

Este directorio contiene archivos XML de prueba para casos especiales que pueden ocurrir cuando el API devuelve datos. Estos casos están diseñados para probar la robustez del sistema de procesamiento de notas.

## Casos de Prueba

### 1. Cero Notas (`zero_notes.xml`)
- **Descripción**: API devuelve 0 notas
- **Propósito**: Probar el manejo de casos vacíos
- **Escenario**: `<osm></osm>` sin elementos `<note>`

### 2. Nota Única (`single_note.xml`)
- **Descripción**: API devuelve solo 1 nota
- **Propósito**: Probar el procesamiento de una sola nota
- **Escenario**: Una nota con dos comentarios (creación y cierre)

### 3. Menos Notas que Hilos (`less_than_threads.xml`)
- **Descripción**: 5 notas (menos que 7 hilos disponibles)
- **Propósito**: Probar cuando hay menos trabajo que hilos disponibles
- **Escenario**: 5 notas para probar la gestión de hilos ociosos

### 4. Igual a Núcleos (`equal_to_cores.xml`)
- **Descripción**: 12 notas (igual a la cantidad de núcleos)
- **Propósito**: Asegurar que todos los hilos en paralelo se activan
- **Escenario**: 12 notas para maximizar el uso de CPU

### 5. Muchas Más que Núcleos (`many_more_than_cores.xml`)
- **Descripción**: 25 notas (muchas más que 7 núcleos)
- **Propósito**: Probar el procesamiento en lotes y gestión de memoria
- **Escenario**: 25 notas para probar el procesamiento masivo

### 6. Doble Cierre (`double_close.xml`)
- **Descripción**: Nota cerrada dos veces consecutivas
- **Propósito**: Probar el manejo de errores del API
- **Escenario**: Error que a veces ocurre en el API de OSM

### 7. Doble Reapertura (`double_reopen.xml`)
- **Descripción**: Nota reabierta dos veces consecutivas
- **Propósito**: Probar el manejo de errores del API
- **Escenario**: Error que a veces ocurre en el API de OSM

### 8. Crear y Cerrar (`create_and_close.xml`)
- **Descripción**: Nota creada y cerrada en el mismo llamado del API
- **Propósito**: Probar el procesamiento de eventos simultáneos
- **Escenario**: Mismo timestamp para creación y cierre

### 9. Cerrar y Reabrir (`close_and_reopen.xml`)
- **Descripción**: Nota cerrada y reabierta en el mismo llamado del API
- **Propósito**: Probar el procesamiento de eventos simultáneos
- **Escenario**: Mismo timestamp para cierre y reapertura

### 10. Abrir-Cerrar-Reabrir (`open_close_reopen.xml`)
- **Descripción**: Nota abierta, cerrada y reabierta en el mismo llamado
- **Propósito**: Probar el procesamiento de secuencias complejas
- **Escenario**: Ciclo completo en un solo llamado del API

### 11. Ciclo Completo (`open_close_reopen_cycle.xml`)
- **Descripción**: Nota con ciclo completo abrir-cerrar-reabrir-cerrar
- **Propósito**: Probar el procesamiento de ciclos complejos
- **Escenario**: Múltiples cambios de estado en un llamado

### 12. Comentar y Cerrar (`comment_and_close.xml`)
- **Descripción**: Nota comentada y después cerrada
- **Propósito**: Probar el procesamiento de comentarios antes del cierre
- **Escenario**: Múltiples comentarios seguidos de cierre

## Uso en Pruebas

### Ejecutar Pruebas con Casos Especiales

```bash
# Probar con cero notas
./bin/process/processAPINotes.sh tests/fixtures/special_cases/zero_notes.xml

# Probar con nota única
./bin/process/processAPINotes.sh tests/fixtures/special_cases/single_note.xml

# Probar con menos notas que hilos
./bin/process/processAPINotes.sh tests/fixtures/special_cases/less_than_threads.xml

# Probar con igual a núcleos
./bin/process/processAPINotes.sh tests/fixtures/special_cases/equal_to_cores.xml

# Probar con muchas más que núcleos
./bin/process/processAPINotes.sh tests/fixtures/special_cases/many_more_than_cores.xml
```

### Casos de Error del API

```bash
# Probar doble cierre
./bin/process/processAPINotes.sh tests/fixtures/special_cases/double_close.xml

# Probar doble reapertura
./bin/process/processAPINotes.sh tests/fixtures/special_cases/double_reopen.xml

# Probar crear y cerrar
./bin/process/processAPINotes.sh tests/fixtures/special_cases/create_and_close.xml

# Probar cerrar y reabrir
./bin/process/processAPINotes.sh tests/fixtures/special_cases/close_and_reopen.xml

# Probar abrir-cerrar-reabrir
./bin/process/processAPINotes.sh tests/fixtures/special_cases/open_close_reopen.xml

# Probar ciclo completo
./bin/process/processAPINotes.sh tests/fixtures/special_cases/open_close_reopen_cycle.xml

# Probar comentar y cerrar
./bin/process/processAPINotes.sh tests/fixtures/special_cases/comment_and_close.xml
```

## Validación de Resultados

### Resultados Esperados

1. **Cero Notas**: No debe generar errores, debe procesar correctamente
2. **Nota Única**: Debe procesar la nota correctamente
3. **Menos que Hilos**: Debe usar solo los hilos necesarios
4. **Igual a Núcleos**: Debe usar todos los hilos disponibles
5. **Muchas Más**: Debe procesar en lotes eficientemente
6. **Errores del API**: Debe manejar los errores graciosamente

### Verificaciones

- [ ] Procesamiento sin errores
- [ ] Uso correcto de hilos paralelos
- [ ] Manejo de errores del API
- [ ] Procesamiento de comentarios
- [ ] Gestión de estados de notas
- [ ] Rendimiento aceptable

## Notas Técnicas

- Todos los archivos XML siguen el formato estándar de OSM
- Los timestamps están coordinados para simular llamadas reales del API
- Los IDs de notas y comentarios son únicos para evitar conflictos
- Las coordenadas están en Madrid, España para consistencia
- Los usuarios son ficticios para propósitos de prueba

## Integración con CI/CD

Estos casos especiales se pueden integrar en el pipeline de CI/CD:

```yaml
# Ejemplo para GitHub Actions
- name: Test Special Cases
  run: |
    for file in tests/fixtures/special_cases/*.xml; do
      echo "Testing: $file"
      ./bin/process/processAPINotes.sh "$file"
    done
```

## Mantenimiento

- Agregar nuevos casos especiales según sea necesario
- Actualizar este README cuando se agreguen nuevos casos
- Verificar que todos los casos funcionen con cambios en el código
- Mantener la consistencia en el formato XML 