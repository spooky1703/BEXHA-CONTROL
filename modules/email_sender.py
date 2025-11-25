import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
import os

# ==================== CONFIGURACIÓN DE CORREO ====================
SENDER_EMAIL = "ryverz.alonso@gmail.com"
SENDER_PASSWORD = "lrwk alqw vyoq nmjg"  # Contraseña de aplicación 

def enviar_correo_reporte(destinatario: str, archivos: list) -> bool:
    """
    Envía un correo con múltiples archivos adjuntos.
    
    Args:
        destinatario (str): Correo del destinatario
        archivos (list): Lista de rutas de archivos a adjuntar (o un solo string)
        
    Returns:
        bool: True si el envío fue exitoso, False en caso contrario
    """
    if not destinatario:
        raise ValueError("El correo destinatario no puede estar vacío")
        
    # Si pasan un solo archivo como string, convertirlo a lista
    if isinstance(archivos, str):
        archivos = [archivos]
        
    # Validar que existan los archivos
    archivos_validos = []
    for ruta in archivos:
        if os.path.exists(ruta):
            archivos_validos.append(ruta)
        else:
            print(f"Advertencia: No se encontró el archivo para adjuntar: {ruta}")

    if not archivos_validos:
        raise FileNotFoundError("No se encontraron archivos válidos para adjuntar")

    msg = MIMEMultipart()
    msg['From'] = SENDER_EMAIL
    msg['To'] = destinatario
    # Determinar asunto y cuerpo según cantidad de archivos
    if len(archivos_validos) == 1:
        nombre_archivo = os.path.basename(archivos_validos[0])
        msg['Subject'] = f"Documento Adjunto - {nombre_archivo}"
        body = f"""
        Hola,
        
        Se adjunta el documento solicitado:
        
        📄 {nombre_archivo}
        
        Saludos,
        Sistema de Administración
        """
    else:
        msg['Subject'] = f"Reporte Mensual y Respaldos - Sistema de Riego"
        body = f"""
        Hola,
        
        Se adjuntan los documentos generados por el Sistema de Control de Riegos:
        
        - Reportes Mensuales (PDF/Excel)
        - Respaldos de Base de Datos
        - Registro de Auditoría
        
        Fecha de generación: {os.path.basename(archivos_validos[0]) if archivos_validos else 'N/A'}
        
        Saludos,
        Sistema de Administración
        """
        
    msg.attach(MIMEText(body, 'plain'))

    # Adjuntar archivos
    for ruta_archivo in archivos_validos:
        try:
            with open(ruta_archivo, "rb") as f:
                part = MIMEApplication(f.read(), Name=os.path.basename(ruta_archivo))
                part['Content-Disposition'] = f'attachment; filename="{os.path.basename(ruta_archivo)}"'
                msg.attach(part)
        except Exception as e:
            print(f"Error al adjuntar {ruta_archivo}: {e}")

    try:
        #  (TLS)
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        server.login(SENDER_EMAIL, SENDER_PASSWORD)
        server.send_message(msg)
        server.quit()
        return True
    except Exception as e:
        print(f"Error al enviar correo: {e}")
        raise e
