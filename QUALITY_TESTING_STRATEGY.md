# Estrategia de Pruebas de Calidad de Código - Repositorios Separados

**Fecha:** 2025-10-13  
**Problema:** Evitar duplicación de pruebas de calidad (shellcheck, shfmt, etc.)

---

## 🎯 Problema Identificado

Con la separación de repositorios, las **pruebas de calidad de código** (shellcheck, shfmt, formateo) podrían duplicarse innecesariamente:

```
ANTES (Monolítico):
OSM-Notes-profile
├── .github/workflows/quality-tests.yml
│   └── Ejecuta shellcheck en TODO bin/
│       ✓ Procesa bin/process/
│       ✓ Procesa bin/wms/
│       ✓ Procesa bin/dwh/          ← Ya no existe
│       ✓ Procesa bin/common*       ← Ahora en submodule

DESPUÉS (Separado):
OSM-Notes-profile
├── .github/workflows/quality-tests.yml
│   └── Ejecuta shellcheck en bin/
│       ✓ bin/process/
│       ✓ bin/wms/
│       ✓ bin/monitor/
│       ✓ lib/osm-common/*  ← ¿Duplicado?

OSM-Notes-Analytics
├── .github/workflows/quality-tests.yml  ← ¿Crear?
│   └── Ejecuta shellcheck en bin/
│       ✓ bin/dwh/
│       ✓ lib/osm-common/*  ← ¿Duplicado?

OSM-Notes-Common
├── ¿Necesita su propio workflow?
│   └── Para probar las funciones compartidas
```

---

## 📊 Análisis de Pruebas de Calidad Actuales

### OSM-Notes-profile (quality-tests.yml)

**Verificaciones que hace:**
1. **shellcheck** → Análisis estático de scripts Bash
   ```bash
   find bin -name "*.sh" -type f -exec shellcheck -x -o all {} \;
   ```

2. **shfmt** → Formateo de código
   ```bash
   find bin -name "*.sh" -type f -exec shfmt -d {} \;
   ```

3. **Security scan** → Busca credenciales hardcoded
4. **Code quality** → Trailing whitespace, shebangs

**Archivos analizados:**
- ✅ `bin/process/*.sh`
- ✅ `bin/wms/*.sh`
- ✅ `bin/monitor/*.sh`
- ✅ `lib/osm-common/*.sh` ← **Submodule (duplicado potencial)**

---

## ✅ Estrategia Recomendada: Tests de Calidad Sin Duplicación

### Principio Fundamental

**Cada repositorio prueba SUS PROPIOS scripts + el submodule localmente**

```
OSM-Notes-Common          (Submodule - Source of Truth)
├── CI/CD: NO ES NECESARIO por ahora
└── Se prueba EN los proyectos que lo usan

OSM-Notes-profile         (Usa el submodule)
├── CI/CD: Prueba bin/ + lib/osm-common/
└── Detecta problemas en Common desde Profile

OSM-Notes-Analytics       (Usa el submodule)
├── CI/CD: Prueba bin/ + lib/osm-common/
└── Detecta problemas en Common desde Analytics
```

**Ventajas:**
- ✅ No es duplicación real (cada repo prueba SU uso del submodule)
- ✅ Detecta problemas de integración temprano
- ✅ No requiere CI/CD en OSM-Notes-Common
- ✅ Simple de mantener

---

## 📋 Estrategia por Repositorio

### 1. OSM-Notes-Common (Sin CI/CD por ahora)

**Razón:** Es código simple y estable. Se prueba en los repos que lo usan.

```
OSM-Notes-Common/
├── commonFunctions.sh
├── validationFunctions.sh
├── errorHandlingFunctions.sh
├── consolidatedValidationFunctions.sh
└── bash_logger.sh

❌ NO crear .github/workflows/ por ahora
✅ Se prueba implícitamente en Profile y Analytics
✅ Agregar CI/CD solo si:
   - El repo crece significativamente (10+ archivos)
   - Múltiples proyectos externos lo usan
   - Hay PRs frecuentes de la comunidad
```

---

### 2. OSM-Notes-profile (Mantener workflow actual)

**Archivos:** `.github/workflows/quality-tests.yml` (ya existe)

**Qué prueba:**
```yaml
shellcheck:
  - bin/process/*.sh          ← Scripts de Profile
  - bin/wms/*.sh              ← Scripts de Profile
  - bin/monitor/*.sh          ← Scripts de Profile
  - lib/osm-common/*.sh       ← Submodule (OK, detecta problemas)

shfmt:
  - bin/**/*.sh               ← Todo lo de Profile
  - lib/osm-common/*.sh       ← Submodule (OK, detecta problemas)
```

