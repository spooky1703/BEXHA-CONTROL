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
        
        # Paquetes ocultos (Nuitka suele detectarlos, pero por seguridad)
        "--include-package=modules",
        "--include-package=reportlab",
        "--include-package=PIL",
        "--include-package=sqlite3",
        
        # Archivo principal
        "main.py"
    ]
    
    # Configuración específica por SO
    if sys.platform.startswith('win'):
        cmd.append("--windows-disable-console")
        if os.path.exists("assets/zapata.ico"):
            cmd.append("--windows-icon-from-ico=assets/zapata.ico")
    elif sys.platform.startswith('darwin'): # Mac
        cmd.append("--macos-disable-console") # O equivalente si existe, Nuitka lo maneja con bundle
        if os.path.exists("assets/zapata.png"):
            cmd.append("--macos-app-icon=assets/zapata.png")
    
    print("\n🚀 Ejecutando comando de compilación (esto puede tardar unos minutos)...")
    print(" ".join(cmd))
    
    try:
        subprocess.check_call(cmd)
        print("\n✅ Compilación segura completada!")
        print(f"📁 Ejecutable en: dist_secure/main.bin (o main.app en Mac)")
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Error durante la compilación: {e}")
        sys.exit(1)

if __name__ == "__main__":
    build_with_nuitka()
