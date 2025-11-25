# modules/documentos.py - Gestión de Documentos de Campesinos
import os
import shutil
import platform
import subprocess
from typing import Optional
from modules.models import obtener_campesino_por_id, actualizar_campesino, get_connection

DOCUMENTOS_DIR = os.path.join('database', 'documentos')

def inicializar_directorio_documentos():
    os.makedirs(DOCUMENTOS_DIR, exist_ok=True)
    print(f"✓ Directorio de documentos inicializado: {DOCUMENTOS_DIR}")

def obtener_directorio_campesino(numero_lote: str) -> str:
    directorio = os.path.join(DOCUMENTOS_DIR, f"lote_{numero_lote}")
    os.makedirs(directorio, exist_ok=True)
    return directorio

def normalizar_nombre(nombre: str) -> str:
    # Remover acentos y caracteres especiales
    reemplazos = {
        'á': 'A', 'é': 'E', 'í': 'I', 'ó': 'O', 'ú': 'U',
        'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U',
        'ñ': 'N', 'Ñ': 'N',
        ' ': '_', '.': '', ',': '', '(': '', ')': ''
    }
    
    nombre_normalizado = nombre.upper()
    for original, reemplazo in reemplazos.items():
        nombre_normalizado = nombre_normalizado.replace(original, reemplazo)
    
    caracteres_validos = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'
    nombre_normalizado = ''.join(c for c in nombre_normalizado if c in caracteres_validos)
    
    return nombre_normalizado

def subir_documento(campesino_id: int, tipo_documento: str, archivo_origen: str) -> Optional[str]:

    try:
        campesino = obtener_campesino_por_id(campesino_id)
        if not campesino:
            raise ValueError("Campesino no encontrado")
        
        if tipo_documento not in ['INE', 'DOCUMENTO_AGRARIO']:
            raise ValueError("Tipo de documento inválido")
        
        if not os.path.exists(archivo_origen):
            raise ValueError("El archivo origen no existe")
        
        _, extension = os.path.splitext(archivo_origen)
        extension = extension.lower()
        
        extensiones_validas = ['.pdf', '.jpg', '.jpeg', '.png']
        if extension not in extensiones_validas:
            raise ValueError(f"Extensión no válida. Use: {', '.join(extensiones_validas)}")
        
        # Crear directorio del campesino
        directorio = obtener_directorio_campesino(campesino['numero_lote'])
        
        # Normalizar nombre del campesino
        nombre_normalizado = normalizar_nombre(campesino['nombre'])
        
        # Crear nombre del archivo: TIPO_NOMBRE.ext
        nombre_archivo = f"{tipo_documento}_{nombre_normalizado}{extension}"
        ruta_destino = os.path.join(directorio, nombre_archivo)
        
        eliminar_documento(campesino_id, tipo_documento, actualizar_db=False)
        
        shutil.copy2(archivo_origen, ruta_destino)
        print(f"✓ Documento copiado: {ruta_destino}")
        
        # Actualizar base de datos
        campo_db = 'ruta_ine' if tipo_documento == 'INE' else 'ruta_documento_agrario'
        
        conn = get_connection()
        cursor = conn.cursor()
        cursor.execute(f'UPDATE campesinos SET {campo_db} = ? WHERE id = ?', 
                      (ruta_destino, campesino_id))
        conn.commit()
        conn.close()
        
        print(f"✓ Base de datos actualizada para campesino {campesino_id}")
        
        return ruta_destino
        
    except Exception as e:
        print(f"Error al subir documento: {e}")
        return None

def obtener_ruta_documento(campesino_id: int, tipo_documento: str) -> Optional[str]:

    try:
        campesino = obtener_campesino_por_id(campesino_id)
        if not campesino:
            return None
        
        campo = 'ruta_ine' if tipo_documento == 'INE' else 'ruta_documento_agrario'
        ruta = campesino.get(campo)
        
        if ruta and os.path.exists(ruta):
            return ruta
        elif ruta:
            # El archivo está en la BD pero no existe físicamente
            print(f"⚠ Archivo en BD pero no existe: {ruta}")
            return None
        
        return None
        
    except Exception as e:
        print(f"Error al obtener ruta de documento: {e}")
        return None

def eliminar_documento(campesino_id: int, tipo_documento: str, actualizar_db: bool = True) -> bool:
    try:
        ruta = obtener_ruta_documento(campesino_id, tipo_documento)
        
        if ruta and os.path.exists(ruta):
            os.remove(ruta)
            print(f"✓ Archivo eliminado: {ruta}")
        
        if actualizar_db:
            campo_db = 'ruta_ine' if tipo_documento == 'INE' else 'ruta_documento_agrario'
            conn = get_connection()
            cursor = conn.cursor()
            cursor.execute(f'UPDATE campesinos SET {campo_db} = NULL WHERE id = ?', 
                          (campesino_id,))
            conn.commit()
            conn.close()
            print(f"✓ Base de datos actualizada (documento eliminado)")
        
        return True
        
    except Exception as e:
        print(f"Error al eliminar documento: {e}")
        return False

def visualizar_documento(ruta_documento: str):
    try:
        if not os.path.exists(ruta_documento):
            raise ValueError("El archivo no existe")
        
        sistema = platform.system()
        
        if sistema == 'Darwin':  # macOS
            subprocess.run(['open', ruta_documento])
        elif sistema == 'Windows':
            os.startfile(ruta_documento)
        else:  # Linux
            subprocess.run(['xdg-open', ruta_documento])
        
        print(f"✓ Abriendo documento: {ruta_documento}")
        
    except Exception as e:
        print(f"Error al visualizar documento: {e}")
        raise

def abrir_carpeta_documentos(numero_lote: str):

    try:
        directorio = obtener_directorio_campesino(numero_lote)
        
        if not os.path.exists(directorio):
            raise ValueError("La carpeta no existe")
        
        sistema = platform.system()
        
        if sistema == 'Darwin':  # macOS
            subprocess.run(['open', directorio])
        elif sistema == 'Windows':
            os.startfile(directorio)
        else:
            subprocess.run(['xdg-open', directorio])
        
        print(f"✓ Abriendo carpeta: {directorio}")
        
    except Exception as e:
        print(f"Error al abrir carpeta: {e}")
        raise

def verificar_documento_existe(campesino_id: int, tipo_documento: str) -> bool:
    """
    Returns:
        True si el documento existe
    """
    ruta = obtener_ruta_documento(campesino_id, tipo_documento)
    return ruta is not None
