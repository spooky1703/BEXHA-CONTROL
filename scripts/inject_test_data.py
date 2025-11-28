import sqlite3
import random
from datetime import datetime, timedelta
import os

# Configuración
DB_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'database', 'riego.db')

CULTIVOS = ['MAÍZ', 'FRIJOL', 'ALFALFA', 'CHILE', 'TOMATE', 'AVENA', 'CALABAZA', 'CEBADA']
BARRIOS = ['CENTRO', 'EL CALVARIO', 'SAN JUAN', 'LA VILLA', 'EL TANQUE']
CICLOS = ['PRIMAVERA-VERANO 2024', 'OTOÑO-INVIERNO 2024', 'PRIMAVERA-VERANO 2025']

def get_connection():
    return sqlite3.connect(DB_PATH)

def inject_data():
    print(f"Conectando a {DB_PATH}...")
    conn = get_connection()
    cursor = conn.cursor()
    
    # 1. Verificar si hay campesinos, si no, crear algunos
    cursor.execute("SELECT COUNT(*) FROM campesinos")
    count = cursor.fetchone()[0]
    
    campesinos_ids = []
    
    if count < 10:
        print("Generando campesinos de prueba...")
        for i in range(20):
            lote = f"TEST-{i+1:03d}"
            nombre = f"Campesino Prueba {i+1}"
            barrio = random.choice(BARRIOS)
            superficie = round(random.uniform(0.5, 5.0), 2)
            
            try:
                cursor.execute('''
                    INSERT INTO campesinos (numero_lote, nombre, localidad, barrio, superficie, activo)
                    VALUES (?, ?, 'Tezontepec', ?, ?, 1)
                ''', (lote, nombre, barrio, superficie))
                campesinos_ids.append(cursor.lastrowid)
            except sqlite3.IntegrityError:
                # Si ya existe, buscar su ID
                cursor.execute("SELECT id FROM campesinos WHERE numero_lote = ?", (lote,))
                campesinos_ids.append(cursor.fetchone()[0])
    else:
        print(f"Se encontraron {count} campesinos existentes.")
        cursor.execute("SELECT id FROM campesinos WHERE activo = 1")
        campesinos_ids = [row[0] for row in cursor.fetchall()]

    # 2. Generar Siembras
    print("Generando siembras...")
    siembras_ids = []
    
    # Limpiar siembras de prueba anteriores si se desea (opcional, aquí solo agregamos)
    
    for camp_id in campesinos_ids:
        # Decidir si tiene siembra activa (70% de probabilidad)
        if random.random() < 0.7:
            cultivo = random.choice(CULTIVOS)
            ciclo = CICLOS[-1] # Ciclo actual
            fecha_inicio = datetime.now() - timedelta(days=random.randint(1, 60))
            
            cursor.execute('''
                INSERT INTO siembras (campesino_id, cultivo, numero_riegos, ciclo, fecha_inicio, activa)
                VALUES (?, ?, 0, ?, ?, 1)
            ''', (camp_id, cultivo, ciclo, fecha_inicio.strftime('%Y-%m-%d')))
            siembras_ids.append(cursor.lastrowid)
            
        # Generar siembras históricas (inactivas)
        for _ in range(random.randint(0, 2)):
            cultivo = random.choice(CULTIVOS)
            ciclo = random.choice(CICLOS[:-1])
            fecha_inicio = datetime.now() - timedelta(days=random.randint(100, 300))
            fecha_fin = fecha_inicio + timedelta(days=90)
            riegos_totales = random.randint(3, 10)
            
            cursor.execute('''
                INSERT INTO siembras (campesino_id, cultivo, numero_riegos, ciclo, fecha_inicio, fecha_fin, activa)
                VALUES (?, ?, ?, ?, ?, ?, 0)
            ''', (camp_id, cultivo, riegos_totales, ciclo, fecha_inicio.strftime('%Y-%m-%d'), fecha_fin.strftime('%Y-%m-%d')))

    # 3. Generar Recibos (Pagos de Riego)
    print("Generando recibos...")
    
    # Obtener todas las siembras (activas e inactivas) para generarles recibos
    cursor.execute("SELECT id, campesino_id, cultivo, ciclo, fecha_inicio FROM siembras")
    todas_siembras = cursor.fetchall()
    
    folio_base = 10000
    
    for siembra in todas_siembras:
        siembra_id, camp_id, cultivo, ciclo, fecha_inicio_str = siembra
        fecha_inicio = datetime.strptime(fecha_inicio_str, '%Y-%m-%d')
        
        # Generar entre 1 y 8 riegos por siembra
        num_riegos = random.randint(1, 8)
        
        # Actualizar contador de riegos en la siembra
        cursor.execute("UPDATE siembras SET numero_riegos = ? WHERE id = ?", (num_riegos, siembra_id))
        
        for i in range(num_riegos):
            folio = folio_base + i
            fecha_riego = fecha_inicio + timedelta(days=i*15 + random.randint(1, 5))
            hora = f"{random.randint(8, 18):02d}:{random.randint(0, 59):02d}:00"
            
            # Costo aleatorio (simulando diferentes tarifas o cantidades)
            costo = random.choice([150.0, 300.0, 450.0])
            tipo_accion = "Nueva siembra" if i == 0 else "Riego adicional"
            
            cursor.execute('''
                INSERT INTO recibos (folio, fecha, hora, campesino_id, siembra_id, cultivo, numero_riego, tipo_accion, costo, ciclo, eliminado)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
            ''', (folio, fecha_riego.strftime('%Y-%m-%d'), hora, camp_id, siembra_id, cultivo, i+1, tipo_accion, costo, ciclo))
            
        folio_base += num_riegos

    conn.commit()
    conn.close()
    print("✅ Datos de prueba inyectados exitosamente.")

if __name__ == "__main__":
    # Crear directorio scripts si no existe
    os.makedirs(os.path.dirname(__file__), exist_ok=True)
    inject_data()
