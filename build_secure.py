# build_secure.py - Script para compilar con Nuitka (Mayor seguridad)
import os
import subprocess
import sys
import shutil

def build_with_nuitka():
    print("🔒 Iniciando compilación segura con Nuitka...")
    
    # Verificar instalación de Nuitka
    try:
        subprocess.check_output([sys.executable, "-m", "nuitka", "--version"])
        print("   Nuitka detectado correctamente.")
    except subprocess.CalledProcessError:
        print("❌ Nuitka no está instalado o no funciona. Ejecuta: pip install nuitka")
        sys.exit(1)

    # Limpiar builds anteriores
    if os.path.exists('dist_secure'):
        shutil.rmtree('dist_secure')
    if os.path.exists('build'):
        shutil.rmtree('build')

    # Comando Nuitka
    # --standalone: Incluye todas las librerías necesarias
    # --onefile: Crea un solo ejecutable
    # --enable-plugin=tk-inter: Soporte para GUI
    # --include-data-dir: Incluir assets y DB
    
    cmd = [
        sys.executable, "-m", "nuitka",
        "--standalone",
        "--onefile",
        "--enable-plugin=tk-inter",
        "--enable-plugin=numpy", # Soporte para numpy si se usa
        
        # Directorios de datos
        "--include-data-dir=assets=assets",
        "--include-data-dir=database=database",
        
        # Configuración de salida
        "--output-dir=dist_secure",
        "--remove-output", # Limpiar archivos temporales
        "-o", "BEXHA_CONTROL.exe", # Forzar extensión .exe
        
        # Optimizaciones y Seguridad
        "--lto=yes", # Link Time Optimization
        "--show-progress",
        "--windows-disable-console", # Desactivar consola siempre
        "--windows-icon-from-ico=assets/zapata.ico", # Icono obligatorio
        
        # Paquetes ocultos
        "--include-package=modules",
        "--include-package=reportlab",
        "--include-package=PIL",
        "--include-package=sqlite3",
        
        # Archivo principal
        "main.py"
    ]
    
    # Advertencia si no se corre en Windows
    if not sys.platform.startswith('win'):
        print("⚠️  ADVERTENCIA: Estás ejecutando este script en un sistema NO Windows.")
        print("   Nuitka compilará un binario para TU sistema actual, no un .exe de Windows.")
        print("   Para generar el .exe final, debes correr este script en Windows.\n")
    
    print("\n🚀 Ejecutando comando de compilación (Windows Target)...")
    print(" ".join(cmd))
    
    try:
        subprocess.check_call(cmd)
        print("\n✅ Compilación segura completada!")
        print(f"📁 Ejecutable listo: dist_secure/BEXHA_CONTROL.exe")
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Error durante la compilación: {e}")
        sys.exit(1)

if __name__ == "__main__":
    build_with_nuitka()
