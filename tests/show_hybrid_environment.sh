#!/bin/bash

# Show hybrid environment structure and files
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

echo "=== AMBIENTE HÍBRIDO DE PRUEBAS ==="
echo
echo "Este ambiente permite probar el procesamiento real de datos"
echo "mientras simula las descargas de internet (wget, aria2c)."
echo

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOCK_COMMANDS_DIR="${SCRIPT_DIR}/mock_commands"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"

echo "📁 **ESTRUCTURA DE ARCHIVOS:**"
echo

echo "🔧 **Scripts de Configuración:**"
echo "   - setup_hybrid_mock_environment.sh: Configura el ambiente híbrido"
echo "   - run_hybrid_tests.sh: Ejecuta pruebas con ambiente híbrido"
echo "   - run_hybrid_tests_fixed.sh: Versión corregida de las pruebas"
echo

echo "🤖 **Comandos Mock (Simulados):**"
echo "   Ubicación: ${MOCK_COMMANDS_DIR}/"
echo
ls -la "${MOCK_COMMANDS_DIR}/" | while read line; do
 echo "   $line"
done
echo

echo "📊 **Datos Reales Disponibles:**"
echo "   Ubicación: ${FIXTURES_DIR}/xml/"
echo
ls -la "${FIXTURES_DIR}/xml/" | while read line; do
 echo "   $line"
done
echo

echo "📋 **ARCHIVOS DE DATOS REALES:**"
echo

echo "1️⃣ **planet_notes_real.xml (149KB, 1315 líneas):"
echo "   - Contiene notas reales de OpenStreetMap"
echo "   - Formato: XML con estructura <osm-notes>"
echo "   - Incluye notas abiertas, cerradas y reabiertas"
echo "   - Ejemplo de contenido:"
head -10 "${FIXTURES_DIR}/xml/planet_notes_real.xml" | sed 's/^/   /'
echo

echo "2️⃣ **api_notes_sample.xml (2.1KB, 61 líneas):"
echo "   - Muestra de notas en formato API"
echo "   - Formato: XML con estructura <osm>"
echo "   - Ejemplo de contenido:"
head -10 "${FIXTURES_DIR}/xml/api_notes_sample.xml" | sed 's/^/   /'
echo

echo "3️⃣ **large_planet_notes.xml (2.7KB, 50 líneas):"
echo "   - Archivo más grande para pruebas de rendimiento"
echo "   - Formato: XML con estructura <osm-notes>"
echo

echo "4️⃣ **planet_notes_sample.xml (1.6KB, 31 líneas):"
echo "   - Muestra pequeña para pruebas rápidas"
echo "   - Formato: XML con estructura <osm-notes>"
echo

echo "🔧 **COMANDOS MOCK DISPONIBLES:**"
echo

echo "📥 **wget (Mock):"
echo "   - Simula descargas HTTP"
echo "   - Crea archivos XML/JSON simulados"
echo "   - Maneja opciones: -O, -q, --timeout"
echo "   - Ejemplo: wget -O file.xml 'https://example.com/data.xml'"
echo

echo "📥 **aria2c (Mock):"
echo "   - Simula descargas con aria2c"
echo "   - Crea archivos comprimidos simulados"
echo "   - Maneja opciones: -o, -q"
echo "   - Ejemplo: aria2c -o file.bz2 'https://example.com/data.bz2'"
echo

echo "🔧 **COMANDOS REALES (No Mockeados):**"
echo

echo "📊 **xmllint:"
echo "   - Validación real de XML"
echo "   - Conteo de elementos"
echo "   - Extracción de datos"
echo "   - Ejemplo: xmllint --xpath 'count(//note)' file.xml"
echo

echo "🔄 **xsltproc:"
echo "   - Transformación real de XML"
echo "   - Conversión a CSV"
echo "   - Procesamiento de XSLT"
echo "   - Ejemplo: xsltproc transform.xslt input.xml > output.csv"
echo

echo "🗄️ **psql:"
echo "   - Conexión real a PostgreSQL"
echo "   - Ejecución de SQL"
echo "   - Carga de datos"
echo "   - Ejemplo: psql -d database -f script.sql"
echo

echo "🗜️ **bzip2:"
echo "   - Descompresión real de archivos"
echo "   - Compresión de datos"
echo "   - Ejemplo: bzip2 -d file.bz2"
echo

echo "✅ **BENEFICIOS DEL AMBIENTE HÍBRIDO:**"
echo

echo "🚀 **Ventajas:"
echo "   - Pruebas sin dependencia de internet"
echo "   - Procesamiento real de datos"
echo "   - Validación real de XML"
echo "   - Datos consistentes y reproducibles"
echo "   - Pruebas más rápidas y confiables"
echo "   - No consume ancho de banda"
echo "   - No depende de servicios externos"
echo

echo "🎯 **Casos de Uso:"
echo "   - Pruebas de validación de XML"
echo "   - Pruebas de transformación XSLT"
echo "   - Pruebas de carga de base de datos"
echo "   - Pruebas de procesamiento de datos"
echo "   - Pruebas de rendimiento"
echo "   - Pruebas de integración"
echo

echo "📝 **CÓMO USAR:**"
echo

echo "1️⃣ **Configurar ambiente:"
echo "   ./setup_hybrid_mock_environment.sh setup"
echo

echo "2️⃣ **Activar ambiente:"
echo "   ./setup_hybrid_mock_environment.sh activate"
echo

echo "3️⃣ **Ejecutar pruebas:"
echo "   ./run_hybrid_tests.sh e2e"
echo

echo "4️⃣ **Desactivar ambiente:"
echo "   ./setup_hybrid_mock_environment.sh deactivate"
echo

echo "🔍 **PARA AGREGAR MÁS NOTAS AL XML DE PRUEBA:**"
echo

echo "Para agregar más notas al XML de prueba del planet dump:"
echo "1. Editar: tests/fixtures/xml/planet_notes_real.xml"
echo "2. Agregar más elementos <note> con estructura válida"
echo "3. Mantener el formato XML correcto"
echo "4. Incluir diferentes tipos de notas (abiertas, cerradas, reabiertas)"
echo "5. Usar coordenadas reales y datos realistas"
echo

echo "📊 **ESTADÍSTICAS ACTUALES:**"
echo

# Count notes in real XML file
if [[ -f "${FIXTURES_DIR}/xml/planet_notes_real.xml" ]]; then
 note_count=$(xmllint --xpath "count(//note)" "${FIXTURES_DIR}/xml/planet_notes_real.xml" 2> /dev/null || echo "0")
 echo "   - Notas en planet_notes_real.xml: ${note_count}"
fi

# Count lines in XML files
for xml_file in "${FIXTURES_DIR}/xml/"*.xml; do
 if [[ -f "$xml_file" ]]; then
  line_count=$(wc -l < "$xml_file" 2> /dev/null || echo "0")
  file_size=$(ls -lh "$xml_file" | awk '{print $5}')
  echo "   - $(basename "$xml_file"): ${line_count} líneas, ${file_size}"
 fi
done

echo
echo "✅ **Ambiente híbrido listo para usar!**"
