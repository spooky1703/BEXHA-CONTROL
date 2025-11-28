import sys
import os
import sqlite3

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from modules.models import DB_PATH

def extract_barrios():
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("SELECT DISTINCT barrio FROM campesinos ORDER BY barrio")
        barrios = [row[0] for row in cursor.fetchall() if row[0]]
        
        print("List of Barrios (Parajes):")
        for barrio in barrios:
            print(f"- {barrio}")
            
        # Also print as a Dart list for easy copying
        print("\nDart List:")
        dart_list = ", ".join([f'"{b}"' for b in barrios])
        print(f"const List<String> parajes = [{dart_list}];")
        
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    extract_barrios()
