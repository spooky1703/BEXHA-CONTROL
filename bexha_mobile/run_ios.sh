#!/bin/bash
# Script para ejecutar BEXHA Mobile en iPhone

# Ruta absoluta a Flutter
FLUTTER_BIN="/Users/alonsomota/development/flutter/bin/flutter"

echo "📱 Buscando dispositivos iOS..."
$FLUTTER_BIN devices

echo "🚀 Iniciando en iPhone..."
echo "⚠️  NOTA: Asegúrate de que tu iPhone esté desbloqueado y conectado por cable."
echo "⚠️  Si es la primera vez, deberás confiar en el desarrollador en Configuración > General > VPN y Gestión de Dispositivos."

$FLUTTER_BIN run --release
