import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from modules.models import obtener_estadisticas_generales, init_db

def test_stats():
    print("Testing statistics generation...")
    try:
        stats = obtener_estadisticas_generales()
        print("Keys found:", stats.keys())
        
        expected_keys = [
            'total_campesinos', 'total_hectareas', 'hectareas_sembradas',
            'porcentaje_sembrado', 'siembras_por_cultivo', 'hectareas_por_cultivo',
            'campesinos_sin_siembra', 'ingreso_potencial', 'ingreso_real',
            'eficiencia_recaudacion', 'hectareas_por_barrio', 'ciclo_actual'
        ]
        
        missing = [k for k in expected_keys if k not in stats]
        
        if missing:
            print(f"FAILED: Missing keys: {missing}")
            sys.exit(1)
            
        print("SUCCESS: All expected keys present.")
        print(f"Total Campesinos: {stats['total_campesinos']}")
        print(f"Ingreso Potencial: ${stats['ingreso_potencial']}")
        print(f"Ingreso Real: ${stats['ingreso_real']}")
        
    except Exception as e:
        print(f"FAILED: Exception occurred: {e}")
        sys.exit(1)

if __name__ == "__main__":
    test_stats()
