# Sistema de Pruebas - OSM-Notes-profile

Este directorio contiene el sistema de pruebas unitarias e integración para el proyecto OSM-Notes-profile.

## Estructura de Directorios

```
tests/
├── unit/
│   ├── bash/                    # Pruebas unitarias de scripts bash
│   │   ├── functionsProcess.test.bats
│   │   ├── processPlanetNotes.test.bats
│   │   └── processAPINotes.test.bats
│   └── sql/                     # Pruebas unitarias de SQL
│       ├── functions.test.sql
│       └── tables.test.sql
├── integration/                  # Pruebas de integración (futuro)
│   ├── api/
│   └── planet/
├── fixtures/                    # Datos de prueba
├── docker/                      # Configuración Docker (futuro)
├── test_helper.bash            # Funciones helper para BATS
├── run_tests.sh                # Script principal para ejecutar pruebas
└── README.md                   # Este archivo
```

## Tecnologías Utilizadas

### BATS (Bash Automated Testing System)
- **Propósito**: Pruebas unitarias para scripts bash
- **Ventajas**: Sintaxis nativa de bash, fácil integración, soporte para mocks
- **Documentación**: https://github.com/bats-core/bats-core

### pgTAP
- **Propósito**: Pruebas unitarias para PostgreSQL
- **Ventajas**: Framework nativo para PostgreSQL, sintaxis TAP estándar
- **Documentación**: https://pgtap.org/

## Instalación de Prerequisitos

### Ubuntu/Debian
```bash
# Instalar BATS
sudo apt-get update
sudo apt-get install bats

# Instalar pgTAP
sudo apt-get install postgresql-15-pgtap

# Verificar instalación
bats --version
pg_prove --version
```

### macOS
```bash
# Instalar BATS con Homebrew
brew install bats-core

# Instalar pgTAP
brew install pgtap
```

## Ejecución de Pruebas

### Ejecutar todas las pruebas
```bash
./tests/run_tests.sh
```

### Ejecutar solo pruebas BATS
```bash
./tests/run_tests.sh --bats-only
```

### Ejecutar solo pruebas pgTAP
```bash
./tests/run_tests.sh --pgtap-only
```

### Mantener base de datos de prueba
```bash
./tests/run_tests.sh --no-cleanup
```

### Ver ayuda
```bash
./tests/run_tests.sh --help
```

## Configuración de Base de Datos de Prueba

El sistema de pruebas utiliza una base de datos temporal llamada `osm_notes_test` que se crea y destruye automáticamente.

### Variables de Entorno
```bash
export TEST_DBNAME="osm_notes_test"
export TEST_DBUSER="test_user"
export TEST_DBPASSWORD="test_pass"
export TEST_DBHOST="localhost"
export TEST_DBPORT="5432"
```

## Tipos de Pruebas

### Pruebas Unitarias de Bash (BATS)

#### functionsProcess.test.bats
- Prueba funciones de utilidad comunes
- Validación de prerequisitos
- Conteo de notas XML
- División de archivos XML para procesamiento paralelo
- Creación de funciones y procedimientos de base de datos

#### processPlanetNotes.test.bats
- Prueba funciones específicas de processPlanetNotes.sh
- Validación de parámetros de entrada
- Creación y eliminación de tablas
- Procesamiento de datos de Planet
- Validación de archivos XML

#### processAPINotes.test.bats
- Prueba funciones específicas de processAPINotes.sh
- Validación de parámetros de entrada
- Creación y eliminación de tablas API
- Procesamiento de datos de API
- Validación de archivos XML

### Pruebas Unitarias de SQL (pgTAP)

#### functions.test.sql
- Prueba existencia de funciones y procedimientos
- Validación de parámetros de entrada
- Prueba de comportamiento de funciones
- Validación de mecanismos de bloqueo

#### tables.test.sql
- Prueba existencia de tablas
- Validación de estructura de columnas
- Verificación de claves primarias y foráneas
- Prueba de inserción de datos

## Escribiendo Nuevas Pruebas

### Pruebas BATS

