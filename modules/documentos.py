# modules/documentos.py - Gestión de Documentos de Campesinos

import os
import shutil
import platform
import subprocess
from typing import Optional
from modules.models import obtener_campesino_por_id, actualizar_campesino, get_connection

# Directorio base para documentos
DOCUMENTOS_DIR = os.path.join('database', 'documentos')

def inicializar_directorio_documentos():
    """Crea el directorio base de documentos si no existe"""
    os.makedirs(DOCUMENTOS_DIR, exist_ok=True)
    print(f"✓ Directorio de documentos inicializado: {DOCUMENTOS_DIR}")

def obtener_directorio_campesino(numero_lote: str) -> str:
    """Obtiene el directorio de documentos para un campesino"""
    directorio = os.path.join(DOCUMENTOS_DIR, f"lote_{numero_lote}")
    os.makedirs(directorio, exist_ok=True)
    return directorio

def normalizar_nombre(nombre: str) -> str:
    """Normaliza un nombre para usarlo en nombres de archivo"""
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
    
    # Remover caracteres no permitidos
    caracteres_validos = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'
    nombre_normalizado = ''.join(c for c in nombre_normalizado if c in caracteres_validos)
    
    return nombre_normalizado

def subir_documento(campesino_id: int, tipo_documento: str, archivo_origen: str) -> Optional[str]:
    """
    Sube y renombra un documento para un campesino.
    
    Args:
        campesino_id: ID del campesino
        tipo_documento: 'INE' o 'DOCUMENTO_AGRARIO'
        archivo_origen: Ruta completa del archivo a subir
        
    Returns:
        Ruta del documento guardado, o None si hubo error
    """
    try:
        # Obtener datos del campesino
        campesino = obtener_campesino_por_id(campesino_id)
        if not campesino:
            raise ValueError("Campesino no encontrado")
        
        # Validar tipo de documento
        if tipo_documento not in ['INE', 'DOCUMENTO_AGRARIO']:
            raise ValueError("Tipo de documento inválido")
        
        # Validar que el archivo existe
        if not os.path.exists(archivo_origen):
            raise ValueError("El archivo origen no existe")
        
        # Obtener extensión del archivo
        _, extension = os.path.splitext(archivo_origen)
        extension = extension.lower()
        
        # Validar extensión
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
        
        # Si ya existe un documento del mismo tipo, eliminarlo
        eliminar_documento(campesino_id, tipo_documento, actualizar_db=False)
        
        # Copiar archivo
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
    """
    Obtiene la ruta de un documento si existe.
    
    Args:
        campesino_id: ID del campesino
        tipo_documento: 'INE' o 'DOCUMENTO_AGRARIO'
        
    Returns:
        Ruta del documento o None si no existe
    """
    try:
        campesino = obtener_campesino_por_id(campesino_id)
        if not campesino:
            return None
        
        campo = 'ruta_ine' if tipo_documento == 'INE' else 'ruta_documento_agrario'
        ruta = campesino.get(campo)
        
        # Verificar que el archivo realmente existe
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
    """
    Elimina un documento de un campesino.
    
    Args:
        campesino_id: ID del campesino
        tipo_documento: 'INE' o 'DOCUMENTO_AGRARIO'
        actualizar_db: Si True, actualiza la base de datos
        
    Returns:
        True si se eliminó correctamente
    """
    try:
        ruta = obtener_ruta_documento(campesino_id, tipo_documento)
        
        # Eliminar archivo físico si existe
        if ruta and os.path.exists(ruta):
            os.remove(ruta)
            print(f"✓ Archivo eliminado: {ruta}")
        
        # Actualizar base de datos
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
    """
    Abre un documento con la aplicación predeterminada del sistema.
    
    Args:
        ruta_documento: Ruta completa del documento
    """
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
    """
    Abre la carpeta de documentos de un campesino en el explorador de archivos.
    
    Args:
        numero_lote: Número de lote del campesino
    """
    try:
        directorio = obtener_directorio_campesino(numero_lote)
        
        if not os.path.exists(directorio):
            raise ValueError("La carpeta no existe")
        
        sistema = platform.system()
        
        if sistema == 'Darwin':  # macOS
            subprocess.run(['open', directorio])
        elif sistema == 'Windows':
            os.startfile(directorio)
        else:  # Linux
            subprocess.run(['xdg-open', directorio])
        
        print(f"✓ Abriendo carpeta: {directorio}")
        
    except Exception as e:
        print(f"Error al abrir carpeta: {e}")
        raise

def verificar_documento_existe(campesino_id: int, tipo_documento: str) -> bool:
    """
    Verifica si un campesino tiene un documento del tipo especificado.
    
    Args:
        campesino_id: ID del campesino
        tipo_documento: 'INE' o 'DOCUMENTO_AGRARIO'
        
    Returns:
        True si el documento existe
    """
    ruta = obtener_ruta_documento(campesino_id, tipo_documento)
    return ruta is not None
