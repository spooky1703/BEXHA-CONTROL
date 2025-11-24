import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
import os

# ==================== CONFIGURACIÓN DE CORREO ====================
SENDER_EMAIL = "ryverz.alonso@gmail.com"
SENDER_PASSWORD = "lrwk alqw vyoq nmjg"  # Contraseña de aplicación 

def enviar_correo_reporte(destinatario: str, ruta_archivo: str) -> bool:
    """
    Returns:
        bool: True si el envío fue exitoso, False en caso contrario
    """
    if not destinatario:
        raise ValueError("El correo destinatario no puede estar vacío")
        
    if not os.path.exists(ruta_archivo):
        raise FileNotFoundError(f"No se encontró el archivo: {ruta_archivo}")

    msg = MIMEMultipart()
    msg['From'] = SENDER_EMAIL
    msg['To'] = destinatario
    msg['Subject'] = f"Reporte del Sistema de Riego - {os.path.basename(ruta_archivo)}"

    body = f"""
    Hola,
    
    Se adjunta el reporte generado por el Sistema de Control de Riegos.
    
    Archivo: {os.path.basename(ruta_archivo)}
    
    Saludos,
    Sistema de Administración
    """
    msg.attach(MIMEText(body, 'plain'))

    # Adjuntar archivo
    with open(ruta_archivo, "rb") as f:
        part = MIMEApplication(f.read(), Name=os.path.basename(ruta_archivo))
        part['Content-Disposition'] = f'attachment; filename="{os.path.basename(ruta_archivo)}"'
        msg.attach(part)

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
