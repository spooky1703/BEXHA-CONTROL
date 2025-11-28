import sqlite3
import json
import os

# Paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE_DIR, 'database', 'riego.db')
OUTPUT_PATH = os.path.join(BASE_DIR, 'bexha_mobile', 'assets', 'ejidatarios.json')

import csv

def export_ejidatarios():
    csv_path = os.path.join(BASE_DIR, 'BEXHA.csv')
    print(f"Reading from CSV: {csv_path}")
    
    ejidatarios = []
    try:
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            # CSV Columns: LOTE,USUARIO,SUP.,PARAJE,NOTAS
            
            id_counter = 1
            for row in reader:
                nombre = row.get('USUARIO', '').strip()
                lote = row.get('LOTE', '').strip()
                paraje = row.get('PARAJE', '').strip()
                
                if nombre and lote:
                    ejidatarios.append({
                        'id': id_counter,
                        'nombre': nombre,
                        'lote': lote,
                        'barrio': paraje
                    })
                    id_counter += 1
            
        print(f"Exporting {len(ejidatarios)} ejidatarios...")
        
        with open(OUTPUT_PATH, 'w', encoding='utf-8') as f:
            json.dump(ejidatarios, f, ensure_ascii=False, indent=2)
            
        print(f"✅ Export successful to: {OUTPUT_PATH}")
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    export_ejidatarios()