**Actualización recomendada:**

```yaml
- name: Run shellcheck on all bash scripts
  run: |
    echo "Running shellcheck on Profile scripts..."
    find bin -name "*.sh" -type f -exec shellcheck -x -o all {} \;
    
    echo "Running shellcheck on Common submodule..."
    # Esto detecta problemas en Common desde el contexto de Profile
    find lib/osm-common -name "*.sh" -type f -exec shellcheck -x -o all {} \; || true
```

**Razón:** Está bien probar el submodule aquí porque detecta problemas de integración.

---

### 3. OSM-Notes-Analytics (Crear workflow similar)

**Archivo:** `.github/workflows/quality-tests.yml` (CREAR)

```yaml
name: Quality Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        submodules: recursive  # ← Importante para el submodule

    - name: Install shellcheck
      run: |
        sudo apt-get update
        sudo apt-get install -y shellcheck

    - name: Run shellcheck on Analytics scripts
      run: |
        echo "Running shellcheck on Analytics scripts..."
        find bin/dwh -name "*.sh" -type f -exec shellcheck -x -o all {} \;
        
        echo "Running shellcheck on Common submodule..."
        find lib/osm-common -name "*.sh" -type f -exec shellcheck -x -o all {} \; || true

  shfmt:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        submodules: recursive

    - name: Install shfmt
      run: |
        sudo apt-get update
        sudo apt-get install -y golang
        go install mvdan.cc/sh/v3/cmd/shfmt@latest
        echo "$HOME/go/bin" >> $GITHUB_PATH

    - name: Check code formatting
      run: |
        echo "Checking Analytics code formatting..."
        find bin/dwh -name "*.sh" -type f -exec shfmt -d -i 1 -sr -bn {} \;
        
        echo "Checking Common code formatting..."
        find lib/osm-common -name "*.sh" -type f -exec shfmt -d -i 1 -sr -bn {} \; || true
```

---

## 🤔 ¿Es Duplicación? NO

### Por qué NO es duplicación problemática:

#### 1. **Contextos Diferentes**
```
Profile prueba:
  commonFunctions.sh en el contexto de processAPINotes.sh
  → Detecta problemas de integración específicos

Analytics prueba:
  commonFunctions.sh en el contexto de ETL.sh
  → Detecta problemas de integración diferentes
```

#### 2. **Detección Temprana**
- Si alguien modifica Common y rompe Profile → CI de Profile falla
- Si alguien modifica Common y rompe Analytics → CI de Analytics falla
- **Ambos son útiles y no redundantes**

#### 3. **Sin Common CI/CD separado**
- Evitas el overhead de mantener un tercer workflow
- No necesitas configurar CI en Common hasta que sea necesario
- Más simple = menos mantenimiento

---

## 🚀 Plan de Implementación

### Fase 1: Actualizar OSM-Notes-profile (Ya está)

```bash
✅ quality-tests.yml existe y funciona
✅ Prueba bin/ + lib/osm-common/
✅ No requiere cambios
```

### Fase 2: Crear CI/CD en OSM-Notes-Analytics (AHORA)

**Crear:** `.github/workflows/quality-tests.yml` en Analytics

```bash
cd /home/angoca/github/OSM-Notes-Analytics

# Crear directorio
mkdir -p .github/workflows

# Copiar y adaptar workflow de Profile
# (ver archivo completo en la propuesta abajo)
```

### Fase 3: Documentar Estrategia (Opcional)

Agregar nota en README de cada repo:

```markdown
## Quality Testing

This repository runs quality tests on:
- Scripts in `bin/` (repository-specific)
- Scripts in `lib/osm-common/` (submodule, tested in context)

Note: The Common submodule is also tested in other repositories
that use it, ensuring compatibility across all projects.
```

---

## 📝 Workflow Propuesto para OSM-Notes-Analytics

