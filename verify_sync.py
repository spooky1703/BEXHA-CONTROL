import sqlite3
import os
from modules.models import crear_campesino, actualizar_campesino, actualizar_superficie_campesino, renombrar_campesino, eliminar_campesino
from modules.cuotas import init_cuotas_db, crear_tipo_cuota, asignar_cuota_a_campesino, get_cuotas_connection

def verify_sync():
    print("=== INICIANDO VERIFICACIÓN DE SINCRONIZACIÓN ===")
    
    # 0. Limpieza previa por si acaso
    from modules.models import obtener_campesino_por_lote
    # 0. Limpieza previa por si acaso
    from modules.models import obtener_campesino_por_lote, get_connection
    existente = obtener_campesino_por_lote('TEST-999')
    if existente:
        print("Limpiando datos anteriores...")
        # Eliminación FÍSICA para permitir reutilizar el lote
        conn = get_connection()
        conn.execute("DELETE FROM campesinos WHERE id = ?", (existente['id'],))
        conn.close()
        
        conn = get_cuotas_connection()
        conn.execute("DELETE FROM cuotas_campesinos WHERE numero_lote = 'TEST-999'")
        conn.close()

    # 1. Crear datos de prueba
    print("\n1. Creando datos de prueba...")
    datos_campesino = {
        'numero_lote': 'TEST-999',
        'nombre': 'Juan Perez Test',
        'localidad': 'Test Loc',
        'barrio': 'Test Barrio',
        'superficie': 1.0
    }
    
    try:
        campesino_id = crear_campesino(datos_campesino)
        print(f"Campesino creado ID: {campesino_id}")
        
        # Crear tipo de cuota
        init_cuotas_db()
        try:
            tipo_cuota_id = crear_tipo_cuota("Cuota Test", 100.0, "Cuota de prueba")
        except ValueError:
            # Si ya existe, buscarla
            conn = get_cuotas_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT id FROM tipos_cuota WHERE nombre = 'Cuota Test'")
            tipo_cuota_id = cursor.fetchone()['id']
            conn.close()
            
        print(f"Tipo de cuota ID: {tipo_cuota_id}")
        
        # Asignar cuota (Monto esperado: 1.0 * 100.0 = 100.0)
        cuota_id = asignar_cuota_a_campesino(
            campesino_id, 'TEST-999', 'Juan Perez Test', 'Test Barrio', tipo_cuota_id, 1.0
        )
        print(f"Cuota asignada ID: {cuota_id}")
        
        # Verificar monto inicial
        conn = get_cuotas_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT monto, nombre_campesino FROM cuotas_campesinos WHERE id = ?", (cuota_id,))
        row = cursor.fetchone()
        print(f"Monto inicial: {row['monto']} (Esperado: 100.0)")
        print(f"Nombre inicial: {row['nombre_campesino']}")
        conn.close()
        
        # 2. Probar cambio de nombre
        print("\n2. Probando sincronización de NOMBRE...")
        actualizar_campesino(campesino_id, {'nombre': 'Juan Perez Modificado'})
        
        conn = get_cuotas_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT nombre_campesino FROM cuotas_campesinos WHERE id = ?", (cuota_id,))
        nuevo_nombre = cursor.fetchone()['nombre_campesino']
        conn.close()
        
        print(f"Nuevo nombre en cuotas: {nuevo_nombre}")
        if nuevo_nombre == 'Juan Perez Modificado':
            print("✓ ÉXITO: Nombre sincronizado correctamente")
        else:
            print("✗ ERROR: Nombre no sincronizado")

        # 3. Probar cambio de superficie (y recálculo)
        print("\n3. Probando sincronización de SUPERFICIE (Recálculo)...")
        # Cambiar superficie a 2.0 (Nuevo monto esperado: 2.0 * 100.0 = 200.0)
        actualizar_superficie_campesino(campesino_id, 2.0)
        
        conn = get_cuotas_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT monto FROM cuotas_campesinos WHERE id = ?", (cuota_id,))
        nuevo_monto = cursor.fetchone()['monto']
        conn.close()
        
        print(f"Nuevo monto en cuotas: {nuevo_monto}")
        if nuevo_monto == 200.0:
            print("✓ ÉXITO: Monto recalculado correctamente")
        else:
            print(f"✗ ERROR: Monto incorrecto (Esperado: 200.0, Obtenido: {nuevo_monto})")
            
        # 4. Limpieza
        print("\n4. Limpiando datos de prueba...")
        eliminar_campesino(campesino_id)
        
        conn = get_cuotas_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM cuotas_campesinos WHERE id = ?", (cuota_id,))
        # Opcional: borrar tipo de cuota si se creó solo para esto
        conn.commit()
        conn.close()
        print("Limpieza completada.")
        
    except Exception as e:
        print(f"ERROR CRÍTICO EN VERIFICACIÓN: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    verify_sync()