```bash
#!/usr/bin/env bats

load test_helper

@test "mi_funcion should work correctly" {
  # Arrange
  local input="test_input"
  
  # Act
  run mi_funcion "${input}"
  
  # Assert
  [ "$status" -eq 0 ]
  [ "$output" = "expected_output" ]
}
```

### Pruebas pgTAP

```sql
-- test_mi_funcion.sql
BEGIN;

SELECT plan(2);

-- Test 1: Check if function exists
SELECT has_function('mi_funcion');

-- Test 2: Test function behavior
SELECT lives_ok(
  'SELECT mi_funcion(''test'')',
  'mi_funcion should work with valid input'
);

SELECT finish();
ROLLBACK;
```

## Mocks y Stubs

### Mock de Comandos Externos
```bash
# Crear mock de wget
cat > "${TEST_TMP_DIR}/wget" << 'EOF'
#!/bin/bash
# Mock wget que crea un archivo XML de muestra
cat > "$2" << 'XML_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note lat="40.7128" lon="-74.0060">
    <id>123</id>
    <status>open</status>
  </note>
</osm-notes>
XML_EOF
echo "Mock wget completed"
EOF
chmod +x "${TEST_TMP_DIR}/wget"
export PATH="${TEST_TMP_DIR}:${PATH}"
```

### Mock de Base de Datos
```bash
# Crear base de datos de prueba
create_test_database

# Insertar datos de prueba
create_sample_data

# Ejecutar pruebas
run mi_prueba

# Limpiar
drop_test_database
```

## Integración Continua (CI/CD)

### GitHub Actions (futuro)
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y bats postgresql-15-pgtap
      - name: Run tests
        run: ./tests/run_tests.sh
        env:
          TEST_DBNAME: osm_notes_test
          TEST_DBUSER: postgres
          TEST_DBPASSWORD: postgres
```

## Reportes y Cobertura

### Reportes de BATS
```bash
# Ejecutar con reporte detallado
bats --tap tests/unit/bash/

# Ejecutar con reporte en formato JUnit
bats --formatter junit tests/unit/bash/ > test-results.xml
```

### Reportes de pgTAP
```bash
# Ejecutar con reporte detallado
pg_prove -d osm_notes_test tests/unit/sql/

# Ejecutar con reporte en formato TAP
pg_prove --tap -d osm_notes_test tests/unit/sql/
```

## Troubleshooting

### Problemas Comunes

#### BATS no está instalado
```bash
# Ubuntu/Debian
sudo apt-get install bats

# macOS
brew install bats-core
```

#### pgTAP no está disponible
```bash
# Ubuntu/Debian
sudo apt-get install postgresql-15-pgtap

# Verificar instalación
psql -d postgres -c "SELECT 1 FROM pg_extension WHERE extname = 'pgtap';"
```

#### PostgreSQL no está ejecutándose
```bash
# Verificar estado
sudo systemctl status postgresql

# Iniciar servicio
sudo systemctl start postgresql
```

#### Permisos de base de datos
```bash
# Crear usuario de prueba
sudo -u postgres createuser test_user

# Crear base de datos
sudo -u postgres createdb osm_notes_test

# Otorgar permisos
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE osm_notes_test TO test_user;"
```

## Contribución

### Agregando Nuevas Pruebas

1. **Crear archivo de prueba** en el directorio apropiado
2. **Seguir convenciones de nomenclatura**:
   - BATS: `nombre_funcion.test.bats`
   - pgTAP: `nombre_tabla.test.sql`
3. **Incluir documentación** en el archivo de prueba
4. **Actualizar run_tests.sh** si es necesario
5. **Ejecutar pruebas** para verificar que funcionan

### Convenciones de Código

- **Nombres de pruebas**: Descriptivos y en inglés
- **Comentarios**: En español para documentación
- **Variables**: En mayúsculas para variables globales
- **Funciones**: Prefijo `__` para funciones internas

## Autor

Andres Gomez (AngocA)
- OSM-LatAm
- OSM-Colombia
- MaptimeBogota

## Versión

2025-07-20 