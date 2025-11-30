#!/bin/bash
# Script para compilar el APK de BEXHA Mobile

# Definir rutas
FLUTTER_BIN="/Users/alonsomota/development/flutter/bin/flutter"
OUTPUT_DIR="../" # Directorio raíz BEXHA
APK_NAME="BEXHA_Scanner.apk"
SOURCE_APK="build/app/outputs/flutter-apk/app-release.apk"

echo "🧹 Limpiando compilaciones anteriores..."
$FLUTTER_BIN clean

echo "📦 Obteniendo dependencias..."
$FLUTTER_BIN pub get

echo "🏗️ Compilando APK (Release) con OFUSCACIÓN..."
$FLUTTER_BIN build apk --release --obfuscate --split-debug-info=debug_symbols

if [ -f "$SOURCE_APK" ]; then
    echo "📋 Copiando APK a la carpeta principal..."
    cp "$SOURCE_APK" "$OUTPUT_DIR/$APK_NAME"
    
    echo ""
    echo "✅ ¡Compilación exitosa!"
    echo "🚀 Tu APK está listo en: $OUTPUT_DIR$APK_NAME"
    echo "   (Ruta absoluta: $(realpath $OUTPUT_DIR$APK_NAME))"
else
    echo "❌ Error: No se encontró el archivo APK generado."
    exit 1
fi
