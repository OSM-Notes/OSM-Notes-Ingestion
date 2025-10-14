# Guía Rápida de Ejecución de Tests

**Versión:** 2025-10-14

## 🚀 Comandos Rápidos

### Verificación Rápida (15-20 min)

```bash
cd /home/angoca/github/OSM-Notes-Ingestion
./tests/run_tests_sequential.sh quick
```

### Tests Básicos - Niveles 1-3 (20-35 min)

```bash
./tests/run_tests_sequential.sh basic
```

### Tests Estándar - Niveles 1-6 (45-75 min)

```bash
./tests/run_tests_sequential.sh standard
```

### Suite Completa - Todos los niveles (90-135 min)

```bash
./tests/run_tests_sequential.sh full
```

---

## 📋 Ejecutar Nivel Específico

### Nivel 1 - Tests Básicos (5-10 min)

```bash
./tests/run_tests_sequential.sh level 1
```

### Nivel 2 - Validación (10-15 min)

```bash
./tests/run_tests_sequential.sh level 2
```

### Nivel 3 - XML/XSLT (8-12 min)

```bash
./tests/run_tests_sequential.sh level 3
```

### Nivel 4 - Procesamiento (15-25 min)

```bash
./tests/run_tests_sequential.sh level 4
```

### Nivel 5 - Procesamiento Paralelo (10-15 min)

```bash
./tests/run_tests_sequential.sh level 5
```

### Nivel 6 - Cleanup y Error Handling (12-18 min)

```bash
./tests/run_tests_sequential.sh level 6
```

### Nivel 7 - Monitoreo y WMS (8-12 min)

```bash
./tests/run_tests_sequential.sh level 7
```

### Nivel 8 - Tests Avanzados (10-15 min)

```bash
./tests/run_tests_sequential.sh level 8
```

### Nivel 9 - Integración End-to-End (10-20 min)

```bash
./tests/run_tests_sequential.sh level 9
```

### Nivel 10 - DWH Enhanced (10-15 min)

```bash
./tests/run_tests_sequential.sh level 10
```

---

## 🎯 Tests por Categoría Funcional

### ProcessAPI

```bash
bats tests/unit/bash/processAPINotes*.bats \
     tests/unit/bash/api_download_verification.test.bats \
     tests/unit/bash/historical_data_validation.test.bats
```

### ProcessPlanet

```bash
bats tests/unit/bash/processPlanetNotes*.bats \
     tests/unit/bash/mock_planet_functions.test.bats
```

### XML/XSLT

```bash
bats tests/unit/bash/xml*.bats tests/unit/bash/xslt*.bats
```

### Procesamiento Paralelo

```bash
bats tests/parallel_processing_test_suite.bats \
     tests/unit/bash/parallel*.bats
```

### Validación

```bash
bats tests/unit/bash/*validation*.bats
```

### Cleanup

```bash
bats tests/unit/bash/cleanup*.bats tests/unit/bash/clean*.bats
```

### WMS

```bash
bats tests/unit/bash/wms*.bats \
     tests/integration/wms_integration.test.bats
```

### Error Handling

```bash
bats tests/unit/bash/error_handling*.bats
```

---

## 🔍 Ejecutar Suite Individual

### Una suite específica

```bash
bats tests/unit/bash/processAPINotes.test.bats
```

### Una suite con verbose

```bash
bats -t tests/unit/bash/processAPINotes.test.bats
```

### Un test específico dentro de una suite

```bash
bats tests/unit/bash/processAPINotes.test.bats -f "nombre_del_test"
```

---

## 📊 Recomendaciones por Situación

### Antes de Commit

```bash
# Opción 1: Quick check (15-20 min)
./tests/run_tests_sequential.sh quick

# Opción 2: Basic (20-35 min)
./tests/run_tests_sequential.sh basic
```

### Antes de Push

```bash
# Standard (45-75 min)
./tests/run_tests_sequential.sh standard
```

### Antes de Merge/PR

```bash
# Full (90-135 min)
./tests/run_tests_sequential.sh full
```

### Durante Desarrollo de Feature

```bash
# Ejecutar solo el nivel relacionado con tu feature
./tests/run_tests_sequential.sh level N

# O la categoría específica
bats tests/unit/bash/[categoria]*.bats
```

### Debugging de Fallo

```bash
# Re-ejecutar suite específica con verbose
bats -t tests/unit/bash/suite_que_fallo.test.bats

# Ver solo un test específico
bats tests/unit/bash/suite.test.bats -f "test_especifico"
```

---

## 🔧 Troubleshooting

### PostgreSQL no disponible

```bash
# Verificar estado
sudo systemctl status postgresql

# Iniciar si está detenido
sudo systemctl start postgresql

# Verificar conexión
psql -U notes -d notes -c "SELECT 1;"
```

### BATS no encontrado

```bash
# Instalar BATS
sudo apt-get update
sudo apt-get install bats
```

### Tests muy lentos

```bash
# Usar modo mock (sin base de datos)
cd tests
source setup_mock_environment.sh
bats unit/bash/*.bats
```

### Ver detalles de error

```bash
# Ejecutar con formato TAP para más detalles
bats -t tests/unit/bash/suite.test.bats

# O redirigir a un archivo
bats tests/unit/bash/suite.test.bats 2>&1 | tee test_output.log
```

---

## 📈 Estructura de Niveles

| Nivel | Descripción | Tests | Tiempo |
|-------|-------------|-------|--------|
| 1 | Básicos (logging, formato) | ~50-60 | 5-10 min |
| 2 | Validación (datos, coordenadas, fechas) | ~100-120 | 10-15 min |
| 3 | XML/XSLT | ~80-100 | 8-12 min |
| 4 | Procesamiento (API, Planet) | ~120-150 | 15-25 min |
| 5 | Procesamiento Paralelo | ~80-100 | 10-15 min |
| 6 | Cleanup y Error Handling | ~100-120 | 12-18 min |
| 7 | Monitoreo y WMS | ~50-70 | 8-12 min |
| 8 | Avanzados y Edge Cases | ~100-130 | 10-15 min |
| 9 | Integración E2E | ~68 | 10-20 min |
| 10 | DWH Enhanced | ~45 | 10-15 min |

---

## 💡 Tips

1. **Para desarrollo activo:** Usa `quick` o el nivel específico de tu feature
2. **Para CI/CD local:** Usa `standard` o `full`
3. **Para debugging:** Ejecuta la suite específica con `-t` para verbose
4. **Para ahorro de tiempo:** Usa modo mock cuando no necesites base de datos
5. **Para ver progreso:** El script secuencial muestra banners con el progreso

---

## 📚 Más Información

- **Matriz completa:** Ver `docs/Test_Matrix.md`
- **Secuencia detallada:** Ver `docs/Test_Execution_Sequence.md`
- **Guía de testing:** Ver `docs/Testing_Guide.md`

---

**Última actualización:** 2025-10-14  
**Mantenedor:** Andres Gomez (AngocA)