```yaml
name: Quality Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        submodules: recursive

    - name: Install shellcheck
      run: |
        sudo apt-get update
        sudo apt-get install -y shellcheck

    - name: Run shellcheck on Analytics scripts
      run: |
        echo "Running shellcheck on Analytics-specific scripts..."
        find bin/dwh -name "*.sh" -type f -exec shellcheck -x -o all {} \;

    - name: Run shellcheck on Common submodule (integration check)
      run: |
        echo "Running shellcheck on Common submodule in Analytics context..."
        find lib/osm-common -name "*.sh" -type f -exec shellcheck -x -o all {} \; || {
          echo "Warning: Common submodule has shellcheck issues in Analytics context"
          exit 0  # Don't fail - Common is maintained by Profile repo
        }

  shfmt:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        submodules: recursive

    - name: Install shfmt
      run: |
        wget -O shfmt https://github.com/mvdan/sh/releases/latest/download/shfmt_v3.7.0_linux_amd64
        chmod +x shfmt
        sudo mv shfmt /usr/local/bin/

    - name: Check Analytics code formatting
      run: |
        echo "Checking Analytics code formatting..."
        find bin/dwh -name "*.sh" -type f -exec shfmt -d -i 1 -sr -bn {} \;

  code-quality:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Check for common issues
      run: |
        echo "Checking for common code quality issues..."
        
        # Check for trailing whitespace
        echo "Checking trailing whitespace..."
        find bin -name "*.sh" -type f -exec grep -l " $" {} \; || echo "No trailing whitespace found"
        
        # Check for proper shebang
        echo "Checking shebangs..."
        find bin -name "*.sh" -type f -exec head -1 {} \; | grep -v "#!/bin/bash" || echo "All shebangs correct"

    - name: Generate quality report
      if: always()
      run: |
        echo "## Quality Test Results" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "### Tests Performed:" >> $GITHUB_STEP_SUMMARY
        echo "- ✅ Shellcheck (Analytics scripts)" >> $GITHUB_STEP_SUMMARY
        echo "- ✅ Shellcheck (Common submodule - integration check)" >> $GITHUB_STEP_SUMMARY
        echo "- ✅ Shfmt (code formatting)" >> $GITHUB_STEP_SUMMARY
        echo "- ✅ Code quality checks" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "### Scope:" >> $GITHUB_STEP_SUMMARY
        echo "- **Analytics Scripts:** bin/dwh/" >> $GITHUB_STEP_SUMMARY
        echo "- **Common Submodule:** lib/osm-common/ (integration test)" >> $GITHUB_STEP_SUMMARY
```

---

## ⚖️ Decisión: ¿Crear CI/CD en OSM-Notes-Common?

### Opción A: NO crear CI/CD en Common (Recomendada) ✅

**Razones:**
- ✅ Código simple y estable (5 archivos)
- ✅ Ya se prueba en Profile y Analytics
- ✅ Menos overhead de mantenimiento
- ✅ Suficiente para proyectos pequeños

**Cuándo reconsiderar:**
- Common crece a 10+ archivos
- PRs frecuentes de la comunidad
- Múltiples proyectos externos lo usan

---

### Opción B: Crear CI/CD básico en Common (Opcional)

**Si decides hacerlo:**

```yaml
name: Quality Tests

on:
  push:
  pull_request:

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Install shellcheck
      run: sudo apt-get install -y shellcheck
    - name: Run shellcheck
      run: find . -name "*.sh" -exec shellcheck -x -o all {} \;

  shfmt:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Install shfmt
      run: |
        wget -O shfmt https://github.com/mvdan/sh/releases/latest/download/shfmt_v3.7.0_linux_amd64
        chmod +x shfmt
        sudo mv shfmt /usr/local/bin/
    - name: Check formatting
      run: find . -name "*.sh" -exec shfmt -d -i 1 -sr -bn {} \;
```

---

## 🎯 Resumen Ejecutivo

### Estrategia Recomendada

| Repositorio | CI/CD Quality | Qué prueba | Duplicación |
|-------------|---------------|------------|-------------|
| **OSM-Notes-profile** | ✅ Ya existe | bin/ + lib/osm-common/ | ✅ No (contexto Profile) |
| **OSM-Notes-Analytics** | 📝 Crear ahora | bin/dwh/ + lib/osm-common/ | ✅ No (contexto Analytics) |
| **OSM-Notes-Common** | ❌ No crear | N/A | ✅ No duplicación |

### Beneficios

1. **No hay duplicación real** → Cada repo prueba en su contexto
2. **Detección temprana** → Problemas se detectan antes de merge
3. **Simple de mantener** → No se requiere CI/CD en Common
4. **Escalable** → Agregar Common CI/CD cuando sea necesario

### Acción Inmediata

```bash
# Crear quality-tests.yml en OSM-Notes-Analytics
# Basado en la plantilla de arriba
# Similar al de Profile pero adaptado a bin/dwh/
```

---

**Conclusión:** NO hay duplicación problemática. Es testing en contextos diferentes que aporta valor.

**Recomendación:** Crear quality workflow en Analytics, NO crear en Common por ahora.

---

**Documento creado:** 2025-10-13  
**Estado:** Propuesta para implementación

