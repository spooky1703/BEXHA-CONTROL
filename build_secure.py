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
        
        # --- POST-PROCESAMIENTO: CREAR CARPETA DE DISTRIBUCIÓN COMPLETA ---
        print("\n📦 Creando carpeta de distribución portátil...")
        
        dist_folder = "BEXHA_CONTROL_PORTABLE"
        if os.path.exists(dist_folder):
            shutil.rmtree(dist_folder)
        os.makedirs(dist_folder)
        
        # 1. Mover el ejecutable
        exe_name = "BEXHA_CONTROL.exe"
        src_exe = os.path.join("dist_secure", exe_name)
        dst_exe = os.path.join(dist_folder, exe_name)
        
        if os.path.exists(src_exe):
            shutil.move(src_exe, dst_exe)
            print(f"   -> Ejecutable movido a {dist_folder}/")
        else:
            print(f"⚠️  No se encontró el .exe en {src_exe} (¿Quizás se compiló como binario en Mac?)")
            # Intentar mover el binario de Mac si existe, solo para que no falle el script
            mac_bin = os.path.join("dist_secure", "BEXHA_CONTROL")
            if os.path.exists(mac_bin):
                shutil.move(mac_bin, os.path.join(dist_folder, "BEXHA_CONTROL"))
                print(f"   -> Binario Mac movido a {dist_folder}/")

        # 2. Copiar BEXHA.csv (Base de datos inicial)
        if os.path.exists("BEXHA.csv"):
            shutil.copy("BEXHA.csv", os.path.join(dist_folder, "BEXHA.csv"))
            print("   -> BEXHA.csv copiado")
            
        # 3. Copiar Assets (Iconos, imágenes)
        if os.path.exists("assets"):
            shutil.copytree("assets", os.path.join(dist_folder, "assets"))
            print("   -> Carpeta assets/ copiada")
            
        # 4. Crear estructura de base de datos y carpetas de trabajo
        db_folder = os.path.join(dist_folder, "database")
        os.makedirs(db_folder, exist_ok=True)
        
        folders_to_create = ["backups", "documentos", "recibos", "reportes"]
        for folder in folders_to_create:
            os.makedirs(os.path.join(db_folder, folder), exist_ok=True)
            
        print("   -> Estructura de carpetas creada (database/ [backups, documentos, recibos, reportes])")

        # 5. Crear README
        with open(os.path.join(dist_folder, "LEEME.txt"), "w", encoding="utf-8") as f:
            f.write("BEXHA CONTROL - SISTEMA DE RIEGO\n")
            f.write("================================\n\n")
            f.write("INSTRUCCIONES:\n")
            f.write("1. Ejecute 'BEXHA_CONTROL.exe' para iniciar el sistema.\n")
            f.write("2. Si es la primera vez, el sistema pedirá la clave de activación.\n")
            f.write("3. La base de datos se generará automáticamente en la carpeta 'database'.\n")
        
        print(f"\n✨ ¡TODO LISTO! Tu carpeta portátil está en: {os.path.abspath(dist_folder)}")
        print("   Copia esta carpeta completa a la computadora destino.")

    except subprocess.CalledProcessError as e:
        print(f"\n❌ Error durante la compilación: {e}")
        sys.exit(1)

if __name__ == "__main__":
    build_with_nuitka()
