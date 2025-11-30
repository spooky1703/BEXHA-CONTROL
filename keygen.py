import hashlib
import hmac
import sys

# CLAVE MAESTRA SECRETA - ¡NO COMPARTIR!
# Esta misma clave debe estar en la app móvil
SECRET_KEY = b"BEXHA_SECURE_MASTER_KEY_2024"

def generate_key(device_id):
    """Genera una clave de activación basada en el ID del dispositivo."""
    # Crear HMAC-SHA256
    h = hmac.new(SECRET_KEY, device_id.encode('utf-8'), hashlib.sha256)
    # Obtener hash en hex
    full_hash = h.hexdigest().upper()
    # Tomar los primeros 8 caracteres como clave corta
    short_key = full_hash[:8]
    return short_key

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python keygen.py <DEVICE_ID>")
        print("Ejemplo: python keygen.py ANDROID_12345")
        sys.exit(1)
    
    device_id = sys.argv[1]
    key = generate_key(device_id)
    
    print(f"\n📱 ID Dispositivo: {device_id}")
    print(f"🔑 Clave Generada: {key}")
    print("-" * 30)
