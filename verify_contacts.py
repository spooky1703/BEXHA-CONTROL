import sys
import os
import sqlite3

# Add project root to path
sys.path.append('/Users/alonsomota/BEXHA')

from modules.models import (
    init_db, 
    migrar_correo_a_contactos, 
    crear_contacto, 
    obtener_contactos, 
    actualizar_contacto, 
    eliminar_contacto,
    obtener_correo_presidente,
    get_connection
)

print("Initializing DB and running migration...")
init_db()
migrar_correo_a_contactos()

print("\nVerifying Presidente contact...")
presidente_email = obtener_correo_presidente()
print(f"Presidente email: {presidente_email}")

if not presidente_email:
    print("WARNING: Presidente email is empty (maybe no previous config?)")
else:
    print("Presidente contact exists.")

print("\nTesting CRUD operations...")
try:
    # Create
    print("Creating 'Secretario'...")
    id_sec = crear_contacto("Secretario", "secretario@test.com")
    print(f"Created with ID: {id_sec}")
    
    # Read
    contactos = obtener_contactos()
    print(f"Contacts found: {len(contactos)}")
    for c in contactos:
        print(f" - {c['alias']}: {c['correo']} (Principal: {c['es_principal']})")
        
    # Update
    print("Updating 'Secretario' email...")
    actualizar_contacto(id_sec, "nuevo_secretario@test.com")
    
    # Verify Update
    contactos = obtener_contactos()
    sec = next((c for c in contactos if c['alias'] == "Secretario"), None)
    if sec and sec['correo'] == "nuevo_secretario@test.com":
        print("Update verified.")
    else:
        print("ERROR: Update failed.")
        
    # Delete Presidente (Should Fail)
    print("Attempting to delete Presidente...")
    try:
        pres = next((c for c in contactos if c['alias'] == "Presidente"), None)
        if pres:
            eliminar_contacto(pres['id'])
            print("ERROR: Presidente was deleted!")
        else:
            print("Pre-check: Presidente not found?")
    except ValueError as e:
        print(f"Success: Caught expected error: {e}")
        
    # Delete Secretario
    print("Deleting 'Secretario'...")
    eliminar_contacto(id_sec)
    
    # Verify Delete
    contactos = obtener_contactos()
    sec = next((c for c in contactos if c['alias'] == "Secretario"), None)
    if not sec:
        print("Delete verified.")
    else:
        print("ERROR: Delete failed.")

except Exception as e:
    print(f"CRUD Error: {e}")

print("\nVerification complete.")
