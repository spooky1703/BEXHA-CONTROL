import webbrowser
import re
from tkinter import messagebox

def abrir_chat_whatsapp(telefono):
    """
    Abre el chat de WhatsApp Web con el número proporcionado.
    Limpia el número de caracteres no numéricos.
    """
    if not telefono:
        messagebox.showwarning("Advertencia", "No hay número de teléfono para contactar.")
        return

    # Limpiar el número (dejar solo dígitos)
    numero_limpio = re.sub(r'\D', '', str(telefono))
    
    if not numero_limpio:
        messagebox.showwarning("Advertencia", "El número de teléfono no es válido.")
        return
        
    # Si el número tiene 10 dígitos (formato común en México), agregar código de país 52
    if len(numero_limpio) == 10:
        numero_limpio = "52" + numero_limpio
    
    url = f"https://web.whatsapp.com/send?phone={numero_limpio}"
    
    try:
        webbrowser.open(url)
    except Exception as e:
        messagebox.showerror("Error", f"No se pudo abrir el navegador:\n{str(e)}")
